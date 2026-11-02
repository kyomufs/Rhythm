import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:uniflow/core/models/note_models.dart';
import 'package:uniflow/features/notes/providers/notes_provider.dart';

/// Subject detail screen — overview + subfolder tabs
class SubjectDetailScreen extends ConsumerStatefulWidget {
  final String subjectId;

  const SubjectDetailScreen({super.key, required this.subjectId});

  @override
  ConsumerState<SubjectDetailScreen> createState() =>
      _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends ConsumerState<SubjectDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(notesProvider);
    final folder =
        ref.read(notesProvider.notifier).getSubjectById(widget.subjectId);

    if (folder == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Предмет')),
        body: const Center(child: Text('Предмет не найден')),
      );
    }

    final color =
        Color(subjectColors[folder.colorIndex % subjectColors.length]);

    return Scaffold(
      appBar: AppBar(
        title: Text(folder.name),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showActionsSheet(context, ref, folder),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Обзор'),
            Tab(text: 'Задачи'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTaskSheet(context, ref, folder),
        child: const Icon(Icons.add_task),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OverviewTab(folder: folder, color: color),
          _TasksTab(folder: folder, color: color),
        ],
      ),
    );
  }

  void _showActionsSheet(
      BuildContext context, WidgetRef ref, SubjectFolder folder) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Text('Действия',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: const Text('Подпапки'),
              subtitle: const Text('Скрыть, добавить или удалить'),
              onTap: () {
                Navigator.pop(ctx);
                _showSubfolderManager(context, ref, folder);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Редактировать преподавателя'),
              onTap: () {
                Navigator.pop(ctx);
                _showEditTeacherSheet(context, ref, folder);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: colorScheme.error),
              title: Text('Удалить предмет',
                  style: TextStyle(color: colorScheme.error)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, ref, folder);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Subfolder manager: hide/show, add and delete subfolders of a subject.
  void _showSubfolderManager(
      BuildContext context, WidgetRef ref, SubjectFolder folder) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            0, 16, 0, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: StatefulBuilder(
          builder: (ctx, setModalState) {
            final theme = Theme.of(ctx);
            final colorScheme = theme.colorScheme;
            // Local snapshot so the sheet reacts before provider reload.
            final current =
                ref.read(notesProvider.notifier).getSubjectById(folder.id) ??
                    folder;
            final addController = TextEditingController();

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Text('Подпапки',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final sf in current.subfolders)
                        ListTile(
                          dense: true,
                          leading: Icon(
                            sf.isHidden
                                ? Icons.folder_off_outlined
                                : Icons.folder_outlined,
                            color: sf.isHidden
                                ? colorScheme.outline
                                : colorScheme.primary,
                          ),
                          title: Text(
                            sf.name,
                            style: TextStyle(
                              decoration: sf.isHidden
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: sf.isHidden
                                  ? colorScheme.outline
                                  : colorScheme.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            '${sf.tasks.length} задач',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: sf.isHidden ? 'Показать' : 'Скрыть',
                                icon: Icon(
                                  sf.isHidden
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: sf.isHidden
                                      ? colorScheme.outline
                                      : colorScheme.onSurfaceVariant,
                                ),
                                onPressed: () async {
                                  await ref
                                      .read(notesProvider.notifier)
                                      .setSubfolderHidden(
                                          folder.id, sf.id, !sf.isHidden);
                                  setModalState(() {});
                                },
                              ),
                              IconButton(
                                tooltip: 'Удалить',
                                icon: Icon(Icons.delete_outline,
                                    color: colorScheme.error),
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: ctx,
                                    builder: (dc) => AlertDialog(
                                      title: const Text('Удалить подпапку?'),
                                      content: Text(
                                        '«${sf.name}» и все её задачи '
                                        'будут удалены.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(dc, false),
                                          child: const Text('Отмена'),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(dc, true),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: colorScheme.error,
                                          ),
                                          child: const Text('Удалить'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true) {
                                    await ref
                                        .read(notesProvider.notifier)
                                        .deleteSubfolder(folder.id, sf.id);
                                    setModalState(() {});
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: addController,
                          decoration: const InputDecoration(
                            hintText: 'Новая подпапка',
                            isDense: true,
                          ),
                          textCapitalization: TextCapitalization.sentences,
                        ),
                      ),
                      const Gap(8),
                      FilledButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Добавить'),
                        onPressed: () async {
                          final name = addController.text.trim();
                          if (name.isEmpty) return;
                          await ref.read(notesProvider.notifier).addSubfolder(
                                folder.id,
                                SubjectSubfolder(
                                  id: '${folder.id}_'
                                      '${DateTime.now().millisecondsSinceEpoch}',
                                  name: name,
                                ),
                              );
                          addController.clear();
                          setModalState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showEditTeacherSheet(
      BuildContext context, WidgetRef ref, SubjectFolder folder) {
    final controller = TextEditingController(text: folder.teacher ?? '');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Преподаватель',
                style: Theme.of(context).textTheme.titleLarge),
            const Gap(16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Имя преподавателя',
                hintText: 'Например, Иванов И.И.',
              ),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
            ),
            const Gap(24),
            FilledButton(
              onPressed: () {
                ref.read(notesProvider.notifier).updateSubject(
                      folder.copyWith(
                        teacher:
                            controller.text.isNotEmpty ? controller.text : null,
                      ),
                    );
                Navigator.pop(ctx);
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, SubjectFolder folder) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить предмет?'),
        content: Text(
          'Все задачи по предмету «${folder.name}» будут удалены.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(notesProvider.notifier).deleteSubject(folder.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  void _showAddTaskSheet(
      BuildContext context, WidgetRef ref, SubjectFolder folder) {
    if (folder.subfolders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала создайте подпапку')),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _TaskSheet(
        folder: folder,
        onSave: (task, subfolderId) {
          ref.read(notesProvider.notifier).saveTask(
                folder.id,
                subfolderId,
                task,
              );
        },
      ),
    );
  }
}

// ============================================================
// Overview Tab
// ============================================================
class _OverviewTab extends StatelessWidget {
  final SubjectFolder folder;
  final Color color;

  const _OverviewTab({required this.folder, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final totalTasks = folder.totalTasks;
    final completedTasks = folder.completedTasks;
    final upcoming = folder.upcomingDeadlines;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card with teacher + progress ring
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                // Progress ring
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CustomPaint(
                    painter: _ProgressRingPainter(
                      progress: folder.completionPercent,
                      color: color,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                    ),
                    child: Center(
                      child: Text(
                        '${(folder.completionPercent * 100).round()}%',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                ),
                const Gap(16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        folder.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (folder.teacher != null &&
                          folder.teacher!.isNotEmpty) ...[
                        const Gap(4),
                        Text(
                          folder.teacher!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Gap(16),

          // Stats cards
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Всего задач',
                  value: '$totalTasks',
                  icon: Icons.list_alt,
                  color: colorScheme.primary,
                ),
              ),
              const Gap(8),
              Expanded(
                child: _StatCard(
                  label: 'Выполнено',
                  value: '$completedTasks',
                  icon: Icons.check_circle_outline,
                  color: colorScheme.tertiary,
                ),
              ),
              const Gap(8),
              Expanded(
                child: _StatCard(
                  label: 'В работе',
                  value: '${totalTasks - completedTasks}',
                  icon: Icons.pending_outlined,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const Gap(16),

          // Upcoming deadlines
          if (upcoming.isNotEmpty) ...[
            Text(
              'Ближайшие дедлайны',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Gap(8),
            ...upcoming.take(5).map((task) {
              final daysUntil = task.dueDate!.difference(DateTime.now()).inDays;
              final isUrgent = daysUntil <= 3;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    task.status == TaskStatus.done
                        ? Icons.check_circle
                        : Icons.pending_outlined,
                    color: task.status == TaskStatus.done
                        ? colorScheme.tertiary
                        : isUrgent
                            ? colorScheme.error
                            : colorScheme.primary,
                  ),
                  title: Text(
                    task.title,
                    style: TextStyle(
                      decoration: task.status == TaskStatus.done
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    DateFormat('d MMMM', 'ru').format(task.dueDate!),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: isUrgent
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            daysUntil == 0 ? 'Сегодня' : '$daysUntil дн.',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : null,
                ),
              );
            }),
          ],

          if (totalTasks == 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(
                      Icons.add_task,
                      size: 48,
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const Gap(12),
                    Text(
                      'Нет задач',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Gap(4),
                    Text(
                      'Добавьте задачи в подпапки',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// Tasks Tab
// ============================================================
class _TasksTab extends StatelessWidget {
  final SubjectFolder folder;
  final Color color;

  const _TasksTab({required this.folder, required this.color});

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
              builder: (ctx) => _TaskSheet(
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

// ============================================================
// Task Sheet — unified create + edit (identical fields)
// ============================================================
class _TaskSheet extends StatefulWidget {
  final SubjectFolder folder;

  /// Existing task to edit; null -> create mode.
  final StudyTask? task;

  /// Subfolder preselected in create mode.
  final String? initialSubfolderId;

  final void Function(StudyTask task, String subfolderId) onSave;

  const _TaskSheet({
    required this.folder,
    required this.onSave,
    this.task,
    this.initialSubfolderId,
  });

  @override
  State<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<_TaskSheet> {
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
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }
}

// ============================================================
// Stat Card
// ============================================================
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: SizedBox(
        height: 96,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const Gap(4),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const Gap(2),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Progress Ring Painter
// ============================================================
class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _ProgressRingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Background circle
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
