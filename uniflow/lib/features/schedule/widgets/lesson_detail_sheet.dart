import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:uniflow/core/models/schedule.dart';
import 'package:uniflow/core/providers/clock_provider.dart';
import 'package:uniflow/core/services/lesson_group_resolver.dart';
import 'package:uniflow/core/theme/app_theme.dart';
import 'package:uniflow/core/theme/motion.dart';
import 'package:uniflow/core/theme/shapes.dart';
import 'package:uniflow/core/theme/typography.dart';
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
    // по своей группе список состоит из неё же. Полный список добираем
    // запросом по аудитории пары (см. LessonGroupResolver); пока он грузится
    // или недоступен, остаёмся при том, что пришло с расписанием.
    final ownGroup = ref.watch(
      scheduleScreenProvider.select((s) => s.currentGroup),
    );
    final needsResolve =
        lesson.groups.length <= 1 && lesson.classroom.isNotEmpty;
    // Прогретое расписание аудитории отдаёт группы синхронно — первый кадр
    // карточки уже с полным списком, без «появляются через полсекунды».
    final cachedGroups = needsResolve
        ? ref.watch(lessonGroupResolverProvider).cachedGroups(
              date: lesson.date,
              time: lesson.time,
              subject: lesson.subject,
              classroom: lesson.classroom,
            )
        : const <GroupInfo>[];
    final resolvedGroups = cachedGroups ??
        (needsResolve
            ? ref
                    .watch(lessonGroupsProvider((
                      date: lesson.date,
                      time: lesson.time,
                      subject: lesson.subject,
                      classroom: lesson.classroom,
                    )))
                    .valueOrNull ??
                const <GroupInfo>[]
            : const <GroupInfo>[]);
    final allGroups = List<GroupInfo>.of(
        resolvedGroups.isNotEmpty ? resolvedGroups : lesson.groups);
    // Своя группа вперёд: остальные — в исходном порядке API.
    if (ownGroup != null) {
      allGroups.sort((a, b) => (a.number == ownGroup ? 0 : 1)
          .compareTo(b.number == ownGroup ? 0 : 1));
    }
    // Одна группа, и это своя же — подпись «Группы» ничего не сообщает.
    final visibleGroups = allGroups.length == 1 &&
            ownGroup != null &&
            allGroups.single.number == ownGroup
        ? const <GroupInfo>[]
        : allGroups;

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
    // «среда · 4 ноября» с маленькой буквы читается как обрыв фразы.
    final weekdayTitle = weekdayStr.isEmpty
        ? ''
        : weekdayStr[0].toUpperCase() + weekdayStr.substring(1);
    final typeName =
        lesson.type.isEmpty ? lesson.lessonType.displayName : lesson.type;

    // Список групп пары бывает длинным (поток на несколько групп), поэтому
    // содержимое листа живёт в прокрутке: иначе хвост чипов просто обрезался
    // нижней кромкой шторки. Высота ограничена долей экрана — лист остаётся
    // шторкой, а не разворачивается на весь экран.
    return _SheetReveal(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Шапка: тип пары крупной плиткой, день и дата рядом. Одна
              // тональная поверхность вместо трёх центрированных строк —
              // взгляд сразу цепляется за то, что это за пара. ──
              Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: AppShapes.circular(AppShapes.extraLarge),
                ),
                child: Row(
                  children: [
                    _TypeBadge(
                      color: lessonColor,
                      icon: _typeIcon(lesson.lessonType),
                    ),
                    const Gap(14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            [weekdayTitle, dateStr]
                                .where((s) => s.isNotEmpty)
                                .join(' · ')
                                .toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.emphasizedLabelMedium(
                              theme.textTheme.labelMedium!.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const Gap(2),
                          Text(
                            typeName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.emphasizedTitleLarge(
                              theme.textTheme.titleLarge!
                                  .copyWith(color: lessonColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isOngoing || isUpcomingToday) ...[
                      const Gap(10),
                      _StatusPill(
                        label: isOngoing
                            ? 'Идёт'
                            : 'Через ${lesson.timeUntilStartAt(now).inMinutes} мин',
                        ongoing: isOngoing,
                      ),
                    ],
                  ],
                ),
              ),
              const Gap(16),

              // ── Предмет ──
              Text(
                lesson.subject,
                style: AppTypography.emphasizedHeadlineSmall(
                  theme.textTheme.headlineSmall!,
                ),
              ),
              // Вторая строка только когда она сообщает новое: тип пары уже
              // стоит в шапке, повторять его под предметом — шум.
              if (isOngoing || isUpcomingToday) ...[
                const Gap(6),
                Text(
                  isOngoing
                      ? 'Идёт сейчас · до конца ${formatCountdown(lesson.timeLeftAt(now))}'
                      : 'Начнётся через ${formatCountdown(lesson.timeUntilStartAt(now))}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],

              if (changeNote != null) ...[
                const Gap(14),
                _ChangeBanner(note: changeNote),
              ],
              const Gap(18),

              // ── Факты пары: время / аудитория / препод / группы. Один
              // столбец, одинаковые строки: подпись сверху, значение снизу. ──
              _DetailRow(
                icon: Icons.schedule,
                label: 'Время',
                child: Text(
                  lesson.time,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (lesson.classroom.isNotEmpty) ...[
                const Gap(14),
                _DetailRow(
                  icon: Icons.place_outlined,
                  label: 'Аудитория',
                  child:
                      Text(lesson.classroom, style: theme.textTheme.bodyLarge),
                ),
              ],
              if (lesson.teacher.isNotEmpty) ...[
                const Gap(14),
                _DetailRow(
                  icon: Icons.person_outline,
                  label: 'Преподаватель',
                  child: Text(lesson.teacher, style: theme.textTheme.bodyLarge),
                ),
              ],
              if (visibleGroups.isNotEmpty) ...[
                const Gap(14),
                _DetailRow(
                  icon: Icons.groups_outlined,
                  label: 'Группы',
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: visibleGroups.map((group) {
                      // Своя группа — первая и выделенная: в длинном списке
                      // иначе не найти, к какой из них относится расписание.
                      final isOwn =
                          ownGroup != null && group.number == ownGroup;
                      return Container(
                        key: ValueKey('lesson-group-${group.number}'),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isOwn
                              ? colorScheme.primaryContainer
                              : colorScheme.surfaceContainerHighest,
                          borderRadius: AppShapes.circular(
                            AppShapes.extraLarge,
                          ),
                        ),
                        child: Text(
                          group.displayName,
                          style: AppTypography.emphasizedLabelMedium(
                            theme.textTheme.labelMedium!.copyWith(
                              color: isOwn
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static IconData _typeIcon(LessonType type) {
    switch (type) {
      case LessonType.lecture:
        return Icons.record_voice_over_outlined;
      case LessonType.practice:
        return Icons.handyman_outlined;
      case LessonType.lab:
        return Icons.science_outlined;
      case LessonType.unknown:
        return Icons.school_outlined;
    }
  }
}

/// Появление содержимого листа: подъём на spatial-пружине и проявление на
/// effects-пружине. Шторка уже едет снизу сама — это второй, более быстрый
/// слой, который делает появление «живым», а не механическим.
///
/// Решение моё, не из M3: спецификация не задаёт хореографию для контента
/// внутри `bottom sheet`.
class _SheetReveal extends StatefulWidget {
  final Widget child;

  const _SheetReveal({required this.child});

  @override
  State<_SheetReveal> createState() => _SheetRevealState();
}

class _SheetRevealState extends State<_SheetReveal>
    with SingleTickerProviderStateMixin {
  // Unbounded: spatial-пружина перелетает цель, а bounded-контроллер срезал
  // бы перелёт.
  late final AnimationController _controller = AnimationController.unbounded(
    vsync: this,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // MediaQuery в initState читать нельзя — только здесь.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.animateWithSpring(MotionTokens.defaultSpatial, to: 1);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        // Прозрачность клампится: перелёт по альфе читается как мигание.
        final opacity = t.clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - t)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Крупная плитка типа пары: скруглённый квадрат с иконкой и цветом пары.
class _TypeBadge extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _TypeBadge({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    // 56dp плитка с радиусом 20: внутренний радиус = 20 − 0, тонкая заливка
    // без обводки, поэтому форму задаёт только сам контейнер.
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: AppShapes.circular(AppShapes.largeIncreased),
      ),
      child: Icon(icon, size: 26, color: color),
    );
  }
}

/// Короткий статус пары: «Идёт» / «Через N мин».
class _StatusPill extends StatelessWidget {
  final String label;
  final bool ongoing;

  const _StatusPill({required this.label, required this.ongoing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final background =
        ongoing ? colorScheme.primary : colorScheme.secondaryContainer;
    final foreground =
        ongoing ? colorScheme.onPrimary : colorScheme.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppShapes.circular(AppShapes.extraLarge),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ongoing ? Icons.play_arrow_rounded : Icons.schedule,
            size: 14,
            color: foreground,
          ),
          const Gap(3),
          Text(
            label,
            style: AppTypography.emphasizedLabelSmall(
              theme.textTheme.labelSmall!.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// Строка-факт расширенной карточки: иконка в тональном кружке, подпись и
/// значение. Иконка остаётся 18dp — по ней строки выравниваются в столбец.
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget child;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
        ),
        const Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
              const Gap(1),
              DefaultTextStyle.merge(
                style: TextStyle(color: colorScheme.onSurface),
                child: child,
              ),
            ],
          ),
        ),
      ],
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: AppShapes.circular(AppShapes.large),
      ),
      child: Row(
        children: [
          Icon(Icons.sync_alt, size: 18, color: colorScheme.onErrorContainer),
          const Gap(10),
          Expanded(
            child: Text(
              text,
              style: AppTypography.emphasizedBodyMedium(
                theme.textTheme.bodyMedium!.copyWith(
                  color: colorScheme.onErrorContainer,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
