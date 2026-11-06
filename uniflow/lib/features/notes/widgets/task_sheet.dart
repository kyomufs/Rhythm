import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:uniflow/core/models/note_models.dart';
import 'package:uniflow/core/theme/shapes.dart';
import 'package:uniflow/shared/widgets/expressive_button_group.dart';

/// Лист задачи: одно и то же поле для создания и редактирования.
class TaskSheet extends StatefulWidget {
  final SubjectFolder folder;

  /// Existing task to edit; null -> create mode.
  final StudyTask? task;

  /// Subfolder preselected in create mode.
  final String? initialSubfolderId;

  final void Function(StudyTask task, String subfolderId) onSave;

  const TaskSheet({
    super.key,
    required this.folder,
    required this.onSave,
    this.task,
    this.initialSubfolderId,
  });

  @override
  State<TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<TaskSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _gradeController;
  late String? _subfolderId;
  late TaskStatus _status;
  late TaskPriority _priority;
  DateTime? _dueDate;

  bool get _isEdit => widget.task != null;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _titleController = TextEditingController(text: task?.title ?? '');
    _descriptionController =
        TextEditingController(text: task?.description ?? '');
    _gradeController = TextEditingController(text: task?.grade ?? '');
    // Prefer the first visible subfolder; fall back to any (the current
    // task may live in a hidden one, which must stay selectable).
    final visible = widget.folder.subfolders.where((sf) => !sf.isHidden);
    _subfolderId = widget.initialSubfolderId ??
        (visible.isNotEmpty
            ? visible.first.id
            : widget.folder.subfolders.isNotEmpty
                ? widget.folder.subfolders.first.id
                : null);
    _status = task?.status ?? TaskStatus.todo;
    _priority = task?.priority ?? TaskPriority.medium;
    _dueDate = task?.dueDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _gradeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEdit ? 'Редактирование задачи' : 'Новая задача',
              style: theme.textTheme.titleLarge,
            ),
            const Gap(16),

            // Title
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Название задачи',
                hintText: 'Например, Лабораторная работа №3',
              ),
              textCapitalization: TextCapitalization.sentences,
              autofocus: !_isEdit,
            ),
            const Gap(12),

            // Description
            TextField(
              controller: _descriptionController,
              decoration:
                  const InputDecoration(labelText: 'Описание (необязательно)'),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
            ),
            const Gap(16),

            // Статус — связная группа M3E: выбранная кнопка перетекает
            // из таблетки в квадрат, соседи остаются на месте.
            Text('Статус',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const Gap(8),
            ExpressiveButtonGroup<TaskStatus>(
              values: TaskStatus.values,
              selected: _status,
              // В шторке три сегмента делят 360dp: «К выполнению» не влезает
              // и режется многоточием, поэтому здесь короткие подписи.
              labelOf: (status) => switch (status) {
                TaskStatus.todo => 'Новая',
                TaskStatus.inProgress => 'В работе',
                TaskStatus.done => 'Готово',
              },
              onChanged: (status) => setState(() => _status = status),
            ),
            const Gap(16),

            // Приоритет — та же связная группа; значок стрелки задаёт
            // направление, поэтому цвет внутри группы не нужен.
            Text('Приоритет',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const Gap(8),
            ExpressiveButtonGroup<TaskPriority>(
              values: TaskPriority.values,
              selected: _priority,
              labelOf: taskPriorityDisplayName,
              iconOf: (priority) {
                switch (priority) {
                  case TaskPriority.low:
                    return Icons.arrow_downward;
                  case TaskPriority.medium:
                    return Icons.remove;
                  case TaskPriority.high:
                    return Icons.priority_high;
                }
              },
              onChanged: (priority) => setState(() => _priority = priority),
            ),
            const Gap(16),

            // Subfolder selector — MD3 tap-to-open style
            Material(
              color: colorScheme.surfaceContainerLow,
              borderRadius: AppShapes.circular(AppShapes.medium),
              child: InkWell(
                borderRadius: AppShapes.circular(AppShapes.medium),
                onTap: () {
                  final candidates = widget.folder.subfolders
                      .where((sf) => !sf.isHidden || sf.id == _subfolderId)
                      .toList();
                  final selected = candidates.firstWhere(
                    (sf) => sf.id == _subfolderId,
                    orElse: () => candidates.first,
                  );
                  _showSubfolderPicker(context, candidates, selected);
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(Icons.folder_outlined,
                          size: 20, color: colorScheme.onSurfaceVariant),
                      const Gap(12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Подпапка',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                )),
                            const Gap(2),
                            Text(
                              widget.folder.subfolders
                                      .where((sf) => sf.id == _subfolderId)
                                      .map((sf) => sf.name)
                                      .firstOrNull ??
                                  'Выберите подпапку',
                              style: theme.textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.unfold_more,
                          color: colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ),
            const Gap(16),

            // Due date — editable in both modes, can be cleared
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _dueDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        locale: const Locale('ru'),
                      );
                      if (picked != null) {
                        setState(() => _dueDate = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _dueDate != null
                          ? DateFormat('d MMMM yyyy', 'ru').format(_dueDate!)
                          : 'Дата сдачи (необязательно)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (_dueDate != null) ...[
                  const Gap(4),
                  IconButton(
                    onPressed: () => setState(() => _dueDate = null),
                    icon: const Icon(Icons.clear),
                    tooltip: 'Убрать дату',
                  ),
                ],
              ],
            ),
            const Gap(12),

            // Grade
            TextField(
              controller: _gradeController,
              decoration: const InputDecoration(
                labelText: 'Оценка (необязательно)',
                hintText: 'Например, 5 или «Отлично»',
              ),
            ),
            const Gap(24),

            FilledButton(
              onPressed: () {
                final title = _titleController.text.trim();
                if (title.isEmpty || _subfolderId == null) return;
                final base = widget.task;
                final description = _descriptionController.text.trim();
                final grade = _gradeController.text.trim();
                final task = StudyTask(
                  id: base?.id ??
                      DateTime.now().millisecondsSinceEpoch.toString(),
                  title: title,
                  description: description.isEmpty ? null : description,
                  status: _status,
                  dueDate: _dueDate,
                  grade: grade.isEmpty ? null : grade,
                  priority: _priority,
                  createdAt: base?.createdAt ?? DateTime.now(),
                );
                widget.onSave(task, _subfolderId!);
                Navigator.pop(context);
              },
              child: Text(_isEdit ? 'Сохранить' : 'Добавить'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSubfolderPicker(BuildContext context,
      List<SubjectSubfolder> subfolders, SubjectSubfolder current) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final colorScheme = theme.colorScheme;
        return DraggableScrollableSheet(
          initialChildSize: 0.4,
          minChildSize: 0.2,
          maxChildSize: 0.7,
          expand: false,
          builder: (ctx, scrollController) {
            // Цвет и скругления — из bottomSheetTheme. Крестик убран:
            // закрытие свайпом вниз или тапом по затемнению.
            return Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Выберите подпапку',
                          style: theme.textTheme.titleLarge),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: subfolders.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 16, endIndent: 16),
                      itemBuilder: (ctx, index) {
                        final sf = subfolders[index];
                        final isCurrent = sf.id == current.id;
                        return ListTile(
                          leading: Icon(
                            sf.isDefault ? Icons.folder : Icons.folder_special,
                            color: isCurrent
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                          title: Text(sf.name),
                          trailing: isCurrent
                              ? Icon(Icons.check, color: colorScheme.primary)
                              : null,
                          onTap: () {
                            setState(() => _subfolderId = sf.id);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}