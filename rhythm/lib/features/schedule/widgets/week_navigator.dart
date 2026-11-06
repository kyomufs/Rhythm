import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:rhythm/core/theme/shapes.dart';
import 'package:rhythm/core/theme/typography.dart';
import 'package:rhythm/core/utils/week_utils.dart';

/// Навигатор недели в форме разрезной кнопки: `< неделя >`.
///
/// Стрелки — отдельные сегменты через 2dp шва, поэтому промахнуться мимо
/// нужной недели сложнее, а центр остаётся одной большой кнопкой «открыть
/// календарь». Общий для главного экрана расписания и для превью из
/// поиска/избранного: раньше превью рисовало свою упрощённую полосу, и две
/// «недели» в одном приложении выглядели по-разному.
class WeekNavigatorBar extends StatelessWidget {
  final WeekInfo weekInfo;
  final bool isCurrentWeek;
  final VoidCallback onPrevWeek;
  final VoidCallback onNextWeek;

  /// Тап по карточке недели. В превью календарь не нужен — тогда null.
  final VoidCallback? onOpenCalendar;

  const WeekNavigatorBar({
    super.key,
    required this.weekInfo,
    required this.isCurrentWeek,
    required this.onPrevWeek,
    required this.onNextWeek,
    this.onOpenCalendar,
  });

  /// Высота сегмента: M-размер кнопок, два ряда текста внутри.
  static const double _height = 56;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final fill = isCurrentWeek
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHigh;
    final onContainer =
        isCurrentWeek ? colorScheme.onPrimaryContainer : colorScheme.onSurface;
    final muted = isCurrentWeek
        ? colorScheme.onPrimaryContainer.withValues(alpha: 0.75)
        : colorScheme.onSurfaceVariant;

    // Внешние углы — полные (таблетка), внутренние — 4dp из спеки split button
    // для размера M; 2dp шва между сегментами.
    const outer = Radius.circular(_height / 2);
    const inner = Radius.circular(AppShapes.extraSmall);
    const arrowWidth = _height;
    const arrowShape = BorderRadius.horizontal(left: outer, right: inner);
    const arrowShapeRight = BorderRadius.horizontal(left: inner, right: outer);
    const centerShape = BorderRadius.all(inner);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: SizedBox(
        height: _height,
        child: Row(
          children: [
            _WeekArrow(
              icon: Icons.chevron_left,
              tooltip: 'Предыдущая неделя',
              onTap: onPrevWeek,
              color: onContainer,
              background: fill,
              borderRadius: arrowShape,
              width: arrowWidth,
            ),
            const Gap(2),
            Expanded(
              child: Material(
                color: fill,
                borderRadius: centerShape,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onOpenCalendar,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // На 320dp «Неделя 46» + чип не влезают: текст
                            // сжимается, чип остаётся целиком.
                            Flexible(
                              child: Text(
                                'Неделя ${weekInfo.weekNumber}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.emphasizedTitleSmall(
                                  theme.textTheme.titleSmall!
                                      .copyWith(color: onContainer),
                                ),
                              ),
                            ),
                            const Gap(6),
                            _ParityChip(
                              isEven: weekInfo.isEven,
                              onContainer: isCurrentWeek,
                            ),
                          ],
                        ),
                        const Gap(1),
                        Text(
                          weekInfo.dateRangeShort,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium
                              ?.copyWith(color: muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Gap(2),
            _WeekArrow(
              icon: Icons.chevron_right,
              tooltip: 'Следующая неделя',
              onTap: onNextWeek,
              color: onContainer,
              background: fill,
              borderRadius: arrowShapeRight,
              width: arrowWidth,
            ),
          ],
        ),
      ),
    );
  }
}

/// Стрелка — отдельный сегмент разрезной кнопки: своя подложка, свой радиус,
/// своя зона нажатия 56×56. Фоном служит тот же контейнер, что и у центра,
/// поэтому полоса читается единым компонентом.
class _WeekArrow extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;
  final Color background;
  final BorderRadius borderRadius;
  final double width;

  const _WeekArrow({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.color,
    required this.background,
    required this.borderRadius,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width,
      child: Material(
        color: background,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Tooltip(
            message: tooltip,
            child: Center(child: Icon(icon, color: color)),
          ),
        ),
      ),
    );
  }
}

class _ParityChip extends StatelessWidget {
  final bool isEven;
  final bool onContainer;

  const _ParityChip({required this.isEven, required this.onContainer});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final background = onContainer
        ? colorScheme.onPrimaryContainer.withValues(alpha: 0.12)
        : colorScheme.secondaryContainer;
    final foreground = onContainer
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppShapes.circular(AppShapes.small),
      ),
      child: Text(
        isEven ? 'чётная' : 'нечётная',
        style: theme.textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
