import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniflow/core/input/desktop_input.dart';

Widget _harness(Widget child, ScrollController controller) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 240,
          height: 64,
          child: child,
        ),
      ),
    ),
  );
}

Widget _strip(ScrollController controller) {
  return ListView.builder(
    controller: controller,
    scrollDirection: Axis.horizontal,
    itemCount: 40,
    itemBuilder: (_, index) => SizedBox(
      width: 60,
      child: Center(child: Text('$index')),
    ),
  );
}

void main() {
  testWidgets('вертикальное колесо листает горизонтальную ленту',
      (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_harness(
      WheelScroll(controller: controller, child: _strip(controller)),
      controller,
    ));
    expect(controller.offset, 0);
    final center = tester.getCenter(find.byType(ListView));
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(center));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 120)));
    await tester.pump();
    expect(controller.offset, greaterThan(0));
  });

  testWidgets('ЛКМ-драг тянет ленту в обратную сторону жеста', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_harness(
      DragPan(controller: controller, child: _strip(controller)),
      controller,
    ));
    await tester.drag(find.byType(ListView), const Offset(-120, 0));
    await tester.pump();
    expect(controller.offset, greaterThan(0));
  });

  testWidgets('hover подсвечивает карточку и возвращает курсор',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: HoverRegion(
            onTap: () => taps++,
            child:
                const SizedBox(width: 120, height: 48, child: Text('Карточка')),
          ),
        ),
      ),
    ));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.text('Карточка')));
    await tester.pump();
    expect(
      tester
          .widget<MouseRegion>(find.descendant(
            of: find.byType(HoverRegion),
            matching: find.byType(MouseRegion),
          ))
          .cursor,
      SystemMouseCursors.click,
    );
    await tester.tap(find.text('Карточка'));
    expect(taps, 1);
  });
}
