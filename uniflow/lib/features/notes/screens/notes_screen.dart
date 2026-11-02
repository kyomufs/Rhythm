import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:uniflow/core/models/note_models.dart';
import 'package:uniflow/features/notes/providers/notes_provider.dart';
import 'package:uniflow/features/notes/screens/subject_detail_screen.dart';
import 'package:uniflow/features/schedule/providers/schedule_provider.dart';

/// Notes main screen — list of subject folders
class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final notesState = ref.watch(notesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Заметки'),
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSubjectSheet(context, ref),
        tooltip: 'Добавить предмет',
        child: const Icon(Icons.add),
      ),
      body: notesState.folders.isEmpty
          ? _buildEmptyState(context, ref)
          : _buildSubjectList(context, ref, notesState, theme, colorScheme),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.school_outlined,
                  size: 72,
                  color: colorScheme.primary.withValues(alpha: 0.6),
                ),
              ),
            ),
            const Gap(32),
            Text(
              'Нет предметов',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Gap(12),
            Text(
              'Добавьте предметы для отслеживания\nзадач и прогресса по курсам',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const Gap(32),
            FilledButton.icon(
              onPressed: () => _showAddSubjectSheet(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Добавить предмет'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectList(
    BuildContext context,
    WidgetRef ref,
    NotesState notesState,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.read(notesProvider.notifier).refresh();
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: notesState.folders.length,
        itemBuilder: (context, index) {
          final folder = notesState.folders[index];
          final color =
              Color(subjectColors[folder.colorIndex % subjectColors.length]);
          final totalTasks = folder.totalTasks;
          final completedTasks = folder.completedTasks;
          final progress = totalTasks > 0 ? completedTasks / totalTasks : 0.0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Dismissible(
              key: Key(folder.id),
              direction: DismissDirection.endToStart,
              confirmDismiss: (direction) async {
                return await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Удалить предмет?'),
                    content: Text(
                      'Все задачи по предмету «${folder.name}» будут удалены.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Отмена'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.error,
                        ),
                        child: const Text('Удалить'),
                      ),
                    ],
                  ),
                );
              },
              onDismissed: (_) {
                ref.read(notesProvider.notifier).deleteSubject(folder.id);
              },
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: colorScheme.error,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.delete, color: colorScheme.onError),
              ),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            SubjectDetailScreen(subjectId: folder.id),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Color indicator
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.school,
                              color: color,
                              size: 24,
                            ),
                          ),
                        ),
                        const Gap(12),
                        // Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                folder.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (folder.teacher != null &&
                                  folder.teacher!.isNotEmpty) ...[
                                const Gap(2),
                                Text(
                                  folder.teacher!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const Gap(4),
                              // Subfolder chips (hidden ones stay out)
                              if (folder.subfolders.any((sf) => !sf.isHidden))
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: folder.subfolders
                                      .where((sf) => !sf.isHidden)
                                      .map((sf) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${sf.name} ${sf.completedCount}/${sf.tasks.length}',
                                        style: theme.textTheme.labelSmall,
                                      ),
                                    );
                                  }).toList(),
                                ),
                            ],
                          ),
                        ),
                        // Progress
                        if (totalTasks > 0)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$completedTasks/$totalTasks',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: completedTasks == totalTasks
                                      ? colorScheme.tertiary
                                      : colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Gap(4),
                              SizedBox(
                                width: 48,
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor:
                                      colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          )
                        else
                          Icon(
                            Icons.chevron_right,
                            color: colorScheme.onSurfaceVariant,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Add subject bottom sheet
  void _showAddSubjectSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _AddSubjectSheet(
        ref: ref,
        scheduleSubjects:
            ref.read(scheduleScreenProvider.notifier).getUniqueSubjects(),
        onAdd: (folder) {
          ref.read(notesProvider.notifier).addSubject(folder);
          Navigator.pop(context);
        },
      ),
    );
  }
}

// ============================================================
// Add Subject Sheet
// ============================================================
class _AddSubjectSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;
  final List<String> scheduleSubjects;
  final ValueChanged<SubjectFolder> onAdd;

  const _AddSubjectSheet({
    required this.ref,
    required this.scheduleSubjects,
    required this.onAdd,
  });

  @override
  ConsumerState<_AddSubjectSheet> createState() => _AddSubjectSheetState();
}

class _AddSubjectSheetState extends ConsumerState<_AddSubjectSheet> {
  final _nameController = TextEditingController();
  final _teacherController = TextEditingController();
  int _selectedColor = 0;
  bool _fromSchedule = false;
  bool _teacherFromSchedule = false;
  String? _selectedSubjectFromSchedule;

  @override
  void dispose() {
    _nameController.dispose();
    _teacherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = DateTime.now();
    final id = '${now.millisecondsSinceEpoch}';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Добавить предмет',
            style: theme.textTheme.titleLarge,
          ),
          const Gap(16),

