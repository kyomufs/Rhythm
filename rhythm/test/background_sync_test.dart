import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tulgusch/core/models/app_settings.dart';
import 'package:tulgusch/core/models/schedule.dart';
import 'package:tulgusch/core/providers/clock_provider.dart';
import 'package:tulgusch/core/services/connectivity_service.dart';
import 'package:tulgusch/core/services/notification_service.dart';
import 'package:tulgusch/core/services/schedule_service.dart';
import 'package:tulgusch/core/services/storage_service.dart';
import 'package:tulgusch/core/api/schedule_api.dart';
import 'package:tulgusch/core/api/api_providers.dart';
import 'package:tulgusch/core/widgets/background_sync_host.dart';
import 'package:tulgusch/features/schedule/providers/schedule_provider.dart';

const _group = '221341:01';

ScheduleItem _item(String subject) => ScheduleItem(
      date: '05.11.2026',
      time: '09:40 - 11:15',
      subject: subject,
      type: 'Лекции',
      classroom: 'Гл.-412',
      teacher: 'Гречева Ирина Алексеевна',
      groups: const [GroupInfo(number: _group)],
      cssClass: 'lecture',
    );

class _CountingApi extends ScheduleApi {
  @override
  Future<bool> ping() async => true;

  _CountingApi(this.items);

  List<ScheduleItem> items;
  int scheduleCalls = 0;

  @override
  Future<ScheduleDateRange> dateRange(String searchValue) async =>
      ScheduleDateRange(
        minDate: DateTime(2026, 9, 1),
        maxDate: DateTime(2027, 1, 25),
        searchField: SearchField.group,
      );

  @override
  Future<List<ScheduleItem>> lessons({
    required String searchField,
    required String searchValue,
  }) async {
    scheduleCalls++;
    return items;
  }

  @override
  Future<List<CalendarItem>> calendar(String searchValue) async => [];

  @override
  Future<List<ScheduleSuggestion>> search(String query) async => [];
}

class _FakeStorage extends StorageService {
  _FakeStorage(this.settings);

  AppSettings settings;
  String? fingerprint;
  List<Map<String, dynamic>> changeLog = [];

  @override
  AppSettings getAppSettings() => settings;

  @override
  Future<void> saveAppSettings(AppSettings value) async {
    settings = value;
  }

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
  CachedSchedule? getCachedSchedule(String searchValue,
          ) =>
      null;

  @override
  Future<void> cacheSchedule(String searchValue, ScheduleData data,
      ) async {}

  @override
  String? getLastSearch() => null;

  @override
  Future<void> saveLastSearch(String searchValue,
      ) async {}

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
}

class _FakeConnectivity implements ConnectivityService {
  @override
  Future<bool> checkConnectivity() async => true;

  @override
  void invalidateCache() {}
}

class _FakeNotifications implements NotificationService {
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

Widget _host({
  required _CountingApi api,
  required _FakeStorage storage,
}) {
  return ProviderScope(
    overrides: [
      demoModeProvider.overrideWithValue(false),
      scheduleApiProvider.overrideWithValue(api),
      scheduleServiceProvider.overrideWithValue(
        ScheduleService(api: api, storage: storage),
      ),
      storageServiceProvider.overrideWithValue(storage),
      connectivityServiceProvider.overrideWithValue(_FakeConnectivity()),
      notificationServiceProvider.overrideWithValue(_FakeNotifications()),
    ],
    child: MaterialApp(
      home: BackgroundSyncHost(
        // Нотифаер создаётся только когда его кто-то слушает — как в оболочке.
        child: Consumer(builder: (context, ref, _) {
          ref.watch(scheduleScreenProvider);
          return const SizedBox.shrink();
        }),
      ),
    ),
  );
}

void main() {
  testWidgets('таймер опрашивает расписание с периодом из настроек',
      (tester) async {
    final api = _CountingApi([_item('Алгебра')]);
    final storage = _FakeStorage(
      const AppSettings(backgroundCheckMinutes: 60),
    );

    await tester.pumpWidget(_host(api: api, storage: storage));
    await tester.pumpAndSettle();
    final afterLoad = api.scheduleCalls;
    expect(afterLoad, greaterThan(0),
        reason: 'первый запрос — обычная загрузка');

    await tester.pump(const Duration(minutes: 59));
    await tester.pumpAndSettle();
    expect(api.scheduleCalls, afterLoad, reason: 'период ещё не истёк');

    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(api.scheduleCalls, greaterThan(afterLoad),
        reason: 'через час пришёл фоновый опрос');

    // Снимаем виджет, иначе периодический таймер останется на teardown.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('при выключенной проверке таймер не заводится', (tester) async {
    final api = _CountingApi([_item('Алгебра')]);
    final storage = _FakeStorage(const AppSettings(backgroundCheckMinutes: 0));

    await tester.pumpWidget(_host(api: api, storage: storage));
    await tester.pumpAndSettle();
    final afterLoad = api.scheduleCalls;

    await tester.pump(const Duration(hours: 3));
    await tester.pumpAndSettle();

    expect(api.scheduleCalls, afterLoad,
        reason: '0 минут — фоновая проверка выключена');

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
