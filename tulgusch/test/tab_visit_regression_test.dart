// Вкладку переключает не только нижняя панель: кнопка «Открыть профиль» на
// пустых оценках пишет индекс в провайдер напрямую. Оболочка строила экран
// только для вкладок, отмеченных в `selectTab`, поэтому такой переход
// показывал заглушку IndexedStack — пустой экран без содержимого.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:tulgusch/app.dart';
import 'package:tulgusch/core/api/api_providers.dart';
import 'package:tulgusch/core/api/schedule_api.dart';
import 'package:tulgusch/core/models/app_settings.dart';
import 'package:tulgusch/core/models/schedule.dart';
import 'package:tulgusch/core/providers/clock_provider.dart';
import 'package:tulgusch/core/services/connectivity_service.dart';
import 'package:tulgusch/core/services/notification_service.dart';
import 'package:tulgusch/core/services/schedule_service.dart';
import 'package:tulgusch/core/services/storage_service.dart';

class _FakeApi extends ScheduleApi {
  @override
  Future<bool> ping() async => true;

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
  }) async =>
      const [];

  @override
  Future<List<CalendarItem>> calendar(String searchValue) async => [];

  @override
  Future<List<ScheduleSuggestion>> search(String query) async => [];
}

class _FakeStorage extends StorageService {
  @override
  String? getMyGroup() => '121212';

  @override
  String? getMySubgroup() => null;

  @override
  String? getStudentId() => null;

  @override
  AppSettings getAppSettings() => const AppSettings();

  @override
  List<FavoriteGroup> getFavoriteGroups() => const [];

  @override
  CachedSchedule? getCachedSchedule(String searchValue) => null;

  @override
  Future<void> cacheSchedule(String searchValue, ScheduleData data) async {}

  @override
  Future<void> saveAppSettings(AppSettings settings) async {}

  @override
  Future<void> setNotificationsAsked() async {}

  @override
  bool isNotificationsAsked() => true;

  @override
  String? getScheduleFingerprint() => null;

  @override
  Future<void> setScheduleFingerprint(String? value) async {}

  @override
  List<Map<String, dynamic>> getChangeLog() => const [];

  @override
  Future<void> saveChangeLog(List<Map<String, dynamic>> entries) async {}

  @override
  DateTime? getChangesSeenAt() => null;
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

Widget _app() {
  final api = _FakeApi();
  return ProviderScope(
    overrides: [
      demoModeProvider.overrideWithValue(false),
      scheduleApiProvider.overrideWithValue(api),
      scheduleServiceProvider.overrideWithValue(
        ScheduleService(api: api, storage: _FakeStorage()),
      ),
      storageServiceProvider.overrideWithValue(_FakeStorage()),
      connectivityServiceProvider.overrideWithValue(_FakeConnectivity()),
      notificationServiceProvider.overrideWithValue(_FakeNotifications()),
    ],
    child: const MaterialApp(
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [Locale('ru', 'RU')],
      locale: Locale('ru'),
      home: MainShell(),
    ),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru_RU');
    Intl.defaultLocale = 'ru_RU';
  });

  testWidgets('внешняя запись в currentTabProvider строит экран вкладки',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Так же, как кнопка «Открыть профиль» на пустых оценках: панель не
    // участвует, индекс пишется в провайдер напрямую.
    final container =
        ProviderScope.containerOf(tester.element(find.byType(MainShell)));
    container.read(currentTabProvider.notifier).state = AppTabs.profile;

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Настройки'), findsOneWidget);
    expect(find.text('Тема, цвет, расписание'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
