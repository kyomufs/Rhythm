import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tulgusch/core/services/update_coordinator.dart';
import 'package:tulgusch/core/widgets/update_feedback.dart';

void main() {
  group('тексты уведомлений об обновлении', () {
    test('одно обновлённое — своя формулировка', () {
      expect(
        updateSuccessText(schedule: true, marks: false),
        'Расписание успешно обновлено',
      );
      expect(
        updateSuccessText(schedule: false, marks: true),
        'Оценки успешно обновлены',
      );
    });

    test('оба сразу — одна общая формулировка', () {
      expect(
        updateSuccessText(schedule: true, marks: true),
        'Расписание и оценки успешно обновлены',
      );
    });
  });

  group('плашка', () {
    Widget host(void Function(BuildContext) onPressed) {
      return MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => onPressed(context),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('успех показывается текстом и галочкой', (tester) async {
      await tester.pumpWidget(host((context) {
        showUpdateSuccessNotification(context, schedule: true, marks: true);
      }));
      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Расписание и оценки успешно обновлены'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      // Дать плашке уйти, чтобы не осталось висящего таймера.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });

    testWidgets('результат обновления показывается как есть', (tester) async {
      await tester.pumpWidget(host((context) {
        showUpdateFeedback(
          context,
          const UpdateResult(UpdateOutcome.updated, marksUpdatedText),
        );
      }));
      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Оценки успешно обновлены'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });

    testWidgets('плашка живёт в Overlay, а не в SnackBar', (tester) async {
      await tester.pumpWidget(host((context) {
        showUpdateSuccessNotification(context, schedule: true, marks: false);
      }));
      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Нижнюю полосу перекрывает навигация — поэтому плашка обязана быть
      // вне Scaffold, иначе её снова не будет видно.
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Расписание успешно обновлено'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });

    testWidgets('офлайн молчит', (tester) async {
      await tester.pumpWidget(host((context) {
        showUpdateFeedback(context, UpdateResult.unavailable);
        showUpdateSuccessNotification(context, schedule: false, marks: false);
      }));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
