import 'package:flutter/material.dart';
import 'package:uniflow/core/theme/motion.dart';
import 'package:uniflow/core/theme/shapes.dart';
import 'package:uniflow/core/theme/typography.dart';

/// Сегментированный переключатель в духе M3 Expressive.
///
/// Штатный `SegmentedButton` перекрашивает сегмент мгновенно: у него нет
/// промежуточного состояния, а именно переезд «таблетки» и читается как выбор.
/// Здесь индикатор едет на spatial-пружине (`fast.spatial` — элемент мелкий,
/// поэтому самый быстрый токен), а тексты меняют только вес и цвет, то есть
/// effects-переход без перелёта.
class AppSegmentedSelector<T> extends StatefulWidget {
  const AppSegmentedSelector({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.iconOf,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final IconData? Function(T value)? iconOf;
  final ValueChanged<T> onSelected;

  /// `ContainerHeight` сегментированного переключателя в M3 — 40dp.
  static const double height = 40;

  @override
  State<AppSegmentedSelector<T>> createState() =>
      _AppSegmentedSelectorState<T>();
}

class _AppSegmentedSelectorState<T> extends State<AppSegmentedSelector<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _position = AnimationController.unbounded(
    vsync: this,
    value: widget.values.indexOf(widget.selected).toDouble(),
  );

  @override
  void didUpdateWidget(AppSegmentedSelector<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = widget.values.indexOf(widget.selected).toDouble();
    if (target < 0 || target == _position.value) return;
    _position.animateWithSpring(
      MediaQuery.disableAnimationsOf(context)
          ? MotionTokens.standardFastSpatial
          : MotionTokens.fastSpatial,
      to: target,
      velocity: _position.velocity,
    );
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final count = widget.values.length;
    if (count == 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final segmentWidth = constraints.maxWidth / count;
        return Container(
          height: AppSegmentedSelector.height,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            // Полный радиус: сегменты — это «таблетки» внутри «таблетки».
            borderRadius: AppShapes.circular(AppSegmentedSelector.height / 2),
          ),
          child: Stack(
            children: [
              // Индикатор выбора.
              AnimatedBuilder(
                animation: _position,
                builder: (context, _) {
                  final index =
                      _position.value.clamp(0.0, count.toDouble() - 1);
                  return Positioned(
                    key: const ValueKey('segment-indicator'),
                    left: index * segmentWidth,
                    top: 0,
                    bottom: 0,
                    width: segmentWidth,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: AppShapes.circular(
                            (AppSegmentedSelector.height - 8) / 2,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              Row(
                children: [
                  for (var i = 0; i < count; i++)
                    Expanded(
                      child: _Segment(
                        label: widget.labelOf(widget.values[i]),
                        icon: widget.iconOf?.call(widget.values[i]),
                        selected: widget.values[i] == widget.selected,
                        onTap: () => widget.onSelected(widget.values[i]),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color =
        selected ? colorScheme.onSecondaryContainer : colorScheme.onSurfaceVariant;
    final textStyle = theme.textTheme.labelLarge!.copyWith(color: color);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // Выбор — это акцент, поэтому выбранный сегмент получает
                  // emphasized-начертание, а не только цвет.
                  style: selected
                      ? AppTypography.emphasizedLabelLarge(textStyle)
                      : textStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
