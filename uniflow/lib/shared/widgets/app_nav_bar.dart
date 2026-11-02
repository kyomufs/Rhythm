import 'package:flutter/material.dart';
import 'package:uniflow/core/theme/motion.dart';
import 'package:uniflow/core/theme/shapes.dart';

/// Один пункт нижнего меню.
class AppNavDestination {
  const AppNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Нижнее меню в духе Material 3 Expressive.
///
/// Своя вёрстка вместо `NavigationBar` нужна по двум причинам: штатный виджет
/// не даёт управлять геометрией индикатора (56 × 32dp) и зазором иконка ↔
/// подпись, а на iOS контент оказывался выше нижней кромки, чем на Android.
/// Геометрия здесь повторяет `ContainerHeight` 64dp и `ContainerBetweenSpace`
/// 6dp, весь блок прижат к нижней безопасной зоне.
class AppNavBar extends StatelessWidget {
  const AppNavBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<AppNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Высота полосы без системного отступа: `ContainerHeight` 64dp.
  static const double _contentHeight = 64;

  /// Индикатор активного пункта: `ActiveIndicatorWidth` ×
  /// `ActiveIndicatorHeight` = 56 × 32dp.
  static const double _indicatorWidth = 56;
  static const double _indicatorHeight = 32;

  /// `ContainerBetweenSpace`: иконка ↔ подпись.
  static const double _iconLabelGap = 6;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Material(
      color: colorScheme.surfaceContainer,
      child: Padding(
        // Иконки прижаты к низу: сверху воздух, снизу только системный отступ.
        padding: EdgeInsets.only(
          top: 8,
          bottom: bottomInset > 0 ? bottomInset : 8,
        ),
        child: SizedBox(
          height: _contentHeight,
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _NavItem(
                    destination: destinations[i],
                    selected: i == selectedIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final AppNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController.unbounded(
    vsync: this,
    value: widget.selected ? 1 : 0,
  );

  @override
  void didUpdateWidget(_NavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      _controller.animateWithSpring(
        MediaQuery.disableAnimationsOf(context)
            ? MotionTokens.standardDefaultSpatial
            : MotionTokens.defaultSpatial,
        to: widget.selected ? 1 : 0,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // M3E: активная подпись — secondary, не onSurface.
    final activeColor = colorScheme.secondary;

    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.destination.label,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: AppShapes.circular(AppShapes.large),
        splashFactory: InkSparkle.splashFactory,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value.clamp(0.0, 1.4);
                return SizedBox(
                  height: AppNavBar._indicatorHeight,
                  child: Center(
                    child: Container(
                      // В покое индикатор уже 56dp: пружина раскрывает его
                      // из сжатого состояния, а не «наращивает» с нуля.
                      width: AppNavBar._indicatorWidth * (0.55 + 0.45 * t),
                      height: AppNavBar._indicatorHeight,
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer
                            .withValues(alpha: t.clamp(0.0, 1.0)),
                        // CornerFull: радиус = половине высоты индикатора.
                        borderRadius: AppShapes.circular(
                          AppNavBar._indicatorHeight / 2,
                        ),
                      ),
                      child: Icon(
                        widget.selected
                            ? widget.destination.selectedIcon
                            : widget.destination.icon,
                        size: 24,
                        color: Color.lerp(
                          colorScheme.onSurfaceVariant,
                          colorScheme.onSecondaryContainer,
                          t.clamp(0.0, 1.0),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppNavBar._iconLabelGap),
            Text(
              widget.destination.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
                color: widget.selected ? activeColor : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
