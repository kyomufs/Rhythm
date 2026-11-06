import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tulgusch/core/api/api_exception.dart';
import 'package:tulgusch/core/api/api_providers.dart';
import 'package:tulgusch/core/api/schedule_api.dart';
import 'package:tulgusch/core/models/schedule.dart';
import 'package:tulgusch/core/services/storage_service.dart';

/// Schedule service provider
final scheduleServiceProvider = Provider<ScheduleService>((ref) {
  return ScheduleService(
    api: ref.watch(scheduleApiProvider),
    storage: ref.watch(storageServiceProvider),
  );
});

/// Service for fetching and caching schedule data
class ScheduleService {
  final ScheduleApi _api;
  final StorageService _storage;

  ScheduleService({required ScheduleApi api, required StorageService storage})
      : _api = api,
        _storage = storage;

  /// Search for groups, teachers, or auditoriums
  Future<List<SearchResult>> search(String query) async {
    final suggestions = await _api.search(query);
    return suggestions.map((s) => SearchResult.fromValue(s.value)).toList();
  }

  /// Get schedule for a search value
  Future<ScheduleState> getSchedule(String searchValue,
      {bool forceRefresh = false}) async {
    // Try to get from cache first
    if (!forceRefresh) {
      final cached = _storage.getCachedSchedule(searchValue);
      if (cached != null && cached.isValid) {
        return ScheduleState(
          searchValue: searchValue,
          dateRange: DateTimeRange(
            start: cached.data.dateRange.minDate,
            end: cached.data.dateRange.maxDate,
          ),
          items: cached.data.items,
        );
      }
    }

    // Fetch from API
    try {
      final data = await _api.fullSchedule(searchValue);

      // Cache the result
      await _storage.cacheSchedule(
        searchValue,
        ScheduleData(
          dateRange: ApiDateRange(
            minDate: data.dateRange.minDate,
            maxDate: data.dateRange.maxDate,
            searchField: data.dateRange.searchField,
          ),
          items: data.lessons,
          calendar: data.calendar,
        ),
      );

      return ScheduleState(
        searchValue: searchValue,
        dateRange: DateTimeRange(
          start: data.dateRange.minDate,
          end: data.dateRange.maxDate,
        ),
        items: data.lessons,
      );
    } on ApiException catch (e) {
      return ScheduleState(
        searchValue: searchValue,
        error: e.message,
      );
    }
  }

  /// Обновляет локальный снимок расписания, не трогая ни состояние экрана, ни
  /// «последний поиск». Нужно для избранных групп: они должны открываться
  /// офлайн из снимка.
  Future<bool> prefetch(String searchValue) async {
    try {
      final data = await _api.fullSchedule(searchValue);
      await _storage.cacheSchedule(
        searchValue,
        ScheduleData(
          dateRange: ApiDateRange(
            minDate: data.dateRange.minDate,
            maxDate: data.dateRange.maxDate,
            searchField: data.dateRange.searchField,
          ),
          items: data.lessons,
          calendar: data.calendar,
        ),
      );
      return true;
    } on ApiException {
      return false;
    }
  }

  /// Get schedule grouped by day
  Map<DateTime, List<ScheduleItem>> groupByDay(List<ScheduleItem> items) {
    final map = <DateTime, List<ScheduleItem>>{};

    for (final item in items) {
      final date = item.parsedDate;
      final dayKey = DateTime(date.year, date.month, date.day);
      map[dayKey] = [...(map[dayKey] ?? []), item];
    }

    // Sort by date
    final sortedKeys = map.keys.toList()..sort();
    return {
      for (final key in sortedKeys) key: map[key]!,
    };
  }


}
