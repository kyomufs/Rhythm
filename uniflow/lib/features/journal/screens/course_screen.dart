import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:uniflow/core/domain/journal.dart';
import 'package:uniflow/core/journal/journal_store.dart';
import 'package:uniflow/core/models/schedule.dart';
import 'package:uniflow/core/theme/shapes.dart';
import 'package:uniflow/core/theme/spacing.dart';
import 'package:uniflow/core/theme/typography.dart';
import 'package:uniflow/features/journal/widgets/course_style.dart';
import 'package:uniflow/features/journal/widgets/journal_editors.dart';
import 'package:uniflow/features/journal/widgets/score_scroller.dart';
import 'package:uniflow/shared/widgets/expressive_button_group.dart';
import 'package:uniflow/shared/widgets/morph_chip.dart';
import 'package:uniflow/shared/widgets/wavy_progress.dart';

/// Дисциплина: сводка, посещение, события и шкала.
class CourseScreen extends ConsumerStatefulWidget {
  const CourseScreen({super.key, required this.courseId});

  final String courseId;

  @override
  ConsumerState<CourseScreen> createState() => _CourseScreenState();
}

enum _CourseTab { summary, attendance, events, scale }

class _CourseScreenState extends ConsumerState<CourseScreen> {
  var _tab = _CourseTab.summary;

  Future<void> _edit(Course course) async {
    final term = ref
        .read(journalProvider)
        .data
        .terms
        .where((t) => t.id == course.termId)
        .firstOrNull;
    if (term == null) return;
    await showDialog<void>(
      context: context,
      builder: (_) => CourseEditorDialog(term: term, course: course),
    );
  }

  Future<void> _delete(Course course) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Удалить дисциплину?',
      message: '«${course.title}» вместе с парами, событиями и баллами '
          'исчезнет из журнала.',
    );
    if (!confirmed || !mounted) return;
    ref.read(journalProvider.notifier).deleteCourse(course.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = ref.watch(journalProvider).data;
    final course = data.courses.where((c) => c.id == widget.courseId).firstOrNull;
    if (course == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Дисциплина удалена')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              course.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.emphasizedTitleLarge(
                theme.textTheme.titleLarge!,
              ),
            ),
            Text(
              [
                courseKindLabel(course.kind),
                if (course.teacher != null && course.teacher!.isNotEmpty)
                  course.teacher!,
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Дисциплина',
            onSelected: (value) {
              if (value == 'edit') _edit(course);
              if (value == 'delete') _delete(course);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Изменить')),
              PopupMenuItem(value: 'delete', child: Text('Удалить')),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.xs),
            child: ExpressiveButtonGroup<_CourseTab>(
              values: _CourseTab.values,
              selected: _tab,
              labelOf: (tab) => switch (tab) {
                _CourseTab.summary => 'Сводка',
                _CourseTab.attendance => 'Пары',
                _CourseTab.events => 'События',
                _CourseTab.scale => 'Шкала',
              },
              iconOf: (tab) => switch (tab) {
                _CourseTab.summary => Icons.insights_outlined,
                _CourseTab.attendance => Icons.event_available_outlined,
                _CourseTab.events => Icons.task_alt,
                _CourseTab.scale => Icons.tune,
              },
              onChanged: (tab) => setState(() => _tab = tab),
            ),
          ),
        ),
      ),
      floatingActionButton: switch (_tab) {
        _CourseTab.attendance
            when data.recordsOf(course.id).isEmpty =>
          null,
        _CourseTab.events when data.assessmentsOf(course.id).isEmpty => null,
        _CourseTab.attendance => FloatingActionButton.extended(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => _NewRecordSheet(course: course),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Пара'),
          ),
        _CourseTab.events => FloatingActionButton.extended(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _AssessmentDialog(course: course),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Событие'),
          ),
        _ => null,
      },
      body: IndexedStack(
        index: _tab.index,
        children: [
          _SummaryTab(course: course),
          _AttendanceTab(course: course),
          _EventsTab(course: course),
          _ScaleTab(course: course),
        ],
      ),
    );
  }
}

