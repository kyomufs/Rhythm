import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:tulgusch/core/domain/journal.dart';
import 'package:tulgusch/core/journal/journal_store.dart';
import 'package:tulgusch/core/theme/shapes.dart';
import 'package:tulgusch/core/theme/spacing.dart';
import 'package:tulgusch/core/theme/typography.dart';
import 'package:tulgusch/shared/widgets/morph_chip.dart';

/// Редактор семестра: имя, границы и удаление вместе с содержимым.
///
/// Семестр — это контейнер для дисциплин, поэтому удаление всегда
/// подтверждается отдельно: вместе с ним уходят пары и события.
class TermEditorDialog extends ConsumerStatefulWidget {
  const TermEditorDialog({super.key, this.term});

  final Term? term;

  @override
  ConsumerState<TermEditorDialog> createState() => _TermEditorDialogState();
}

class _TermEditorDialogState extends ConsumerState<TermEditorDialog> {
  late final _title = TextEditingController(
    text: widget.term?.title ?? _defaultTitle(),
  );
  late DateTime _start = widget.term?.start ?? _defaultRange().$1;
  late DateTime _end = widget.term?.end ?? _defaultRange().$2;

  String _defaultTitle() {
    final now = DateTime.now();
    final year = now.month >= 8 ? now.year : now.year - 1;
    final season = now.month >= 8 ? 'Осенний' : 'Весенний';
    return '$season семестр $year/${(year + 1) % 100}';
  }

  (DateTime, DateTime) _defaultRange() {
    final now = DateTime.now();
    return now.month >= 8
        ? (DateTime(now.year, 9, 1), DateTime(now.year, 12, 31))
        : (DateTime(now.year, 2, 7), DateTime(now.year, 6, 30));
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool start}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
        if (_end.isBefore(_start)) _end = _start;
      } else {
        _end = picked;
        if (_end.isBefore(_start)) _start = _end;
      }
    });
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final notifier = ref.read(journalProvider.notifier);
    final term = widget.term;
    if (term == null) {
      notifier.addTerm(Term(
        id: 'term-${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        start: _start,
        end: _end,
      ));
    } else {
      notifier.updateTerm(term.copyWith(
        title: title,
        start: _start,
        end: _end,
      ));
    }
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final term = widget.term;
    if (term == null) return;
    final confirmed = await confirmDelete(
      context,
      title: 'Удалить семестр?',
      message: 'Вместе с «${term.title}» удалятся его дисциплины, '
          'пары и события. Это необратимо.',
    );
    if (!confirmed || !mounted) return;
    ref.read(journalProvider.notifier).deleteTerm(term.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(
        widget.term == null ? 'Новый семестр' : 'Семестр',
        style: AppTypography.emphasizedTitleLarge(theme.textTheme.titleLarge!),
      ),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _title,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              const Gap(AppSpacing.sm),
              _DateField(
                label: 'Начало',
                value: _start,
                onTap: () => _pickDate(start: true),
              ),
              const Gap(AppSpacing.xs),
              _DateField(
                label: 'Конец',
                value: _end,
                onTap: () => _pickDate(start: false),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.term != null)
          TextButton(
            onPressed: _delete,
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: const Text('Удалить'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(onPressed: _save, child: const Text('Сохранить')),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppShapes.small),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppShapes.small),
        ),
        child: Row(
          children: [
            Icon(Icons.event_outlined,
                size: 20, color: theme.colorScheme.onSurfaceVariant),
            const Gap(AppSpacing.xs),
            Text(label, style: theme.textTheme.bodyMedium),
            const Spacer(),
            Text(
              DateFormat('d MMMM y', 'ru').format(value),
              style: theme.textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }
}

/// Редактор дисциплины: имя, преподаватель, тип и — только при создании —
/// стартовая шкала. Существующую шкалу меняют на вкладке «Шкала», чтобы
/// категории не сбрасывались из-за смены типа.
class CourseEditorDialog extends ConsumerStatefulWidget {
  const CourseEditorDialog({super.key, required this.term, this.course});

  final Term term;
  final Course? course;

  @override
  ConsumerState<CourseEditorDialog> createState() => _CourseEditorDialogState();
}

class _CourseEditorDialogState extends ConsumerState<CourseEditorDialog> {
  late final _title = TextEditingController(text: widget.course?.title ?? '');
  late final _teacher =
      TextEditingController(text: widget.course?.teacher ?? '');
  late var _kind = widget.course?.kind ?? CourseKind.exam;
  var _preset = 0;

  @override
  void dispose() {
    _title.dispose();
    _teacher.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final teacher = _teacher.text.trim();
    final notifier = ref.read(journalProvider.notifier);
    final course = widget.course;
    if (course == null) {
      notifier.addCourse(Course(
        id: 'course-${DateTime.now().microsecondsSinceEpoch}',
        termId: widget.term.id,
        title: title,
        teacher: teacher.isEmpty ? null : teacher,
        kind: _kind,
        scale: gradeScalePresets[_preset].build(),
        colorIndex: notifier.data.courses.length,
      ));
    } else {
      notifier.updateCourse(course.copyWith(
        title: title,
        teacher: teacher.isEmpty ? null : teacher,
        kind: _kind,
      ));
    }
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final course = widget.course;
    if (course == null) return;
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
    return AlertDialog(
      title: Text(
        widget.course == null ? 'Новая дисциплина' : 'Дисциплина',
        style: AppTypography.emphasizedTitleLarge(theme.textTheme.titleLarge!),
      ),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _title,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              const Gap(AppSpacing.sm),
              TextField(
                controller: _teacher,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Преподаватель',
                  hintText: 'Необязательно',
                ),
              ),
              const Gap(AppSpacing.md),
              Text('Форма отчётности', style: theme.textTheme.labelLarge),
              const Gap(AppSpacing.xs),
              Row(
                children: [
                  for (final (index, kind) in CourseKind.values.indexed)
                    Flexible(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: index == CourseKind.values.length - 1
                              ? 0
                              : 2,
                        ),
                        child: MorphChip(
                          label: courseKindLabel(kind),
                          selected: _kind == kind,
                          isFirst: index == 0,
                          isLast: index == CourseKind.values.length - 1,
                          onTap: () => setState(() => _kind = kind),
                        ),
                      ),
                    ),
                ],
              ),
              if (widget.course == null) ...[
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
              ] else ...[
                const Gap(AppSpacing.md),
                Text(
                  'Шкала: ${widget.course!.scale.categories.length} '
                  'категорий, порог ${widget.course!.scale.passThreshold.round()}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (widget.course != null)
          TextButton(
            onPressed: _delete,
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: const Text('Удалить'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(onPressed: _save, child: const Text('Сохранить')),
      ],
    );
  }
}

/// Подтверждение необратимого удаления: одно и то же слово в кнопке и
/// заголовке, чтобы действие нельзя было перепутать с «Отменой».
Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
            foregroundColor: Theme.of(ctx).colorScheme.onError,
          ),
          child: const Text('Удалить'),
        ),
      ],
    ),
  );
  return result ?? false;
}
