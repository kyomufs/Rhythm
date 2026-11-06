import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:tulgusch/core/models/schedule.dart';
import 'package:tulgusch/core/providers/clock_provider.dart';
import 'package:tulgusch/core/services/lesson_group_resolver.dart';
import 'package:tulgusch/core/theme/app_theme.dart';
import 'package:tulgusch/core/theme/motion.dart';
import 'package:tulgusch/core/theme/shapes.dart';
import 'package:tulgusch/core/theme/typography.dart';
import 'package:tulgusch/features/schedule/providers/schedule_provider.dart';
import 'package:tulgusch/shared/widgets/expressive_button_group.dart';
import 'package:tulgusch/shared/widgets/split_button.dart';
import 'package:tulgusch/shared/widgets/wavy_progress.dart';

/// Opens the lesson detail bottom sheet.
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

/// Расширенная карточка пары.
///
/// Композиция сверху вниз: hero-блок с типом пары и живым прогрессом,
/// предмет, баннер изменения, сетка фактов и разрезная кнопка «Скопировать».
/// Факты разложены плитками, а не строками списка: две колонки на телефоне
/// читаются быстрее, а «широкие» поля (преподаватель, группы) занимают
/// всю ширину.
class LessonDetailSheet extends ConsumerStatefulWidget {
  final ScheduleItem lesson;

  const LessonDetailSheet({super.key, required this.lesson});

  @override
  ConsumerState<LessonDetailSheet> createState() => _LessonDetailSheetState();
}

class _LessonDetailSheetState extends ConsumerState<LessonDetailSheet> {
  Timer? _resetCopied;
  bool _copied = false;

  @override
  void dispose() {
    _resetCopied?.cancel();
    super.dispose();
  }

