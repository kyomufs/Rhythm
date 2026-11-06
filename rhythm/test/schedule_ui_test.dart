import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rhythm/core/domain/source.dart';
import 'package:rhythm/core/models/schedule.dart';
import 'package:rhythm/core/sources/source_api.dart';
import 'package:rhythm/core/sources/source_store.dart';
import 'package:rhythm/core/providers/clock_provider.dart';
import 'package:rhythm/core/services/connectivity_service.dart';
import 'package:rhythm/core/services/notification_service.dart';
import 'package:rhythm/core/services/schedule_service.dart';
import 'package:rhythm/core/services/storage_service.dart';
import 'package:rhythm/features/schedule/screens/schedule_screen.dart';
import 'package:rhythm/features/schedule/widgets/lesson_detail_sheet.dart';
import 'package:rhythm/features/schedule/widgets/lesson_tile.dart';

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

class _FakeApi extends ScheduleApi {
  _FakeApi(this.items, {this.auditoriumItems});

  final List<ScheduleItem> items;

  /// Ответ на запрос по аудитории: так проверяется добор групп пары.
  final List<ScheduleItem>? auditoriumItems;

  /// Сколько раз спросили расписание аудитории (прогрев групп пары).
  int auditoriumCalls = 0;

  @override
  Future<SourceDateRange> dateRange(String searchValue) async =>
      SourceDateRange(
        minDate: DateTime(2026, 9, 1),
        maxDate: DateTime(2027, 1, 25),
        searchField: SearchField.group,
      );

  @override
  Future<List<ScheduleItem>> lessons({
    required String searchField,
    required String searchValue,
  }) async {
    if (searchField == SearchField.auditorium.value) {
      auditoriumCalls++;
      return auditoriumItems ?? items;
    }
    return items;
  }

  @override
  Future<List<CalendarItem>> calendar(String searchValue) async => [];

  @override
  Future<List<SourceSuggestion>> search(String query) async => [];
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
  CachedSchedule? getCachedSchedule(String searchValue,
          {String namespace = ''}) =>
      null;

  @override
  Future<void> cacheSchedule(String searchValue, ScheduleData data,
      {String namespace = ''}) async {}

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

// ── Harness ────────────────────────────────────────────────────

/// Тесты идут на реальной текущей дате: расписание показывает именно
/// текущую неделю, и подменять часы ради фикстуры незачем.
final _now = DateTime.now();

String _fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}.'
    '${d.month.toString().padLeft(2, '0')}.${d.year}';

/// Источник, от лица которого идёт тест: экран берёт группу и возможности
/// из него, а не из глобального хранилища.
Source _source(String group) => Source(
      id: 'tulsu',
      kind: SourceKind.university,
      title: 'ТулГУ',
      providerId: 'tulsu',
      config: {'group': group, 'subgroup': '01'},
      createdAt: DateTime(2026, 9, 1),
    );

