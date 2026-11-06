import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:rhythm/core/domain/source.dart';
import 'package:rhythm/integrations/catalog.dart';
import 'package:rhythm/core/sources/source_store.dart';
import 'package:rhythm/core/theme/spacing.dart';
import 'package:rhythm/features/sources/screens/source_edit_screen.dart';

/// Пилюля активного источника в шапке.
///
/// Активный контекст должен быть виден всегда: баллы и расписание принадлежат
/// источнику, и переключение — смена контекста, а не настройка.
class SourcePill extends ConsumerWidget {
  const SourcePill({super.key, this.onLight = false, this.maxWidth = 150});

  /// На цветной шапке бейдж и текст берут цвета из `onPrimary`.
  final bool onLight;

  /// Ширина плашки: на узких шапках её приходится ужимать.
  final double maxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sources = ref.watch(sourcesProvider);
    final active = sources.active;
    if (!sources.isReady || active == null) return const SizedBox.shrink();

    final foreground =
        onLight ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;
    final background = onLight
        ? theme.colorScheme.onPrimary.withValues(alpha: 0.16)
        : theme.colorScheme.surfaceContainerHigh;

    return Tooltip(
      message: sources.hasMany ? 'Сменить источник' : 'Источник',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => showSourceSheet(context),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SourceBadge(source: active, size: 24),
              const Gap(AppSpacing.xs),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Text(
                  active.title,
                  overflow: TextOverflow.ellipsis,
                  style:
                      theme.textTheme.labelLarge?.copyWith(color: foreground),
                ),
              ),
              if (sources.hasMany) ...[
                const Gap(2),
                Icon(Icons.keyboard_arrow_down,
                    size: 18, color: foreground.withValues(alpha: 0.8)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.source, this.size = 32});

  final Source source;
  final double size;

  @override
  Widget build(BuildContext context) {
    const palette = [
      (Color(0xFF6750A4), Color(0xFFEADDFF)),
      (Color(0xFF00696D), Color(0xFFB2ECEE)),
      (Color(0xFF8B5000), Color(0xFFFFDDB3)),
      (Color(0xFF8F4A5F), Color(0xFFFFD9E2)),
      (Color(0xFF3F5F90), Color(0xFFD7E3FF)),
    ];
    final (bg, fg) = palette[source.colorIndex % palette.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(
        source.badge,
        style: TextStyle(
          color: fg,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

/// Модальный список источников: галочка активного, чипы возможностей и
/// «Добавить источник» под разделителем.
Future<void> showSourceSheet(BuildContext context) {
  final wide = MediaQuery.sizeOf(context).width >= 720;
  if (wide) {
    return showDialog<void>(
      context: context,
      builder: (_) => const Dialog(
        child: SizedBox(
          width: 420,
          height: 560,
          child: SourceSheetBody(),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const SafeArea(top: false, child: SourceSheetBody()),
  );
}

class SourceSheetBody extends ConsumerWidget {
  const SourceSheetBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(sourcesProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.xs),
          child: Text('Источники', style: theme.textTheme.titleMedium),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            children: [
              for (final source in state.sources)
                _SourceTile(
                    source: source, isActive: source.id == state.active?.id),
            ],
          ),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.add),
          title: const Text('Добавить источник'),
          onTap: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SourceEditScreen(),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SourceTile extends ConsumerWidget {
  const _SourceTile({required this.source, required this.isActive});

  final Source source;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final connector = connectorFor(source);
    final caps = connector.capabilities;
    final kind = connector.descriptor.kind;

    return ListTile(
      leading: _SourceBadge(source: source),
      title: Text(source.title, style: theme.textTheme.titleSmall),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              kind.label,
              if (source.subtitle != null && source.subtitle!.isNotEmpty)
                source.subtitle!,
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (caps.isNotEmpty) ...[
            const Gap(AppSpacing.xxs),
            Wrap(
              spacing: AppSpacing.xxs,
              runSpacing: AppSpacing.xxs,
              children: [
                for (final cap in caps) _CapabilityChip(capability: cap),
              ],
            ),
          ],
        ],
      ),
      isThreeLine: caps.isNotEmpty,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive)
            Icon(Icons.check_circle, color: theme.colorScheme.primary),
          PopupMenuButton<String>(
            tooltip: 'Ещё',
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (value) async {
              if (value == 'edit') {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SourceEditScreen(source: source),
                  ),
                );
              } else if (value == 'delete') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Удалить источник?'),
                    content: Text(
                      'Вместе с «${source.title}» удалится его журнал: '
                      'семестры, дисциплины и баллы.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Отмена'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Удалить'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true || !context.mounted) return;
                await ref.read(sourcesProvider.notifier).remove(source.id);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Изменить')),
              PopupMenuItem(value: 'delete', child: Text('Удалить')),
            ],
          ),
        ],
      ),
      onTap: () {
        ref.read(sourcesProvider.notifier).select(source.id);
        Navigator.of(context).pop();
      },
    );
  }
}

class _CapabilityChip extends StatelessWidget {
  const _CapabilityChip({required this.capability});

  final SourceCapability capability;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        sourceCapabilityLabel(capability),
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}
