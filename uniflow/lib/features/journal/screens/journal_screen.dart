import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:uniflow/core/domain/journal.dart';
import 'package:uniflow/core/domain/source.dart';
import 'package:uniflow/core/input/desktop_input.dart';
import 'package:uniflow/core/journal/journal_store.dart';
import 'package:uniflow/core/sources/source_store.dart';
import 'package:uniflow/core/theme/spacing.dart';
import 'package:uniflow/features/journal/screens/course_screen.dart';
import 'package:uniflow/features/sources/screens/source_edit_screen.dart';
import 'package:uniflow/features/sources/widgets/source_pill.dart';
import 'package:uniflow/shared/widgets/empty_state.dart';

/// Журнал успеваемости: лента семестров, дисциплины с прогрессом.
class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  final _termController = ScrollController();
  String? _termId;

  @override
  void dispose() {
    _termController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final source = ref.watch(activeSourceProvider);
    final journal = ref.watch(journalProvider);

    if (source == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Журнал')),
        body: EmptyState(
          icon: Icons.inbox_outlined,
          title: 'Нет источника',
          message: 'Добавьте университет, школу или работу —\n'
              'журнал ведётся отдельно для каждого',
          action: FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SourceEditScreen()),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Добавить источник'),
          ),
        ),
      );
    }

    final terms = journal.data.terms;
    final term = _termId == null
        ? (terms.isEmpty ? null : terms.last)
        : terms.firstWhere(
            (t) => t.id == _termId,
            orElse: () => terms.isEmpty ? _draftTerm(source) : terms.last,
          );
    final courses =
        term == null ? const <Course>[] : journal.data.coursesOf(term.id);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const SourcePill(),
            const Gap(AppSpacing.sm),
            Text('Журнал', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Новый семестр',
            onPressed: () => _addTerm(context, source),
            icon: const Icon(Icons.event_repeat),
          ),
        ],
      ),
      floatingActionButton: term == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _addCourse(context, term),
              icon: const Icon(Icons.add),
              label: const Text('Дисциплина'),
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (terms.isNotEmpty)
            _TermStrip(
              terms: terms,
              selectedId: term?.id,
              controller: _termController,
              onSelected: (id) => setState(() => _termId = id),
            ),
          if (term != null) _TermSummary(term: term, courses: courses),
          Expanded(
            child: term == null || courses.isEmpty
                ? EmptyState(
                    icon: Icons.menu_book_outlined,
                    title: 'Пока нет дисциплин',
                    message: 'Добавьте предмет, настройте шкалу баллов\n'
                        'и отмечайте пары прямо из расписания',
                    action: term == null
                        ? FilledButton.icon(
                            onPressed: () => _addTerm(context, source),
                            icon: const Icon(Icons.event_repeat),
                            label: const Text('Начать семестр'),
                          )
                        : FilledButton.icon(
                            onPressed: () => _addCourse(context, term),
                            icon: const Icon(Icons.add),
                            label: const Text('Добавить дисциплину'),
                          ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md, AppSpacing.xs, AppSpacing.md, 88),
                    itemCount: courses.length,
                    separatorBuilder: (_, __) => const Gap(AppSpacing.xs),
                    itemBuilder: (context, index) {
                      final course = courses[index];
                      return _CourseCard(course: course);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Term _draftTerm(Source source) => Term(
        id: '_draft',
        sourceId: source.id,
        title: 'Текущий семестр',
        start: DateTime.now(),
        end: DateTime.now(),
      );

  Future<void> _addTerm(BuildContext context, Source source) async {
    final notifier = ref.read(journalProvider.notifier);
    final term = notifier.ensureTerm();
    setState(() => _termId = term.id);
  }

  Future<void> _addCourse(BuildContext context, Term term) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _CourseDialog(term: term),
    );
  }
}

class _TermStrip extends StatelessWidget {
  const _TermStrip({
    required this.terms,
    required this.selectedId,
    required this.controller,
    required this.onSelected,
  });

