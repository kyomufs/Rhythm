import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:rhythm/core/theme/spacing.dart';
import 'package:rhythm/core/theme/typography.dart';
import 'package:rhythm/app.dart';
import 'package:rhythm/core/widgets/refresh_confirmation.dart';
import 'package:rhythm/core/widgets/update_feedback.dart';
import 'package:rhythm/features/performance/providers/performance_provider.dart';
import 'package:rhythm/features/sources/widgets/source_pill.dart';
import 'package:rhythm/features/performance/widgets/marks_table.dart';
import 'package:rhythm/shared/widgets/empty_state.dart';
import 'package:rhythm/shared/widgets/loading_indicator.dart';
import 'package:rhythm/shared/widgets/morph_chip.dart';
import 'package:rhythm/shared/widgets/wavy_progress.dart';

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
        title: Row(
          children: [
            const SourcePill(),
            const Gap(AppSpacing.xs),
            Text('Успеваемость', style: theme.textTheme.titleLarge),
          ],
        ),
        centerTitle: false,
        actions: [
          if (isConfigured)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                // Как и в расписании: сначала подтверждение, потом запрос.
                final confirmed = await confirmRefresh(
                  context,
                  title: 'Обновить оценки?',
                  body: 'Данные будут запрошены заново. Сохранённые оценки '
                      'останутся, если сеть недоступна.',
                );
                if (!confirmed || !context.mounted) return;
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
                            // Тонкая волна вместо прямой полосы: тот же
                            // индикатор фоновой загрузки, но в языке темы.
                            if (state.isLoading)
                              const Padding(
                                padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
                                child: WavyProgressIndicator(
                                  value: null,
                                  height: 4,
                                  strokeWidth: 2,
                                  wavelength: 12,
                                  amplitude: 1.2,
                                ),
                              ),
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
    return EmptyState(
      icon: Icons.sync_problem_outlined,
      title: 'Не удалось загрузить',
      message: state.error!,
      action: FilledButton.tonalIcon(
        onPressed: () async {
          final result =
              await ref.read(performanceProvider.notifier).loadMarks();
          if (!context.mounted) return;
          showUpdateFeedback(context, result);
        },
        icon: const Icon(Icons.refresh),
        label: const Text('Повторить'),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, WidgetRef ref,
      ColorScheme colorScheme, ThemeData theme) {
    return EmptyState(
      icon: Icons.assistant_navigation,
      title: 'Нет данных об успеваемости',
      message: 'Оценки за семестр ещё не подгружены',
      action: FilledButton.tonalIcon(
        onPressed: () async {
          final result =
              await ref.read(performanceProvider.notifier).loadMarks();
          if (!context.mounted) return;
          showUpdateFeedback(context, result);
        },
        icon: const Icon(Icons.download_outlined),
        label: const Text('Загрузить'),
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
              // 2dp шва внутри ленты и 2dp до гуттера: связка читается
              // одной лентой, как у группы кнопок.
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: semesters.length,
              separatorBuilder: (_, __) => const Gap(2),
              itemBuilder: (context, index) {
                final sem = semesters[index];
                final isSelected = state.selectedSemester == sem;
                // Map actual term number to display: "1 семестр", "2 семестр"...
                final displayIndex = index + 1;
                // Лента связная: круглые торцы только у крайних семестров,
                // поэтому флаги зависят от позиции в списке.
                return MorphChip(
                  label: '$displayIndex семестр',
                  selected: isSelected,
                  isFirst: index == 0,
                  isLast: index == semesters.length - 1,
                  semanticLabel: 'Семестр $displayIndex',
                  onTap: () => ref
                      .read(performanceProvider.notifier)
                      .selectSemester(sem),
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
