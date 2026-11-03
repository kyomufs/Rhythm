import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:uniflow/core/models/note_models.dart';

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
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
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
