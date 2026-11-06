// Клавиатура на страницах онбординга: тело страницы должно прокручиваться,
// а не ломаться полосой переполнения над нижней кнопкой.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniflow/features/profile/screens/onboarding_screen.dart';

Widget _app() => const ProviderScope(
      child: MaterialApp(home: OnboardingScreen()),
    );

void main() {
  testWidgets('страницы ввода переживают поднятую клавиатуру', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Клавиатура занимает больше половины экрана — худший реальный случай
    // для страницы с заголовком, подсказкой и полем ввода.
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    // Три страницы с полями: группа, подгруппа, зачётка.
    for (var page = 0; page < 3; page++) {
      await tester.tap(find.text('Далее'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'страница ${page + 1} не должна переполняться');
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Далее'), findsOneWidget,
          reason: 'нижняя кнопка остаётся доступной');
    }
  });
}
