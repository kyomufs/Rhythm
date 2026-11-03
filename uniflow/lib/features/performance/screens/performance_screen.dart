import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:uniflow/core/theme/spacing.dart';
import 'package:uniflow/core/theme/typography.dart';
import 'package:uniflow/app.dart';
import 'package:uniflow/core/widgets/update_feedback.dart';
import 'package:uniflow/features/performance/providers/performance_provider.dart';
import 'package:uniflow/features/performance/widgets/marks_table.dart';
import 'package:uniflow/shared/widgets/empty_state.dart';
import 'package:uniflow/shared/widgets/loading_indicator.dart';

/// Performance (academic marks) screen
class PerformanceScreen extends ConsumerWidget {
  const PerformanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final state = ref.watch(performanceProvider);
    final isConfigured = ref.watch(isPerformanceConfiguredProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Успеваемость'),
        centerTitle: false,
        actions: [
          if (isConfigured)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                final result =
                    await ref.read(performanceProvider.notifier).loadMarks();
                if (!context.mounted) return;
                showUpdateFeedback(context, result);
              },
              tooltip: 'Обновить',
            ),
        ],
      ),
      body: !isConfigured
          ? _buildNotConfigured(context, ref, colorScheme, theme)
          // Stale-while-revalidate: cached marks stay visible during a
          // background sync (slim progress bar on top); the full spinner
          // only appears when there is nothing local to show yet.
          : state.isLoading && state.marks.isEmpty
              ? const LoadingIndicator()
              : state.error != null
                  ? _buildError(context, ref, state, colorScheme, theme)
                  : state.marks.isEmpty
                      ? _buildEmpty(context, ref, colorScheme, theme)
                      : Column(
                          children: [
                            if (state.isLoading)
                              const LinearProgressIndicator(minHeight: 2),
                            Expanded(
                              child: _buildMarksView(context, ref, state),
                            ),
                          ],
                        ),
    );
  }

  Widget _buildNotConfigured(BuildContext context, WidgetRef ref,
      ColorScheme colorScheme, ThemeData theme) {
    return EmptyState(
      icon: Icons.school_outlined,
      title: 'Настройте профиль',
      message:
          'Для просмотра успеваемости укажите\nномер зачётки и подгруппу в профиле',
      action: FilledButton.icon(
        onPressed: () => ref.read(currentTabProvider.notifier).state = 3,
        icon: const Icon(Icons.person),
        label: const Text('Открыть профиль'),
      ),
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref,
      PerformanceState state, ColorScheme colorScheme, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 64, color: colorScheme.error.withValues(alpha: 0.5)),
            const Gap(16),
            Text(state.error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant)),
            const Gap(16),
            FilledButton.tonal(
              onPressed: () => ref.read(currentTabProvider.notifier).state = 3,
              child: const Text('Настроить профиль'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, WidgetRef ref,
      ColorScheme colorScheme, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy,
              size: 64, color: colorScheme.primary.withValues(alpha: 0.3)),
          const Gap(16),
          Text('Нет данных об успеваемости',
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: colorScheme.onSurfaceVariant)),
          const Gap(16),
          FilledButton.tonal(
            onPressed: () async {
              final result =
                  await ref.read(performanceProvider.notifier).loadMarks();
              if (!context.mounted) return;
              showUpdateFeedback(context, result);
            },
            child: const Text('Загрузить'),
          ),
        ],
      ),
    );
  }

  Widget _buildMarksView(
      BuildContext context, WidgetRef ref, PerformanceState state) {
    final semesters = state.availableSemesters;

    return Column(
      children: [
        // Semester tabs — show as 1, 2, 3... (sequential)
        if (semesters.isNotEmpty)
          SizedBox(
            height: 56,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: semesters.length,
              separatorBuilder: (_, __) => const Gap(8),
              itemBuilder: (context, index) {
                final sem = semesters[index];
                final isSelected = state.selectedSemester == sem;
                // Map actual term number to display: "1 семестр", "2 семестр"...
                final displayIndex = index + 1;
                return Semantics(
                  // Чип — переключатель одного выбора: без selected скринридер
                  // читает только подпись и не сообщает текущий семестр.
                  selected: isSelected,
                  inMutuallyExclusiveGroup: true,
                  child: FilterChip(
                    label: Text('$displayIndex семестр'),
                    selected: isSelected,
                    onSelected: (_) => ref
                        .read(performanceProvider.notifier)
                        .selectSemester(sem),
                  ),
                );
              },
            ),
          ),

        // Stats row
        _StatsRow(
          total: state.totalSubjects,
          attested: state.attestedCount,
          notAttested: state.notAttestedCount,
        ),

        const Divider(height: 1),

        // Marks table: семестр выбран чипами выше, внутри — таблица с
        // прокруткой и перетаскиваемыми ширинами столбцов.
        Expanded(
          child: MarksTable(items: state.semesterMarks),
        ),
      ],
    );
  }
}

// ============================================================
// Stats Row
// ============================================================
class _StatsRow extends StatelessWidget {
  final int total;
  final int attested;
  final int notAttested;

  const _StatsRow({
    required this.total,
    required this.attested,
    required this.notAttested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: colorScheme.surfaceContainerLow,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            label: 'Всего',
            value: '$total',
            color: colorScheme.onSurface,
          ),
          _StatItem(
            label: 'Аттестовано',
            value: '$attested',
            color: colorScheme.primary,
          ),
          _StatItem(
            label: 'Не аттестовано',
            value: '$notAttested',
            color: notAttested > 0
                ? colorScheme.error
                : colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: AppTypography.emphasizedHeadlineSmall(
            theme.textTheme.headlineSmall!,
          ).copyWith(color: color),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          label,
          style: theme.textTheme.labelMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