          // Toggle: manual or from schedule. FittedBox labels scale down
          // instead of clipping on narrow dialogs (same rule as the task
          // sheet's status/priority segments).
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Вручную', maxLines: 1),
                ),
                icon: Icon(Icons.edit, size: 18),
              ),
              ButtonSegment(
                value: true,
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Из расписания', maxLines: 1),
                ),
                icon: Icon(Icons.school, size: 18),
              ),
            ],
            selected: {_fromSchedule},
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
            onSelectionChanged: (set) {
              setState(() {
                _fromSchedule = set.first;
                if (_fromSchedule && widget.scheduleSubjects.isNotEmpty) {
                  _selectedSubjectFromSchedule = widget.scheduleSubjects.first;
                  _nameController.text = widget.scheduleSubjects.first;
                  _autoFillTeacher(widget.scheduleSubjects.first);
                } else {
                  _selectedSubjectFromSchedule = null;
                  _nameController.clear();
                  _teacherController.clear();
                  _teacherFromSchedule = false;
                }
              });
            },
          ),
          const Gap(16),

          if (_fromSchedule && widget.scheduleSubjects.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Сначала выберите группу в расписании',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else if (_fromSchedule)
            // MD3 style: tap to open subject picker bottom sheet
            Material(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () =>
                    _showSubjectPicker(context, widget.scheduleSubjects),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(Icons.school_outlined,
                          size: 20, color: colorScheme.onSurfaceVariant),
                      const Gap(12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Предмет',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const Gap(2),
                            Text(
                              _selectedSubjectFromSchedule ??
                                  'Выберите предмет',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: _selectedSubjectFromSchedule != null
                                    ? colorScheme.onSurface
                                    : colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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
            )
          else
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Название предмета',
                hintText: 'Например, Математический анализ',
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          const Gap(12),

          // Teacher field
          TextField(
            controller: _teacherController,
            readOnly: _teacherFromSchedule,
            decoration: InputDecoration(
              labelText: 'Преподаватель (необязательно)',
              hintText: _teacherFromSchedule
                  ? 'Авто из расписания'
                  : 'Например, Иванов И.И.',
              suffixIcon: _teacherFromSchedule
                  ? const Icon(Icons.lock_outline, size: 18)
                  : null,
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const Gap(16),

          // Color picker
          Text(
            'Цвет',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Gap(8),
          Row(
            children: List.generate(subjectColors.length, (i) {
              final isSelected = _selectedColor == i;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = i),
                child: Container(
                  width: 36,
                  height: 36,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Color(subjectColors[i]),
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                            color: theme.colorScheme.onSurface,
                            width: 3,
                          )
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
              );
            }),
          ),
          const Gap(24),

          // Add button
          FilledButton(
            onPressed: _nameController.text.isEmpty
                ? null
                : () {
                    // Create default subfolders from defaultSubfolderNames
                    final subfolders = defaultSubfolderNames
                        .map((name) => SubjectSubfolder(
                              id: '${id}_${defaultSubfolderNames.indexOf(name)}',
                              name: name,
                              isDefault: true,
                            ))
                        .toList();

                    final folder = SubjectFolder(
                      id: id,
                      name: _nameController.text,
                      teacher: _teacherController.text.isNotEmpty
                          ? _teacherController.text
                          : null,
                      colorIndex: _selectedColor,
                      createdAt: DateTime.now(),
                      subfolders: subfolders,
                    );
                    widget.onAdd(folder);
                  },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  void _autoFillTeacher(String subjectName) {
    final scheduleNotifier = widget.ref.read(scheduleScreenProvider.notifier);
    final teacher = scheduleNotifier.getScheduleTeacherByName(subjectName);
    if (teacher != null && teacher.isNotEmpty) {
      setState(() {
        _teacherController.text = teacher;
        _teacherFromSchedule = true;
      });
    } else {
      setState(() {
        _teacherController.text = '';
        _teacherFromSchedule = false;
      });
    }
  }

  void _showSubjectPicker(BuildContext context, List<String> subjects) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final searchController = TextEditingController();
    List<String> filtered = List.from(subjects);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.3,
              maxChildSize: 0.9,
              expand: false,
              builder: (ctx, scrollController) {
                // Цвет и скругления даёт bottomSheetTheme; крестик не нужен —
                // закрытие свайпом вниз или тапом по затемнению.
                return Material(
                  type: MaterialType.transparency,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Выберите предмет',
                              style: theme.textTheme.titleLarge),
                        ),
                      ),
                      // Search
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: TextField(
                          controller: searchController,
                          decoration: InputDecoration(
                            hintText: 'Поиск предмета',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      searchController.clear();
                                      setModalState(
                                          () => filtered = List.from(subjects));
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (q) {
                            setModalState(() {
                              filtered = subjects
                                  .where((s) =>
                                      s.toLowerCase().contains(q.toLowerCase()))
                                  .toList();
                            });
                          },
                        ),
                      ),
                      const Gap(8),
                      // Subject list
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(
                              height: 1, indent: 16, endIndent: 16),
                          itemBuilder: (ctx, index) {
                            final subject = filtered[index];
                            final isCurrent =
                                subject == _selectedSubjectFromSchedule;
                            return ListTile(
                              leading: Icon(
                                Icons.school_outlined,
                                color: isCurrent
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant,
                              ),
                              title: Text(
                                subject,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: isCurrent
                                  ? Icon(Icons.check,
                                      color: colorScheme.primary)
                                  : null,
                              onTap: () {
                                setState(() {
                                  _selectedSubjectFromSchedule = subject;
                                  _nameController.text = subject;
                                  _autoFillTeacher(subject);
                                });
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
      },
    );
  }
}
