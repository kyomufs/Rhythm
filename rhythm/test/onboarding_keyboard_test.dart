// Онбординг — один экран с формой группы. Проверяем, что поднятая клавиатура
// не выдавливает кнопку и что поле группы остаётся доступным.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tulgusch/features/profile/screens/onboarding_screen.dart';

Widget _app() => const ProviderScope(
      child: MaterialApp(home: OnboardingScreen()),
    );

void main() {
  testWidgets('форма группы не ломается поднятой клавиатурой', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Поля видны сразу: ни выбора вуза, ни промежуточных страниц.
    expect(find.text('Ваша группа'), findsOneWidget);
    expect(find.text('Группа'), findsOneWidget);
    expect(find.text('Подгруппа'), findsOneWidget);
    expect(find.text('Номер зачётки'), findsOneWidget);
    // Курсор сразу в поле группы: первый запуск начинается с ввода.
    final groupField = tester.widget<TextField>(find.byType(TextField).first);
    expect(groupField.autofocus, isTrue);

    // Клавиатура занимает больше половины экрана — худший реальный случай.
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    expect(find.text('Открыть расписание'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '221341');
    await tester.pumpAndSettle();

    expect(find.text('221341'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
