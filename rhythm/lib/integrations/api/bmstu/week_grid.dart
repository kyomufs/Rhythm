/// Чётность учебной недели. BMSTU отдаёт пары сеткой на неделю и помечает
/// их `ch` / `zn`; приложение работает с конкретными датами, поэтому сетку
/// надо развернуть.
enum WeekParity {
  all,
  odd,
  even,
}

/// `ch` — числитель (нечётная неделя), `zn` — знаменатель (чётная).
/// Проверено на `/schedules/current`: `weekName: знаменатель` при
/// `weekNumber: 10`.
WeekParity parseWeekParity(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'ch':
      return WeekParity.odd;
    case 'zn':
      return WeekParity.even;
    default:
      return WeekParity.all;
  }
}

/// Понедельник недели, в которую попадает [date].
DateTime mondayOf(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.subtract(Duration(days: day.weekday - 1));
}

/// Номер учебной недели относительно начала семестра, первая неделя = 1.
int weekIndex(DateTime date, DateTime semesterStart) {
  final diff = DateTime(date.year, date.month, date.day)
      .difference(mondayOf(semesterStart))
      .inDays;
  return diff ~/ 7 + 1;
}

bool matchesParity(DateTime date, DateTime semesterStart, WeekParity parity) {
  if (parity == WeekParity.all) return true;
  final odd = weekIndex(date, semesterStart).isOdd;
  return parity == WeekParity.odd ? odd : !odd;
}

/// Все даты с нужным днём недели в диапазоне [from]..[to] включительно,
/// подходящие по чётности.
List<DateTime> datesForWeekday({
  required DateTime from,
  required DateTime to,
  required int weekday,
  required WeekParity parity,
  required DateTime semesterStart,
}) {
  if (weekday < 1 || weekday > 7) return const [];
  final start = DateTime(from.year, from.month, from.day);
  final end = DateTime(to.year, to.month, to.day);
  var cursor = start.add(Duration(days: (weekday - start.weekday + 7) % 7));
  final dates = <DateTime>[];
  while (!cursor.isAfter(end)) {
    if (matchesParity(cursor, semesterStart, parity)) {
      dates.add(cursor);
    }
    cursor = cursor.add(const Duration(days: 7));
  }
  return dates;
}
