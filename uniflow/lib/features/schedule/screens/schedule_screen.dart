import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:uniflow/app.dart';
import 'package:uniflow/core/demo/demo_schedule.dart';
import 'package:uniflow/core/models/schedule.dart';
import 'package:uniflow/core/services/schedule_service.dart';
import 'package:uniflow/core/theme/shapes.dart';
import 'package:uniflow/core/widgets/update_feedback.dart';
import 'package:uniflow/features/schedule/providers/schedule_provider.dart';
import 'package:uniflow/features/schedule/screens/schedule_changes_screen.dart';
import 'package:uniflow/features/schedule/screens/schedule_preview_screen.dart';
import 'package:uniflow/features/schedule/widgets/day_schedule.dart';
import 'package:uniflow/features/schedule/widgets/lesson_detail_sheet.dart';
import 'package:uniflow/shared/widgets/empty_state.dart';
import 'package:uniflow/shared/widgets/expressive_loading_indicator.dart';
import 'package:uniflow/shared/widgets/loading_indicator.dart';

/// Main Schedule Screen
class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  final _scrollController = ScrollController();
  final _listKey = GlobalKey();
  final Map<String, GlobalKey> _dayKeys = {};
  bool _scrolledToToday = false;

  GlobalKey _getKeyForDay(DateTime day) {
    final key = '${day.year}-${day.month}-${day.day}';
    return _dayKeys.putIfAbsent(key, () => GlobalKey());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Scroll so the given day header sits at the top of the list.
  /// Retries across frames because the list may still be loading
  /// (day keys are absent until the schedule items are built).
  /// Uses an instant jump: an animated scroll can be cancelled by a
  /// content re-layout (e.g. the week switching right after a pick).
  void _scrollToDay(DateTime day,
      {int attempt = 0, void Function(bool ok)? onDone}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _getKeyForDay(day).currentContext;
      if (ctx == null) {
        if (attempt < 12) {
          // addPostFrameCallback never schedules a frame on its own —
          // without this the retry chain stalls forever after a miss.
          WidgetsBinding.instance.scheduleFrame();
          _scrollToDay(day, attempt: attempt + 1, onDone: onDone);
        } else {
          onDone?.call(false);
        }
        return;
      }
      Scrollable.ensureVisible(
        ctx,
        duration: Duration.zero,
        curve: Curves.linear,
        alignment: 0.0,
      );
      onDone?.call(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scheduleScreenProvider);

    // Auto-scroll when highlightedDate changes (calendar pick)
    ref.listen<ScheduleScreenState>(scheduleScreenProvider, (prev, next) {
      if (next.highlightedDate != null &&
          next.highlightedDate != prev?.highlightedDate) {
        _scrollToDay(next.highlightedDate!, onDone: (_) {});
      }
    });

    // On first open, jump straight to today's section of the week.
    if (!_scrolledToToday &&
        (state.currentGroup != null || state.isDemo) &&
        !state.schedule.isLoading &&
        state.schedule.error == null &&
        state.schedule.items.isNotEmpty &&
        state.isCurrentWeek) {
      _scrolledToToday = true;
      final now = DateTime.now();
      _scrollToDay(DateTime(now.year, now.month, now.day), onDone: (ok) {
        // The day card was not built yet — retry on a later qualifying
        // rebuild instead of giving up silently.
        if (!ok) _scrolledToToday = false;
      });
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: _ScheduleHeader(state: state),
        centerTitle: false,
        actions: [
          // Change journal entry point — always visible (history
          // survives refreshes; badge only marks unseen changes).
          IconButton(
            icon: Badge(
              isLabelVisible: state.hasUnseenChanges,
              label: state.changeRecords.isNotEmpty
                  ? Text('${state.changeRecords.length}')
                  : null,
              child: const Icon(Icons.difference_outlined),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const ScheduleChangesScreen()),
            ),
            tooltip: 'Изменения',
          ),
          if (state.currentGroup != null || state.isDemo) ...[
            IconButton(
              icon: state.schedule.isLoading
                  ? const ExpressiveLoadingIndicator(size: 20)
                  : const Icon(Icons.refresh),
              onPressed: state.schedule.isLoading
                  ? null
                  : () async {
                      final result = await ref
                          .read(scheduleScreenProvider.notifier)
                          .refresh();
                      if (!context.mounted) return;
                      showUpdateFeedback(context, result);
                    },
              tooltip: 'Обновить',
            ),
          ],
          if (state.currentGroup != null) ...[
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => _showSearchSheet(context, ref),
              tooltip: 'Поиск',
            ),
          ],
          if (!state.isCurrentWeek)
            TextButton(
              onPressed: () =>
                  ref.read(scheduleScreenProvider.notifier).goToToday(),
              child: const Text('Сегодня'),
            ),
        ],
      ),
      body: state.currentGroup == null && !state.isDemo
          ? _buildNoGroupView(context, ref)
          : _buildScheduleView(context, ref, state),
    );
  }

  Widget _buildNoGroupView(BuildContext context, WidgetRef ref) {
    return EmptyState(
      icon: Icons.school_outlined,
      title: 'Выберите группу',
      message: 'Укажите номер группы\nв разделе «Профиль» → «Настройки»',
      action: FilledButton.icon(
        onPressed: () {
          ref.read(currentTabProvider.notifier).state = 3;
        },
        icon: const Icon(Icons.person),
        label: const Text('Открыть профиль'),
      ),
    );
  }

  Widget _buildScheduleView(
    BuildContext context,
    WidgetRef ref,
    ScheduleScreenState state,
  ) {
    final schedule = state.schedule;

    // Stale-while-revalidate: when a local copy is already on screen,
    // keep it visible during a background sync and only show the slim
    // progress bar; the full-screen spinner is for a cold start with
    // nothing to display yet.
    final hasVisibleContent =
        schedule.error == null && schedule.items.isNotEmpty;

    return Column(
      children: [
        _WeekNavigatorBar(
          state: state,
          onNextWeek: () =>
              ref.read(scheduleScreenProvider.notifier).goToNextWeek(),
          onPrevWeek: () =>
              ref.read(scheduleScreenProvider.notifier).goToPrevWeek(),
          onOpenCalendar: () => _openCalendar(context, ref),
        ),
        if (schedule.isLoading && hasVisibleContent)
          const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: schedule.isLoading && schedule.items.isEmpty
              ? const LoadingIndicator(message: 'Загрузка расписания...')
              : schedule.error != null
                  ? _buildError(
                      context, ref, schedule, Theme.of(context).colorScheme)
                  : schedule.items.isEmpty
                      ? _buildEmpty(Theme.of(context).colorScheme)
                      : _buildWeekSchedule(context, ref, state),
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref,
      ScheduleState schedule, ColorScheme colorScheme) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline,
              size: 64, color: colorScheme.error.withValues(alpha: 0.5)),
          const Gap(16),
          Text('Ошибка загрузки', style: theme.textTheme.titleMedium),
          const Gap(8),
          Text(schedule.error!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: colorScheme.onSurfaceVariant)),
          const Gap(16),
          FilledButton.tonal(
            onPressed: () async {
              final result =
                  await ref.read(scheduleScreenProvider.notifier).refresh();
              if (!context.mounted) return;
              showUpdateFeedback(context, result);
            },
            child: const Text('Повторить'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy,
              size: 64, color: colorScheme.primary.withValues(alpha: 0.3)),
          const Gap(16),
          Text('Нет занятий на эту неделю',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildWeekSchedule(
      BuildContext context, WidgetRef ref, ScheduleScreenState state) {
    final weekByDay = state.currentWeekByDay;
    final allDays = List.generate(7, (i) {
      final day = state.currentWeekStart.add(Duration(days: i));
      return DateTime(day.year, day.month, day.day);
    });
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);

    return RefreshIndicator(
      onRefresh: () async {
        // Жест вниз — это намерение, а не команда: сначала подтверждение.
        final confirmed = await _confirmRefresh(context);
        if (!confirmed || !context.mounted) return;
        final result = await ref.read(scheduleScreenProvider.notifier).refresh();
        if (!context.mounted) return;
        showUpdateFeedback(context, result);
      },
      child: ListView(
        key: _listKey,
        controller: _scrollController,
        // Build every day of the week up front: a lazy SliverList leaves
        // far-off day cards unmounted, so GlobalKey lookups for scroll
        // targets (today / calendar picks) would silently find nothing.
        scrollCacheExtent: const ScrollCacheExtent.pixels(50000),
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          for (final day in allDays)
            Padding(
              key: _getKeyForDay(day),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: DaySchedule(
                date: day,
                lessons: weekByDay[day] ?? [],
                isToday: day == todayKey,
                isHighlighted: state.highlightedDate == day,
                onLessonClick: (lesson) => _showLessonDetail(context, lesson),
              ),
            ),
        ],
      ),
    );
  }

  void _showLessonDetail(BuildContext context, ScheduleItem lesson) {
    showLessonDetailSheet(context, lesson);
  }

  /// Подтверждение обновления по жесту вниз.
  Future<bool> _confirmRefresh(BuildContext context) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.refresh),
        title: const Text('Обновить расписание?'),
        content: const Text(
          'Данные будут запрошены заново. Сохранённое расписание '
          'останется, если сеть недоступна.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Обновить',
              style: theme.textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _openCalendar(BuildContext context, WidgetRef ref) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020, 9, 1),
      lastDate: DateTime(2030, 8, 31),
      locale: const Locale('ru'),
    );
    if (picked != null && context.mounted) {
      ref.read(scheduleScreenProvider.notifier).selectDate(picked);
    }
  }

  void _showSearchSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _SearchBottomSheet(),
    );
  }
}

