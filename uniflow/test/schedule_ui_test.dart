import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniflow/core/api/endpoints.dart';
import 'package:uniflow/core/api/tulsu_api.dart';
import 'package:uniflow/core/models/schedule.dart';
import 'package:uniflow/core/providers/clock_provider.dart';
import 'package:uniflow/core/services/connectivity_service.dart';
import 'package:uniflow/core/services/notification_service.dart';
import 'package:uniflow/core/services/schedule_service.dart';
import 'package:uniflow/core/services/storage_service.dart';
import 'package:uniflow/features/schedule/screens/schedule_screen.dart';
import 'package:uniflow/features/schedule/widgets/lesson_tile.dart';

// ── Fakes ──────────────────────────────────────────────────────

const _group = '221341:01';

ScheduleItem _item({
  required String subject,
  required DateTime date,
  String time = '10:00 - 11:30',
  String classroom = 'Гл.-408',
  String teacher = 'Двоенко Сергей Данилович',
  List<GroupInfo>? groups,
}) {
  return ScheduleItem(
    date: _fmt(date),
    time: time,
    subject: subject,
    type: 'Лекции',
    classroom: classroom,
    teacher: teacher,
    groups: groups ?? [const GroupInfo(number: _group)],
    cssClass: 'lecture',
  );
}

class _FakeApi extends TulsuApiClient {
  _FakeApi(this.items);

  final List<ScheduleItem> items;

  @override
  Future<ApiDateRange> getDateRange(String searchValue) async => ApiDateRange(
        minDate: DateTime(2026, 9, 1),
        maxDate: DateTime(2027, 1, 25),
        searchField: SearchFieldType.group,
      );

  @override
  Future<List<ScheduleItem>> getSchedule(
          String searchField, String searchValue) async =>
      items;

  @override
  Future<List<CalendarItem>> getCalendar(String searchValue) async => [];

  @override
  Future<List<SearchSuggestion>> search(String query) async => [];
}

class _FakeStorage extends StorageService {
  _FakeStorage({this.favorites = const []});

  String myGroup = _group;
  List<FavoriteGroup> favorites;
  String? fingerprint;
  List<Map<String, dynamic>> changeLog = [];

  @override
  String? getMyGroup() => myGroup;

  @override
  String? getMySubgroup() => '01';

  @override
  List<FavoriteGroup> getFavoriteGroups() => favorites;

  @override
  Future<void> removeFavoriteGroup(String groupNumber) async {
    favorites = favorites
        .where((f) => f.groupNumber != groupNumber)
        .toList(growable: false);
  }

  @override
  String? getScheduleFingerprint() => fingerprint;

  @override
  Future<void> setScheduleFingerprint(String? value) async {
    fingerprint = value;
  }

  @override
  CachedSchedule? getCachedSchedule(String searchValue) => null;

  @override
  Future<void> cacheSchedule(String searchValue, ScheduleData data) async {}

  @override
  String? getLastSearch() => null;

  @override
  Future<void> saveLastSearch(String searchValue) async {}

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
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> areNotificationsEnabled() async => true;

  @override
  Future<void> show(int id, String title, String body) async {}
}

// ── Harness ────────────────────────────────────────────────────

/// Тесты идут на реальной текущей дате: расписание показывает именно
/// текущую неделю, и подменять часы ради фикстуры незачем.
final _now = DateTime.now();

String _fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}.'
    '${d.month.toString().padLeft(2, '0')}.${d.year}';

Widget _app({
  required List<ScheduleItem> items,
  _FakeStorage? storage,
}) {
  return ProviderScope(
    overrides: [
      demoModeProvider.overrideWithValue(false),
      scheduleServiceProvider.overrideWithValue(
        ScheduleService(api: _FakeApi(items), storage: _FakeStorage()),
      ),
      storageServiceProvider.overrideWithValue(storage ?? _FakeStorage()),
      connectivityServiceProvider.overrideWithValue(_FakeConnectivity()),
      notificationServiceProvider.overrideWithValue(_FakeNotifications()),
    ],
    child: MaterialApp(
      theme: ThemeData(useMaterial3: true),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ru', 'RU')],
      locale: const Locale('ru'),
      home: const ScheduleScreen(),
    ),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru_RU');
    Intl.defaultLocale = 'ru_RU';
  });


  testWidgets('шапка показывает номер группы, щит и звезду избранного',
      (tester) async {
    await tester.pumpWidget(_app(items: [
      _item(subject: 'Математический анализ', date: _now),
    ]));
    await tester.pumpAndSettle();

    expect(find.text(_group), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage)
                .assetName
                .contains('tulsu_shield.png'),
      ),
      findsOneWidget,
      reason: 'глиф-щит стоит перед номером группы',
    );
    expect(find.byIcon(Icons.star_outline), findsOneWidget);
    expect(find.text('Расписание'), findsNothing,
        reason: 'подпись «Расписание» из угла убрана');
  });

  testWidgets('звезда открывает лист избранных групп с сохранёнными группами',
      (tester) async {
    final storage = _FakeStorage(favorites: [
      FavoriteGroup(groupNumber: '221341', addedAt: DateTime(2026, 10, 1)),
      FavoriteGroup(groupNumber: '220042-11', addedAt: DateTime(2026, 10, 2)),
    ]);

    await tester.pumpWidget(_app(
      items: [_item(subject: 'Математический анализ', date: _now)],
      storage: storage,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.star_outline));
    await tester.pumpAndSettle();

    expect(find.text('Избранные группы'), findsOneWidget);
    expect(find.text('221341'), findsOneWidget);
    expect(find.text('220042-11'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing,
        reason: 'крестик закрытия из меню убран');
  });

  testWidgets('навигатор недели показывает номер, чётность и даты',
      (tester) async {
    await tester.pumpWidget(_app(items: [
      _item(subject: 'Математический анализ', date: _now),
    ]));
    await tester.pumpAndSettle();

    expect(find.textContaining('Неделя'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data == 'чётная' || w.data == 'нечётная'),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);

    final before = tester.widget<Text>(find.textContaining('Неделя')).data;
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.textContaining('Неделя')).data,
        isNot(before),
        reason: 'стрелка переключает неделю');
  });

  testWidgets('карточка предмета открывает лист без блока «Группы»',
      (tester) async {
    await tester.pumpWidget(_app(items: [
      _item(subject: 'Математический анализ', date: _now),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(LessonTile).first);
    await tester.pumpAndSettle();

    expect(find.text('Математический анализ'), findsWidgets);
    expect(find.widgetWithText(Chip, _group), findsNothing,
        reason: 'чип своей же группы ничего не сообщает и не показывается');
  });

  testWidgets('лист показывает другие группы, если они есть в паре',
      (tester) async {
    await tester.pumpWidget(_app(items: [
      _item(
        subject: 'Математический анализ',
        date: _now,
        groups: const [
          GroupInfo(number: _group),
          GroupInfo(number: '221341и'),
        ],
      ),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(LessonTile).first);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(Chip, '221341и'), findsOneWidget,
        reason: 'чужие группы в паре видны');
    expect(find.widgetWithText(Chip, _group), findsOneWidget);
  });
}
