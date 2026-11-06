import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:uniflow/core/models/schedule.dart';
import 'package:uniflow/core/services/schedule_service.dart';
import 'package:uniflow/core/services/storage_service.dart';
import 'package:uniflow/core/theme/shapes.dart';
import 'package:uniflow/core/theme/typography.dart';
import 'package:uniflow/features/profile/providers/profile_providers.dart';
import 'package:uniflow/features/schedule/providers/schedule_provider.dart';
import 'package:uniflow/shared/widgets/loading_indicator.dart';

/// Student profile editor: group, subgroup and student ID (зачётка)
/// combined into ONE screen with THREE fields, as requested —
/// replaces the three separate bottom sheets from the profile tab.
class StudentProfileScreen extends ConsumerStatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  ConsumerState<StudentProfileScreen> createState() =>
      _StudentProfileScreenState();
}

class _StudentProfileScreenState extends ConsumerState<StudentProfileScreen> {
  late final TextEditingController _groupController;
  late final TextEditingController _subgroupController;
  late final TextEditingController _studentIdController;

  @override
  void initState() {
    super.initState();
    final storage = ref.read(storageServiceProvider);
    final group = ref.read(scheduleScreenProvider).currentGroup ??
        storage.getMyGroup() ??
        '';
    _groupController = TextEditingController(text: group);
    _subgroupController =
        TextEditingController(text: storage.getMySubgroup() ?? '');
    _studentIdController =
        TextEditingController(text: storage.getStudentId() ?? '');
  }

  @override
  void dispose() {
    _groupController.dispose();
    _subgroupController.dispose();
    _studentIdController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final storage = ref.read(storageServiceProvider);
    final group = _groupController.text.trim();
    final subgroup = _subgroupController.text.trim();
    final studentId = _studentIdController.text.trim();

    final previousGroup = ref.read(scheduleScreenProvider).currentGroup;
    if (group.isNotEmpty && group != previousGroup) {
      // Loads the schedule and resets the change-detection baseline.
      await ref.read(scheduleScreenProvider.notifier).setMyGroup(group);
    } else if (group.isEmpty && previousGroup != null) {
      await ref.read(scheduleScreenProvider.notifier).clearMyGroup();
    }
    await storage.setMySubgroup(subgroup);
    await storage.setStudentId(studentId);
    ref.read(profileRevisionProvider.notifier).state++;

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Профиль сохранён')),
    );
  }

  @override
  Widget build(BuildContext context) {
      return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль ученика'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Group ──
          _FieldCard(
            icon: Icons.group_outlined,
            title: 'Группа',
            child: TextField(
              controller: _groupController,
              decoration: InputDecoration(
                hintText: 'Например, 221341',
                prefixIcon: const Icon(Icons.group_outlined),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Найти группу',
                  onPressed: () => _openGroupSearch(),
                ),
              ),
              keyboardType: TextInputType.number,
            ),
          ),
          const Gap(12),

          // ── Subgroup ──
          _FieldCard(
            icon: Icons.subdirectory_arrow_right,
            title: 'Подгруппа',
            hint: 'Нужна для успеваемости. Полный формат: 221341:01',
            child: TextField(
              controller: _subgroupController,
              decoration: const InputDecoration(
                hintText: 'Например, 01',
                prefixIcon: Icon(Icons.subdirectory_arrow_right),
              ),
              keyboardType: TextInputType.number,
            ),
          ),
          const Gap(12),

          // ── Student ID (зачётка) ──
          _FieldCard(
            icon: Icons.badge_outlined,
            title: 'Номер зачётки',
            hint: 'Нужен для загрузки оценок',
            child: TextField(
              controller: _studentIdController,
              decoration: const InputDecoration(
                hintText: 'Например, 221341',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              keyboardType: TextInputType.number,
            ),
          ),
          const Gap(24),

          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Сохранить'),
            ),
          ),
        ],
      ),
    );
  }

  void _openGroupSearch() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _GroupSearchSheet(
        onSelected: (String value) {
          Navigator.pop(context);
          setState(() => _groupController.text = value);
        },
      ),
    );
  }
}

/// Карточка одного поля профиля: подпись, поле и подсказка под ним.
class _FieldCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final String? hint;

  const _FieldCard({
    required this.icon,
    required this.title,
    required this.child,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: AppShapes.circular(AppShapes.largeIncreased),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colorScheme.primary),
              const Gap(8),
              Text(
                title,
                style: AppTypography.emphasizedTitleSmall(
                  theme.textTheme.titleSmall!,
                ),
              ),
            ],
          ),
          const Gap(10),
          child,
          if (hint != null) ...[
            const Gap(6),
            Text(
              hint!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// Group Search Sheet (same behavior as the profile tab)
// ============================================================
class _GroupSearchSheet extends ConsumerStatefulWidget {
  final ValueChanged<String> onSelected;
  const _GroupSearchSheet({required this.onSelected});

  @override
  ConsumerState<_GroupSearchSheet> createState() => _GroupSearchSheetState();
}

class _GroupSearchSheetState extends ConsumerState<_GroupSearchSheet> {
  final _controller = TextEditingController();
  List<SearchResult> _results = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.length < 2) {
      setState(() {
        _results = [];
        _isLoading = false;
      });
      return;
    }
    setState(() => _isLoading = true);
    try {
      final service = ref.read(scheduleServiceProvider);
      final results = await service.search(query);
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        // Цвет и скругления — из bottomSheetTheme: меню поиска не должно
        // выделяться на фоне меню, из которого открыто. Крестик убран,
        // закрытие — свайп вниз или тап по затемнению.
        return Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child:
                      Text('Поиск группы', style: theme.textTheme.titleLarge),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Номер группы',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _controller.clear();
                              _search('');
                            },
                          )
                        : null,
                  ),
                  onChanged: _search,
                  onSubmitted: (v) {
                    if (v.isNotEmpty) widget.onSelected(v);
                  },
                ),
              ),
              const Gap(8),
              Expanded(
                child: _isLoading
                    ? const LoadingIndicator()
                    : _results.isEmpty
                        ? Center(
                            child: Text('Введите минимум 2 символа',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant)),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: _results.length,
                            itemBuilder: (ctx, i) {
                              final r = _results[i];
                              return ListTile(
                                leading: Icon(r.type == SearchResultType.group
                                    ? Icons.group_outlined
                                    : Icons.person_outline),
                                title: Text(r.value),
                                subtitle: Text(r.type.displayName),
                                onTap: () => widget.onSelected(r.value),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}
