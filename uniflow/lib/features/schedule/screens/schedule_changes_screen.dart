import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:uniflow/core/models/change_record.dart';
import 'package:uniflow/core/theme/shapes.dart';
import 'package:uniflow/features/schedule/providers/schedule_provider.dart';

/// Dedicated screen listing every detected schedule change, grouped
/// into one block per day. Changed lessons are visually highlighted;
/// изменённая пара показана двумя карточками: зачёркнутой «было» и обычной
/// «стало».
class ScheduleChangesScreen extends ConsumerStatefulWidget {
  const ScheduleChangesScreen({super.key});

  @override
  ConsumerState<ScheduleChangesScreen> createState() =>
      _ScheduleChangesScreenState();
}

class _ScheduleChangesScreenState extends ConsumerState<ScheduleChangesScreen> {
  @override
  void initState() {
    super.initState();
    // Opening the screen marks the fresh batch as reviewed (badge off);
    // the journal history itself is kept.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(scheduleScreenProvider.notifier).markChangesSeen();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scheduleScreenProvider);
    final journal = state.changeJournal;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Изменения'),
        centerTitle: false,
        actions: [
          if (journal.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Очистить журнал',
              onPressed: () => _confirmClear(context, ref),
            ),
        ],
      ),
      body: journal.isEmpty
          ? const _EmptyChanges()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                for (final block in _groupByDay(journal)) ...[
                  _DayBlockHeader(
                    date: block.date,
                    count: block.records.length,
                  ),
                  const Gap(8),
                  for (final record in block.records) ...[
                    _ChangeCard(record: record),
                    const Gap(8),
                  ],
                ],
                const Gap(24),
                Text(
                  'Журнал хранит изменения за последние 14 дней '
                  '(не более 50 записей).',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
    );
  }

  /// Group journal entries by lesson day (newest day first, records
  /// inside a day sorted by lesson time).
  List<_DayBlock> _groupByDay(List<ChangeRecord> journal) {
    final byDay = <String, List<ChangeRecord>>{};
    for (final record in journal) {
      byDay.putIfAbsent(record.date, () => []).add(record);
    }
    final keys = byDay.keys.toList()
      ..sort((a, b) =>
          _parseDate(b)?.compareTo(_parseDate(a) ?? DateTime(0)) ??
          b.compareTo(a));
    return [
      for (final key in keys)
        _DayBlock(
          date: _parseDate(key),
          records: byDay[key]!..sort((a, b) => a.time.compareTo(b.time)),
        ),
    ];
  }

  static DateTime? _parseDate(String value) {
    final parts = value.split('.');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }

  void _confirmClear(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Очистить журнал изменений?'),
        content: const Text(
            'История изменений расписания будет удалена безвозвратно.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              await ref
                  .read(scheduleScreenProvider.notifier)
                  .clearChangeJournal();
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Журнал изменений очищен')),
                );
              }
            },
            child: const Text('Очистить'),
          ),
        ],
      ),
    );
  }
}

class _DayBlock {
  final DateTime? date;
  final List<ChangeRecord> records;

  const _DayBlock({required this.date, required this.records});
}

/// Day header styled after the schedule's day cards.
class _DayBlockHeader extends StatelessWidget {
  final DateTime? date;
  final int count;

