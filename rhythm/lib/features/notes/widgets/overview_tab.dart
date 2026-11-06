import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:tulgusch/core/models/note_models.dart';
import 'package:tulgusch/core/theme/motion.dart';
import 'package:tulgusch/core/theme/shapes.dart';
import 'package:tulgusch/core/theme/typography.dart';

/// Вкладка «Обзор»: прогресс предмета, статистика и ближайшие дедлайны.
class OverviewTab extends StatelessWidget {
  final SubjectFolder folder;
  final Color color;

  const OverviewTab({
    super.key,
    required this.folder,
    required this.color,
  });

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
          // ── Шапка: кольцо прогресса и преподаватель на одной тональной
          // поверхности. Цвет предмета задаёт только акцент, фон остаётся
          // из схемы. ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: AppShapes.circular(AppShapes.extraLarge),
            ),
            child: Row(
              children: [
                _ProgressRing(
                  progress: folder.completionPercent,
                  color: color,
                  trackColor: colorScheme.surfaceContainerHighest,
                ),
                const Gap(16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        folder.name,
                        style: AppTypography.emphasizedTitleMedium(
                          theme.textTheme.titleMedium!,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (folder.teacher != null &&
                          folder.teacher!.isNotEmpty) ...[
                        const Gap(4),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const Gap(4),
                            Expanded(
                              child: Text(
                                folder.teacher!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const Gap(6),
                      Text(
                        '$completedTasks из $totalTasks задач закрыто',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Gap(16),

          // ── Статистика: одна панель на три ячейки вместо трёх карточек.
          // Три отдельных Card на телефоне выглядят как три разных сущности,
          // хотя это один показатель в трёх разрезах. ──
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: AppShapes.circular(AppShapes.largeIncreased),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: _StatCell(
                    label: 'Всего',
                    value: '$totalTasks',
                    color: colorScheme.onSurface,
                  ),
                ),
                _StatDivider(color: colorScheme.outlineVariant),
                Expanded(
                  child: _StatCell(
                    label: 'Выполнено',
                    value: '$completedTasks',
                    color: colorScheme.tertiary,
                  ),
                ),
                _StatDivider(color: colorScheme.outlineVariant),
                Expanded(
                  child: _StatCell(
                    label: 'В работе',
                    value: '${totalTasks - completedTasks}',
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const Gap(20),

          // ── Ближайшие дедлайны ──
          if (upcoming.isNotEmpty) ...[
            Text(
              'Ближайшие дедлайны',
              style: AppTypography.emphasizedTitleSmall(
                theme.textTheme.titleSmall!,
              ),
            ),
            const Gap(10),
            ...upcoming.take(5).map((task) {
              final daysUntil = task.dueDate!.difference(DateTime.now()).inDays;
              final isUrgent = daysUntil <= 3;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _DeadlineRow(
                  task: task,
                  daysUntil: daysUntil,
                  isUrgent: isUrgent,
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
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius:
                            AppShapes.circular(AppShapes.largeIncreased),
                      ),
                      child: Icon(
                        Icons.add_task,
                        size: 30,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Gap(12),
                    Text(
                      'Нет задач',
                      style: AppTypography.emphasizedTitleSmall(
                        theme.textTheme.titleSmall!,
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

/// Кольцо прогресса: дуга доезжает до значения на slow-spatial пружине.
///
/// Статичное кольцо сообщает число, но не показывает, что прогресс только что
/// изменился, — а именно это здесь важно.
class _ProgressRing extends StatefulWidget {
  const _ProgressRing({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  @override
  State<_ProgressRing> createState() => _ProgressRingState();
}

class _ProgressRingState extends State<_ProgressRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController.unbounded(
    vsync: this,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = widget.progress;
    } else {
      _controller.animateWithSpring(MotionTokens.slowSpatial, to: widget.progress);
    }
  }

  @override
  void didUpdateWidget(_ProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress == widget.progress) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = widget.progress;
    } else {
      _controller.animateWithSpring(
        MotionTokens.defaultSpatial,
        to: widget.progress,
        velocity: _controller.velocity,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 72,
      height: 72,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          // Перелёт пружины клампится: дуга, ушедшая за 100%, рисует петлю.
          final progress = _controller.value.clamp(0.0, 1.0);
          return CustomPaint(
            painter: _ProgressRingPainter(
              progress: progress,
              color: widget.color,
              backgroundColor: widget.trackColor,
            ),
            child: Center(
              child: Text(
                '${(progress * 100).round()}%',
                style: AppTypography.emphasizedTitleSmall(
                  theme.textTheme.titleSmall!.copyWith(color: widget.color),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Ячейка панели статистики.
class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: AppTypography.emphasizedHeadlineSmall(
            theme.textTheme.headlineSmall!.copyWith(color: color, height: 1.1),
          ),
        ),
        const Gap(2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: color.withValues(alpha: 0.6),
    );
  }
}

/// Строка дедлайна: статус точкой, название и срок; срочные — красным.
class _DeadlineRow extends StatelessWidget {
  const _DeadlineRow({
    required this.task,
    required this.daysUntil,
    required this.isUrgent,
  });

  final StudyTask task;
  final int daysUntil;
  final bool isUrgent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDone = task.status == TaskStatus.done;
    final accent = isDone
        ? colorScheme.tertiary
        : isUrgent
            ? colorScheme.error
            : colorScheme.primary;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: AppShapes.circular(AppShapes.large),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    color: isDone ? colorScheme.onSurfaceVariant : null,
                  ),
                ),
                const Gap(1),
                Text(
                  DateFormat('d MMMM', 'ru').format(task.dueDate!),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (isUrgent) ...[
            const Gap(8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: AppShapes.circular(AppShapes.small),
              ),
              child: Text(
                daysUntil == 0 ? 'Сегодня' : '$daysUntil дн.',
                style: AppTypography.emphasizedLabelSmall(
                  theme.textTheme.labelSmall!.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
          ],
        ],
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
    final radius = size.width / 2 - 5;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    if (progress <= 0) return;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