// ── Сводка ─────────────────────────────────────────────────────

class _SummaryTab extends ConsumerWidget {
  const _SummaryTab({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final stats = ref.watch(courseStatsProvider(course.id));
    final accent = courseAccent(scheme, course.colorIndex);
    final passLeft = stats.pointsToPass;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppShapes.extraLarge),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${(stats.percent * 100).round()}',
                    style: AppTypography.emphasizedHeadlineLarge(
                      theme.textTheme.headlineLarge!,
                    ).copyWith(color: scheme.onPrimaryContainer, height: 1),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5, left: 2),
                    child: Text(
                      '%',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.onPrimaryContainer
                            .withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (stats.total > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                      decoration: BoxDecoration(
                        color:
                            scheme.onPrimaryContainer.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppShapes.small),
                      ),
                      child: Text(
                        'прогноз ${stats.predictedGrade}',
                        style: AppTypography.emphasizedLabelLarge(
                          theme.textTheme.labelLarge!,
                        ).copyWith(color: scheme.onPrimaryContainer),
                      ),
                    ),
                ],
              ),
              const Gap(AppSpacing.xs),
              WavyProgressIndicator(
                value: stats.percent.clamp(0.0, 1.0),
                color: scheme.onPrimaryContainer,
                trackColor: scheme.onPrimaryContainer.withValues(alpha: 0.22),
              ),
              const Gap(AppSpacing.sm),
              Row(
                children: [
                  Text(
                    '${_num(stats.total)} из ${_num(stats.totalMax)} баллов',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.9),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    passLeft == null
                        ? 'порог ${_num(stats.scale.passThreshold)} набран'
                        : 'до порога ${_num(passLeft)}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Gap(AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'В семестре',
                value: _num(stats.current),
                hint: 'из ${_num(stats.currentMax)}',
                icon: Icons.timelapse,
              ),
            ),
            const Gap(AppSpacing.xs),
            Expanded(
              child: _MetricTile(
                label: 'Экзамен',
                value: _num(stats.exam),
                hint: 'из ${_num(stats.examMax)}',
                icon: Icons.school_outlined,
              ),
            ),
          ],
        ),
        const Gap(AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'Посещение',
                value: '${stats.attendancePercent}%',
                hint: '${stats.visited} из ${stats.lessons} пар',
                icon: Icons.groups_outlined,
              ),
            ),
            const Gap(AppSpacing.xs),
            Expanded(
              child: _MetricTile(
                label: stats.overdue > 0 ? 'Просрочено' : 'Ближайший дедлайн',
                value: stats.overdue > 0
                    ? '${stats.overdue}'
                    : stats.nextDeadline == null
                        ? '—'
                        : DateFormat('d MMM', 'ru')
                            .format(stats.nextDeadline!),
                hint: stats.overdue > 0
                    ? 'событий'
                    : stats.nextDeadline == null
                        ? 'нет событий'
                        : 'событие',
                icon: stats.overdue > 0
                    ? Icons.error_outline
                    : Icons.flag_outlined,
                danger: stats.overdue > 0,
              ),
            ),
          ],
        ),
        const Gap(AppSpacing.lg),
        _SectionTitle(
          title: 'Категории',
          trailing: stats.categories.isEmpty
              ? null
              : '${_num(stats.total)} / ${_num(stats.totalMax)}',
        ),
        const Gap(AppSpacing.xs),
        if (stats.categories.isEmpty)
          Text(
            'Шкала пуста — добавьте категории на вкладке «Шкала»',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppShapes.largeIncreased),
            ),
            child: Column(
              children: [
                for (final (index, progress) in stats.categories.indexed) ...[
                  if (index > 0)
                    Divider(
                      height: 1,
                      indent: AppSpacing.md,
                      endIndent: AppSpacing.md,
                      color: scheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                progress.category.name,
                                style: AppTypography.emphasizedBodyMedium(
                                  theme.textTheme.bodyMedium!,
                                ),
                              ),
                            ),
                            if (progress.category.isExam)
                              const Padding(
                                padding:
                                    EdgeInsets.only(right: AppSpacing.xs),
                                child: _Tag(label: 'экзамен'),
                              ),
                            Text(
                              '${_num(progress.earned)} / ${_num(progress.max)}',
                              style: theme.textTheme.labelLarge,
                            ),
                          ],
                        ),
                        const Gap(AppSpacing.xs),
                        WavyProgressIndicator(
                          value: progress.percent.clamp(0.0, 1.0),
                          color: accent,
                          trackColor: scheme.surfaceContainerHighest,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
    this.danger = false,
  });

  final String label;
  final String value;
  final String hint;
  final IconData icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = danger ? scheme.error : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppShapes.large),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const Gap(AppSpacing.xxs),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(color: color),
                ),
              ),
            ],
          ),
          const Gap(AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: AppTypography.emphasizedTitleLarge(
                  theme.textTheme.titleLarge!,
                ).copyWith(color: danger ? scheme.error : scheme.onSurface),
              ),
              const Gap(4),
              Flexible(
                child: Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          title,
          style: AppTypography.emphasizedTitleMedium(theme.textTheme.titleMedium!),
        ),
        const Spacer(),
        if (trailing != null)
          Text(
            trailing!,
            style: theme.textTheme.labelLarge
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppShapes.small),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall
            ?.copyWith(color: theme.colorScheme.onSecondaryContainer),
      ),
    );
  }
}

