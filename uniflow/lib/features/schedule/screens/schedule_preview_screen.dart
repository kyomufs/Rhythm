import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:uniflow/core/models/schedule.dart';
import 'package:uniflow/core/services/schedule_service.dart';
import 'package:uniflow/core/utils/week_utils.dart';
import 'package:uniflow/core/widgets/refresh_confirmation.dart';
import 'package:uniflow/features/schedule/providers/schedule_provider.dart';
import 'package:uniflow/features/schedule/widgets/day_schedule.dart';
import 'package:uniflow/features/schedule/widgets/lesson_detail_sheet.dart';
import 'package:uniflow/features/schedule/widgets/week_navigator.dart';
import 'package:uniflow/shared/widgets/empty_state.dart';
import 'package:uniflow/shared/widgets/loading_indicator.dart';

/// Read-only schedule preview for any search value (group, teacher, auditorium).
/// Does NOT change the user's persistent group.
class SchedulePreviewScreen extends ConsumerStatefulWidget {
  final String searchValue;
  final String title;

  const SchedulePreviewScreen({
    super.key,
    required this.searchValue,
    required this.title,
  });

  @override
  ConsumerState<SchedulePreviewScreen> createState() =>
      _SchedulePreviewScreenState();
}

class _SchedulePreviewScreenState extends ConsumerState<SchedulePreviewScreen> {
  List<ScheduleItem> _items = [];
  bool _isLoading = true;
  String? _error;
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    _weekStart = getCurrentWeekStart();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ref.read(scheduleServiceProvider);
      final result = await service.getSchedule(widget.searchValue);
      if (mounted) {
        setState(() {
          _items = result.items;
          _error = result.error;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<ScheduleItem> get _weekItems {
    return filterByWeek(
      _items,
      _weekStart,
      (item) => item.parsedDate,
    );
  }

  Map<DateTime, List<ScheduleItem>> get _weekByDay {
    final map = <DateTime, List<ScheduleItem>>{};
    for (final item in _weekItems) {
      final date = item.parsedDate;
      final dayKey = DateTime(date.year, date.month, date.day);
      map[dayKey] = [...(map[dayKey] ?? []), item];
    }
    final sortedKeys = map.keys.toList()..sort();
    return {for (final key in sortedKeys) key: map[key]!};
  }

  WeekInfo get _weekInfo => getWeekInfo(_weekStart);
  bool get _isCurrentWeek => _weekStart == getCurrentWeekStart();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final notifier = ref.read(scheduleScreenProvider.notifier);
    final isFav = notifier.isFavoriteGroup(widget.searchValue);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(isFav ? Icons.star_rounded : Icons.star_outline_rounded),
            color: isFav ? colorScheme.primary : null,
            onPressed: () {
              if (isFav) {
                notifier.removeFavoriteGroup(widget.searchValue);
              } else {
                notifier.addFavoriteGroup(widget.searchValue);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text('«${widget.searchValue}» добавлена в избранное'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
              setState(() {});
            },
            tooltip: isFav ? 'Убрать из избранного' : 'Добавить в избранное',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              final confirmed = await confirmRefresh(
                context,
                title: 'Обновить расписание?',
                body: 'Данные будут запрошены заново. Показанное расписание '
                    'останется, если сеть недоступна.',
              );
              if (!confirmed || !mounted) return;
              await _loadSchedule();
            },
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingIndicator(message: 'Загрузка расписания...')
          : _error != null
              ? _buildError()
              : _items.isEmpty
                  ? _buildEmpty()
                  : _buildContent(),
    );
  }

  Widget _buildContent() {
    final allDays = List.generate(6, (i) {
      final day = _weekStart.add(Duration(days: i));
      return DateTime(day.year, day.month, day.day);
    });

    return Column(
      children: [
        // Навигатор недели общий с главным экраном: своя упрощённая полоса
        // здесь выглядела как другая версия приложения.
        WeekNavigatorBar(
          weekInfo: _weekInfo,
          isCurrentWeek: _isCurrentWeek,
          onPrevWeek: () => setState(() {
            _weekStart = getPrevWeekStart(_weekStart);
          }),
          onNextWeek: () => setState(() {
            _weekStart = getNextWeekStart(_weekStart);
          }),
        ),
        const Gap(8),
        // Schedule list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: allDays.length,
            itemBuilder: (context, index) {
              final day = allDays[index];
              final lessons = _weekByDay[day] ?? [];
              final now = DateTime.now();
              final isToday = day.year == now.year &&
                  day.month == now.month &&
                  day.day == now.day;

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: DaySchedule(
                  date: day,
                  lessons: lessons,
                  isToday: isToday,
                  onLessonClick: (lesson) =>
                      showLessonDetailSheet(context, lesson),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return EmptyState(
      icon: Icons.cloud_off_outlined,
      title: 'Ошибка загрузки',
      message: _error!,
      action: FilledButton.tonalIcon(
        onPressed: _loadSchedule,
        icon: const Icon(Icons.refresh),
        label: const Text('Повторить'),
      ),
    );
  }

  Widget _buildEmpty() {
    return const EmptyState(
      icon: Icons.event_busy_outlined,
      title: 'Нет занятий',
      message: 'На эту неделю пар в расписании нет',
    );
  }
}
