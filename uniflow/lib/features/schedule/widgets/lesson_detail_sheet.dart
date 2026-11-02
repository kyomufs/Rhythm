import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:uniflow/core/models/schedule.dart';
import 'package:uniflow/core/providers/clock_provider.dart';
import 'package:uniflow/core/theme/app_theme.dart';
import 'package:uniflow/core/theme/shapes.dart';
import 'package:uniflow/features/schedule/providers/schedule_provider.dart';

/// Opens the MD3 lesson detail bottom sheet.
///
/// Shared by the main schedule screen and the read-only preview
/// (search results / favorites).
void showLessonDetailSheet(BuildContext context, ScheduleItem lesson) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => LessonDetailSheet(lesson: lesson),
  );
}

/// Lesson Detail Sheet — layout: type=ЛВ, time=ПВ, date=ПН
///
/// Drag handle comes from the global `bottomSheetTheme.showDragHandle`,
/// so it must not be drawn manually here.
class LessonDetailSheet extends ConsumerWidget {
  final ScheduleItem lesson;

  const LessonDetailSheet({super.key, required this.lesson});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final lessonColor = AppTheme.getColor(lesson.cssClass);

    // Live clock: banner while the lesson is running. Minute resolution
    // is enough to pick the banner; the exact seconds are rendered by the
    // banner itself from the one-second clock.
    final now = ref.watch(
      clockProvider.select(
        (t) => DateTime(t.year, t.month, t.day, t.hour, t.minute),
      ),
    );
    final isOngoing = lesson.isOngoingAt(now);

    // Countdown for today's lesson that hasn't started yet.
    final startAt = lesson.startsAt;
    final isUpcomingToday = !isOngoing &&
        startAt != null &&
        startAt.isAfter(now) &&
        startAt.year == now.year &&
        startAt.month == now.month &&
        startAt.day == now.day;

    // API отдаёт GROUPS только те группы, по которым шёл запрос: при поиске
    // по своей группе список состоит из неё же, и подпись «Группы» с одной
    // строкой ничего не сообщает. Такие списки показываем только когда в них
    // действительно есть другие группы.
    final ownGroup = ref.watch(
      scheduleScreenProvider.select((s) => s.currentGroup),
    );
    final visibleGroups = lesson.groups.length == 1 &&
            ownGroup != null &&
            lesson.groups.single.number == ownGroup
        ? const <GroupInfo>[]
        : lesson.groups;

    // Latest journal entry describing exactly this lesson.
    final changeRecord = ref.watch(scheduleScreenProvider
        .select((s) => s.latestChangeFor(lesson.fingerprintRow)));
    final changeNote = changeRecord?.summaryNote;

    // Date parts (DD.MM.YYYY)
    DateTime? parsedDate;
    try {
      parsedDate = lesson.parsedDate;
    } catch (_) {
      parsedDate = null;
    }
    final dateStr = parsedDate != null
        ? DateFormat('d MMMM', 'ru').format(parsedDate)
        : lesson.date;
    final weekdayStr =
        parsedDate != null ? DateFormat.EEEE('ru').format(parsedDate) : '';

    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 8, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Шапка: дата и день недели по центру ──
          Center(
            child: Column(
              children: [
                if (weekdayStr.isNotEmpty)
                  Text(
                    weekdayStr,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: lessonColor,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                const Gap(2),
                Text(
                  dateStr,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Gap(18),

          // ── Предмет по центру ──
          Text(
            lesson.subject,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          const Gap(8),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: lessonColor.withValues(alpha: 0.12),
                borderRadius: AppShapes.circular(AppShapes.small),
              ),
              child: Text(
                lesson.type.isEmpty
                    ? lesson.lessonType.displayName
                    : lesson.type,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: lessonColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const Gap(16),

          // ── Время и корпус по бокам, между ними — тихая линия ──
          Row(
            children: [
              _MetaPill(
                icon: Icons.schedule,
                text: lesson.time,
                background: lessonColor.withValues(alpha: 0.12),
                foreground: lessonColor,
              ),
              Expanded(
                child: Divider(
                  indent: 12,
                  endIndent: 12,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              if (lesson.classroom.isNotEmpty)
                _MetaPill(
                  icon: Icons.location_on_outlined,
                  text: lesson.classroom,
                  background: colorScheme.surfaceContainerHighest,
                  foreground: colorScheme.onSurface,
                ),
            ],
          ),

          if (changeNote != null) ...[
            const Gap(14),
            _ChangeBanner(note: changeNote),
          ],

          if (isOngoing) ...[
            const Gap(14),
            _OngoingBanner(lesson: lesson),
          ],

          if (isUpcomingToday) ...[
            const Gap(14),
            _UpcomingBanner(lesson: lesson),
          ],

          const Gap(16),
          Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
          const Gap(14),

          // ── Остальное: преподаватель и группы по центру ──
          if (lesson.teacher.isNotEmpty)
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 17,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const Gap(6),
                  Flexible(
                    child: Text(
                      lesson.teacher,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (visibleGroups.isNotEmpty) ...[
            const Gap(12),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: visibleGroups.map((group) {
                  return Chip(
                    label: Text(group.displayName,
                        style: theme.textTheme.labelSmall),
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    side: BorderSide.none,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ),
          ],
          const Gap(8),
        ],
      ),
    );
  }
}

/// Full-width banner shown while the lesson is running: highlights the
/// card and shows exactly how much time is left until it ends.
class _OngoingBanner extends ConsumerWidget {
  final ScheduleItem lesson;

  const _OngoingBanner({required this.lesson});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = ref.watch(clockProvider);
    final left = lesson.timeLeftAt(now);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.timelapse,
              size: 20, color: colorScheme.onPrimaryContainer),
          const Gap(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Идёт сейчас',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(2),
                Text(
                  'До конца пары ${formatCountdown(left)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.access_time,
              size: 18, color: colorScheme.onPrimaryContainer),
        ],
      ),
    );
  }
}

/// Banner shown before today's lesson starts: quiet secondary tonal
/// card with the exact countdown to the start time.
class _UpcomingBanner extends ConsumerWidget {
  final ScheduleItem lesson;

  const _UpcomingBanner({required this.lesson});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = ref.watch(clockProvider);
    final left = lesson.timeUntilStartAt(now);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.watch_later_outlined,
              size: 20, color: colorScheme.onSecondaryContainer),
          const Gap(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Начнётся скоро',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(2),
                Text(
                  'До начала пары ${formatCountdown(left)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.access_time,
              size: 18, color: colorScheme.onSecondaryContainer),
        ],
      ),
    );
  }
}

/// Banner shown when the lesson was affected by the latest schedule change.
class _ChangeBanner extends StatelessWidget {
  final String note;

  const _ChangeBanner({required this.note});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final text = note == 'Новое занятие'
        ? 'Новое занятие в расписании'
        : 'Изменение расписания: $note';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.sync_alt, size: 16, color: colorScheme.onErrorContainer),
          const Gap(10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Компактная «пилюля» с иконкой и текстом — время и корпус в шапке листа.
class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color background;
  final Color foreground;

  const _MetaPill({
    required this.icon,
    required this.text,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppShapes.circular(AppShapes.small),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const Gap(5),
          Text(
            text,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
