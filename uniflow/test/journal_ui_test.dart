import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:uniflow/core/domain/journal.dart';
import 'package:uniflow/core/domain/source.dart';
import 'package:uniflow/core/models/schedule.dart';
import 'package:uniflow/core/services/storage_service.dart';
import 'package:uniflow/features/journal/screens/journal_screen.dart';
import 'package:uniflow/features/journal/widgets/score_scroller.dart';

final _term = Term(
  id: 't1',
  sourceId: 's1',
  title: 'Осенний семестр',
  start: DateTime(2026, 9, 1),
  end: DateTime(2026, 12, 31),
);

Course _course() {
  final scale = defaultGradeScale();
  return Course(
    id: 'c1',
    termId: 't1',
    title: 'Математика',
    teacher: 'Иванов',
    scale: scale,
  );
}

class _FakeStorage extends StorageService {
  _FakeStorage(this.data);

  final JournalData data;

  @override
  bool get isInitialized => true;

  @override
  List<Source> getSources() => [
        Source(
          id: 's1',
          kind: SourceKind.university,
          title: 'ТулГУ',
          subtitle: '221341',
          providerId: 'tulsu',
          createdAt: DateTime(2026, 9, 1),
        ),
      ];

  @override
  String? getActiveSourceId() => 's1';

  @override
  JournalData getJournal(String sourceId) => data;

  @override
  Future<void> saveJournal(String sourceId, JournalData data) async {}

  @override
  String? getMyGroup() => '221341';

  @override
  String? getFullAcademicGroup() => '221341:01';
}

Widget _app(JournalData data) {
  return ProviderScope(
    overrides: [
      storageServiceProvider.overrideWithValue(_FakeStorage(data)),
    ],
    child: const MaterialApp(
      locale: Locale('ru'),
      supportedLocales: [Locale('ru')],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: JournalScreen(),
    ),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru');
  });

  testWidgets('журнал показывает дисциплину и накопленные баллы',
      (tester) async {
    final course = _course();
    final practiceId = course.scale.categories.first.id;
    await tester.pumpWidget(_app(JournalData(
      terms: [_term],
      courses: [course],
      records: [
        LessonRecord(
          id: 'l1',
          courseId: 'c1',
          date: DateTime(2026, 9, 10),
          slot: 2,
          type: LessonType.practice,
          points: 23,
        ),
      ],
      assessments: [
        Assessment(
          id: 'a1',
          courseId: 'c1',
          categoryId: practiceId,
          title: 'Контрольная',
          maxPoints: 10,
          dueDate: DateTime(2026, 12, 20),
        ),
      ],
    )));
    await tester.pumpAndSettle();

    expect(find.text('Математика'), findsOneWidget);
    expect(find.text('23/60 в семестре'), findsOneWidget);
    expect(find.text('1/1 пар'), findsOneWidget);
    expect(find.text('1 просрочено'), findsNothing);
    expect(find.text('Осенний семестр'), findsOneWidget);
  });

  testWidgets('пустой журнал предлагает начать семестр', (tester) async {
    await tester.pumpWidget(_app(const JournalData()));
    await tester.pumpAndSettle();

    expect(find.text('Пока нет дисциплин'), findsOneWidget);
    expect(find.text('Начать семестр'), findsOneWidget);
  });

  testWidgets('скроллер балла отдаёт выбранное значение', (tester) async {
    int? value;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => ScoreScroller(
            max: 10,
            value: value ?? 3,
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('7'));
    await tester.pump();
    expect(value, 7);

    await tester.tap(find.byTooltip("Плюс один"));
    await tester.pump();
    expect(value, 8);

    await tester.tap(find.text('Сбросить'));
    await tester.pump();
    expect(value, isNull);
  });
}