// ============================================================
// Шапка: герб, номер группы и вход в избранное
// ============================================================
class _ScheduleHeader extends ConsumerWidget {
  final ScheduleScreenState state;

  const _ScheduleHeader({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final group = state.isDemo ? demoGroup : state.currentGroup;

    if (group == null) {
      return Text('Расписание', style: theme.textTheme.titleLarge);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Монохромный герб: тот же силуэт, что на иконке приложения, но
        // перекрашенный в цвет текста — в шапке он не должен спорить с
        // акцентным цветом.
        Image.asset(
          'assets/branding/tulsu_shield.png',
          width: 28,
          height: 28,
          color: colorScheme.onSurfaceVariant,
          colorBlendMode: BlendMode.srcIn,
          filterQuality: FilterQuality.high,
        ),
        const Gap(8),
        Flexible(
          child: Text(
            group,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Gap(2),
        IconButton(
          onPressed: () => _showFavoritesSheet(context),
          icon: const Icon(Icons.star_outline),
          iconSize: 22,
          visualDensity: VisualDensity.compact,
          tooltip: 'Избранные группы',
        ),
      ],
    );
  }
}

// ============================================================
// Избранные группы — лист из-под шапки
// ============================================================
void _showFavoritesSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _FavoritesSheet(),
  );
}

