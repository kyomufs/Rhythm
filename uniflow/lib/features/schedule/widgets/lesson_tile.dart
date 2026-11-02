import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:uniflow/core/models/schedule.dart';
import 'package:uniflow/core/providers/clock_provider.dart';
import 'package:uniflow/core/theme/app_theme.dart';
import 'package:uniflow/core/theme/shapes.dart';

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

  const LessonTile({
    super.key,
    required this.item,
    this.onTap,
    this.showDate = false,
    this.isCompact = false,
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

    return InkWell(
      onTap: onTap,
      borderRadius: AppShapes.circular(AppShapes.large),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 12 : 16,
          vertical: isCompact ? 10 : 14,
        ),
        decoration: isOngoing
            ? BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.06),
                border: Border.all(color: colorScheme.primary, width: 1.5),
                borderRadius: AppShapes.circular(AppShapes.large),
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
                      fontFamily: 'Rubik',
                      fontSize: 9.5,
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
                        children: [
                          // Time badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: lessonColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.time,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: lessonColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Spacer(),
                          // Classroom / corpus
                          if (item.classroom.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
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
                                    style:
                                        theme.textTheme.labelMedium?.copyWith(
                                      color: colorScheme.onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
                      // Countdown to today's upcoming lesson start
                      if (isUpcomingToday) ...[
                        const Gap(8),
                        _UpcomingCountdown(lesson: item),
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
        borderRadius: BorderRadius.circular(10),
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
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor:
                  colorScheme.onPrimaryContainer.withValues(alpha: 0.15),
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tonal countdown block shown under the teacher while today's lesson
/// hasn't started yet: clock icon + exact "До начала пары" countdown
/// (secondary tonal colors — quieter than the ongoing primary card).
class _UpcomingCountdown extends ConsumerWidget {
  final ScheduleItem lesson;

  const _UpcomingCountdown({required this.lesson});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = ref.watch(clockProvider);
    final left = lesson.timeUntilStartAt(now);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.watch_later_outlined,
              size: 15, color: colorScheme.onSecondaryContainer),
          const Gap(6),
          Expanded(
            child: Text(
              'До начала пары — ${formatCountdown(left)}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
