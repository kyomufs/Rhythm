import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tulgusch/core/models/schedule.dart';
import 'package:tulgusch/core/providers/clock_provider.dart';
import 'package:tulgusch/features/schedule/widgets/lesson_tile.dart';

/// Clock pinned to a fixed instant, so the rendered countdown text is
/// predictable instead of depending on the wall clock.
class _FrozenClock extends ClockNotifier {
  _FrozenClock(DateTime now) {
    state = now;
  }
}

ScheduleItem _item({
  String date = '02.11.2026',
  String time = '08:00 - 09:30',
}) =>
    ScheduleItem(
      date: date,
      time: time,
      subject: 'Матанализ',
      type: 'Лекции',
      classroom: '101',
      teacher: 'Иванов Иван',
      groups: const [],
      cssClass: 'lecture',
    );

void main() {
  group('timeUntilStartAt', () {
    test('returns the exact remainder, seconds included', () {
      final item = _item();
      expect(
        item.timeUntilStartAt(DateTime(2026, 11, 2, 7, 12, 26)),
        const Duration(minutes: 47, seconds: 34),
      );
    });

    test('is zero once the lesson has started', () {
      final item = _item();
      expect(
        item.timeUntilStartAt(DateTime(2026, 11, 2, 8, 0, 1)),
        Duration.zero,
      );
    });

    test('is zero when the time range cannot be parsed', () {
      final item = _item(time: 'по договорённости');
      expect(
        item.timeUntilStartAt(DateTime(2026, 11, 2, 7, 12)),
        Duration.zero,
      );
    });
  });

  group('timeLeftAt', () {
    test('returns the exact remainder, seconds included', () {
      final item = _item();
      expect(
        item.timeLeftAt(DateTime(2026, 11, 2, 9, 12, 26)),
        const Duration(minutes: 17, seconds: 34),
      );
    });

    test('is zero after the lesson ends', () {
      final item = _item();
      expect(
        item.timeLeftAt(DateTime(2026, 11, 2, 9, 30)),
        Duration.zero,
      );
    });
  });

  group('isOngoingAt', () {
    final item = _item();

    test('is false one second before the start', () {
      expect(item.isOngoingAt(DateTime(2026, 11, 2, 7, 59, 59)), isFalse);
    });

    test('is true exactly at the start', () {
      expect(item.isOngoingAt(DateTime(2026, 11, 2, 8, 0)), isTrue);
    });

    test('is false exactly at the end', () {
      expect(item.isOngoingAt(DateTime(2026, 11, 2, 9, 30)), isFalse);
    });
  });

  group('formatCountdown', () {
    test('shows only seconds under a minute', () {
      expect(formatCountdown(const Duration(seconds: 34)), '34 с');
    });

    test('shows minutes and seconds', () {
      expect(formatCountdown(const Duration(minutes: 12, seconds: 34)),
          '12 мин 34 с');
    });

    test('pads minutes and seconds once hours appear', () {
      expect(
        formatCountdown(const Duration(hours: 1, minutes: 5, seconds: 9)),
        '1 ч 05 мин 09 с',
      );
    });

    test('never goes negative', () {
      expect(formatCountdown(const Duration(seconds: -5)), '0 с');
      expect(formatCountdown(Duration.zero), '0 с');
    });
  });

  group('LessonTile countdown', () {
    Future<void> pumpTile(WidgetTester tester, DateTime now) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clockProvider.overrideWith((ref) => _FrozenClock(now)),
          ],
          child: MaterialApp(
            home: Scaffold(body: LessonTile(item: _item())),
          ),
        ),
      );
    }

    testWidgets('shows exact time until the start', (tester) async {
      await pumpTile(tester, DateTime(2026, 11, 2, 7, 12, 26));
      // Компактная пилюля в строке времени: минуты:секунды без слов.
      expect(find.text('47:34'), findsOneWidget);
      // Unmount to dispose the clock and its pending tick timer.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('shows exact time until the end', (tester) async {
      await pumpTile(tester, DateTime(2026, 11, 2, 9, 12, 26));
      expect(find.text('До конца пары — 17 мин 34 с'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
