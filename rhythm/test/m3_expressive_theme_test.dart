import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rhythm/core/theme/motion.dart';
import 'package:rhythm/core/theme/shapes.dart';
import 'package:rhythm/core/theme/theme_provider.dart';
import 'package:rhythm/shared/widgets/app_nav_bar.dart';
import 'package:rhythm/shared/widgets/empty_state.dart';
import 'package:rhythm/shared/widgets/expressive_loading_indicator.dart';

/// Проверки геометрии и моушена на уровне виджетов: то, что нельзя увидеть в
/// `flutter analyze`, но что ломается при правке темы.
final testTheme = buildAppTheme(
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
  brightness: Brightness.light,
);

void main() {
  Widget host(Widget child, {bool reduceMotion = false, double textScale = 1}) {
    return MaterialApp(
      theme: testTheme,
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 720),
          disableAnimations: reduceMotion,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(body: child),
      ),
    );
  }

  group('нижняя панель', () {
    const destinations = [
      AppNavDestination(
        icon: Icons.calendar_today_outlined,
        selectedIcon: Icons.calendar_today,
        label: 'Расписание',
      ),
      AppNavDestination(
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        label: 'Профиль',
      ),
    ];

    testWidgets('высота контента 64dp и индикатор 56×32dp', (tester) async {
      await tester.pumpWidget(host(
        AppNavBar(
          destinations: destinations,
          selectedIndex: 0,
          onSelected: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      final content = tester.getSize(find
          .ancestor(
            of: find.byIcon(Icons.calendar_today),
            matching: find.byType(Row),
          )
          .first);
      expect(content.height, 64);

      // Индикатор — Material со StadiumBorder, а не Container: важно, что
      // при выбранном пункте он занимает ровно 56×32, а не как он нарисован.
      final indicator =
          tester.getSize(find.byKey(const ValueKey('nav-indicator-Расписание')));
      expect(indicator.width, closeTo(56, 0.5));
      expect(indicator.height, 32);
    });

    testWidgets('тап по иконке и по подписи переключает пункт', (tester) async {
      final tapped = <int>[];
      await tester.pumpWidget(host(
        AppNavBar(
          destinations: destinations,
          selectedIndex: 0,
          onSelected: tapped.add,
        ),
      ));
      await tester.pumpAndSettle();

      // Иконка лежит внутри овала с InkWell: раньше пустой колбэк внутри
      // InkWell забирал тап, и пункт только подсвечивался.
      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle();
      expect(tapped, [1]);

      // Подпись вне овала — её ловит внешний жест всей ячейки.
      await tester.tap(find.text('Расписание'));
      await tester.pumpAndSettle();
      expect(tapped, [1, 0]);
    });
  });

  group('тема', () {
    testWidgets('кнопки 40dp с морфом формы при нажатии', (tester) async {
      final style = testTheme.filledButtonTheme.style!;
      expect(style.minimumSize!.resolve({})!.height, 40);

      final restShape = style.shape!.resolve({})! as StadiumBorder;
      expect(restShape, isA<StadiumBorder>());

      final pressed = style.shape!.resolve({WidgetState.pressed})!
          as RoundedRectangleBorder;
      expect(pressed.borderRadius, AppShapes.pressedButtonRadius);
    });

    test('карточка — CornerMedium, FAB — CornerLarge', () {
      final card = testTheme.cardTheme.shape! as RoundedRectangleBorder;
      expect(card.borderRadius, AppShapes.cardRadius);
      expect(AppShapes.cardRadius, AppShapes.circular(12));

      final fab = testTheme.floatingActionButtonTheme.shape!
          as RoundedRectangleBorder;
      expect(fab.borderRadius, AppShapes.circular(16));
    });
  });

  group('пружины', () {
    testWidgets('при disableAnimations схема становится standard', (tester) async {
      late MotionScheme scheme;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          scheme = MotionScheme.of(context);
          return const SizedBox();
        }),
      ));
      expect(scheme.slowSpatial.stiffness, MotionTokens.slowSpatial.stiffness);

      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(builder: (context) {
            scheme = MotionScheme.of(context);
            return const SizedBox();
          }),
        ),
      ));
      expect(
        scheme.slowSpatial.stiffness,
        MotionTokens.standardSlowSpatial.stiffness,
      );
    });

    test('длительность из пружины короче трёх секунд', () {
      final expressive = springDuration(MotionTokens.slowSpatial);
      final standard = springDuration(MotionTokens.standardSlowSpatial);
      expect(expressive.inMilliseconds, greaterThan(0));
      expect(expressive.inMilliseconds, lessThan(3000));
      expect(standard.inMilliseconds, lessThan(expressive.inMilliseconds));
    });
  });

  group('фигуры индикатора', () {
    test('семь фигур, по 64 точки, вписанных в 0..1', () {
      expect(ExpressiveShapes.sequence, hasLength(7));
      for (final shape in ExpressiveShapes.sequence) {
        expect(shape, hasLength(ExpressiveShapes.samples));
        for (final p in shape) {
          expect(p.dx, inInclusiveRange(-0.0001, 1.0001));
          expect(p.dy, inInclusiveRange(-0.0001, 1.0001));
        }
      }
    });

    test('соседние фигуры различаются', () {
      final a = ExpressiveShapes.sequence[0];
      final b = ExpressiveShapes.sequence[1];
      final diff = <double>[
        for (var i = 0; i < a.length; i++) (a[i] - b[i]).distance,
      ].reduce((x, y) => x + y);
      expect(diff, greaterThan(1));
    });
  });

  group('индикатор загрузки', () {
    testWidgets('морфит фигуры и вращается', (tester) async {
      await tester.pumpWidget(host(const ExpressiveLoadingIndicator()));
      expect(find.byType(CustomPaint), findsWidgets);

      // Полный цикл морфа — 650 мс; после него фигура меняется.
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.takeException(), isNull);

      // Контроллеры живые: тест не должен завершиться с таймерами.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('при reduce-motion рисует одну статичную фигуру',
        (tester) async {
      await tester.pumpWidget(
        host(const ExpressiveLoadingIndicator(), reduceMotion: true),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  group('текст в масштабе 2.0', () {
    testWidgets('пустое состояние не переполняется', (tester) async {
      await tester.pumpWidget(host(
        EmptyState(
          icon: Icons.school_outlined,
          title: 'Выберите группу',
          message: 'Укажите номер группы\nв разделе «Профиль» → «Настройки»',
          action: FilledButton(
            onPressed: () {},
            child: const Text('Открыть профиль'),
          ),
        ),
        textScale: 2,
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
