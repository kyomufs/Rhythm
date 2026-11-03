import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:uniflow/core/models/note_models.dart';

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

  /// Compact density + tighter side padding so full Russian labels
  /// ("К выполнению", "Средний") fit three segments on a phone width.
  ButtonStyle _segmentButtonStyle() => ButtonStyle(
        visualDensity: VisualDensity.compact,
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 8),
        ),
      );

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

            // Status — full-width segmented buttons (easier to tap than
            // tiny chips). Labels lead: segments share the row width, so
            // a FittedBox scales long Russian words down instead of
            // clipping them ("К вы | В выпо" bug).
            Text('Статус',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const Gap(8),
            SegmentedButton<TaskStatus>(
              segments: [
                ButtonSegment(
                  value: TaskStatus.todo,
                  label: _SegmentLabel(taskStatusDisplayName(TaskStatus.todo)),
                ),
                ButtonSegment(
                  value: TaskStatus.inProgress,
                  label: _SegmentLabel(
                      taskStatusDisplayName(TaskStatus.inProgress)),
                ),
                ButtonSegment(
                  value: TaskStatus.done,
                  label: _SegmentLabel(taskStatusDisplayName(TaskStatus.done)),
                ),
              ],
              selected: {_status},
              showSelectedIcon: false,
              style: _segmentButtonStyle(),
              onSelectionChanged: (s) => setState(() => _status = s.first),
            ),
            const Gap(16),

            // Priority — segmented buttons with semantic colors
            Text('Приоритет',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const Gap(8),
            SegmentedButton<TaskPriority>(
              segments: [
                ButtonSegment(
                  value: TaskPriority.low,
                  label:
                      _SegmentLabel(taskPriorityDisplayName(TaskPriority.low)),
                ),
                ButtonSegment(
                  value: TaskPriority.medium,
                  label: _SegmentLabel(
                      taskPriorityDisplayName(TaskPriority.medium)),
                ),
                ButtonSegment(
                  value: TaskPriority.high,
                  label:
                      _SegmentLabel(taskPriorityDisplayName(TaskPriority.high)),
                ),
              ],
              selected: {_priority},
              showSelectedIcon: false,
              style: _segmentButtonStyle().copyWith(
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (!states.contains(WidgetState.selected)) return null;
                  final scheme = Theme.of(context).colorScheme;
                  switch (_priority) {
                    case TaskPriority.low:
                      return scheme.onSecondaryContainer;
                    case TaskPriority.medium:
                      return scheme.onSurface;
                    case TaskPriority.high:
                      return scheme.onErrorContainer;
                  }
                }),
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (!states.contains(WidgetState.selected)) return null;
                  final scheme = Theme.of(context).colorScheme;
                  switch (_priority) {
                    case TaskPriority.low:
                      return scheme.secondaryContainer;
                    case TaskPriority.medium:
                      return scheme.surfaceContainerHighest;
                    case TaskPriority.high:
                      return scheme.errorContainer;
                  }
                }),
              ),
              onSelectionChanged: (p) => setState(() => _priority = p.first),
            ),
            const Gap(16),

            // Subfolder selector — MD3 tap-to-open style
            Material(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
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
// ============================================================
// Segment label — scales instead of clipping
// ============================================================

/// Segment label that scales the text down when the segment is narrower
/// than the full word, instead of clipping it mid-letter.
class _SegmentLabel extends StatelessWidget {
  final String text;

  const _SegmentLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}
