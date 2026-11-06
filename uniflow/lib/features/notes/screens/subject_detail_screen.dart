import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:uniflow/core/models/note_models.dart';
import 'package:uniflow/core/theme/motion.dart';
import 'package:uniflow/features/notes/providers/notes_provider.dart';
import 'package:uniflow/features/notes/widgets/overview_tab.dart';
import 'package:uniflow/features/notes/widgets/task_list.dart';
import 'package:uniflow/features/notes/widgets/task_sheet.dart';
import 'package:uniflow/shared/widgets/expressive_button_group.dart';

/// Subject detail screen — overview + subfolder tabs
class SubjectDetailScreen extends ConsumerStatefulWidget {
  final String subjectId;

  const SubjectDetailScreen({super.key, required this.subjectId});

  @override
  ConsumerState<SubjectDetailScreen> createState() =>
      _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends ConsumerState<SubjectDetailScreen> {
  /// 0 — обзор, 1 — задачи. Страницы листаются, группа кнопок задаёт
  /// выбранную: два способа переключения живут на одном состоянии.
  int _tab = 0;
  late final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTaskSheet(context, ref, folder),
        child: const Icon(Icons.add_task),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: ExpressiveButtonGroup<int>(
              values: const [0, 1],
              selected: _tab,
              labelOf: (tab) => tab == 0 ? 'Обзор' : 'Задачи',
              iconOf: (tab) =>
                  tab == 0 ? Icons.dashboard_outlined : Icons.checklist,
              onChanged: (tab) {
                if (tab == _tab) return;
                setState(() => _tab = tab);
                // Страница едет spatial-пружиной: пролистывание и нажатие
                // выглядят одинаково, источник переключения не важен.
                _pageController.animateToPage(
                  tab,
                  duration: springDuration(MotionTokens.defaultSpatial),
                  curve: Curves.easeOutCubic,
                );
              },
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (tab) => setState(() => _tab = tab),
              children: [
                OverviewTab(folder: folder, color: color),
                TasksTab(folder: folder, color: color),
              ],
            ),
          ),
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
      builder: (ctx) => TaskSheet(
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
