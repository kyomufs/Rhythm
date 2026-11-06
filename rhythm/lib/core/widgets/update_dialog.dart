import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:rhythm/core/services/update_service.dart';
import 'package:rhythm/shared/widgets/wavy_progress.dart';

/// Shows the app-update flow dialog: "update available" → download with
/// a progress bar → system install prompt.
///
/// [currentVersion] is displayed for the "1.0.0 →1.1.0" comparison line.
void showUpdateDialog(BuildContext context, UpdateService service,
    UpdateInfo info, String currentVersion) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _UpdateDialog(
      service: service,
      info: info,
      currentVersion: currentVersion,
    ),
  );
}

class _UpdateDialog extends StatefulWidget {
  final UpdateService service;
  final UpdateInfo info;
  final String currentVersion;

  const _UpdateDialog({
    required this.service,
    required this.info,
    required this.currentVersion,
  });

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

enum _UpdatePhase { offer, downloading, failed }

class _UpdateDialogState extends State<_UpdateDialog> {
  _UpdatePhase _phase = _UpdatePhase.offer;
  double _progress = 0;

  Future<void> _startDownload() async {
    setState(() {
      _phase = _UpdatePhase.downloading;
      _progress = 0;
    });
    try {
      final path = await widget.service.download(widget.info, (value) {
        if (mounted) setState(() => _progress = value);
      });
      if (!mounted) return;
      // Hand the APK to the system installer first ("Install this app?"
      // opens over the app), then close the dialog. If the install call
      // throws, the dialog stays and switches to the failed phase.
      await widget.service.installApk(path);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _phase = _UpdatePhase.failed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Text('Доступно обновление ${widget.info.version}'),
      content: switch (_phase) {
        _UpdatePhase.offer => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'У вас установлена версия ${widget.currentVersion}. '
                'Скачать ${widget.info.version}?',
              ),
              const Gap(6),
              Text(
                'После скачивания система предложит установить обновление.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        _UpdatePhase.downloading => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WavyProgressIndicator(value: _progress, height: 8, strokeWidth: 3),
              const Gap(10),
              Text(
                'Скачивание… ${(_progress * 100).round()}%',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        _UpdatePhase.failed => const Text(
            'Не удалось скачать обновление. Проверьте соединение '
            'и попробуйте позже.',
          ),
      },
      actions: switch (_phase) {
        _UpdatePhase.offer => [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Позже'),
            ),
            FilledButton(
              onPressed: _startDownload,
              child: const Text('Обновить'),
            ),
          ],
        _UpdatePhase.downloading => [
            const TextButton(
              onPressed: null,
              child: Text('Скачивается…'),
            ),
          ],
        _UpdatePhase.failed => [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Закрыть'),
            ),
            FilledButton(
              onPressed: _startDownload,
              child: const Text('Повторить'),
            ),
          ],
      },
    );
  }
}