// ── Пары ───────────────────────────────────────────────────────

class _AttendanceTab extends ConsumerWidget {
  const _AttendanceTab({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(journalProvider).data.recordsOf(course.id);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (records.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.event_available_outlined,
                    size: 44, color: scheme.onPrimaryContainer),
              ),
              const Gap(AppSpacing.md),
              Text(
                'Пар пока нет',
                style: AppTypography.emphasizedTitleLarge(
                  theme.textTheme.titleLarge!,
                ),
              ),
              const Gap(AppSpacing.xxs),
              Text(
                'Отметьте пару вручную или заполните журнал\n'
                'из расписания',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const Gap(AppSpacing.md),
              FilledButton.icon(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => _NewRecordSheet(course: course),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Отметить пару'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
      itemCount: records.length,
      separatorBuilder: (_, __) => const Gap(AppSpacing.xs),
      itemBuilder: (context, index) {
        final record = records[index];
        return _RecordTile(record: record);
      },
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record});

  final LessonRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final df = DateFormat('d', 'ru');
    final month = DateFormat('MMM', 'ru').format(record.date);
    final visited = attendanceCountsAsVisited(record.attendance);

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppShapes.large),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (_) => _RecordSheet(record: record),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: visited
                      ? scheme.secondaryContainer
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppShapes.medium),
                ),
                child: Column(
                  children: [
                    Text(
                      df.format(record.date),
                      style: AppTypography.emphasizedTitleLarge(
                        theme.textTheme.titleLarge!,
                      ).copyWith(
                        color: visited
                            ? scheme.onSecondaryContainer
                            : scheme.onSurfaceVariant,
                        height: 1,
                      ),
                    ),
                    Text(
                      month,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: visited
                            ? scheme.onSecondaryContainer
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${record.slot} пара · '
                      '${lessonTypeShortLabel(record.type)}',
                      style: AppTypography.emphasizedBodyMedium(
                        theme.textTheme.bodyMedium!,
                      ),
                    ),
                    const Gap(2),
                    Text(
                      [
                        attendanceLabel(record.attendance),
                        if (record.reason != null && record.reason!.isNotEmpty)
                          record.reason!,
                        if (record.comment != null &&
                            record.comment!.isNotEmpty)
                          record.comment!,
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (record.points != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppShapes.small),
                  ),
                  child: Text(
                    '${_num(record.points!)} б.',
                    style: AppTypography.emphasizedLabelLarge(
                      theme.textTheme.labelLarge!,
                    ).copyWith(color: scheme.onPrimaryContainer),
                  ),
                )
              else
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordSheet extends ConsumerWidget {
  const _RecordSheet({required this.record});

  final LessonRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(journalProvider.notifier);
    final scale = ref
        .watch(journalProvider)
        .data
        .courses
        .where((c) => c.id == record.courseId)
        .firstOrNull
        ?.scale;
    final category = scale?.categoryForLesson(record.type);
    final max = (category?.maxPoints ?? 10).round();

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.md + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${DateFormat('d MMMM, EEEE', 'ru').format(record.date)} · '
              '${record.slot} пара',
              style: AppTypography.emphasizedTitleMedium(
                theme.textTheme.titleMedium!,
              ),
            ),
            const Gap(AppSpacing.md),
            ExpressiveButtonGroup<Attendance>(
              values: Attendance.values,
              selected: record.attendance,
              labelOf: (value) => switch (value) {
                Attendance.present => 'Был',
                Attendance.absent => 'Не был',
                Attendance.excused => 'Уваж.',
                Attendance.late => 'Опоздал',
              },
              onChanged: (value) => notifier.setAttendance(
                record.id,
                value,
                reason: value == record.attendance ? record.reason : null,
              ),
            ),
            const Gap(AppSpacing.md),
            ScoreScroller(
              max: max,
              value: record.points?.round(),
              label: 'Баллы за пару',
              onChanged: (value) =>
                  notifier.setPoints(record.id, value?.toDouble()),
            ),
            const Gap(AppSpacing.sm),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => _CommentDialog(record: record),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Комментарий'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    final confirmed = await confirmDelete(
                      context,
                      title: 'Удалить пару?',
                      message: 'Отметка и баллы за эту пару исчезнут.',
                    );
                    if (!confirmed || !context.mounted) return;
                    ref.read(journalProvider.notifier).deleteLesson(record.id);
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  child: const Text('Удалить'),
                ),
                const Gap(AppSpacing.xs),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Готово'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentDialog extends ConsumerStatefulWidget {
  const _CommentDialog({required this.record});

  final LessonRecord record;

  @override
  ConsumerState<_CommentDialog> createState() => _CommentDialogState();
}