class _FavoritesSheet extends ConsumerWidget {
  const _FavoritesSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final favorites =
        ref.watch(scheduleScreenProvider.select((s) => s.favoriteGroups));

    return Material(
      type: MaterialType.transparency,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
              child: Row(
                children: [
                  Icon(Icons.star, size: 20, color: colorScheme.primary),
                  const Gap(8),
                  Text('Избранные группы', style: theme.textTheme.titleLarge),
                ],
              ),
            ),
            if (favorites.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Пока пусто. Добавьте группу через поиск — она появится '
                      'здесь и будет доступна без сети.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    const Gap(16),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.pop(context);
                        showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (_) => const _SearchBottomSheet(),
                        );
                      },
                      icon: const Icon(Icons.search),
                      label: const Text('Найти группу'),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: favorites.length,
                  itemBuilder: (context, index) {
                    final fav = favorites[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.secondaryContainer,
                        child: Icon(Icons.groups_outlined,
                            size: 20,
                            color: colorScheme.onSecondaryContainer),
                      ),
                      title: Text(fav.groupNumber,
                          style: theme.textTheme.titleMedium),
                      subtitle: const Text('Открыть расписание'),
                      trailing: IconButton(
                        onPressed: () => ref
                            .read(scheduleScreenProvider.notifier)
                            .removeFavoriteGroup(fav.groupNumber),
                        icon: const Icon(Icons.star),
                        color: colorScheme.primary,
                        tooltip: 'Убрать из избранного',
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => SchedulePreviewScreen(
                              searchValue: fav.groupNumber,
                              title: fav.groupNumber,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Неделя: стрелки отдельно, карточка недели отдельно
// ============================================================
class _WeekNavigatorBar extends StatelessWidget {
  final ScheduleScreenState state;
  final VoidCallback onNextWeek;
  final VoidCallback onPrevWeek;
  final VoidCallback onOpenCalendar;

  const _WeekNavigatorBar({
    required this.state,
    required this.onNextWeek,
    required this.onPrevWeek,
    required this.onOpenCalendar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final weekInfo = state.weekInfo;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          _WeekArrow(
            icon: Icons.chevron_left,
            tooltip: 'Предыдущая неделя',
            onTap: onPrevWeek,
          ),
          const Gap(8),
          Expanded(
            child: Material(
              color: state.isCurrentWeek
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHigh,
              borderRadius: AppShapes.circular(AppShapes.largeIncreased),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onOpenCalendar,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Неделя ${weekInfo.weekNumber}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: state.isCurrentWeek
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurface,
                            ),
                          ),
                          const Gap(6),
                          _ParityChip(
                            isEven: weekInfo.isEven,
                            onContainer: state.isCurrentWeek,
                          ),
                        ],
                      ),
                      const Gap(2),
                      Text(
                        weekInfo.dateRangeShort,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: state.isCurrentWeek
                              ? colorScheme.onPrimaryContainer
                                  .withValues(alpha: 0.8)
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Gap(8),
          _WeekArrow(
            icon: Icons.chevron_right,
            tooltip: 'Следующая неделя',
            onTap: onNextWeek,
          ),
        ],
      ),
    );
  }
}

