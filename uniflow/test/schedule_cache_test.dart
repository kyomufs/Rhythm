import 'package:flutter_test/flutter_test.dart';
import 'package:uniflow/core/api/endpoints.dart';
import 'package:uniflow/core/api/tulsu_api.dart';
import 'package:uniflow/core/models/schedule.dart';
import 'package:uniflow/core/services/connectivity_service.dart';
import 'package:uniflow/core/services/notification_service.dart';
import 'package:uniflow/core/services/schedule_service.dart';
import 'package:uniflow/core/services/storage_service.dart';
import 'package:uniflow/core/services/update_coordinator.dart';
import 'package:uniflow/features/schedule/providers/schedule_provider.dart';

// ── Fakes ──────────────────────────────────────────────────────

const _group = '221341:01';

ScheduleItem _item(String subject) => ScheduleItem(
      date: '04.11.2026',
      time: '10:00 - 11:30',
      subject: subject,
      type: 'Лекции',
      classroom: 'Гл.-408',
      teacher: 'Двоенко Сергей Данилович',
      groups: const [GroupInfo(number: _group)],
      cssClass: 'lecture',
    );

ScheduleData _data(List<ScheduleItem> items) => ScheduleData(
      dateRange: ApiDateRange(
        minDate: DateTime(2026, 9, 1),
        maxDate: DateTime(2027, 1, 25),
        searchField: SearchFieldType.group,
      ),
      items: items,
      calendar: const [],
    );

class _FakeApi extends TulsuApiClient {
  _FakeApi({this.items = const [], this.fail = false});

  final List<ScheduleItem> items;
  final bool fail;
  int calls = 0;

  @override
  Future<ScheduleData> getFullSchedule(String searchValue) async {
    calls++;
    if (fail) throw const ApiException('Нет подключения к интернету');
    return _data(items);
  }
}

class _CacheStorage extends StorageService {
  _CacheStorage({this.cached = const {}});

  Map<String, CachedSchedule> cached;
  final Map<String, ScheduleData> written = {};
  String? fingerprint;
  List<Map<String, dynamic>> changeLog = [];

  @override
  String? getMyGroup() => _group;

  @override
  String? getMySubgroup() => '01';

  @override
  List<FavoriteGroup> getFavoriteGroups() => const [];

  @override
  String? getScheduleFingerprint() => fingerprint;

  @override
  Future<void> setScheduleFingerprint(String? value) async {
    fingerprint = value;
  }

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
  DateTime? getChangesSeenAt() => null;

  @override
  Future<void> setChangesSeenAt(DateTime value) async {}

  @override
  CachedSchedule? getCachedSchedule(String searchValue) => cached[searchValue];

  @override
  Future<void> cacheSchedule(String searchValue, ScheduleData data) async {
    written[searchValue] = data;
  }

  @override
  Future<void> saveLastSearch(String searchValue) async {}
}

class _OfflineConnectivity implements ConnectivityService {
  @override
  Future<bool> checkConnectivity() async => false;

  @override
  void invalidateCache() {}
}

class _SilentNotifications implements NotificationService {
  @override
  void Function(String? payload)? onTap;

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> areNotificationsEnabled() async => true;

  @override
  Future<void> show(int id, String title, String body,
      {String? payload}) async {}
}

Future<void> _flush() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

CachedSchedule _snapshot(String group, {required Duration age}) =>
    CachedSchedule(
      searchValue: group,
      data: _data([_item('Математический анализ')]),
      cachedAt: DateTime.now().subtract(age),
    );

// ── Tests ──────────────────────────────────────────────────────

void main() {
  test('свежий кэш отдаётся без обращения к API', () async {
    final api = _FakeApi(items: [_item('Из API')]);
    final storage = _CacheStorage(cached: {_group: _snapshot(_group, age: const Duration(hours: 2))});
    final service = ScheduleService(api: api, storage: storage);

    final state = await service.getSchedule(_group);

    expect(api.calls, 0);
    expect(state.items.single.subject, 'Математический анализ');
    expect(state.error, isNull);
  });

  test('просроченный кэш остаётся на экране, если API недоступно', () async {
    final api = _FakeApi(fail: true);
    final storage = _CacheStorage(cached: {
      _group: _snapshot(_group, age: const Duration(days: 6)),
    });
    final connectivity = _OfflineConnectivity();

    final notifier = ScheduleScreenNotifier(
      ScheduleService(api: api, storage: storage),
      storage,
      connectivity,
      _SilentNotifications(),
      UpdateCoordinator(connectivity),
    );
    await _flush();

    expect(api.calls, 0, reason: 'офлайн не дёргает API даже за свежими данными');
    expect(notifier.state.schedule.items.single.subject, 'Математический анализ',
        reason: 'снимок недельной давности всё равно показывается');
    expect(notifier.state.schedule.error, isNull,
        reason: 'вместо ошибки — сохранённое расписание');
  });

  test('prefetch сохраняет снимок избранной группы', () async {
    final api = _FakeApi(items: [_item('Физика')]);
    final storage = _CacheStorage();
    final service = ScheduleService(api: api, storage: storage);

    final ok = await service.prefetch('221341и');

    expect(ok, isTrue);
    expect(storage.written.containsKey('221341и'), isTrue,
        reason: 'снимок избранного лежит в кэше и открывается офлайн');
    expect(storage.written['221341и']!.items.single.subject, 'Физика');
  });
}