Widget _app({
  required List<ScheduleItem> items,
  List<ScheduleItem>? auditoriumItems,
  _FakeStorage? storage,
  _FakeApi? api,
}) {
  final client = api ?? _FakeApi(items, auditoriumItems: auditoriumItems);
  return ProviderScope(
    overrides: [
      demoModeProvider.overrideWithValue(false),
      activeSourceProvider.overrideWithValue(_source(_group)),
      scheduleApiProvider.overrideWithValue(client),
      scheduleServiceProvider.overrideWithValue(
        ScheduleService(
          api: client,
          storage: _FakeStorage(),
        ),
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
            (w.image as AssetImage).assetName.contains('tulsu_shield.png'),
      ),
      findsOneWidget,
      reason: 'глиф-щит стоит перед номером группы',
    );
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
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

    await tester.tap(find.byIcon(Icons.star_rounded));
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
    expect(
        tester.widget<Text>(find.textContaining('Неделя')).data, isNot(before),
        reason: 'стрелка переключает неделю');
  });

  testWidgets('в шапке карточки дня только день недели, без даты',
      (tester) async {
    await tester.pumpWidget(_app(items: [
      _item(subject: 'Математический анализ', date: _now),
    ]));
    await tester.pumpAndSettle();

    final dayName = DateFormat.EEEE('ru').format(_now);
    final capital = dayName[0].toUpperCase() + dayName.substring(1);
    final dateStr = DateFormat('d MMMM', 'ru').format(_now);

    expect(find.text(capital), findsOneWidget,
        reason: 'день недели остаётся в шапке');
    expect(find.textContaining(dateStr), findsNothing,
        reason:
            'число уже стоит в квадратике слева — словами его не повторяем');
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
    expect(find.byKey(const ValueKey('lesson-group-$_group')), findsNothing,
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

    expect(find.byKey(const ValueKey('lesson-group-221341и')), findsOneWidget,
        reason: 'чужие группы в паре видны');
    expect(find.byKey(const ValueKey('lesson-group-$_group')), findsOneWidget);
  });

  testWidgets(
      'в карточке время и аудитория — плитки в ряд, препод и группы ниже',
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

    // Факты разложены плитками: время и аудитория делят строку, широкие
    // поля (преподаватель, группы) идут во всю ширину под ними.
    final time = tester.getTopLeft(find.text('ВРЕМЯ'));
    final room = tester.getTopLeft(find.text('АУДИТОРИЯ'));
    final teacher = tester.getTopLeft(find.text('ПРЕПОДАВАТЕЛЬ'));
    final groups = tester.getTopLeft(find.text('ГРУППЫ'));

    expect(room.dy, time.dy, reason: 'время и аудитория стоят в одной строке');
    expect(room.dx, greaterThan(time.dx));
    expect(teacher.dy, greaterThan(time.dy));
    expect(teacher.dx, lessThan(room.dx));
    expect(groups.dy, greaterThan(teacher.dy));
  });

  testWidgets('группы пары прогреваются сразу после загрузки расписания',
      (tester) async {
    final lesson = _item(subject: 'Математический анализ', date: _now);
    final api = _FakeApi(
      [lesson],
      auditoriumItems: [
        _item(
          subject: 'Математический анализ',
          date: _now,
          groups: const [
            GroupInfo(number: _group),
            GroupInfo(number: '221341и'),
          ],
        ),
      ],
    );

    await tester.pumpWidget(_app(items: [lesson], api: api));
    await tester.pumpAndSettle();

    expect(api.auditoriumCalls, greaterThan(0),
        reason: 'группы пары тянутся заранее, до открытия карточки');

    // Карточка открывается с уже готовыми группами: одного кадра хватает,
    // чипы не должны «доезжать» после появления листа.
    await tester.tap(find.byType(LessonTile).first);
    await tester.pump();
    expect(find.byKey(const ValueKey('lesson-group-221341и')), findsOneWidget);
  });

  testWidgets('группы пары добираются из расписания аудитории', (tester) async {
    // Основной запрос по группе отдаёт GROUPS только со своей группой —
    // полный список приходит из запроса по аудитории той же пары.
    final lesson = _item(subject: 'Математический анализ', date: _now);
    await tester.pumpWidget(_app(
      items: [lesson],
      auditoriumItems: [
        _item(
          subject: 'Математический анализ',
          date: _now,
          groups: const [
            GroupInfo(number: _group),
            GroupInfo(number: '221341и'),
            GroupInfo(number: '220431'),
          ],
        ),
      ],
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(LessonTile).first);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('lesson-group-221341и')), findsOneWidget,
        reason: 'группа из расписания аудитории попала в карточку');
    expect(find.byKey(const ValueKey('lesson-group-220431')), findsOneWidget);
    expect(find.byKey(const ValueKey('lesson-group-$_group')), findsOneWidget,
        reason: 'своя группа тоже видна и стоит первой');
  });

  testWidgets('много групп прокручиваются внутри карточки', (tester) async {
    // Поток на два десятка групп: чипы обязаны переноситься и прокручиваться,
    // а не обрезаться нижней кромкой шторки.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 520);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final groups = <GroupInfo>[
      const GroupInfo(number: _group),
      for (var i = 1; i <= 24; i++) GroupInfo(number: '2204$i'),
    ];
    await tester.pumpWidget(_app(items: [
      _item(subject: 'Математический анализ', date: _now, groups: groups),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(LessonTile).first);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'переполнения нет: содержимое живёт в прокрутке');
    final scroller = find.descendant(
      of: find.byType(LessonDetailSheet),
      matching: find.byType(SingleChildScrollView),
    );
    expect(scroller, findsOneWidget);

    final last = find.byKey(const ValueKey('lesson-group-220424'));
    expect(find.byKey(const ValueKey('lesson-group-220424')).hitTestable(),
        findsNothing,
        reason: 'последняя группа ниже сгиба, пока лист не прокрутили');

    await tester.drag(scroller, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(last.hitTestable(), findsOneWidget,
        reason: 'до последней группы можно доскроллить');
  });

  group('шапка на узком экране', () {
    Future<void> pumpAt(WidgetTester tester, double width) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_app(items: [
        _item(subject: 'Математический анализ', date: _now),
      ]));
      await tester.pumpAndSettle();
    }

    testWidgets('шире 360dp действия стоят иконками', (tester) async {
      await pumpAt(tester, 420);

      expect(find.byType(PopupMenuButton<Object?>), findsNothing);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byIcon(Icons.difference_outlined), findsOneWidget);
      expect(find.text(_group), findsOneWidget);
    });

    testWidgets('уже 360dp действия уходят в меню, заголовок не обрезан',
        (tester) async {
      await pumpAt(tester, 320);

      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsNothing);
      expect(find.byIcon(Icons.search), findsNothing);
      // Переполнение ряда — тоже провал теста: билдинг ловит его сам.

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Изменения'), findsOneWidget);
      expect(find.text('Обновить'), findsOneWidget);
      expect(find.text('Поиск'), findsOneWidget);
    });
  });

  testWidgets('кнопка обновления сначала спрашивает подтверждение',
      (tester) async {
    await tester.pumpWidget(_app(items: [
      _item(subject: 'Математический анализ', date: _now),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    expect(find.text('Обновить расписание?'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Обновить'), findsOneWidget);

    // Отмена закрывает диалог и не запускает запрос.
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(find.text('Обновить расписание?'), findsNothing);
  });
}
