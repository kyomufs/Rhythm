import 'package:tulgusch/core/models/schedule.dart';

/// Демо-режим показывает только то, что программа умеет на самом деле:
/// реальные пары, реальные корпуса и реальную сетку звонков ТулГУ. Выдумана
/// ровно одна вещь — номер группы, чтобы фейковые данные нельзя было принять
/// за настоящие.
const demoGroup = '221341:00-демо';

/// Предметы ИПМиКН ТулГУ.
const demoSubjects = [
  'Математический анализ',
  'Дискретная математика',
  'Алгебра и геометрия',
  'Теория вероятностей и математическая статистика',
  'Программирование',
  'Архитектура вычислительных систем',
  'Операционные системы',
  'Базы данных',
  'Компьютерные сети',
  'Веб-технологии',
  'Физика',
  'Иностранный язык',
  'История России',
  'Физическая культура',
];

/// Преподаватели демо-группы.
const demoTeachers = [
  'Иванов А. В.',
  'Смирнова Е. П.',
  'Кузнецов Д. М.',
  'Петрова О. С.',
  'Соколов И. А.',
  'Морозова Н. В.',
];

/// Аудитории ТулГУ: номер корпуса и комнаты через дефис, как в расписании
/// (Гл — главный корпус, Л — лабораторный).
const demoClassrooms = [
  '3-218',
  '3-412',
  '5-407',
  '6-105',
  '9-112',
  '11-120',
  '12-121',
  'Гл-211',
  'Л-108',
];

/// Сетка звонков ТулГУ.
const demoSlots = [
  '08:20 - 09:50',
  '10:00 - 11:30',
  '11:40 - 13:10',
  '13:50 - 15:20',
  '15:30 - 17:00',
  '17:10 - 18:40',
];

const _demoTypes = [
  ('Лекции', 'lecture'),
  ('Практические занятия', 'practice'),
  ('Лабораторные работы', 'lab'),
];

/// Собирает демо-расписание на три недели вокруг [now] (пн–сб) и добавляет
/// одну пару, идущую прямо сейчас, чтобы было что показать в счётчике
/// «до конца пары».
List<ScheduleItem> buildDemoSchedule(DateTime now) {
  final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
  final items = <ScheduleItem>[];

  for (final weekOffset in const [-1, 0, 1]) {
    final week = monday.add(Duration(days: 7 * weekOffset));
    for (var day = 0; day < 6; day++) {
      final date = week.add(Duration(days: day));
      final count = day == 5 ? 3 : (day.isEven ? 5 : 4);
      for (var i = 0; i < count; i++) {
        final seed = (weekOffset + 1) * 97 + day * 13 + i * 7;
        final (type, cssClass) = _demoTypes[seed % _demoTypes.length];
        items.add(ScheduleItem(
          date: _fmtDate(date),
          time: demoSlots[i % demoSlots.length],
          subject: demoSubjects[seed % demoSubjects.length],
          type: type,
          classroom: demoClassrooms[seed % demoClassrooms.length],
          teacher: demoTeachers[(seed + 2) % demoTeachers.length],
          groups: const [GroupInfo(number: demoGroup)],
          cssClass: cssClass,
        ));
      }
    }
  }

  return _withCurrentPair(items, now);
}

/// Пара сетки, которая идёт в момент [now] (по сетке звонков ТулГУ), или
/// `null` — ночью и в перерывах пар нет.
String? currentDemoSlot(DateTime now) {
  final minute = now.hour * 60 + now.minute;
  for (final slot in demoSlots) {
    final range = _minutesOf(slot);
    if (range == null) continue;
    final (start, end) = range;
    if (minute >= start && minute < end) return slot;
  }
  return null;
}

/// Гарантирует, что у сегодняшнего дня есть пара в текущем слоте: иначе
/// счётчик «до конца пары» нечего было бы показать. Ничего не выдумывает
/// сверх сетки звонков — только добавляет недостающую пару.
List<ScheduleItem> _withCurrentPair(List<ScheduleItem> items, DateTime now) {
  final slot = currentDemoSlot(now);
  if (slot == null) return items;
  final todayKey = _fmtDate(now);
  if (items.any((i) => i.date == todayKey && i.time == slot)) return items;

  final seed = now.day;
  final (type, cssClass) = _demoTypes[seed % _demoTypes.length];
  return [
    ...items,
    ScheduleItem(
      date: todayKey,
      time: slot,
      subject: demoSubjects[seed % demoSubjects.length],
      type: type,
      classroom: demoClassrooms[seed % demoClassrooms.length],
      teacher: demoTeachers[seed % demoTeachers.length],
      groups: const [GroupInfo(number: demoGroup)],
      cssClass: cssClass,
    ),
  ];
}

/// "HH:MM - HH:MM" → (startMinute, endMinute); null when unparseable.
(int, int)? _minutesOf(String time) {
  final match =
      RegExp(r'(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})').firstMatch(time);
  if (match == null) return null;
  final start = int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
  var end = int.parse(match.group(3)!) * 60 + int.parse(match.group(4)!);
  if (end <= start) end += 24 * 60;
  return (start, end);
}

String _fmtDate(DateTime d) {
  final day = d.day.toString().padLeft(2, '0');
  final month = d.month.toString().padLeft(2, '0');
  return '$day.$month.${d.year}';
}
