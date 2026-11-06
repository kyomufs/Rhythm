import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:uniflow/core/domain/journal.dart';
import 'package:uniflow/core/models/schedule.dart';
import 'package:uniflow/core/journal/journal_store.dart';
import 'package:uniflow/core/theme/spacing.dart';
import 'package:uniflow/features/journal/widgets/score_scroller.dart';

/// Дисциплина: сводка, посещение, события и шкала.
class CourseScreen extends ConsumerStatefulWidget {
  const CourseScreen({super.key, required this.courseId});

  final String courseId;

  @override
  ConsumerState<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends ConsumerState<CourseScreen> {
  @override
  Widget build(BuildContext context) {
    final data = ref.watch(journalProvider).data;
    final course =
        data.courses.where((c) => c.id == widget.courseId).firstOrNull;
    if (course == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Дисциплина удалена')),
      );
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title:
              Text(course.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Сводка'),
              Tab(text: 'Посещение'),
              Tab(text: 'События'),
              Tab(text: 'Шкала'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _SummaryTab(course: course),
            _AttendanceTab(course: course),
            _EventsTab(course: course),
            _ScaleTab(course: course),
          ],
        ),
      ),
    );
  }
}

class _SummaryTab extends ConsumerWidget {
  const _SummaryTab({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stats = ref.watch(courseStatsProvider(course.id));
    final percent = (stats.percent * 100).round();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Row(
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: CircularProgressIndicator(
                      value: (stats.percent).clamp(0.0, 1.0),
                      strokeWidth: 8,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$percent%',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text('прогресс', style: theme.textTheme.labelSmall),
                    ],
                  ),
                ],
              ),
            ),
            const Gap(AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatRow(
                    label: 'В семестре',
                    value: '${_num(stats.current)} / ${_num(stats.currentMax)}',
                  ),
                  _StatRow(
                    label: 'Экзамен',
                    value: '${_num(stats.exam)} / ${_num(stats.examMax)}',
                  ),
                  _StatRow(
                    label: 'Прогноз',
                    value: '${stats.predictedGrade}',
                    emphasize: true,
                  ),
                  _StatRow(
                    label: 'Посещение',
                    value: '${stats.attendancePercent}%',
                  ),
                ],
              ),
            ),
          ],
        ),
        const Gap(AppSpacing.lg),
        Text('Категории', style: theme.textTheme.titleSmall),
        const Gap(AppSpacing.xs),
        for (final progress in stats.categories) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        progress.category.name +
                            (progress.category.isExam ? ' · экзамен' : ''),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      '${_num(progress.earned)} / ${_num(progress.max)}',
                      style: theme.textTheme.labelLarge,
                    ),
                  ],
                ),
                const Gap(4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.percent.clamp(0.0, 1.0),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
        ],
        const Gap(AppSpacing.sm),
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('До зачёта',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const Gap(4),
                Text(
                  stats.pointsToPass == null
                      ? 'Порог ${_num(stats.scale.passThreshold)} набран'
                      : 'Не хватает ${_num(stats.pointsToPass!)} из ${_num(stats.totalMax)}',
                  style: theme.textTheme.bodyMedium,
                ),
                if (stats.nextDeadline != null) ...[
                  const Gap(AppSpacing.xs),
                  Text(
                    'Ближайший дедлайн: '
                    '${DateFormat('d MMMM', 'ru').format(stats.nextDeadline!)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                if (stats.overdue > 0) ...[
                  const Gap(AppSpacing.xxs),
                  Text(
                    'Просрочено событий: ${stats.overdue}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Text(
            value,
            style: emphasize
                ? theme.textTheme.titleSmall
                : theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _AttendanceTab extends ConsumerWidget {
  const _AttendanceTab({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(journalProvider).data.recordsOf(course.id);
    final df = DateFormat('d MMM, EEE', 'ru');

    return Scaffold(
      body: records.isEmpty
          ? const Center(
              child: Text('Пар пока нет — отметки появятся из расписания'),
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: records.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final record = records[index];
                return ListTile(
                  title:
                      Text('${df.format(record.date)} · ${record.slot} пара'),
                  subtitle: Text(
                    [
                      lessonTypeShortLabel(record.type),
                      attendanceLabel(record.attendance),
                      if (record.reason != null && record.reason!.isNotEmpty)
                        record.reason!,
                      if (record.comment != null && record.comment!.isNotEmpty)
                        record.comment!,
                    ].join(' · '),
                  ),
                  trailing: record.points == null
                      ? null
                      : Text('${_num(record.points!)} б.',
                          style: Theme.of(context).textTheme.labelLarge),
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    showDragHandle: true,
                    isScrollControlled: true,
                    builder: (_) => _RecordSheet(record: record),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Отметить пару',
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (_) => _NewRecordSheet(course: course),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _RecordSheet extends ConsumerWidget {
  const _RecordSheet({required this.record});

  final LessonRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            Text('${DateFormat('d MMMM', 'ru').format(record.date)} · '
                '${record.slot} пара'),
            const Gap(AppSpacing.sm),
            SegmentedButton<Attendance>(
              segments: const [
                ButtonSegment(
                    value: Attendance.present,
                    label: Text('Был'),
                    icon: Icon(Icons.check)),
                ButtonSegment(
                    value: Attendance.absent,
                    label: Text('Не был'),
                    icon: Icon(Icons.close)),
              ],
              selected: {
                record.attendance == Attendance.present
                    ? Attendance.present
                    : Attendance.absent,
              },
              onSelectionChanged: (values) => notifier.setAttendance(
                record.id,
                values.first,
                reason: values.first == Attendance.absent ? 'не указана' : null,
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
                TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => _CommentDialog(record: record),
                  ),
                  child: const Text('Комментарий'),
                ),
                const Spacer(),
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
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(DateFormat('d MMMM y', 'ru').format(_date)),
              trailing: const Icon(Icons.edit_calendar),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            Row(
              children: [
                Text('Пара', style: Theme.of(context).textTheme.labelLarge),
                const Gap(AppSpacing.sm),
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
              ],
            ),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                for (final type in const [
                  LessonType.lecture,
                  LessonType.practice,
                  LessonType.lab,
                  LessonType.seminar,
                ])
                  ChoiceChip(
                    label: Text(lessonTypeShortLabel(type)),
                    selected: _type == type,
                    onSelected: (_) => setState(() => _type = type),
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

class _EventsTab extends ConsumerWidget {
  const _EventsTab({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assessments =
        ref.watch(journalProvider).data.assessmentsOf(course.id);
    final df = DateFormat('d MMM', 'ru');
    final theme = Theme.of(context);

    return Scaffold(
      body: assessments.isEmpty
          ? const Center(
              child: Text('Событий нет: добавьте контрольную или зачёт'))
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: assessments.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = assessments[index];
                final graded = item.isGraded;
                return ListTile(
                  leading: Icon(
                    graded ? Icons.check_circle_outline : Icons.schedule,
                    color: item.isOverdue ? theme.colorScheme.error : null,
                  ),
                  title: Text(item.title),
                  subtitle: Text([
                    if (item.dueDate != null) 'до ${df.format(item.dueDate!)}',
                    course.scale.categoryById(item.categoryId)?.name ?? '—',
                  ].join(' · ')),
                  trailing: Text(
                    graded
                        ? '${_num(item.earnedPoints!)} / ${_num(item.maxPoints)}'
                        : '— / ${_num(item.maxPoints)}',
                    style: theme.textTheme.labelLarge,
                  ),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (_) => _AssessmentDialog(
                      course: course,
                      assessment: item,
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Добавить событие',
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => _AssessmentDialog(course: course),
        ),
        child: const Icon(Icons.add),
      ),
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
      content: SingleChildScrollView(
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
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.flag_outlined),
              title: Text(_due == null
                  ? 'Без дедлайна'
                  : DateFormat('d MMMM y', 'ru').format(_due!)),
              trailing: const Icon(Icons.edit_calendar),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _due ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _due = picked);
              },
            ),
          ],
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
    final sum = _scale.totalMax;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        DropdownButtonFormField<int>(
          initialValue: null,
          hint: const Text('Пресет шкалы'),
          decoration: const InputDecoration(labelText: 'Пресет'),
          items: [
            for (var i = 0; i < gradeScalePresets.length; i++)
              DropdownMenuItem(
                value: i,
                child: Text(gradeScalePresets[i].label),
              ),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => _scale = gradeScalePresets[value].build());
          },
        ),
        const Gap(AppSpacing.sm),
        if ((sum - 100).abs() > 0.01)
          Text(
            'Сумма категорий $sum — не 100. Это разрешено, но проверьте веса.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.error),
          ),
        for (final category in _scale.categories)
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerLow,
            child: ListTile(
              onTap: () => _editCategory(category),
              title: Text(category.name),
              subtitle:
                  Text(category.isExam ? 'Экзамен' : 'В течение семестра'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Меньше',
                    onPressed: category.maxPoints <= 5
                        ? null
                        : () => setState(() {
                              _scale = _replaceCategory(
                                category.copyWith(
                                    maxPoints: category.maxPoints - 5),
                              );
                            }),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text(_num(category.maxPoints)),
                  IconButton(
                    tooltip: 'Больше',
                    onPressed: () => setState(() {
                      _scale = _replaceCategory(
                        category.copyWith(maxPoints: category.maxPoints + 5),
                      );
                    }),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  IconButton(
                    tooltip: 'Удалить категорию',
                    onPressed: _scale.categories.length <= 1
                        ? null
                        : () => setState(() {
                              _scale = _scale.copyWith(
                                categories: [
                                  for (final item in _scale.categories)
                                    if (item.id != category.id) item,
                                ],
                              );
                            }),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addCategory,
            icon: const Icon(Icons.add),
            label: const Text('Добавить категорию'),
          ),
        ),
        const Gap(AppSpacing.xs),
        Row(
          children: [
            Text('Порог зачёта', style: theme.textTheme.labelLarge),
            const Spacer(),
            Text('${_scale.passThreshold.round()}',
                style: theme.textTheme.titleSmall),
          ],
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
          content: Column(
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
    ? value.round().toString()
    : value.toStringAsFixed(1);