  ScheduleItem get lesson => widget.lesson;

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    setState(() => _copied = true);
    // Подтверждение живёт на самой кнопке: снекбар под модальной шторкой
    // не видно, а всплывающая плашка перекрыла бы карточку.
    _resetCopied?.cancel();
    _resetCopied = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  /// Текст для буфера: короткий (предмет и время) или полный.
  String _copyText({required bool full}) {
    final parts = <String>[
      lesson.subject,
      lesson.time,
      if (full && lesson.classroom.isNotEmpty) lesson.classroom,
      if (full && lesson.teacher.isNotEmpty) lesson.teacher,
      if (full && lesson.date.isNotEmpty) lesson.date,
    ];
    return parts.where((part) => part.isNotEmpty).join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final lessonColor = AppTheme.getColor(lesson.cssClass);

    // Live clock: minute resolution is enough to pick the hero state;
    // the exact seconds are rendered by the live block itself.
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

    final hasClassroom = lesson.classroom.isNotEmpty;
    final hasTeacher = lesson.teacher.isNotEmpty;

    return _SheetReveal(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Hero: тип пары, день и живой прогресс на одной поверхности.
              // Пока пара идёт, блок становится главным элементом экрана:
              // волна прогресса внутри hero-плашки. ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius:
                      AppShapes.circular(AppShapes.extraLargeIncreased),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
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
                      ],
                    ),
                    if (isOngoing) ...[
                      const Gap(16),
                      _LiveProgress(lesson: lesson, color: lessonColor),
                    ],
                  ],
                ),
              ),
              const Gap(18),

              // ── Предмет ──
              Text(
                lesson.subject,
                style: AppTypography.emphasizedHeadlineSmall(
                  theme.textTheme.headlineSmall!,
                ),
              ),
              if (isUpcomingToday) ...[
                const Gap(6),
                Text(
                  'Начнётся через ${formatCountdown(lesson.timeUntilStartAt(now))}',
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
              const Gap(16),

              // ── Факты: две колонки, затем широкие поля во всю ширину. ──
              // IntrinsicHeight: плитки должны быть одной высоты, а stretch
              // в скроллящейся колонке упирается в бесконечную высоту.
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _FactTile(
                        icon: Icons.schedule,
                        label: 'Время',
                        child: Text(
                          lesson.time,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                    if (hasClassroom) ...[
                      const Gap(10),
                      Expanded(
                        child: _FactTile(
                          icon: Icons.place_outlined,
                          label: 'Аудитория',
                          child: Text(
                            lesson.classroom,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (hasTeacher) ...[
                const Gap(10),
                _FactTile(
                  icon: Icons.person_outline,
                  label: 'Преподаватель',
                  child: Text(
                    lesson.teacher,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
              if (visibleGroups.isNotEmpty) ...[
                const Gap(10),
                _FactTile(
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
                          borderRadius: AppShapes.circular(AppShapes.small + 4),
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
              const Gap(16),
              const Gap(20),

              // ── Действие: разрезная кнопка. Основное — скопировать пару
              // в коротком виде, меню — варианты. ──
              Align(
                alignment: Alignment.centerLeft,
                child: ExpressiveSplitButton(
                  label: _copied ? 'Скопировано' : 'Скопировать',
                  icon: _copied ? Icons.check : Icons.copy_all_outlined,
                  size: ExpressiveButtonSize.small,
                  onPressed: () => _copy(_copyText(full: false)),
                  actions: [
                    ExpressiveSplitAction(
                      label: 'Предмет и время',
                      icon: Icons.short_text,
                      onSelected: () => _copy(_copyText(full: false)),
                    ),
                    ExpressiveSplitAction(
                      label: 'Всё занятие',
                      icon: Icons.article_outlined,
                      onSelected: () => _copy(_copyText(full: true)),
                    ),
                    if (hasClassroom)
                      ExpressiveSplitAction(
                        label: 'Только аудитория',
                        icon: Icons.place_outlined,
                        onSelected: () => _copy(lesson.classroom),
                      ),
                  ],
                ),
              ),
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
      case LessonType.seminar:
        return Icons.forum_outlined;
      case LessonType.unknown:
        return Icons.school_outlined;
    }
  }
}

/// Живой прогресс идущей пары: точный остаток тикает раз в секунду, волна
/// едет вместе с ним. Виджет сам подписан на секундные часы, поэтому тиканье
/// не перестраивает всю карточку.
class _LiveProgress extends ConsumerWidget {
  const _LiveProgress({required this.lesson, required this.color});

  final ScheduleItem lesson;
  final Color color;

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
      final total = end.difference(start).inSeconds;
      if (total > 0) {
        progress = ((total - left.inSeconds) / total).clamp(0.0, 1.0);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.timer_outlined, size: 16, color: color),
            const Gap(6),
            Expanded(
              child: Text(
                'До конца пары — ${formatCountdown(left)}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Text(
              '${(progress * 100).round()}%',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const Gap(8),
        WavyProgressIndicator(
          value: progress,
          color: color,
          trackColor: color.withValues(alpha: 0.18),
          height: 9,
          strokeWidth: 3,
          wavelength: 13,
        ),
      ],
    );
  }
}

/// Появление содержимого листа: подъём на spatial-пружине и проявление на
/// effects-пружине. Шторка уже едет снизу сама — это второй, более быстрый
/// слой, который делает появление «живым», а не механическим.
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
    // 64dp с радиусом 22: на hero-поверхности (32dp) на неё смотрит
    // вложенность 32 → 22 при отступе 10.
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: AppShapes.circular(22),
      ),
      child: Icon(icon, size: 30, color: color),
    );
  }
}

/// Плитка факта: тональная поверхность, иконка с подписью сверху и значение.
///
/// Плитки вместо строк списка дают сетку 2×2 на телефоне: время и аудитория
/// стоят рядом, потому что ищутся вместе.
class _FactTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget child;

  const _FactTile({
    required this.icon,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: AppShapes.circular(AppShapes.largeIncreased),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
              const Gap(6),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const Gap(8),
          DefaultTextStyle.merge(
            style: TextStyle(color: colorScheme.onSurface),
            child: child,
          ),
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: AppShapes.circular(AppShapes.largeIncreased),
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
