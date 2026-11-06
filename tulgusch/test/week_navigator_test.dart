// Полоса недели: стрелки — отдельные сегменты с тактильным откликом и
// пружинным сжатием под пальцем. Тест ловит и сам вызов (навигация не
// должна теряться из-за обёртки), и отклик вибро-канала.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tulgusch/core/utils/week_utils.dart';
import 'package:tulgusch/features/schedule/widgets/week_navigator.dart';

final _week = WeekInfo(
  weekNumber: 10,
  startDate: DateTime(2026, 11, 2),
  endDate: DateTime(2026, 11, 8),
  isEven: true,
);

void main() {
  testWidgets('стрелки недели вызывают колбэки и дают тактильный отклик',
      (tester) async {
    var prev = 0;
    var next = 0;
    final haptics = <String>[];
    final messenger = TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        haptics.add('${call.arguments}');
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WeekNavigatorBar(
          weekInfo: _week,
          isCurrentWeek: true,
          onPrevWeek: () => prev++,
          onNextWeek: () => next++,
        ),
      ),
    ));

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(prev, 1);
    expect(next, 1);
    expect(haptics, isNotEmpty);
  });
}
