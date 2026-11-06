// Stale-while-revalidate coverage: a warm local copy must be painted
// synchronously on startup, before any connectivity probe or network
// wait, and the background sync replaces it in place.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rhythm/core/models/marks.dart';
import 'package:rhythm/core/models/schedule.dart';
import 'package:rhythm/core/services/connectivity_service.dart';
import 'package:rhythm/core/services/notification_service.dart';
import 'package:rhythm/core/services/schedule_service.dart';
import 'package:rhythm/core/services/storage_service.dart';
import 'package:rhythm/core/services/update_coordinator.dart';
import 'package:rhythm/core/sources/source_api.dart';
import 'package:rhythm/features/performance/providers/performance_provider.dart';
import 'package:rhythm/features/schedule/providers/schedule_provider.dart';

// ── Helpers ────────────────────────────────────────────────────

ScheduleItem _item(String subject,
        {String classroom = '101', String time = '08:00 - 09:30'}) =>
    ScheduleItem(
      date: '23.09.2026',
      time: time,
      subject: subject,
      type: 'Лекции',
      classroom: classroom,
      teacher: 'Иванов Иван',
      groups: const [],
      cssClass: 'lecture',
    );

MarksItem _mark(String discipline, {String term = '3'}) => MarksItem(
      term: term,
      discipline: discipline,
      mark: '5',
      markTitle: 'отлично',
      teacherMark: '5',
      retake: '',
      recredit: false,
    );

FinalMark _finalMark(String discipline) => FinalMark(
      term: '3',
      discipline: discipline,
      markTitle: 'отлично',
      teacherMark: '5',
    );

CachedSchedule _cachedSchedule(List<ScheduleItem> items) => CachedSchedule(
      searchValue: '221341',
      data: ScheduleData(
        dateRange: ApiDateRange(
          minDate: DateTime(2026, 9, 21),
          maxDate: DateTime(2026, 10, 25),
          searchField: SearchField.group,
        ),
        items: items,
        calendar: const [],
      ),
      cachedAt: DateTime.now(),
    );

/// Flush pending microtasks/timers without a widget binding.
Future<void> _flush() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

// ── Schedule fakes ─────────────────────────────────────────────

class FakeScheduleService implements ScheduleService {
  List<ScheduleItem> data;
  int getScheduleCalls = 0;

  FakeScheduleService(this.data);

  @override
  Future<ScheduleState> getSchedule(String searchValue,
      {bool forceRefresh = false}) async {
    getScheduleCalls++;
    return ScheduleState(searchValue: searchValue, items: data);
  }

  @override
  Future<List<SearchResult>> search(String query) async => [];

  @override
  Future<bool> prefetch(String searchValue) async => true;

  @override
  Future<ScheduleState> getCurrentWeekSchedule(String searchValue) =>
      getSchedule(searchValue);

  @override
  List<ScheduleItem> getScheduleForDate(
          List<ScheduleItem> items, DateTime date) =>
      [];

  @override
  Map<DateTime, List<ScheduleItem>> groupByDay(List<ScheduleItem> items) => {};

  @override
  List<String> getUniqueValues(List<ScheduleItem> items, String field) => [];
}

class WarmStorage extends StorageService {
  String myGroupValue = '221341';
  String? fingerprint;
  CachedSchedule? cached;

  @override
  String? getMyGroup() => myGroupValue;

  @override
  List<FavoriteGroup> getFavoriteGroups() => const [];

  @override
  String? getScheduleFingerprint() => fingerprint;

  @override
  Future<void> setScheduleFingerprint(String? value) async {
    fingerprint = value;
  }

  @override
  CachedSchedule? getCachedSchedule(String searchValue) => cached;

  // The base class keeps these in an uninitialized Hive box; tests use
  // an in-memory journal instead.
  @override
  List<Map<String, dynamic>> getChangeLog() => const [];

  @override
  Future<void> saveChangeLog(List<Map<String, dynamic>> entries) async {}

  @override
  DateTime? getChangesSeenAt() => null;
}

class FakeConnectivity implements ConnectivityService {
  bool online = true;

  @override
  Future<bool> checkConnectivity() async => online;

  @override
  void invalidateCache() {}
}

class FakeNotifications implements NotificationService {
  @override
  void Function(String? payload)? onTap;

  final List<int> shownIds = [];

  @override
  Future<void> show(int id, String title, String body,
      {String? payload}) async {
    shownIds.add(id);
  }

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> areNotificationsEnabled() async => true;
}

ScheduleScreenNotifier _scheduleNotifier({
  required FakeScheduleService service,
  required WarmStorage storage,
  required FakeConnectivity connectivity,
  required FakeNotifications notifications,
}) =>
    ScheduleScreenNotifier(
      service,
      storage,
      connectivity,
      notifications,
      UpdateCoordinator(connectivity),
    );

// ── Performance fakes ──────────────────────────────────────────

class FakeProgressApi implements FinalMarksApi {
  FakeProgressApi(
      {Completer<List<FinalMark>>? pending, List<FinalMark>? result})
      : _pending = pending,
        _result = result;

  final Completer<List<FinalMark>>? _pending;
  final List<FinalMark>? _result;
  int calls = 0;

  @override
  Future<List<FinalMark>> finalMarks({
    required String studentId,
    required String group,
  }) {
    calls++;
    return _pending?.future ?? Future.value(_result ?? const <FinalMark>[]);
  }
}

