// Подсказки полей профиля: группа и группа для оценок принимают индекс
// подгруппы, зачётка — просто номер. Плейсхолдеры не должны путать форматы,
// поэтому фиксируем их текстом.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tulgusch/features/profile/widgets/tulgu_profile_form.dart';

Widget _form() => const MaterialApp(
      home: Scaffold(body: TulguProfileForm()),
    );

void main() {
  testWidgets('подсказки пустых полей профиля', (tester) async {
    await tester.pumpWidget(_form());

    expect(find.text('121212:00'), findsOneWidget);
    expect(find.text('343434'), findsOneWidget);

    await tester.tap(find.text('Отдельная группа для оценок'));
    await tester.pumpAndSettle();

    // Поле группы для оценок повторяет формат группы расписания.
    expect(find.text('121212:00'), findsNWidgets(2));
  });
}
