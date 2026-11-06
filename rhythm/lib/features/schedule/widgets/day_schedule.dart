import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:rhythm/core/models/schedule.dart';
import 'package:rhythm/core/theme/shapes.dart';
import 'package:rhythm/core/theme/typography.dart';
import 'package:rhythm/features/schedule/widgets/lesson_tile.dart';

/// Расписание дня: одна карточка на день.
///
/// Карточка дня — самый частый элемент экрана, поэтому у неё есть два режима:
/// полный (есть пары) и узкий (день свободен). Разная высота даёт неделе
/// ритм: занятые дни читаются сразу, пустые не съедают экран.
///
/// Внутренняя геометрия — по правилу вложенности: радиус карточки 32dp,
/// отступ тела 6dp, значит радиус пары 26dp.
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

  /// Радиус карточки дня. Крупнее обычной карточки: неделя — главный экран.
  static const double radius = AppShapes.extraLargeIncreased;

  /// Отступ между карточкой и парой внутри неё.
  static const double bodyInset = 6;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final dayName = DateFormat.EEEE('ru').format(date);
    final sortedLessons = List<ScheduleItem>.from(lessons)
      ..sort((a, b) => a.time.compareTo(b.time));

    if (sortedLessons.isEmpty) {
      return _FreeDayCard(
        date: date,
        title: _capitalize(title ?? dayName),
        isToday: isToday,
        isHighlighted: isHighlighted,
      );
    }

    final bandColor = isToday
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHigh;
    final onBand =
        isToday ? colorScheme.onPrimaryContainer : colorScheme.onSurface;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: AppShapes.circular(radius),
        border: Border.all(
          color: isHighlighted
              ? colorScheme.primary
              : colorScheme.outlineVariant.withValues(alpha: 0.35),
          width: isHighlighted ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Шапка дня ──
          // Нижние углы шапки прямые: она читается как «шапка» карточки,
          // а не как ещё одна плашка внутри неё.
          Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
            decoration: BoxDecoration(
              color: bandColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(radius - 1),
              ),
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
                        style: AppTypography.emphasizedTitleMedium(
                          theme.textTheme.titleMedium!.copyWith(color: onBand),
                        ),
                      ),
                      const Gap(2),
                      Text(
                        _daySummary(sortedLessons),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: onBand.withValues(alpha: 0.75),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isToday) ...[
                  const Gap(8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
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
              ],
            ),
          ),

          // ── Пары внутри той же карточки ──
          Padding(
            padding: const EdgeInsets.all(bodyInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < sortedLessons.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 54, right: 12),
                      child: Divider(
                        height: 1,
                        color:
                            colorScheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                  LessonTile(
                    item: sortedLessons[i],
                    radius: radius - bodyInset,
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

/// Свободный день: узкая карточка в один ряд.
///
/// Полноразмерная карточка с текстом «Пар нет» занимала столько же места,
/// сколько день с четырьмя парами, и неделя превращалась в простыню.
class _FreeDayCard extends StatelessWidget {
  const _FreeDayCard({
    required this.date,
    required this.title,
    required this.isToday,
    required this.isHighlighted,
  });

  final DateTime date;
  final String title;
  final bool isToday;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: AppShapes.circular(AppShapes.extraLarge),
        border: Border.all(
          color: isHighlighted
              ? colorScheme.primary
              : colorScheme.outlineVariant.withValues(alpha: 0.35),
          width: isHighlighted ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          _DateBadge(date: date, isToday: isToday, size: 40, radius: 14),
          const Gap(12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.emphasizedLabelLarge(
                theme.textTheme.labelLarge!.copyWith(
                  color: isToday ? colorScheme.primary : colorScheme.onSurface,
                ),
              ),
            ),
          ),
          const Gap(8),
          Icon(
            Icons.free_breakfast_outlined,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
          const Gap(6),
          Text(
            'Пар нет',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Дата: число крупно, месяц под ним мелким капсом.
class _DateBadge extends StatelessWidget {
  const _DateBadge({
    required this.date,
    required this.isToday,
    this.size = 52,
    this.radius = AppShapes.largeIncreased,
  });

  final DateTime date;
  final bool isToday;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isToday ? colorScheme.primary : colorScheme.surface,
        borderRadius: AppShapes.circular(radius),
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
                fontSize: size >= 48 ? null : 16,
              ),
            ),
          ),
          Text(
            DateFormat('MMM', 'ru').format(date).replaceAll('.', ''),
            style: theme.textTheme.labelSmall?.copyWith(
              color: isToday
                  ? colorScheme.onPrimary.withValues(alpha: 0.85)
                  : colorScheme.onSurfaceVariant,
              fontSize: 9,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// «2 пары · 10:00–13:30» — количество и общий размах дня.
String _daySummary(List<ScheduleItem> lessons) {
  final count = lessons.length;
  final head = '$count ${_lessonsWord(count)}';
  final range = _timeRange(lessons);
  return range == null ? head : '$head · $range';
}

String? _timeRange(List<ScheduleItem> lessons) {
  String? start;
  String? end;
  for (final lesson in lessons) {
    final parts = lesson.time.split('-');
    if (parts.length < 2) continue;
    start ??= parts.first.trim();
    end = parts.last.trim();
  }
  if (start == null || end == null) return null;
  return '$start–$end';
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
