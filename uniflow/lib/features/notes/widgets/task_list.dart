import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:uniflow/core/models/note_models.dart';
import 'package:uniflow/features/notes/providers/notes_provider.dart';
import 'package:uniflow/features/notes/widgets/task_sheet.dart';

/// Вкладка «Задачи»: скрытые подпапки отфильтрованы, остальные идут секциями.
class TasksTab extends StatelessWidget {
  final SubjectFolder folder;
  final Color color;

  const TasksTab({
    super.key,
    required this.folder,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // Hidden subfolders are managed via ⋮ → «Подпапки» and stay out of
    // the way here; their tasks still count in the subject overview.
    final subfolders = folder.subfolders.where((sf) => !sf.isHidden).toList();

    if (subfolders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 48,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const Gap(12),
            Text(
              folder.subfolders.isEmpty
                  ? 'Нет подпапок'
                  : 'Все подпапки скрыты',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const Gap(4),
            Text(
              'Управляйте ими: меню ⋮ → «Подпапки»',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: subfolders.length,
      itemBuilder: (context, index) {
        final subfolder = subfolders[index];
        return _SubfolderSection(
          folderId: folder.id,
          subfolder: subfolder,
          color: color,
        );
      },
    );
  }
}

// ============================================================
// Subfolder Section
// ============================================================
class _SubfolderSection extends StatelessWidget {
  final String folderId;
  final SubjectSubfolder subfolder;
  final Color color;

  const _SubfolderSection({
    required this.folderId,
    required this.subfolder,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final total = subfolder.tasks.length;
    final done = subfolder.completedCount;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: tinted pill with icon, name and progress counter
          Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
            ),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    subfolder.isDefault
                        ? Icons.folder_outlined
                        : Icons.create_new_folder_outlined,
                    size: 18,
                    color: color,
                  ),
                ),
                const Gap(10),
                Expanded(
                  child: Text(
                    subfolder.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (total > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$done/$total',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: done == total
                            ? colorScheme.tertiary
                            : colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (subfolder.tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Text(
                'Нет задач',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            ...subfolder.tasks.map((task) => _TaskTile(
                  folderId: folderId,
                  subfolderId: subfolder.id,
                  task: task,
                  color: color,
                )),
        ],
      ),
    );
  }
}

// ============================================================
// Task Tile
// ============================================================
class _TaskTile extends StatelessWidget {
  final String folderId;
  final String subfolderId;
  final StudyTask task;
  final Color color;

  const _TaskTile({
    required this.folderId,
    required this.subfolderId,
    required this.task,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDone = task.status == TaskStatus.done;
    final isOverdue = task.dueDate != null &&
        task.dueDate!.isBefore(DateTime.now()) &&
        !isDone;

    // Priority dot color (MD3 tonal pairing: secondary < tertiary < error)
    Color priorityColor;
    switch (task.priority) {
      case TaskPriority.low:
        priorityColor = colorScheme.secondary;
      case TaskPriority.medium:
        priorityColor = colorScheme.tertiary;
      case TaskPriority.high:
        priorityColor = colorScheme.error;
    }

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: colorScheme.error,
        child: Icon(Icons.delete, color: colorScheme.onError),
      ),
      onDismissed: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            ProviderScope.containerOf(context)
                .read(notesProvider.notifier)
                .deleteTask(folderId, subfolderId, task.id);
          }
        });
      },
      // Flat row (the surrounding subfolder card already provides chrome)
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            final folder = ProviderScope.containerOf(context)
                .read(notesProvider.notifier)
                .getSubjectById(folderId);
            if (folder == null) return;
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (ctx) => TaskSheet(
                folder: folder,
                task: task,
                initialSubfolderId: subfolderId,
                onSave: (updatedTask, targetSubfolderId) {
                  ProviderScope.containerOf(context)
                      .read(notesProvider.notifier)
                      .saveTask(folderId, targetSubfolderId, updatedTask);
                },
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Status checkbox
                GestureDetector(
                  onTap: () {
                    final newStatus = isDone
                        ? TaskStatus.todo
                        : task.status == TaskStatus.todo
                            ? TaskStatus.inProgress
                            : TaskStatus.done;
                    ProviderScope.containerOf(context)
                        .read(notesProvider.notifier)
                        .updateTaskStatus(
                            folderId, subfolderId, task.id, newStatus);
                  },
                  child: Icon(
                    isDone
                        ? Icons.check_circle
                        : task.status == TaskStatus.inProgress
                            ? Icons.play_circle_outline
                            : Icons.radio_button_unchecked,
                    color: isDone
                        ? colorScheme.tertiary
                        : task.status == TaskStatus.inProgress
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                ),
                const Gap(10),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              task.title,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                decoration:
                                    isDone ? TextDecoration.lineThrough : null,
                                color: isDone
                                    ? colorScheme.onSurfaceVariant
                                    : colorScheme.onSurface,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const Gap(4),
                      Row(
                        children: [
                          // Priority dot
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: priorityColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const Gap(6),
                          // Due date
                          if (task.dueDate != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isOverdue
                                    ? colorScheme.error.withValues(alpha: 0.12)
                                    : colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 10,
                                    color: isOverdue
                                        ? colorScheme.error
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                  const Gap(4),
                                  Text(
                                    DateFormat('d MMM', 'ru')
                                        .format(task.dueDate!),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: isOverdue
                                          ? colorScheme.error
                                          : colorScheme.onSurfaceVariant,
                                      fontWeight:
                                          isOverdue ? FontWeight.w600 : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // Grade
                          if (task.grade != null) ...[
                            const Gap(6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: colorScheme.tertiaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                task.grade!,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onTertiaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const Gap(4),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