class _CommentDialogState extends ConsumerState<_CommentDialog> {
  late final _text = TextEditingController(text: widget.record.comment ?? '');

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Комментарий'),
      content: TextField(
        controller: _text,
        maxLines: 3,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Что было на паре'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            final value = _text.text.trim();
            ref.read(journalProvider.notifier).saveLesson(
                  widget.record.copyWith(comment: value.isEmpty ? null : value),
                );
            Navigator.of(context).pop();
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

class _NewRecordSheet extends ConsumerStatefulWidget {
  const _NewRecordSheet({required this.course});

  final Course course;

  @override
  ConsumerState<_NewRecordSheet> createState() => _NewRecordSheetState();
}

class _NewRecordSheetState extends ConsumerState<_NewRecordSheet> {
  var _date = DateTime.now();
  var _slot = 1;
  var _type = LessonType.practice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.md + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Отметить пару',
              style: AppTypography.emphasizedTitleLarge(
                theme.textTheme.titleLarge!,
              ),
            ),
            const Gap(AppSpacing.sm),
            InkWell(
              borderRadius: BorderRadius.circular(AppShapes.medium),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _date = picked);
              },
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppShapes.medium),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_outlined, size: 20),
                    const Gap(AppSpacing.xs),
                    Text(DateFormat('d MMMM y', 'ru').format(_date)),
                    const Spacer(),
                    const Icon(Icons.edit_calendar, size: 18),
                  ],
                ),
              ),
            ),
            const Gap(AppSpacing.sm),
            Row(
              children: [
                Text('Пара', style: theme.textTheme.labelLarge),
                Expanded(
                  child: Slider(
                    value: _slot.toDouble(),
                    min: 1,
                    max: 8,
                    divisions: 7,
                    label: '$_slot',
                    onChanged: (value) => setState(() => _slot = value.round()),
                  ),
                ),
                Text('$_slot', style: theme.textTheme.titleSmall),
              ],
            ),
            const Gap(AppSpacing.xs),
            Row(
              children: [
                for (final (index, type) in const [
                  LessonType.lecture,
                  LessonType.practice,
                  LessonType.lab,
                  LessonType.seminar,
                ].indexed)
                  Flexible(
                    child: Padding(
                      padding: EdgeInsets.only(right: index == 3 ? 0 : 2),
                      child: MorphChip(
                        label: lessonTypeShortLabel(type),
                        selected: _type == type,
                        isFirst: index == 0,
                        isLast: index == 3,
                        onTap: () => setState(() => _type = type),
                      ),
                    ),
                  ),
              ],
            ),
            const Gap(AppSpacing.md),
            FilledButton(
              onPressed: () {
                final record = LessonRecord(
                  id: 'rec-${DateTime.now().microsecondsSinceEpoch}',
                  courseId: widget.course.id,
                  date: DateTime(_date.year, _date.month, _date.day),
                  slot: _slot,
                  type: _type,
                );
                ref.read(journalProvider.notifier).saveLesson(record);
                Navigator.of(context).pop();
              },
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── События ────────────────────────────────────────────────────

class _EventsTab extends ConsumerWidget {
  const _EventsTab({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assessments =
        ref.watch(journalProvider).data.assessmentsOf(course.id);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final df = DateFormat('d MMM', 'ru');

    if (assessments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.task_alt,
                    size: 44, color: scheme.onSecondaryContainer),
              ),
              const Gap(AppSpacing.md),
              Text(
                'Событий нет',
                style: AppTypography.emphasizedTitleLarge(
                  theme.textTheme.titleLarge!,
                ),
              ),
              const Gap(AppSpacing.xxs),
              Text(
                'Добавьте контрольную, зачёт или экзамен —\n'
                'дедлайн появится в сводке',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const Gap(AppSpacing.md),
              FilledButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => _AssessmentDialog(course: course),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Добавить событие'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
      itemCount: assessments.length,
      separatorBuilder: (_, __) => const Gap(AppSpacing.xs),
      itemBuilder: (context, index) {
        final item = assessments[index];
        final graded = item.isGraded;
        final overdue = item.isOverdue;
        return Material(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppShapes.large),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) =>
                  _AssessmentDialog(course: course, assessment: item),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: graded
                          ? scheme.primaryContainer
                          : overdue
                              ? scheme.errorContainer
                              : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppShapes.medium),
                    ),
                    child: Icon(
                      graded
                          ? Icons.check
                          : overdue
                              ? Icons.priority_high
                              : Icons.schedule,
                      color: graded
                          ? scheme.onPrimaryContainer
                          : overdue
                              ? scheme.onErrorContainer
                              : scheme.onSurfaceVariant,
                    ),
                  ),
                  const Gap(AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.emphasizedBodyMedium(
                            theme.textTheme.bodyMedium!,
                          ),
                        ),
                        const Gap(2),
                        Text(
                          [
                            if (item.dueDate != null)
                              'до ${df.format(item.dueDate!)}',
                            course.scale.categoryById(item.categoryId)?.name ??
                                '—',
                          ].join(' · '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: overdue
                                ? scheme.error
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    graded
                        ? '${_num(item.earnedPoints!)} / ${_num(item.maxPoints)}'
                        : '— / ${_num(item.maxPoints)}',
                    style: AppTypography.emphasizedLabelLarge(
                      theme.textTheme.labelLarge!,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AssessmentDialog extends ConsumerStatefulWidget {
  const _AssessmentDialog({required this.course, this.assessment});

  final Course course;
  final Assessment? assessment;

  @override
  ConsumerState<_AssessmentDialog> createState() => _AssessmentDialogState();
}

class _AssessmentDialogState extends ConsumerState<_AssessmentDialog> {
  late final _title =
      TextEditingController(text: widget.assessment?.title ?? '');
  late final _max = TextEditingController(
      text: widget.assessment?.maxPoints.toString() ?? '10');
  late final _earned = TextEditingController(
      text: widget.assessment?.earnedPoints?.toString() ?? '');
  late DateTime? _due = widget.assessment?.dueDate;
  late String _categoryId =
      widget.assessment?.categoryId ?? widget.course.scale.categories.first.id;

  @override
  void dispose() {
    _title.dispose();
    _max.dispose();
    _earned.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.assessment == null ? 'Новое событие' : 'Событие'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                autofocus: widget.assessment == null,
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              const Gap(AppSpacing.sm),
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: 'Категория'),
                items: [
                  for (final category in widget.course.scale.categories)
                    DropdownMenuItem(
                        value: category.id, child: Text(category.name)),
                ],
                onChanged: (value) =>
                    setState(() => _categoryId = value ?? _categoryId),
              ),
              const Gap(AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _max,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Максимум'),
                    ),
                  ),
                  const Gap(AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: _earned,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Получено'),
                    ),
                  ),
                ],
              ),
              const Gap(AppSpacing.sm),
              InkWell(
                borderRadius: BorderRadius.circular(AppShapes.medium),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _due ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _due = picked);
                },
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppShapes.medium),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.flag_outlined, size: 20),
                      const Gap(AppSpacing.xs),
                      Text(_due == null
                          ? 'Без дедлайна'
                          : DateFormat('d MMMM y', 'ru').format(_due!)),
                      const Spacer(),
                      const Icon(Icons.edit_calendar, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.assessment != null)
          TextButton(
            onPressed: () {
              ref
                  .read(journalProvider.notifier)
                  .deleteAssessment(widget.assessment!.id);
              Navigator.of(context).pop();
            },
            child: const Text('Удалить'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            final title = _title.text.trim();
            if (title.isEmpty) return;
            final earned = double.tryParse(_earned.text.replaceAll(',', '.'));
            final max = double.tryParse(_max.text.replaceAll(',', '.')) ?? 10;
            final assessment = Assessment(
              id: widget.assessment?.id ??
                  'as-${DateTime.now().microsecondsSinceEpoch}',
              courseId: widget.course.id,
              categoryId: _categoryId,
              title: title,
              dueDate: _due,
              maxPoints: max,
              earnedPoints: earned,
              status: earned == null
                  ? AssessmentStatus.planned
                  : AssessmentStatus.graded,
            );
            ref.read(journalProvider.notifier).saveAssessment(assessment);
            Navigator.of(context).pop();
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

// ── Шкала ──────────────────────────────────────────────────────

class _ScaleTab extends ConsumerStatefulWidget {
  const _ScaleTab({required this.course});

  final Course course;

  @override
  ConsumerState<_ScaleTab> createState() => _ScaleTabState();
}

class _ScaleTabState extends ConsumerState<_ScaleTab> {
  late GradeScale _scale = widget.course.scale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sum = _scale.totalMax;
    final inconsistent = (sum - 100).abs() > 0.01;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.lg),
      children: [
        const _SectionTitle(title: 'Пресет'),
        const Gap(AppSpacing.xs),
        Row(
          children: [
            for (final (index, preset) in gradeScalePresets.indexed)
              Flexible(
                child: Padding(
                  padding: EdgeInsets.only(
                      right: index == gradeScalePresets.length - 1 ? 0 : 2),
                  child: MorphChip(
                    label: preset.label,
                    selected: _matchesPreset(preset),
                    isFirst: index == 0,
                    isLast: index == gradeScalePresets.length - 1,
                    onTap: () => setState(() => _scale = preset.build()),
                  ),
                ),
              ),
          ],
        ),
        if (inconsistent) ...[
          const Gap(AppSpacing.xs),
          Text(
            'Сумма категорий ${_num(sum)} — не 100. Так можно, но проверьте веса.',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
        ],
        const Gap(AppSpacing.lg),
        _SectionTitle(title: 'Категории', trailing: '${_num(sum)} б.'),
        const Gap(AppSpacing.xs),
        Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppShapes.largeIncreased),
          ),
          child: Column(
            children: [
              for (final (index, category) in _scale.categories.indexed) ...[
                if (index > 0)
                  Divider(
                    height: 1,
                    indent: AppSpacing.md,
                    endIndent: AppSpacing.md,
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                _CategoryRow(
                  category: category,
                  onTap: () => _editCategory(category),
                  onLess: category.maxPoints <= 5
                      ? null
                      : () => setState(() => _scale = _replaceCategory(
                            category.copyWith(maxPoints: category.maxPoints - 5),
                          )),
                  onMore: () => setState(() => _scale = _replaceCategory(
                        category.copyWith(maxPoints: category.maxPoints + 5),
                      )),
                  onDelete: _scale.categories.length <= 1
                      ? null
                      : () => setState(() {
                            _scale = _scale.copyWith(
                              categories: [
                                for (final item in _scale.categories)
                                  if (item.id != category.id) item,
                              ],
                            );
                          }),
                ),
              ],
            ],
          ),
        ),
        const Gap(AppSpacing.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addCategory,
            icon: const Icon(Icons.add),
            label: const Text('Добавить категорию'),
          ),
        ),
        const Gap(AppSpacing.lg),
        _SectionTitle(
          title: 'Порог зачёта',
          trailing: '${_scale.passThreshold.round()} б.',
        ),
        Slider(
          value: _scale.passThreshold,
          min: 0,
          max: 100,
          divisions: 20,
          onChanged: (value) => setState(
            () => _scale = _scale.copyWith(passThreshold: value),
          ),
        ),
        const Gap(AppSpacing.sm),
        FilledButton.icon(
          onPressed: () {
            ref.read(journalProvider.notifier).updateCourse(
                  widget.course.copyWith(scale: _scale),
                );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Шкала сохранена')),
            );
          },
          icon: const Icon(Icons.save_outlined),
          label: const Text('Сохранить шкалу'),
        ),
      ],
    );
  }

  bool _matchesPreset(GradeScalePreset preset) {
    final built = preset.build();
    if (built.categories.length != _scale.categories.length) return false;
    for (var i = 0; i < built.categories.length; i++) {
      if (built.categories[i].name != _scale.categories[i].name ||
          built.categories[i].maxPoints != _scale.categories[i].maxPoints) {
        return false;
      }
    }
    return true;
  }

  Future<void> _addCategory() async {
    final result = await _askCategory();
    if (result == null || !mounted) return;
    setState(() {
      _scale = _scale.copyWith(
        categories: [
          ..._scale.categories,
          GradeCategory(
            id: 'cat-${DateTime.now().microsecondsSinceEpoch}',
            name: result.$1,
            maxPoints: result.$2,
            lessonType: result.$3,
            isExam: result.$4,
          ),
        ],
      );
    });
  }

  Future<void> _editCategory(GradeCategory category) async {
    final result = await _askCategory(
      name: category.name,
      max: category.maxPoints,
      type: category.lessonType,
      isExam: category.isExam,
    );
    if (result == null || !mounted) return;
    setState(() {
      _scale = _replaceCategory(category.copyWith(
        name: result.$1,
        maxPoints: result.$2,
        lessonType: result.$3,
        isExam: result.$4,
      ));
    });
  }

  /// Название, максимум и чем категория наполняется. Экзамен — отдельный
  /// флаг: он не привязан к типу пары, но входит в 100 баллов.
  Future<(String, double, LessonType?, bool)?> _askCategory({
    String name = '',
    double max = 10,
    LessonType? type,
    bool isExam = false,
  }) async {
    final nameController = TextEditingController(text: name);
    final maxController = TextEditingController(text: _num(max));
    var lessonType = type;
    var exam = isExam;
    final result = await showDialog<(String, double, LessonType?, bool)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          title: Text(name.isEmpty ? 'Новая категория' : 'Категория'),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Название'),
                  ),
                  const Gap(AppSpacing.sm),
                  TextField(
                    controller: maxController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Максимум баллов',
                      suffixText: 'б.',
                    ),
                  ),
                  const Gap(AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xxs,
                    children: [
                      for (final option in _categoryKinds)
                        ChoiceChip(
                          label: Text(option.label),
                          selected:
                              exam == option.isExam && lessonType == option.type,
                          onSelected: (_) => setLocal(() {
                            exam = option.isExam;
                            lessonType = option.type;
                          }),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final title = nameController.text.trim();
                final points = double.tryParse(
                  maxController.text.trim().replaceAll(',', '.'),
                );
                if (title.isEmpty || points == null || points <= 0) return;
                Navigator.of(dialogContext)
                    .pop((title, points, lessonType, exam));
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    maxController.dispose();
    return result;
  }

  GradeScale _replaceCategory(GradeCategory category) {
    return _scale.copyWith(
      categories: [
        for (final item in _scale.categories)
          item.id == category.id ? category : item,
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.onTap,
    required this.onLess,
    required this.onMore,
    required this.onDelete,
  });

  final GradeCategory category;
  final VoidCallback onTap;
  final VoidCallback? onLess;
  final VoidCallback onMore;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.xs, AppSpacing.xs, AppSpacing.xs),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: AppTypography.emphasizedBodyMedium(
                      theme.textTheme.bodyMedium!,
                    ),
                  ),
                  Text(
                    [
                      category.isExam
                          ? 'Экзамен'
                          : _categoryKindLabel(category.lessonType),
                      '${_num(category.maxPoints)} б.',
                    ].join(' · '),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Меньше',
              visualDensity: VisualDensity.compact,
              onPressed: onLess,
              icon: const Icon(Icons.remove_circle_outline, size: 20),
            ),
            SizedBox(
              width: 34,
              child: Text(
                _num(category.maxPoints),
                textAlign: TextAlign.center,
                style: AppTypography.emphasizedLabelLarge(
                  theme.textTheme.labelLarge!,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Больше',
              visualDensity: VisualDensity.compact,
              onPressed: onMore,
              icon: const Icon(Icons.add_circle_outline, size: 20),
            ),
            IconButton(
              tooltip: 'Удалить категорию',
              visualDensity: VisualDensity.compact,
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

String _categoryKindLabel(LessonType? type) {
  if (type == null) return 'События';
  return switch (type) {
    LessonType.lecture => 'Лекции',
    LessonType.practice => 'Практики',
    LessonType.lab => 'Лабораторные',
    LessonType.seminar => 'Семинары',
    LessonType.unknown => 'Любые пары',
  };
}

class _CategoryKind {
  const _CategoryKind(this.label, this.type, this.isExam);

  final String label;
  final LessonType? type;
  final bool isExam;
}

const _categoryKinds = [
  _CategoryKind('Только события', null, false),
  _CategoryKind('Практики', LessonType.practice, false),
  _CategoryKind('Лабораторные', LessonType.lab, false),
  _CategoryKind('Лекции', LessonType.lecture, false),
  _CategoryKind('Экзамен', null, true),
];

String _num(double value) => value == value.roundToDouble()
    ? '${value.round()}'
    : value.toStringAsFixed(1);
