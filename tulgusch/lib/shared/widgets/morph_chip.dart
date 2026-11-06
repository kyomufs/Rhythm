import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:tulgusch/core/theme/motion.dart';
import 'package:tulgusch/core/theme/shapes.dart';
import 'package:tulgusch/core/theme/typography.dart';

/// Чип с морфом формы — экспрессивная замена `FilterChip`.
///
/// В M3E выбранный чип не просто заливается цветом: он перетекает из
/// таблетки в прямоугольник и обратно. Штатный `FilterChip` красит форму
/// мгновенно, поэтому морф здесь собран вручную:
/// spatial-пружина ведёт форму, effects-пружина — заливку и цвет текста.
class MorphChip extends StatefulWidget {
  const MorphChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.semanticLabel,
    this.isFirst = true,
    this.isLast = true,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  /// Для случая, когда на экране не одно такое кольцо выбора.
  final String? semanticLabel;

  /// Крайние чипы держат круглый торец связки, как у связной группы.
  final bool isFirst;
  final bool isLast;

  @override
  State<MorphChip> createState() => _MorphChipState();
}

class _MorphChipState extends State<MorphChip> with TickerProviderStateMixin {
  late final AnimationController _morph =
      AnimationController.unbounded(vsync: this);
  late final AnimationController _fill =
      AnimationController.unbounded(vsync: this);
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _morph.value = widget.selected ? 1 : 0;
    _fill.value = widget.selected ? 1 : 0;
  }

  @override
  void didUpdateWidget(MorphChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected == widget.selected) return;
    final to = widget.selected ? 1.0 : 0.0;

    // Reduce-motion: состояние меняется без перелёта.
    if (MediaQuery.disableAnimationsOf(context)) {
      _morph.value = to;
      _fill.value = to;
      return;
    }

    final scheme = MotionScheme.of(context);
    // Перелёт формы гаснет коротко: чип маленький, длинная пружина на нём
    // читается как дрожание.
    _morph.animateWithSpring(
      scheme.fastSpatial,
      to: to,
      velocity: _morph.velocity,
    );
    _fill.animateWithSpring(
      scheme.fastEffects,
      to: to,
      velocity: _fill.velocity,
    );
  }

  @override
  void dispose() {
    _morph.dispose();
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: Listenable.merge([_morph, _fill]),
      builder: (context, _) {
        final morph = _morph.value.clamp(0.0, 1.0);
        final fill = _fill.value.clamp(0.0, 1.0);

        // Связка как у группы кнопок: внешний торец ленты круглый, все
        // стыки внутри — малый радиус, выбранный чип вынимается в таблетку.
        const pill = AppShapes.extraLargeIncreased;
        final restLeft = widget.isFirst ? pill : AppShapes.small;
        final restRight = widget.isLast ? pill : AppShapes.small;
        final left = ui.lerpDouble(restLeft, pill, morph)!;
        final right = ui.lerpDouble(restRight, pill, morph)!;
        // Та же пара, что у связной группы кнопок: тихая заливка → primary.
        // Обводки нет — выбранный чип отличается заливкой и формой, а не
        // рамкой, иначе лента семестров снова читается как набор outlined-chip.
        final background = Color.lerp(
          colorScheme.surfaceContainerHighest,
          colorScheme.primary,
          fill,
        )!;
        final foreground = Color.lerp(
          colorScheme.onSurfaceVariant,
          colorScheme.onPrimary,
          fill,
        )!;

        return Semantics(
          button: true,
          selected: widget.selected,
          inMutuallyExclusiveGroup: true,
          label: widget.semanticLabel,
          child: Material(
            color: background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(left),
                bottomLeft: Radius.circular(left),
                topRight: Radius.circular(right),
                bottomRight: Radius.circular(right),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) {
                  return foreground.withValues(alpha: 0.10);
                }
                return null;
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: 16, color: foreground),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      widget.label,
                      maxLines: 1,
                      style: widget.selected
                          ? AppTypography.emphasizedLabelLarge(
                              theme.textTheme.labelLarge!
                                  .copyWith(color: foreground),
                            )
                          : theme.textTheme.labelLarge!
                              .copyWith(color: foreground),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