  const _DayBlockHeader({required this.date, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final d = date;

    final dayNumber = d == null ? '?' : '${d.day}';
    final caption = d == null
        ? 'Неизвестная дата'
        : '${DateFormat.EEEE('ru').format(d)}, '
            '${DateFormat('d MMMM yyyy', 'ru').format(d)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: AppShapes.circular(AppShapes.medium),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: AppShapes.circular(AppShapes.small),
            ),
            child: Text(
              dayNumber,
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Gap(12),
          Expanded(
            child: Text(
              caption,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: AppShapes.circular(AppShapes.extraExtraLarge),
            ),
            child: Text(
              '$count изм.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One highlighted change entry («изменено» / «новое» / «отменено»).
class _ChangeCard extends StatelessWidget {
  final ChangeRecord record;

  const _ChangeCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final (accent, icon, kindLabel) = switch (record.kind) {
      ChangeKind.modified => (
          colorScheme.tertiary,
          Icons.sync_alt,
          'Изменено',
        ),
      ChangeKind.added => (
          colorScheme.primary,
          Icons.add_circle_outline,
          'Новое',
        ),
      ChangeKind.removed => (
          colorScheme.error,
          Icons.remove_circle_outline,
          'Отменено',
        ),
    };

    final background = switch (record.kind) {
      ChangeKind.modified => colorScheme.tertiaryContainer,
      ChangeKind.added => colorScheme.primaryContainer,
      ChangeKind.removed => colorScheme.errorContainer,
    };
    final onBackground = switch (record.kind) {
      ChangeKind.modified => colorScheme.onTertiaryContainer,
      ChangeKind.added => colorScheme.onPrimaryContainer,
      ChangeKind.removed => colorScheme.onErrorContainer,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppShapes.circular(AppShapes.large),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accent),
              const Gap(8),
              // Kind badge — «Изменено» / «Новое» / «Отменено».
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: AppShapes.circular(AppShapes.extraExtraLarge),
                ),
                child: Text(
                  kindLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Gap(8),
              const Spacer(),
              Text(
                record.time,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: onBackground.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Gap(10),
          // Суть изменения без «12:00 → 13:30»: слева зачёркнутая карточка
          // «было», справа обычная «стало». У нового и отменённого занятия
          // карточка одна — сравнивать не с чем.
          if (record.kind == ChangeKind.modified &&
              record.fieldChanges.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _SnapshotCard(
                    snapshot: _LessonSnapshot.previous(record),
                    accent: colorScheme.outline,
                    struck: true,
                    label: 'Было',
                    colorScheme: colorScheme,
                    theme: theme,
                  ),
                ),
                const Gap(8),
                Expanded(
                  child: _SnapshotCard(
                    snapshot: _LessonSnapshot.current(record),
                    accent: accent,
                    struck: false,
                    label: 'Стало',
                    colorScheme: colorScheme,
                    theme: theme,
                  ),
                ),
              ],
            )
          else
            _SnapshotCard(
              snapshot: _LessonSnapshot.current(record),
              accent: accent,
              struck: record.kind == ChangeKind.removed,
              label: null,
              colorScheme: colorScheme,
              theme: theme,
            ),
          const Gap(6),
          Text(
            'Обнаружено: ${DateFormat('d MMMM, HH:mm', 'ru').format(record.detectedAt)}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: onBackground.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// Занятие в том виде, в котором оно было или стало: без разбора по полям,
/// просто карточка, которую видно целиком.
class _LessonSnapshot {
  final String subject;
  final String type;
  final String time;
  final String classroom;
  final String teacher;

  const _LessonSnapshot({
    required this.subject,
    required this.type,
    required this.time,
    required this.classroom,
    required this.teacher,
  });

  factory _LessonSnapshot.current(ChangeRecord record) => _LessonSnapshot(
        subject: record.subject,
        type: record.type,
        time: record.time,
        classroom: record.classroom,
        teacher: record.teacher,
      );

  /// Восстанавливает прежнее занятие: поля из записи, подменённые на
  /// `before` для каждого изменённого поля.
  factory _LessonSnapshot.previous(ChangeRecord record) {
    var snapshot = _LessonSnapshot.current(record);
    for (final change in record.fieldChanges) {
      snapshot = switch (change.field) {
        'Предмет' => snapshot._copyWith(subject: change.before),
        'Тип' => snapshot._copyWith(type: change.before),
        'Время' => snapshot._copyWith(time: change.before),
        'Преподаватель' => snapshot._copyWith(teacher: change.before),
        'Аудитория' => snapshot._copyWith(classroom: change.before),
        _ => snapshot,
      };
    }
    return snapshot;
  }

  _LessonSnapshot _copyWith({
    String? subject,
    String? type,
    String? time,
    String? classroom,
    String? teacher,
  }) =>
      _LessonSnapshot(
        subject: subject ?? this.subject,
        type: type ?? this.type,
        time: time ?? this.time,
        classroom: classroom ?? this.classroom,
        teacher: teacher ?? this.teacher,
      );
}

class _SnapshotCard extends StatelessWidget {
  final _LessonSnapshot snapshot;
  final Color accent;
  final bool struck;
  final String? label;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _SnapshotCard({
    required this.snapshot,
    required this.accent,
    required this.struck,
    required this.label,
    required this.colorScheme,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final muted = colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: struck
            ? colorScheme.surface.withValues(alpha: 0.55)
            : colorScheme.surface.withValues(alpha: 0.85),
        borderRadius: AppShapes.circular(AppShapes.medium),
        border: Border.all(
          color: struck
              ? colorScheme.outlineVariant
              : accent.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Text(
              label!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: struck ? muted : accent,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            const Gap(4),
          ],
          Text(
            snapshot.subject,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: struck ? muted : colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              decoration: struck ? TextDecoration.lineThrough : null,
              decorationColor: muted,
            ),
          ),
          const Gap(4),
          Text(
            snapshot.time,
            style: theme.textTheme.labelMedium?.copyWith(
              color: struck ? muted : accent,
              fontWeight: FontWeight.w700,
              decoration: struck ? TextDecoration.lineThrough : null,
              decorationColor: muted,
            ),
          ),
          if (snapshot.classroom.isNotEmpty || snapshot.teacher.isNotEmpty) ...[
            const Gap(2),
            Text(
              [
                if (snapshot.classroom.isNotEmpty) 'Ауд. ${snapshot.classroom}',
                if (snapshot.teacher.isNotEmpty) snapshot.teacher,
              ].join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: muted,
                decoration: struck ? TextDecoration.lineThrough : null,
                decorationColor: muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyChanges extends StatelessWidget {
  const _EmptyChanges();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history,
                size: 72, color: colorScheme.primary.withValues(alpha: 0.3)),
            const Gap(20),
            Text(
              'Изменений пока нет',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Gap(8),
            Text(
              'Здесь появится история изменений расписания:\n'
              'переносы, новые и отменённые занятия.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
