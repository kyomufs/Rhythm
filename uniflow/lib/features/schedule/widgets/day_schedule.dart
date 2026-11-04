import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:uniflow/core/models/schedule.dart';
import 'package:uniflow/core/theme/shapes.dart';
import 'package:uniflow/core/theme/typography.dart';
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

    // Sort lessons by time
    final sortedLessons = List<ScheduleItem>.from(lessons)
      ..sort((a, b) => a.time.compareTo(b.time));

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: AppShapes.circular(AppShapes.extraLarge),
        side: BorderSide(
          color: isHighlighted
              ? colorScheme.primary
              : colorScheme.outlineVariant.withValues(alpha: 0.35),
          width: isHighlighted ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Шапка дня ──
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
            decoration: BoxDecoration(
              color: isHighlighted
                  ? colorScheme.primaryContainer.withValues(alpha: 0.55)
                  : isToday
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHigh,
            ),
            child: Row(
              children: [
                _DateBadge(date: date, isToday: isToday),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _capitalize(title ?? dayName),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.emphasizedLabelLarge(
                          theme.textTheme.labelLarge!.copyWith(
                            color: isToday || isHighlighted
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const Gap(2),
                      Text(
                        sortedLessons.isEmpty
                            ? 'Нет пар'
                            : '${sortedLessons.length} '
                                '${_lessonsWord(sortedLessons.length)}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: isToday || isHighlighted
                              ? colorScheme.onPrimaryContainer
                                  .withValues(alpha: 0.75)
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isToday)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius:
                          AppShapes.circular(AppShapes.extraLargeIncreased),
                    ),
                    child: Text(
                      'Сегодня',
                      style: AppTypography.emphasizedLabelSmall(
                        theme.textTheme.labelSmall!
                            .copyWith(color: colorScheme.onPrimary),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Пары внутри той же карточки ──
          // Внутренний отступ 4: радиус пары = радиус дня − отступ
          // (28 − 4 = 24), поэтому скругление первой и последней пары
          // повторяет скругление карточки, а не спорит с ним.
          if (sortedLessons.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(4),
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

/// Дата в шапке дня: число крупно, месяц под ним мелким капсом.
class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.date, required this.isToday});

  final DateTime date;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground =
        isToday ? colorScheme.onPrimary : colorScheme.onSurfaceVariant;

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isToday
            ? colorScheme.primary
            : colorScheme.surfaceContainerHighest,
        borderRadius: AppShapes.circular(AppShapes.large),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            DateFormat('d').format(date),
            style: AppTypography.emphasizedTitleMedium(
              theme.textTheme.titleMedium!.copyWith(
                color: isToday ? colorScheme.onPrimary : colorScheme.onSurface,
                height: 1.05,
              ),
            ),
          ),
          Text(
            DateFormat('MMM', 'ru').format(date).replaceAll('.', ''),
            style: theme.textTheme.labelSmall?.copyWith(
              color: foreground,
              fontSize: 9,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// «1 пара», «2 пары», «5 пар».
String _lessonsWord(int count) {
  final mod10 = count % 10;
  final mod100 = count % 100;
  if (mod10 == 1 && mod100 != 11) return 'пара';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return 'пары';
  return 'пар';
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