/// Стрелки живут отдельно от карточки недели: своя скруглённая кнопка на
/// каждую, поэтому промахнуться мимо нужной недели сложнее.
class _WeekArrow extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _WeekArrow({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHighest,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon),
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _ParityChip extends StatelessWidget {
  final bool isEven;
  final bool onContainer;

  const _ParityChip({required this.isEven, required this.onContainer});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final background = onContainer
        ? colorScheme.onPrimaryContainer.withValues(alpha: 0.12)
        : colorScheme.secondaryContainer;
    final foreground = onContainer
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppShapes.circular(AppShapes.small),
      ),
      child: Text(
        isEven ? 'чётная' : 'нечётная',
        style: theme.textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
// ============================================================
// Search Bottom Sheet — preview + favorite toggle
// ============================================================
class _SearchBottomSheet extends ConsumerStatefulWidget {
  const _SearchBottomSheet();

  @override
  ConsumerState<_SearchBottomSheet> createState() => _SearchBottomSheetState();
}

class _SearchBottomSheetState extends ConsumerState<_SearchBottomSheet> {
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
    final colorScheme = theme.colorScheme;
    final notifier = ref.read(scheduleScreenProvider.notifier);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        // Цвет и скругления даёт bottomSheetTheme — меню поиска выглядит
        // частью того меню, из которого открылось. Крестик не нужен:
        // закрытие — свайп вниз или тап по затемнению.
        return Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              // Title
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Поиск', style: theme.textTheme.titleLarge),
                ),
              ),
              // Search field
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Группа, преподаватель или аудитория',
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
                ),
              ),
              const Gap(8),
              // Results
              Expanded(
                child: _isLoading
                    ? const LoadingIndicator()
                    : _results.isEmpty
                        ? _buildEmptyState(context)
                        : Material(
                            type: MaterialType.transparency,
                            child: ListView.builder(
                              controller: scrollController,
                              itemCount: _results.length,
                              itemBuilder: (context, index) {
                                final result = _results[index];
                                final isFav =
                                    notifier.isFavoriteGroup(result.value);
                                return ListTile(
                                  leading: Icon(_iconForType(result.type)),
                                  title: Text(result.value),
                                  subtitle: Text(result.type.displayName),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Favorite toggle
                                      IconButton(
                                        icon: Icon(
                                          isFav
                                              ? Icons.star
                                              : Icons.star_border,
                                          size: 20,
                                        ),
                                        color: isFav
                                            ? colorScheme.primary
                                            : colorScheme.onSurfaceVariant,
                                        onPressed: () {
                                          if (isFav) {
                                            notifier.removeFavoriteGroup(
                                                result.value);
                                          } else {
                                            notifier
                                                .addFavoriteGroup(result.value);
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    '«${result.value}» добавлена в избранное'),
                                                duration:
                                                    const Duration(seconds: 2),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                      const Icon(Icons.chevron_right, size: 20),
                                    ],
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => SchedulePreviewScreen(
                                          searchValue: result.value,
                                          title: result.value,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search,
              size: 48, color: colorScheme.primary.withValues(alpha: 0.3)),
          const Gap(8),
          Text('Введите минимум 2 символа',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  IconData _iconForType(SearchResultType type) {
    switch (type) {
      case SearchResultType.group:
        return Icons.group_outlined;
      case SearchResultType.teacher:
        return Icons.person_outline;
      case SearchResultType.auditorium:
        return Icons.room_outlined;
      case SearchResultType.subject:
        return Icons.book_outlined;
    }
  }
}
