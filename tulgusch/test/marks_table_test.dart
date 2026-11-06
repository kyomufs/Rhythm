import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tulgusch/core/models/marks.dart';
import 'package:tulgusch/features/performance/widgets/marks_table.dart';

MarksItem _mark(
  String discipline, {
  String mark = '',
  String markTitle = '',
  String teacher = '',
  String retake = '',
  String term = '3',
}) {
  return MarksItem(
    term: term,
    discipline: discipline,
    mark: mark,
    markTitle: markTitle,
    teacherMark: teacher,
    retake: retake,
    recredit: false,
  );
}

Widget _app(List<MarksItem> items) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: Scaffold(body: MarksTable(items: items)),
  );
}

double _headerWidth(WidgetTester tester, String col) =>
    tester.getSize(find.byKey(ValueKey('marks-header-$col'))).width;

void main() {
  testWidgets('шапка и строки таблицы показывают данные', (tester) async {
    await tester.pumpWidget(_app([
      _mark('Математический анализ',
          mark: '5', markTitle: 'Отлично', teacher: 'Двоенко С. Д.'),
      _mark('Физика', mark: '4', markTitle: 'Хорошо', teacher: 'Иванов И. И.'),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Дисциплина'), findsOneWidget);
    expect(find.text('Преподаватель'), findsOneWidget);
    expect(find.text('Оценка'), findsOneWidget);
    expect(find.text('Аттестация'), findsOneWidget);
    expect(find.text('Математический анализ'), findsOneWidget);
    expect(find.text('Отл.'), findsOneWidget,
        reason: 'аттестация сокращается до аббревиатуры');
    expect(find.text('Двоенко С. Д.'), findsOneWidget);
  });

  testWidgets('пустой столбец «Пересдача» не показывается', (tester) async {
    await tester.pumpWidget(_app([_mark('Физика', mark: '4')]));
    await tester.pumpAndSettle();
    expect(find.text('Пересдача'), findsNothing);

    await tester.pumpWidget(_app([
      _mark('Физика', mark: '4', retake: 'Комиссия 12.01'),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('Пересдача'), findsOneWidget);
    expect(find.text('Комиссия 12.01'), findsOneWidget);
  });

  testWidgets('ширина столбца тянется за разделитель и сбрасывается даблом',
      (tester) async {
    await tester.pumpWidget(_app([_mark('Физика', mark: '4')]));
    await tester.pumpAndSettle();

    final before = _headerWidth(tester, 'discipline');
    final rect =
        tester.getRect(find.byKey(const ValueKey('marks-header-discipline')));
    // Захват стоит вплотную к правому краю шапки столбца.
    await tester.dragFrom(
        Offset(rect.right - 4, rect.center.dy), const Offset(60, 0));
    await tester.pumpAndSettle();

    final widened = _headerWidth(tester, 'discipline');
    expect(widened, greaterThan(before));
    expect(widened - before, closeTo(60, 1));

    final moved =
        tester.getRect(find.byKey(const ValueKey('marks-header-discipline')));
    await tester.tapAt(Offset(moved.right - 4, moved.center.dy));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(Offset(moved.right - 4, moved.center.dy));
    await tester.pumpAndSettle();
    expect(_headerWidth(tester, 'discipline'), closeTo(before, 1));
  });

  testWidgets('столбец не сжимается меньше минимума', (tester) async {
    await tester.pumpWidget(_app([_mark('Физика', mark: '4')]));
    await tester.pumpAndSettle();

    final rect =
        tester.getRect(find.byKey(const ValueKey('marks-header-discipline')));
    await tester.dragFrom(
        Offset(rect.right - 4, rect.center.dy), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(_headerWidth(tester, 'discipline'), closeTo(150, 1));
  });

  testWidgets('на узком экране таблица прокручивается по горизонтали',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app([
      _mark('Математический анализ',
          mark: '5', markTitle: 'Отлично', teacher: 'Двоенко С. Д.'),
    ]));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'таблица не должна переполнять экран');
    final before = tester.getRect(find.text('Дисциплина')).left;
    await tester.drag(
        find.text('Математический анализ'), const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Дисциплина')).left, lessThan(before));
  });

  testWidgets('масштаб меняется кнопками ± и сбрасывается', (tester) async {
    await tester.pumpWidget(_app([
      _mark('Математический анализ',
          mark: '5', markTitle: 'Отлично', teacher: 'Двоенко С. Д.'),
    ]));
    await tester.pumpAndSettle();

    String label() =>
        tester.widget<Text>(find.byKey(const ValueKey('marks-zoom-label'))).data!;

    expect(label(), '100%');
    final base = _headerWidth(tester, 'mark');

    await tester.tap(find.byTooltip('Крупнее'));
    await tester.pumpAndSettle();
    expect(label(), '115%');
    expect(_headerWidth(tester, 'mark'), greaterThan(base),
        reason: 'столбец растёт вместе с масштабом');

    await tester.tap(find.byTooltip('Мельче'));
    await tester.pumpAndSettle();
    expect(label(), '100%');

    await tester.tap(find.byTooltip('Крупнее'));
    await tester.tap(find.byTooltip('Крупнее'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Сбросить масштаб'));
    await tester.pumpAndSettle();
    expect(label(), '100%');
    expect(_headerWidth(tester, 'mark'), closeTo(base, 0.5));
  });
}
