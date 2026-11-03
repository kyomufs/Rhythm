import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:uniflow/core/models/schedule.dart';
import 'package:uniflow/core/theme/shapes.dart';
import 'package:uniflow/features/schedule/widgets/lesson_tile.dart';

/// Day schedule widget: ONE card per day (MD3).
///
/// Header (date, weekday, lesson count) is part of the same card,
/// lessons are separated by inset dividers (outline-variant).
class DaySchedule extends StatelessWidget {
  final DateTime date;
  final List<ScheduleItem> lessons;
  final String? title;
  final bool isToday;
  final bool isHighlighted;
  final ValueChanged<ScheduleItem>? onLessonClick;

  const DaySchedule({
    super.key,
    required this.date,
    required this.lessons,
    this.title,
    this.isToday = false,
    this.isHighlighted = false,
    this.onLessonClick,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Format date
    final dayName = DateFormat.EEEE('ru').format(date);
    final dateStr = DateFormat('d MMMM', 'ru').format(date);

    // Sort lessons by time
    final sortedLessons = List<ScheduleItem>.from(lessons)
      ..sort((a, b) => a.time.compareTo(b.time));

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: AppShapes.circular(AppShapes.largeIncreased),
        side: BorderSide(
          color: isHighlighted
              ? colorScheme.primary
              : colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: isHighlighted ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Day header (same card) ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isHighlighted
                  ? colorScheme.primaryContainer.withValues(alpha: 0.55)
                  : isToday
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainer,
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
            ),
            child: Row(
              children: [
                // Day number pill
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isToday
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      DateFormat('d').format(date),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isToday
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const Gap(12),
                // Day info — день недели и дата в одну строку: две строки
                // в шапке карточки съедали высоту без пользы.
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: _capitalize(title ?? dayName),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: isToday || isHighlighted
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: '  $dateStr',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: isToday || isHighlighted
                              ? colorScheme.onPrimaryContainer
                                  .withValues(alpha: 0.8)
                              : colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Lesson count badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isToday || isHighlighted
                        ? colorScheme.onPrimary.withValues(alpha: 0.14)
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${lessons.length} пар',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isToday || isHighlighted
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Lessons inside the same card ──
          if (sortedLessons.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Нет занятий',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ),
            )
          else
            // Внутренний отступ 4: радиус пары = радиус дня − отступ
            // (20 − 4 = 16), поэтому скругление первой и последней пары
            // повторяет скругление карточки, а не спорит с ним.
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < sortedLessons.length; i++) ...[
                    if (i > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 54, right: 12),
                        child: Divider(
                          color:
                              colorScheme.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                    LessonTile(
                      item: sortedLessons[i],
                      onTap: onLessonClick != null
                          ? () => onLessonClick!(sortedLessons[i])
                          : null,
                      isCompact: true,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Week schedule widget
class WeekSchedule extends StatelessWidget {
  final Map<DateTime, List<ScheduleItem>> scheduleByDay;
  final DateTime? currentDay;
  final ValueChanged<ScheduleItem>? onLessonClick;

  const WeekSchedule({
    super.key,
    required this.scheduleByDay,
    this.currentDay,
    this.onLessonClick,
  });

  @override
  Widget build(BuildContext context) {
    final sortedDays = scheduleByDay.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sortedDays.length,
      itemBuilder: (context, index) {
        final date = sortedDays[index];
        final lessons = scheduleByDay[date]!;
        final isToday = currentDay != null &&
            date.year == currentDay!.year &&
            date.month == currentDay!.month &&
            date.day == currentDay!.day;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: DaySchedule(
            date: date,
            lessons: lessons,
            isToday: isToday,
            onLessonClick: onLessonClick,
          ),
        );
      },
    );
  }
}

/// «понедельник» → «Понедельник»: `DateFormat.EEEE` отдаёт имя со строчной.
String _capitalize(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}