  final List<Term> terms;
  final String? selectedId;
  final ScrollController controller;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: WheelScroll(
        controller: controller,
        child: DragPan(
          controller: controller,
          child: ListView.separated(
            controller: controller,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: terms.length,
            separatorBuilder: (_, __) => const Gap(AppSpacing.xs),
            itemBuilder: (context, index) {
              final term = terms[index];
              return Center(
                child: ChoiceChip(
                  label: Text(term.title),
                  selected: term.id == selectedId,
                  onSelected: (_) => onSelected(term.id),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TermSummary extends StatelessWidget {
  const _TermSummary({required this.term, required this.courses});

  final Term term;
  final List<Course> courses;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final df = DateFormat('d MMM', 'ru');
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.sm),
      child: Row(
        children: [
          Icon(sourceKindIcon(SourceKind.university),
              size: 16, color: theme.colorScheme.onSurfaceVariant),
          const Gap(AppSpacing.xxs),
          Text(
            '${df.format(term.start)} — ${df.format(term.end)}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const Gap(AppSpacing.sm),
          Text(
            courses.length == 1
                ? '1 дисциплина'
                : '${courses.length} дисциплин',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _CourseCard extends ConsumerWidget {
  const _CourseCard({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stats = ref.watch(courseStatsProvider(course.id));
    final df = DateFormat('d MMM', 'ru');
    final progress = stats.currentMax <= 0
        ? 0.0
        : (stats.current / stats.currentMax).clamp(0.0, 1.0);

    return HoverRegion(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CourseScreen(courseId: course.id),
        ),
      ),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(course.title,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                  const Gap(AppSpacing.xs),
                  _GradeBadge(stats: stats),
                ],
              ),
              const Gap(AppSpacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
              const Gap(AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xxs,
                children: [
                  _Meta(
                    icon: Icons.trending_up,
                    text:
                        '${_num(stats.current)}/${_num(stats.currentMax)} в семестре',
                  ),
                  _Meta(
                    icon: Icons.how_to_reg,
                    text: '${stats.visited}/${stats.lessons} пар',
                  ),
                  if (stats.nextDeadline != null)
                    _Meta(
                      icon: Icons.flag_outlined,
                      text: 'до ${df.format(stats.nextDeadline!)}',
                    ),
                  if (stats.overdue > 0)
                    _Meta(
                      icon: Icons.warning_amber_rounded,
                      text: '${stats.overdue} просрочено',
                      color: theme.colorScheme.error,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolved = color ?? theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: resolved),
        const Gap(4),
        Text(text, style: theme.textTheme.bodySmall?.copyWith(color: resolved)),
      ],
    );
  }
}

class _GradeBadge extends StatelessWidget {
  const _GradeBadge({required this.stats});

  final CourseStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final passed = stats.total >= stats.scale.passThreshold;
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color:
            passed ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Text(
        '${stats.predictedGrade}',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: passed ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

String _num(double value) => value == value.roundToDouble()
    ? '${value.round()}'
    : value.toStringAsFixed(1);

class _CourseDialog extends ConsumerStatefulWidget {
  const _CourseDialog({required this.term});

  final Term term;

  @override
  ConsumerState<_CourseDialog> createState() => _CourseDialogState();
}

class _CourseDialogState extends ConsumerState<_CourseDialog> {
  final _title = TextEditingController();
  var _kind = CourseKind.exam;
  var _preset = 0;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Новая дисциплина'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _title,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            const Gap(AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                for (final kind in CourseKind.values)
                  ChoiceChip(
                    label: Text(courseKindLabel(kind)),
                    selected: _kind == kind,
                    onSelected: (_) => setState(() => _kind = kind),
                  ),
              ],
            ),
            const Gap(AppSpacing.md),
            DropdownButtonFormField<int>(
              initialValue: _preset,
              decoration: const InputDecoration(labelText: 'Шкала'),
              items: [
                for (var i = 0; i < gradeScalePresets.length; i++)
                  DropdownMenuItem(
                    value: i,
                    child: Text(gradeScalePresets[i].label),
                  ),
              ],
              onChanged: (value) => setState(() => _preset = value ?? 0),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            final title = _title.text.trim();
            if (title.isEmpty) return;
            ref.read(journalProvider.notifier).addCourse(
                  Course(
                    id: 'course-${DateTime.now().microsecondsSinceEpoch}',
                    termId: widget.term.id,
                    title: title,
                    kind: _kind,
                    scale: gradeScalePresets[_preset].build(),
                    colorIndex: DateTime.now().millisecond % 5,
                  ),
                );
            Navigator.of(context).pop();
          },
          child: const Text('Добавить'),
        ),
      ],
    );
  }
}
