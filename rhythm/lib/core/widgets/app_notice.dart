import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rhythm/core/theme/motion.dart';
import 'package:rhythm/core/theme/shapes.dart';
import 'package:rhythm/core/theme/typography.dart';

/// Тон плашки: успех или ошибка.
enum AppNoticeTone { success, error }

/// Всплывающее уведомление поверх всего интерфейса.
///
/// `SnackBar` живёт внутри `Scaffold`, поэтому его перекрывают нижняя
/// навигация, модальные шторки и диалоги — именно из-за этого «расписание
/// обновлено» не было видно. Overlay рисует плашку над всем деревом, так что
/// её видно с любого экрана и она не зависит от того, какой Scaffold сейчас
/// на вершине.
class AppNotice {
  AppNotice._();

  static OverlayEntry? _entry;

  /// Показать плашку. Новая вытесняет предыдущую, не дожидаясь её таймера.
  static void show(
    BuildContext context, {
    required String message,
    AppNoticeTone tone = AppNoticeTone.success,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (message.isEmpty) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _entry?.remove();
    _entry = null;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _NoticeLayer(
        message: message,
        tone: tone,
        duration: duration,
        onDismissed: () {
          if (_entry == entry) _entry = null;
          if (entry.mounted) entry.remove();
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  /// Убрать плашку досрочно (например, при выходе с экрана).
  static void dismiss() {
    _entry?.remove();
    _entry = null;
  }
}

class _NoticeLayer extends StatefulWidget {
  const _NoticeLayer({
    required this.message,
    required this.tone,
    required this.duration,
    required this.onDismissed,
  });

  final String message;
  final AppNoticeTone tone;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_NoticeLayer> createState() => _NoticeLayerState();
}

class _NoticeLayerState extends State<_NoticeLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController.unbounded(
    vsync: this,
    value: 0,
  );
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    // Старт сразу, без post-frame: пружина всё равно стартует с 0 и даёт
    // первый тик на следующем кадре, а отложенный старт оставлял плашку
    // невидимой один лишний кадр.
    _controller.animateWithSpring(MotionTokens.defaultSpatial, to: 1);
    _timer = Timer(widget.duration, _close);
  }

  void _close() {
    if (_closing || !mounted) return;
    _closing = true;
    _timer?.cancel();
    _controller
        .animateWithSpring(MotionTokens.standardFastSpatial, to: 0)
        .whenComplete(() {
      if (mounted) widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSuccess = widget.tone == AppNoticeTone.success;
    final background =
        isSuccess ? colorScheme.inverseSurface : colorScheme.errorContainer;
    final foreground =
        isSuccess ? colorScheme.onInverseSurface : colorScheme.onErrorContainer;
    final accent = isSuccess ? colorScheme.inversePrimary : colorScheme.error;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final t = _controller.value.clamp(0.0, 1.0);
                return Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, -28 * (1 - t)),
                    child: Transform.scale(
                      scale: 0.94 + 0.06 * t,
                      child: child,
                    ),
                  ),
                );
              },
              child: Semantics(
                liveRegion: true,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Material(
                    color: background,
                    elevation: 3,
                    borderRadius:
                        AppShapes.circular(AppShapes.extraLargeIncreased),
                    child: InkWell(
                      onTap: _close,
                      borderRadius:
                          AppShapes.circular(AppShapes.extraLargeIncreased),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 18, 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isSuccess
                                    ? Icons.check_circle_rounded
                                    : Icons.error_outline,
                                size: 20,
                                color: accent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                widget.message,
                                style: AppTypography.emphasizedLabelLarge(
                                  theme.textTheme.labelLarge!
                                      .copyWith(color: foreground),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
