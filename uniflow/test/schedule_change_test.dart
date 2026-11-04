import 'package:flutter_test/flutter_test.dart';
import 'package:uniflow/core/demo/demo_schedule.dart';
import 'package:uniflow/core/models/change_record.dart';
import 'package:uniflow/core/models/schedule.dart';
import 'package:uniflow/core/services/connectivity_service.dart';
import 'package:uniflow/core/services/notification_service.dart';
import 'package:uniflow/core/services/schedule_service.dart';
import 'package:uniflow/core/services/storage_service.dart';
import 'package:uniflow/core/services/update_coordinator.dart';
import 'package:uniflow/features/schedule/providers/schedule_provider.dart';

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

/// Flush pending microtasks/timers without a widget binding.
Future<void> _flush() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

// ── Fakes ──────────────────────────────────────────────────────

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

class FakeStorage extends StorageService {
  String myGroupValue = '221341';
  String? fingerprint;
  final List<FavoriteGroup> favorites = [];
  List<Map<String, dynamic>> changeLog = [];
  DateTime? changesSeen;

  @override
  String? getMyGroup() => myGroupValue;

  @override
  List<FavoriteGroup> getFavoriteGroups() => favorites;

  @override
  String? getScheduleFingerprint() => fingerprint;

  @override
  Future<void> setScheduleFingerprint(String? value) async {
    fingerprint = value;
  }

  @override
  CachedSchedule? getCachedSchedule(String searchValue) => null;

  // The base class keeps these in an uninitialized Hive box; tests use
  // an in-memory journal instead.
  @override
  List<Map<String, dynamic>> getChangeLog() => changeLog;

  @override
  Future<void> saveChangeLog(List<Map<String, dynamic>> entries) async {
    changeLog = entries;
  }

  @override
  Future<void> clearChangeLog() async {
    changeLog = [];
  }

  @override
  DateTime? getChangesSeenAt() => changesSeen;

  @override
  Future<void> setChangesSeenAt(DateTime value) async {
    changesSeen = value;
  }
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
  final List<String> titles = [];
  final List<String?> payloads = [];

  @override
  Future<void> show(int id, String title, String body,
      {String? payload}) async {
    shownIds.add(id);
    titles.add(title);
    payloads.add(payload);
  }

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> areNotificationsEnabled() async => true;
}

ScheduleScreenNotifier _notifier({
  required List<ScheduleItem> data,
  required FakeStorage storage,
  required FakeNotifications notifications,
  bool demo = false,
}) {
  final connectivity = FakeConnectivity();
  return ScheduleScreenNotifier(
    FakeScheduleService(data),
    storage,
    connectivity,
    notifications,
    UpdateCoordinator(connectivity),
    demo: demo,
  );
}

// ── Tests ──────────────────────────────────────────────────────

