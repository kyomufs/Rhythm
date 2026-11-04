import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniflow/shared/widgets/app_segmented_selector.dart';

void main() {
  /// Левая граница индикатора выбора в координатах экрана.
  double indicatorLeft(WidgetTester tester) {
    final box = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('segment-indicator')),
    );
    return box.localToGlobal(Offset.zero).dx;
  }

  Widget host({
    required int selected,
    required ValueChanged<int> onSelected,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppSegmentedSelector<int>(
              values: const [0, 15, 30, 60, 180],
              selected: selected,
              labelOf: (v) => '$v',
              onSelected: onSelected,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('индикатор едет к выбранному сегменту, не заскакивая в начало',
      (tester) async {
    var selected = 30;
    await tester.pumpWidget(host(
      selected: selected,
      onSelected: (value) => selected = value,
    ));
    await tester.pumpAndSettle();

    final start = indicatorLeft(tester);

    // Пользователь нажал «180» — третий по счёту с конца сегмент.
    await tester.tap(find.text('180'));
    await tester.pumpWidget(host(
      selected: 180,
      onSelected: (value) => selected = value,
    ));

    var previous = start;
    for (var frame = 0; frame < 40; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      final left = indicatorLeft(tester);
      // Ни одна промежуточная позиция не может оказаться левее старта:
      // старая пружина стартовала из нуля и давала рывок в начало шкалы.
      expect(left, greaterThanOrEqualTo(previous - 0.01),
          reason: 'кадр $frame: индикатор поехал назад');
      previous = left;
      if ((left - previous).abs() < 0.001 && frame > 2) break;
    }

    // Пружина перелетает цель и возвращается — конечная позиция у сегмента.
    await tester.pumpAndSettle();
    final selector = tester.getRect(find.byType(AppSegmentedSelector<int>));
    final slotWidth = selector.width / 5;
    expect(indicatorLeft(tester), closeTo(selector.left + 4 * slotWidth, 0.5));
  });
}
