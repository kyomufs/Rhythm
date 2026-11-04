import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:uniflow/core/theme/shapes.dart';
import 'package:uniflow/core/theme/typography.dart';
import 'package:uniflow/core/utils/week_utils.dart';

/// Навигатор недели: стрелки отдельно, карточка недели отдельно.
///
/// Общий для главного экрана расписания и для превью из поиска/избранного —
/// раньше превью рисовало свою упрощённую полосу, и две «недели» в одном
/// приложении выглядели по-разному.
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final onContainer =
        isCurrentWeek ? colorScheme.onPrimaryContainer : colorScheme.onSurface;
    final muted = isCurrentWeek
        ? colorScheme.onPrimaryContainer.withValues(alpha: 0.75)
        : colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Material(
        color: isCurrentWeek
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHigh,
        borderRadius: AppShapes.circular(AppShapes.extraExtraLarge),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            _WeekArrow(
              icon: Icons.chevron_left,
              tooltip: 'Предыдущая неделя',
              onTap: onPrevWeek,
              color: onContainer,
            ),
            Expanded(
              child: InkWell(
                onTap: onOpenCalendar,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
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
                      const Gap(2),
                      Text(
                        weekInfo.dateRangeShort,
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _WeekArrow(
              icon: Icons.chevron_right,
              tooltip: 'Следующая неделя',
              onTap: onNextWeek,
              color: onContainer,
            ),
          ],
        ),
      ),
    );
  }
}

/// Стрелки живут отдельно от карточки недели: своя скруглённая кнопка на
/// каждую, поэтому промахнуться мимо нужной недели сложнее.
/// Стрелка внутри общей «таблетки»: своя зона нажатия 48dp, без
/// собственной подложки — фоном служит сама таблетка.
class _WeekArrow extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;

  const _WeekArrow({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon),
      tooltip: tooltip,
      color: color,
      visualDensity: VisualDensity.compact,
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
