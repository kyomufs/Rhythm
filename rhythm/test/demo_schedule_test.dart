import 'package:flutter_test/flutter_test.dart';
import 'package:rhythm/core/demo/demo_schedule.dart';

/// Фиксированное время внутри второй пары (10:00–11:30) — тесты на
/// «идущую сейчас» пару не должны зависеть от момента запуска.
final _insidePair = DateTime(2026, 11, 4, 10, 15);
final _outsidePair = DateTime(2026, 11, 4, 3, 0);

void main() {
  final now = DateTime.now();

  test('demo schedule spans three weeks around today', () {
    final items = buildDemoSchedule(now);
    expect(items, isNotEmpty);

    final dates = items
        .map((i) {
          try {
            return i.parsedDate;
          } catch (_) {
            return null;
          }
        })
        .whereType<DateTime>()
        .toList();
    expect(dates, isNotEmpty);

    final min = dates.reduce((a, b) => a.isBefore(b) ? a : b);
    final max = dates.reduce((a, b) => a.isAfter(b) ? a : b);
    expect(
      now.subtract(const Duration(days: 7)).isBefore(max),
      isTrue,
      reason: 'current week must be covered',
    );
    expect(
      now.add(const Duration(days: 7)).isAfter(min),
      isTrue,
      reason: 'current week must be covered',
    );
  });

  test('demo adds the running pair when one is on the bell grid', () {
    final items = buildDemoSchedule(_insidePair);
    expect(
      items.any((i) => i.isOngoingAt(_insidePair)),
      isTrue,
      reason: 'the countdown gimmick needs a live lesson',
    );
    expect(currentDemoSlot(_insidePair), '10:00 - 11:30');
  });

  test('no invented pair outside the bell grid', () {
    expect(currentDemoSlot(_outsidePair), isNull);
    final items = buildDemoSchedule(_outsidePair);
    expect(items.any((i) => i.isOngoingAt(_outsidePair)), isFalse);
  });

  test('demo time ranges are parseable and follow the TulSU grid', () {
    final items = buildDemoSchedule(_insidePair);
    for (final item in items) {
      expect(item.startsAt, isNotNull, reason: 'unparseable "${item.time}"');
      expect(
        demoSlots,
        contains(item.time),
        reason: '"${item.time}" is not a TulSU pair',
      );
      expect(item.endsAt!.isAfter(item.startsAt!), isTrue);
    }
  });

  test('demo rows all belong to the fake demo group', () {
    final items = buildDemoSchedule(now);
    for (final item in items) {
      expect(item.groups.single.number, demoGroup);
    }
    expect(
      demoGroup,
      contains('демо'),
      reason: 'фейковые данные обязаны быть помечены в номере группы',
    );
  });

  test('demo data carries no joke text or emoji', () {
    final items = buildDemoSchedule(now);
    const banned = ['навсегда', 'снова', 'шанс', 'заказывали', 'отменили'];
    for (final item in items) {
      final text = '${item.subject} ${item.type} ${item.teacher}'.toLowerCase();
      for (final word in banned) {
        expect(text.contains(word), isFalse, reason: '$word found in $text');
      }
      expect(
        item.subject.runes.any((r) => r > 0x2100),
        isFalse,
        reason: 'no emoji / symbols in "${item.subject}"',
      );
    }
  });
}
