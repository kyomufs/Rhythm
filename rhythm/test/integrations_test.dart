import 'package:flutter_test/flutter_test.dart';
import 'package:rhythm/core/models/schedule.dart';
import 'package:rhythm/integrations/api/bmstu/week_grid.dart';
import 'package:rhythm/integrations/contract/schedule_document.dart';

void main() {
  group('канонический документ', () {
    ScheduleDocument document() => ScheduleDocument(
          sourceId: 'bmstu-1',
          sourceTitle: 'МГТУ им. Баумана',
          targetField: 'groupId',
          targetValue: 'bad351b6',
          rangeFrom: DateTime(2026, 9, 1),
          rangeTo: DateTime(2027, 1, 5),
          lessons: [
            const ScheduleItem(
              date: '07.11.2026',
              time: '10:40 - 12:10',
              subject: 'Программирование',
              type: 'Лекция',
              classroom: '221х',
              teacher: 'Ломовской И. В.',
              groups: [GroupInfo(number: 'ИУ7-31Б')],
              cssClass: 'lecture',
            ),
          ],
          events: [
            CalendarItem(
              beginDate: DateTime(2026, 12, 31),
              endDate: DateTime(2027, 1, 8),
              type: 'Каникулы',
            ),
          ],
          fetchedAt: DateTime(2026, 11, 6, 12),
        );

    test('переживает круговорот и сохраняет поля', () {
      final restored = ScheduleDocument.fromJson(document().toJson());
      expect(restored.targetValue, 'bad351b6');
      expect(restored.lessons.single.subject, 'Программирование');
      expect(restored.lessons.single.time, '10:40 - 12:10');
      expect(restored.lessons.single.parsedDate, DateTime(2026, 11, 7));
      expect(restored.events.single.type, 'Каникулы');
      expect(restored.toSourceSchedule().lessons, hasLength(1));
    });

    test('чужую версию схемы отвергает', () {
      final json = document().toJson()..['schemaVersion'] = 99;
      expect(
        () => ScheduleDocument.fromJson(json),
        throwsA(isA<ScheduleDocumentException>()),
      );
    });
  });

  group('сетка BMSTU', () {
    test('чётность: ch — числитель, zn — знаменатель', () {
      expect(parseWeekParity('ch'), WeekParity.odd);
      expect(parseWeekParity('zn'), WeekParity.even);
      expect(parseWeekParity('all'), WeekParity.all);
    });

    test('номер недели считается от начала семестра', () {
      // Проверено на /schedules/current: 06.11.2026 — 10-я неделя.
      expect(weekIndex(DateTime(2026, 11, 6), DateTime(2026, 9, 1)), 10);
    });

    test('даты раскладываются по чётности', () {
      final all = datesForWeekday(
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 21),
        weekday: DateTime.monday,
        parity: WeekParity.all,
        semesterStart: DateTime(2026, 9, 1),
      );
      expect(all, hasLength(3));

      final odd = datesForWeekday(
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 21),
        weekday: DateTime.monday,
        parity: WeekParity.odd,
        semesterStart: DateTime(2026, 9, 1),
      );
      expect(odd, [DateTime(2026, 9, 14)]);

      final even = datesForWeekday(
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 21),
        weekday: DateTime.monday,
        parity: WeekParity.even,
        semesterStart: DateTime(2026, 9, 1),
      );
      expect(even, [DateTime(2026, 9, 7), DateTime(2026, 9, 21)]);
    });
  });
}