void main() {
  test('first open stores the fingerprint baseline without notifying',
      () async {
    final storage = FakeStorage();
    final notifications = FakeNotifications();

    _notifier(
        data: [_item('Алгебра')],
        storage: storage,
        notifications: notifications);
    await _flush();

    expect(storage.fingerprint, isNotNull, reason: 'baseline must be saved');
    expect(notifications.shownIds, isEmpty,
        reason: 'first run has nothing to compare against');
  });

  test('identical schedule on the next open triggers no notification',
      () async {
    final storage = FakeStorage();
    final notifications = FakeNotifications();

    // First open: stores the baseline for "Алгебра".
    _notifier(
        data: [_item('Алгебра')],
        storage: storage,
        notifications: notifications);
    await _flush();
    expect(notifications.shownIds, isEmpty);

    // Second open with byte-identical data.
    _notifier(
        data: [_item('Алгебра')],
        storage: storage,
        notifications: notifications);
    await _flush();

    expect(notifications.shownIds, isEmpty,
        reason: 'unchanged schedule must stay silent');
  });

  test('changed schedule notifies and updates the visible state', () async {
    final storage = FakeStorage();
    final notifications = FakeNotifications();

    // First open: baseline for "Алгебра".
    _notifier(
        data: [_item('Алгебра')],
        storage: storage,
        notifications: notifications);
    await _flush();
    expect(notifications.shownIds, isEmpty);

    // Second open: the university changed the lesson to "Геометрия".
    final notifier = _notifier(
        data: [_item('Геометрия')],
        storage: storage,
        notifications: notifications);
    await _flush();

    expect(notifications.shownIds, [2],
        reason: 'schedule-change notification id is 2');
    expect(notifications.titles, ['Расписание изменилось']);
    expect(notifications.payloads, [changesNotificationPayload],
        reason: 'payload ведёт тап по уведомлению в журнал изменений');
    expect(notifier.state.schedule.items.single.subject, 'Геометрия',
        reason: 'fresh data must be shown immediately');
    expect(storage.fingerprint, isNot(equals('')),
        reason: 'baseline moves forward after the alert');
  });

  test('фоновая проверка ловит изменение и возвращает true', () async {
    final storage = FakeStorage();
    final notifications = FakeNotifications();
    final service = FakeScheduleService([_item('Алгебра')]);
    final connectivity = FakeConnectivity();
    final notifier = ScheduleScreenNotifier(
      service,
      storage,
      connectivity,
      notifications,
      UpdateCoordinator(connectivity),
    );
    await _flush();
    expect(notifications.shownIds, isEmpty);

    // Университет поменял пару, а приложение всё это время открыто.
    service.data = [_item('Геометрия')];
    final reported = await notifier.pollForChanges();

    expect(reported, isTrue, reason: 'таймер сообщает об изменении');
    expect(notifications.shownIds, [2]);
    expect(notifications.payloads, [changesNotificationPayload]);
  });

  test('фоновая проверка молчит в демо-режиме и без группы', () async {
    final storage = FakeStorage();
    final notifications = FakeNotifications();
    final connectivity = FakeConnectivity();
    final service = FakeScheduleService([_item('Алгебра')]);

    final demo = ScheduleScreenNotifier(
      service,
      storage,
      connectivity,
      notifications,
      UpdateCoordinator(connectivity),
      demo: true,
    );
    await _flush();

    expect(await demo.pollForChanges(), isFalse);
    expect(service.getScheduleCalls, 0,
        reason: 'демо-расписание не запрашивается в фоне');

    // Без выбранной группы опрашивать нечего.
    storage.myGroupValue = '';
    final noGroup = ScheduleScreenNotifier(
      FakeScheduleService([_item('Алгебра')]),
      storage,
      connectivity,
      notifications,
      UpdateCoordinator(connectivity),
    );
    await _flush();
    expect(await noGroup.pollForChanges(), isFalse);
    expect(notifications.shownIds, isEmpty);
  });

  test('changed schedule marks modified, new and cancelled lessons', () async {
    final storage = FakeStorage();
    final notifications = FakeNotifications();

    // Baseline: Алгебра (a.101) + Геометрия.
    _notifier(data: [
      _item('Алгебра'),
      _item('Геометрия', time: '09:45 - 11:15'),
    ], storage: storage, notifications: notifications);
    await _flush();
    expect(notifications.shownIds, isEmpty);

    // University moved Алгебра to a.102, cancelled Геометрия,
    // added Тригонометрия.
    final notifier = _notifier(data: [
      _item('Алгебра', classroom: '102'),
      _item('Тригонометрия', time: '12:00 - 13:30'),
    ], storage: storage, notifications: notifications);
    await _flush();

    expect(notifications.shownIds, [2]);
    expect(notifier.state.changeNotes.values, contains('Аудитория: 101 → 102'));
    expect(notifier.state.changeNotes.values, contains('Новое занятие'));
    expect(notifier.state.removedLessons.single, contains('Геометрия'));
  });

  test('offline app open serves cache and states the offline reason', () async {
    final storage = FakeStorage();
    final notifications = FakeNotifications();
    final connectivity = FakeConnectivity()..online = false;

    final notifier = ScheduleScreenNotifier(
      FakeScheduleService([_item('Алгебра')]),
      storage,
      connectivity,
      notifications,
      UpdateCoordinator(connectivity),
    );
    await _flush();

    // Connectivity probe says offline → the offline branch runs: no
    // cache in this fake → explicit "no internet" error in the state.
    expect(notifier.state.schedule.error, 'Нет подключения к интернету');
    expect(notifications.shownIds, isEmpty);
  });

  test('teacher-only change is reported as a field-level modification',      () async {
    final storage = FakeStorage();
    final notifications = FakeNotifications();

    _notifier(
        data: [_item('Алгебра')],
        storage: storage,
        notifications: notifications);
    await _flush();
    expect(notifications.shownIds, isEmpty);

    // Same lesson, new teacher — the fingerprint now includes teacher.
    const replaced = ScheduleItem(
      date: '23.09.2026',
      time: '08:00 - 09:30',
      subject: 'Алгебра',
      type: 'Лекции',
      classroom: '101',
      teacher: 'Петров Пётр',
      groups: [],
      cssClass: 'lecture',
    );
    final notifier = _notifier(
        data: [replaced], storage: storage, notifications: notifications);
    await _flush();

    expect(notifications.shownIds, [2]);
    final record = notifier.state.changeRecords.single;
    expect(record.kind, ChangeKind.modified);
    expect(record.fieldChanges.single.field, 'Преподаватель');
    expect(record.fieldChanges.single.before, 'Иванов Иван');
    expect(record.fieldChanges.single.after, 'Петров Пётр');
  });

  test('legacy 5-field fingerprint without teacher does not false-positive',
      () async {
    final storage = FakeStorage();
    final notifications = FakeNotifications();

    // Simulate a pre-upgrade stored baseline (no teacher column):
    // date|time|subject|classroom|type.
    storage.fingerprint = '23.09.2026|08:00 - 09:30|Алгебра|101|Лекции';

    _notifier(
        data: [_item('Алгебра')],
        storage: storage,
        notifications: notifications);
    await _flush();

    expect(notifications.shownIds, isEmpty,
        reason: 'teacher diff must be skipped for legacy rows');
    expect(storage.fingerprint, contains('Иванов Иван'),
        reason: 'baseline migrates to the 6-field format');
  });

  test('detected changes are persisted into the journal', () async {
    final storage = FakeStorage();
    final notifications = FakeNotifications();

    _notifier(
        data: [_item('Алгебра')],
        storage: storage,
        notifications: notifications);
    await _flush();
    expect(storage.changeLog, isEmpty);

    _notifier(
        data: [_item('Геометрия')],
        storage: storage,
        notifications: notifications);
    await _flush();

    expect(notifications.shownIds, [2]);
    expect(storage.changeLog, hasLength(1),
        reason: 'fresh records must land in the Hive journal');
    expect(storage.changeLog.single['kind'], 'modified');
    expect(storage.changeLog.single['subject'], 'Геометрия');
  });

  test('markChangesSeen clears the badge but keeps the journal history',
      () async {
    final storage = FakeStorage();
    final notifications = FakeNotifications();

    _notifier(
        data: [_item('Алгебра')],
        storage: storage,
        notifications: notifications);
    await _flush();

    final notifier = _notifier(
        data: [_item('Геометрия')],
        storage: storage,
        notifications: notifications);
    await _flush();
    expect(notifier.state.hasUnseenChanges, isTrue);
    expect(notifier.state.changeRecords, isNotEmpty);

    await notifier.markChangesSeen();

    expect(notifier.state.hasUnseenChanges, isFalse);
    expect(notifier.state.changeRecords, isEmpty);
    expect(notifier.state.changeJournal, isNotEmpty,
        reason: 'history survives badge dismissal');
    expect(storage.changesSeen, isNotNull);

    // A reopened instance restores the journal from storage.
    final reopened = _notifier(
        data: [_item('Геометрия')],
        storage: storage,
        notifications: notifications);
    await _flush();
    expect(reopened.state.changeJournal, isNotEmpty);
    expect(reopened.state.hasUnseenChanges, isFalse,
        reason: 'journal entries older than the seen mark stay seen');
  });

  test('manual journal clear empties state and storage', () async {
    final storage = FakeStorage();
    final notifications = FakeNotifications();

    _notifier(
        data: [_item('Алгебра')],
        storage: storage,
        notifications: notifications);
    await _flush();
    final notifier = _notifier(
        data: [_item('Геометрия')],
        storage: storage,
        notifications: notifications);
    await _flush();
    expect(notifier.state.changeJournal, isNotEmpty);

    await notifier.clearChangeJournal();

    expect(notifier.state.changeJournal, isEmpty);
    expect(storage.changeLog, isEmpty);
  });

  test('journal prune enforces the 50-entry cap and 14-day TTL', () async {
    final now = DateTime(2026, 9, 23, 12);
    ChangeRecord rec(DateTime at, {String subject = 'Алгебра'}) => ChangeRecord(
          detectedAt: at,
          kind: ChangeKind.added,
          date: '23.09.2026',
          subject: subject,
          type: 'Лекции',
          time: '08:00 - 09:30',
          classroom: '101',
          teacher: 'Иванов Иван',
        );

    final entries = [
      rec(now.subtract(const Duration(days: 20)), subject: 'Старая'),
      for (var i = 0; i < 60; i++)
        rec(now.subtract(Duration(minutes: i)), subject: 'Предмет $i'),
    ];
    final pruned = ScheduleScreenNotifier.pruneJournal(entries, now: now);

    expect(pruned, hasLength(50), reason: 'hard cap');
    expect(pruned.every((r) => r.subject != 'Старая'), isTrue,
        reason: 'entries older than 14 days are dropped');
  });

  test('demo mode skips the API and shows only real-functionality data',
      () async {
    final storage = FakeStorage()..myGroupValue = '';
    final notifications = FakeNotifications();
    final service = FakeScheduleService([_item('Алгебра')]);
    final connectivity = FakeConnectivity();

    final notifier = ScheduleScreenNotifier(
      service,
      storage,
      connectivity,
      notifications,
      UpdateCoordinator(connectivity),
      demo: true,
    );
    await _flush();

    expect(service.getScheduleCalls, 0, reason: 'demo never calls the API');
    expect(storage.fingerprint, isNull,
        reason: 'demo must not overwrite the real baseline');
    expect(storage.changeLog, isEmpty, reason: 'demo journal is memory-only');
    expect(notifier.state.isDemo, isTrue);
    expect(notifier.state.schedule.items, isNotEmpty);
    expect(notifier.state.schedule.searchValue, demoGroup);
    expect(
      notifier.state.schedule.items.every(
          (i) => i.groups.single.number == demoGroup),
      isTrue,
      reason: 'every demo row is marked with the fake group',
    );
    expect(notifier.state.changeJournal, isEmpty,
        reason: 'ничего не выдумываем: журнал изменений в демо пуст');
    expect(notifier.state.hasUnseenChanges, isFalse);
    expect(notifications.shownIds, isEmpty);

    // Refresh в демо отвечает успехом и ничего не меняет — так же, как
    // настоящий путь, когда данные уже свежие.
    final result = await notifier.refresh();
    expect(result.outcome, UpdateOutcome.updated);
    expect(result.message, scheduleUpdatedText);
    expect(service.getScheduleCalls, 0);
    expect(notifier.state.changeRecords, isEmpty);
    expect(notifications.shownIds, isEmpty);
  });
}
