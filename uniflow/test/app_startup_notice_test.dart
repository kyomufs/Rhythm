// Автообновление при входе: приложение само тянет расписание и оценки на
// старте, поэтому пользователь должен увидеть плашку об успехе без каких-либо
// действий. Тест поднимает настоящую оболочку и проверяет обе ветки — одну
// плашку на два источника и одиночные формулировки.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:uniflow/app.dart';
import 'package:uniflow/core/api/api_exception.dart';
import 'package:uniflow/core/models/app_settings.dart';
import 'package:uniflow/core/models/marks.dart';
import 'package:uniflow/core/models/note_models.dart';
import 'package:uniflow/core/models/schedule.dart';
import 'package:uniflow/core/providers/clock_provider.dart';
import 'package:uniflow/core/services/connectivity_service.dart';
import 'package:uniflow/core/services/notification_service.dart';
import 'package:uniflow/core/services/schedule_service.dart';
import 'package:uniflow/core/services/storage_service.dart';
import 'package:uniflow/core/sources/source_api.dart';
import 'package:uniflow/core/sources/source_store.dart';

final _now = DateTime.now();

String _fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}.'
    '${d.month.toString().padLeft(2, '0')}.${d.year}';

ScheduleItem _lesson(String subject) => ScheduleItem(
      date: _fmt(_now),
      time: '10:00 - 11:30',
      subject: subject,
      type: 'Лекции',
      classroom: 'Гл.-408',
      teacher: 'Двоенко Сергей Данилович',
      groups: const [GroupInfo(number: '221341:01')],
      cssClass: 'lecture',
    );

class _FakeApi extends ScheduleApi {
  _FakeApi(this.items);

  final List<ScheduleItem> items;

  @override
  Future<SourceDateRange> dateRange(String searchValue) async => SourceDateRange(
        minDate: DateTime(2026, 9, 1),
        maxDate: DateTime(2027, 1, 25),
        searchField: SearchField.group,
      );

  @override
  Future<List<ScheduleItem>> lessons({
    required String searchField,
    required String searchValue,
  }) async =>
      items;

  @override
  Future<List<CalendarItem>> calendar(String searchValue) async => [];

  @override
  Future<List<SourceSuggestion>> search(String query) async => [];
}

class _FakeProgress implements FinalMarksApi {
  _FakeProgress({this.fail = false});

  final bool fail;

  @override
  Future<List<FinalMark>> finalMarks({
    required String studentId,
    required String group,
  }) async {
    if (fail) throw const ApiException('нет связи');
    return [
      const FinalMark(
        term: '3',
        discipline: 'Математический анализ',
        markTitle: 'отлично',
        teacherMark: '5',
      ),
    ];
  }
}

class _FakeStorage extends StorageService {

  @override
  String? getMyGroup() => '221341';

  @override
  String? getMySubgroup() => '01';

  @override
  String? getStudentId() => '12345';

  @override
  AppSettings getAppSettings() => const AppSettings();

  @override
  List<FavoriteGroup> getFavoriteGroups() => const [];

  @override
  CachedSchedule? getCachedSchedule(String searchValue) => null;

  @override
  Future<void> cacheSchedule(String searchValue, ScheduleData data) async {}

  @override
  String? getLastSearch() => null;

  @override
  Future<void> saveLastSearch(String searchValue) async {}

  @override
  Future<void> saveAppSettings(AppSettings settings) async {}

  @override
  Future<void> setNotificationsAsked() async {}

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

  @override
  List<MarksItem>? getCachedMarks({
    required String studentId,
    required String group,
  }) =>
      null;

  @override
  Future<void> cacheMarks({
    required String studentId,
    required String group,
    required List<MarksItem> marks,
  }) async {}

  @override
  bool isNotificationsAsked() => true;

  // Заметки и остальные вкладки оболочки живут в той же Hive-коробке,
  // поэтому их чтения тоже отдаём в памяти.
  @override
  Future<void> migrateFromLegacy() async {}

  @override
  List<SubjectFolder> getStudyFolders() => const [];

  @override
  Future<void> saveStudyFolders(List<SubjectFolder> folders) async {}
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

Widget _app({_FakeProgress? progress}) {
  final api = _FakeApi([_lesson('Математический анализ')]);
  return ProviderScope(
    overrides: [
      demoModeProvider.overrideWithValue(false),
      scheduleApiProvider.overrideWithValue(api),
      finalMarksApiProvider.overrideWithValue(progress ?? _FakeProgress()),
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

  testWidgets('автообновление при входе: одна плашка на расписание и оценки',
      (tester) async {
    await tester.pumpWidget(_app());
    // Первый кадр → post-frame колбэк оболочки → оба провайдера грузятся.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Расписание и оценки успешно обновлены'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('автообновление при входе: только расписание, если оценки не шли',
      (tester) async {
    await tester.pumpWidget(_app(progress: _FakeProgress(fail: true)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Расписание успешно обновлено'), findsOneWidget);
    expect(find.text('Расписание и оценки успешно обновлены'), findsNothing);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('подписка в шапке не мешает: плашка одна', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));

    // Плашка живёт в Overlay, а не в ScaffoldMessenger: снизу её
    // перекрывала навигация, поэтому проверяем сам текст и единственность.
    expect(find.text('Расписание и оценки успешно обновлены'), findsOneWidget);
    expect(find.text('Расписание успешно обновлено'), findsNothing);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
