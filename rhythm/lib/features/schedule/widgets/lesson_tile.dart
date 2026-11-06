import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:rhythm/core/models/schedule.dart';
import 'package:rhythm/core/providers/clock_provider.dart';
import 'package:rhythm/core/theme/app_theme.dart';
import 'package:rhythm/core/theme/shapes.dart';
import 'package:rhythm/shared/widgets/press_scale.dart';
import 'package:rhythm/shared/widgets/wavy_progress.dart';

/// Lesson tile widget for displaying a single lesson.
///
/// Layout (MD3):
///   [ type ]  TIME            CORPUS
///   (vert.)  Subject
///            Teacher
///            [ ongoing countdown block ]
///
/// The content column is vertically centered against the type strip.
class LessonTile extends ConsumerWidget {
  final ScheduleItem item;
  final VoidCallback? onTap;
  final bool showDate;
  final bool isCompact;

  /// Радиус скругления плитки. Задаётся снаружи, чтобы вложенность
  /// считалась от контейнера: `radius родителя - отступ` (правило M3E).
  final double radius;

  const LessonTile({
    super.key,
    required this.item,
    this.onTap,
    this.showDate = false,
    this.isCompact = false,
    this.radius = AppShapes.extraLarge - 4,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final lessonColor = AppTheme.getColor(item.cssClass);

    // Live clock: highlight the ongoing lesson and show time left.
    // Only minute resolution matters here — the second-precise text is
    // rendered by the countdown blocks below, so the tile (and every
    // other card of the week) does not rebuild on each second tick.
    final now = ref.watch(
      clockProvider.select(
        (t) => DateTime(t.year, t.month, t.day, t.hour, t.minute),
      ),
    );
    final isOngoing = item.isOngoingAt(now);

    // Upcoming today's lesson: countdown to its start (same tone of
    // "time left" UX as the ongoing block, but quieter colors).
    final startAt = item.startsAt;
    final isUpcomingToday = !isOngoing &&
        startAt != null &&
        startAt.isAfter(now) &&
        startAt.year == now.year &&
        startAt.month == now.month &&
        startAt.day == now.day;

    return PressScale(
      onTap: onTap,
      borderRadius: AppShapes.circular(radius),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 12 : 16,
          vertical: isCompact ? 10 : 14,
        ),
        decoration: isOngoing
            ? BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.07),
                border: Border.all(color: colorScheme.primary, width: 1.5),
                borderRadius: AppShapes.circular(radius),
              )
            : null,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Vertical type strip (left) ──
              Container(
                width: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: lessonColor.withValues(alpha: 0.12),
                  borderRadius: AppShapes.circular(AppShapes.small),
                ),
                child: RotatedBox(
                  quarterTurns: -1,
                  child: Text(
                    (item.type.isEmpty
                            ? item.lessonType.displayName
                            : shortLessonType(item.type,
                                cssClass: item.cssClass))
                        .toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: lessonColor,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const Gap(12),
              // ── Content (vertically centered) ──
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: time (left) + corpus/classroom (right)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Группа «время + счётчик» ужимается целиком: в
                          // узкой карточке она не выталкивает аудиторию за
                          // границу ряда.
                          Flexible(
                            flex: 3,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Time badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          lessonColor.withValues(alpha: 0.12),
                                      borderRadius: AppShapes.circular(
                                        AppShapes.small,
                                      ),
                                    ),
                                    child: Text(
                                      item.time,
                                      style:
                                          theme.textTheme.labelMedium?.copyWith(
                                        color: lessonColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  // Обратный отсчёт до начала — прямо в
                                  // строке времени: в свёрнутой карточке это
                                  // факт, а не второй блок контента.
                                  if (isUpcomingToday) ...[
                                    const Gap(6),
                                    _UpcomingPill(lesson: item),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          // Classroom / corpus: остаток строки, длинный
                          // номер аудитории обрезается, а не ломает ряд.
                          if (item.classroom.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              flex: 2,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest,
                                    borderRadius:
                                        AppShapes.circular(AppShapes.small),
                                  ),
                                  // Длинный номер аудитории в узкой паре
                                  // ужимается целиком, а не ломает ряд.
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.location_on_outlined,
                                          size: 13,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                        const Gap(4),
                                        Text(
                                          item.classroom,
                                          maxLines: 1,
                                          softWrap: false,
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                            color: colorScheme.onSurface,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const Gap(8),
                      // Subject
                      Text(
                        item.subject,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Teacher
                      if (item.teacher.isNotEmpty) ...[
                        const Gap(4),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 15,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const Gap(4),
                            Expanded(
                              child: Text(
                                item.teacher,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      // Ongoing countdown block (under the teacher)
                      if (isOngoing) ...[
                        const Gap(8),
                        _OngoingCountdown(lesson: item),
                      ],
                      // Groups (only for full-size tile)
                      if (!isCompact && item.groups.isNotEmpty) ...[
                        const Gap(8),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: item.groups.map((group) {
                            return Chip(
                              label: Text(
                                group.displayName,
                                style: theme.textTheme.labelSmall,
                              ),
                              backgroundColor:
                                  colorScheme.surfaceContainerHighest,
                              padding: EdgeInsets.zero,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact lesson tile for list view
class CompactLessonTile extends StatelessWidget {
  final ScheduleItem item;
  final VoidCallback? onTap;

  const CompactLessonTile({
    super.key,
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LessonTile(
      item: item,
      onTap: onTap,
      isCompact: true,
    );
  }
}

/// Full-width "time left" block shown under the teacher while the lesson
/// is running: timer icon + exact countdown + elapsed-progress bar
/// (M3 tonal card).
///
/// Watches the one-second clock itself, so the ticking digits repaint
/// without rebuilding the surrounding lesson tile.
class _OngoingCountdown extends ConsumerWidget {
  final ScheduleItem lesson;

  const _OngoingCountdown({required this.lesson});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = ref.watch(clockProvider);
    final left = lesson.timeLeftAt(now);

    final start = lesson.startsAt;
    final end = lesson.endsAt;
    var progress = 0.0;
    if (start != null && end != null) {
      final totalSeconds = end.difference(start).inSeconds;
      if (totalSeconds > 0) {
        progress =
            ((totalSeconds - left.inSeconds) / totalSeconds).clamp(0.0, 1.0);
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: AppShapes.circular(AppShapes.medium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timer_outlined,
                  size: 15, color: colorScheme.onPrimaryContainer),
              const Gap(6),
              Expanded(
                child: Text(
                  'До конца пары — ${formatCountdown(left)}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const Gap(6),
          // Волнистый индикатор: прямая полоса в экспрессивной теме читается
          // как служебный прогресс, а пара идёт прямо сейчас — это главный
          // момент экрана.
          WavyProgressIndicator(
            value: progress,
            color: colorScheme.onPrimaryContainer,
            trackColor: colorScheme.onPrimaryContainer.withValues(alpha: 0.15),
            height: 8,
            strokeWidth: 3,
            wavelength: 12,
          ),
        ],
      ),
    );
  }
}

/// Пилюля «через 12:30» в строке времени свёрнутой карточки.
///
/// Часы:минуты:секунды вместо фразы «До начала пары — 12 мин 30 с»: тикающие
/// секунды — единственный живой элемент недельного списка, но двухстрочная
/// плашка во всю ширину отнимала у предмета целую строку. Свои часы — чтобы
/// перерисовывалась только пилюля, а не вся карточка и соседние за ней.
class _UpcomingPill extends ConsumerWidget {
  final ScheduleItem lesson;

  const _UpcomingPill({required this.lesson});

  /// Компактный формат: `12:30`, от часа — `1:05:20`.
  String _left(Duration remaining) {
    final total = remaining.isNegative ? Duration.zero : remaining;
    final hours = total.inHours;
    final minutes = total.inMinutes.remainder(60);
    final seconds = total.inSeconds.remainder(60);
    String two(int value) => value.toString().padLeft(2, '0');
    if (hours > 0) return '$hours:${two(minutes)}:${two(seconds)}';
    return '$minutes:${two(seconds)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = ref.watch(clockProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: AppShapes.circular(AppShapes.extraLarge),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.play_arrow_rounded,
            size: 13,
            color: colorScheme.onSecondaryContainer,
          ),
          const Gap(2),
          Text(
            _left(lesson.timeUntilStartAt(now)),
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