class FakeMarkStorage extends StorageService {
  List<MarksItem>? cachedMarks;

  @override
  String? getStudentId() => '12345';

  @override
  String? getFullAcademicGroup() => '221341-01';

  @override
  List<MarksItem>? getCachedMarks({
    required String studentId,
    required String group,
  }) =>
      cachedMarks;

  @override
  Future<void> cacheMarks({
    required String studentId,
    required String group,
    required List<MarksItem> marks,
  }) async {
    cachedMarks = marks;
  }
}

// ── Tests ──────────────────────────────────────────────────────

void main() {
  group('schedule stale-while-revalidate', () {
    test('warm cache is painted synchronously, before any network wait',
        () async {
      final storage = WarmStorage()
        ..cached = _cachedSchedule([_item('Из кэша')]);
      final service = FakeScheduleService([_item('Свежее из API')]);
      final connectivity = FakeConnectivity();
      final notifications = FakeNotifications();

      final notifier = _scheduleNotifier(
        service: service,
        storage: storage,
        connectivity: connectivity,
        notifications: notifications,
      );

      // The synchronous prefix of _init ran inside the constructor:
      // the local copy must already be on screen, with no spinner.
      expect(notifier.state.currentGroup, '221341');
      expect(notifier.state.schedule.items.single.subject, 'Из кэша',
          reason: 'cache must paint before the connectivity probe');
      expect(notifier.state.schedule.isLoading, isFalse);
      expect(notifier.state.schedule.error, isNull);

      // Background sync completes: fresh data replaces the copy.
      await _flush();
      expect(notifier.state.schedule.items.single.subject, 'Свежее из API');
      expect(notifier.state.schedule.error, isNull);
      expect(notifications.shownIds, isEmpty,
          reason: 'first open only stores the baseline');
      expect(storage.fingerprint, isNotNull);
    });

    test('offline keeps the painted copy and never hits the API', () async {
      final storage = WarmStorage()
        ..cached = _cachedSchedule([_item('Из кэша')]);
      final service = FakeScheduleService([_item('Свежее из API')]);
      final connectivity = FakeConnectivity()..online = false;
      final notifications = FakeNotifications();

      final notifier = _scheduleNotifier(
        service: service,
        storage: storage,
        connectivity: connectivity,
        notifications: notifications,
      );
      expect(notifier.state.schedule.items.single.subject, 'Из кэша');

      await _flush();
      expect(service.getScheduleCalls, 0,
          reason: 'offline must not touch the API');
      expect(notifier.state.schedule.items.single.subject, 'Из кэша');
      expect(notifier.state.schedule.error, isNull,
          reason: 'a painted copy suppresses the offline error screen');
      expect(notifier.state.schedule.isLoading, isFalse);
    });

    test('cold start without cache: spinner, then an explicit offline error',
        () async {
      final storage = WarmStorage(); // no cached schedule
      final service = FakeScheduleService([_item('Свежее из API')]);
      final connectivity = FakeConnectivity()..online = false;
      final notifications = FakeNotifications();

      final notifier = _scheduleNotifier(
        service: service,
        storage: storage,
        connectivity: connectivity,
        notifications: notifications,
      );

      // Loading starts synchronously — the empty view must not flash.
      expect(notifier.state.schedule.isLoading, isTrue);
      expect(notifier.state.schedule.items, isEmpty);

      await _flush();
      expect(notifier.state.schedule.error, 'Нет подключения к интернету');
      expect(notifier.state.schedule.isLoading, isFalse);
      expect(service.getScheduleCalls, 0);
    });
  });

  group('marks stale-while-revalidate', () {
    test('warm marks cache paints before the network answer arrives', () async {
      final pending = Completer<List<FinalMark>>();
      final api = FakeProgressApi(pending: pending);
      final storage = FakeMarkStorage()..cachedMarks = [_mark('Из кэша')];
      final connectivity = FakeConnectivity();

      final notifier =
          PerformanceNotifier(api, storage, UpdateCoordinator(connectivity));

      // Кэш отрисован синхронно, до проверки доступности и запроса.
      expect(notifier.state.marks.single.discipline, 'Из кэша');
      expect(notifier.state.error, isNull);

      // Запрос стартует после проверки доступности.
      await _flush();
      expect(api.calls, 1, reason: 'synced with the API in the background');
      expect(notifier.state.isLoading, isTrue,
          reason: 'background revalidation is still running');
      expect(notifier.state.marks.single.discipline, 'Из кэша');

      pending.complete([_finalMark('Свежее из API')]);
      await _flush();
      expect(notifier.state.marks.single.discipline, 'Свежее из API');
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNull);
    });

    test('offline keeps the painted marks instead of an error screen',
        () async {
      final pending = Completer<List<FinalMark>>();
      final api = FakeProgressApi(pending: pending);
      final storage = FakeMarkStorage()..cachedMarks = [_mark('Из кэша')];
      final connectivity = FakeConnectivity()..online = false;

      final notifier =
          PerformanceNotifier(api, storage, UpdateCoordinator(connectivity));
      expect(notifier.state.marks.single.discipline, 'Из кэша');
      await _flush();

      expect(api.calls, 0, reason: 'офлайн не ходит в API вообще');

      expect(notifier.state.marks.single.discipline, 'Из кэша');
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNull,
          reason: 'served cache must not surface an error');
    });
  });
}
