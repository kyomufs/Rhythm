/// Utility for computing academic week info from TULSU schedule dates.
///
/// TULSU academic year starts September 1.
/// Week 1 = Sep 1–7 (odd), Week 2 = Sep 8–14 (even), etc.
class WeekInfo {
  final int weekNumber;
  final DateTime startDate;
  final DateTime endDate;
  final bool isEven;

  const WeekInfo({
    required this.weekNumber,
    required this.startDate,
    required this.endDate,
    required this.isEven,
  });

  /// Monday of this week (startDate is always Monday)
  DateTime get monday => startDate;

  /// Last day (Sunday)
  DateTime get sunday => endDate;

  /// Whether a given date falls within this week
  bool contains(DateTime date) {
    return !date.isBefore(startDate) && !date.isAfter(endDate);
  }

  /// Format like: "21.09.26–27.09.26"
  String get dateRange {
    return '${_fmt(startDate)}–${_fmt(endDate)}';
  }

  /// Format like: "21.09–27.09"
  String get dateRangeShort {
    return '${_fmtShort(startDate)}–${_fmtShort(endDate)}';
  }

  /// Full header: "Неделя 3 · 15.09–21.09 (нечётная акад. неделя)"
  String get header {
    final parity = isEven ? 'чётная' : 'нечётная';
    return 'Неделя $weekNumber · $dateRangeShort ($parity акад. неделя)';
  }

  /// Short header: "Неделя 3 (нечётная)"
  String get shortHeader {
    final parity = isEven ? 'чётная' : 'нечётная';
    return 'Неделя $weekNumber ($parity)';
  }

  static String _fmt(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${(d.year % 100).toString().padLeft(2, '0')}';
  }

  static String _fmtShort(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
  }

  @override
  String toString() => header;
}

/// Get the academic week info for a given [date].
///
/// Week 1 starts on the Monday on or before September 1.
/// Odd weeks are odd-numbered, even weeks are even-numbered.
WeekInfo getWeekInfo(DateTime date) {
  final semesterStart = _getSemesterStart(date.year);
  final weekStart = _mondayOnOrBefore(date);
  final daysSinceStart = weekStart.difference(semesterStart).inDays;
  final weekNumber = (daysSinceStart ~/ 7) + 1;

  return WeekInfo(
    weekNumber: weekNumber,
    startDate: weekStart,
    endDate: weekStart.add(const Duration(days: 6)),
    isEven: weekNumber.isEven,
  );
}

/// Get the Monday on or before [date].
DateTime _mondayOnOrBefore(DateTime date) {
  // weekday: Monday=1, Sunday=7
  final daysSinceMonday = date.weekday - 1;
  return DateTime(date.year, date.month, date.day)
      .subtract(Duration(days: daysSinceMonday));
}

/// Get the start of the academic semester for [year].
/// Semester starts on the Monday on or before September 1.
DateTime _getSemesterStart(int year) {
  final sep1 = DateTime(year, 9, 1);
  return _mondayOnOrBefore(sep1);
}

/// Navigate to next/previous week from [currentStart].
DateTime getNextWeekStart(DateTime currentStart) {
  return currentStart.add(const Duration(days: 7));
}

DateTime getPrevWeekStart(DateTime currentStart) {
  return currentStart.subtract(const Duration(days: 7));
}

/// Get the week start (Monday) for a given [date].
DateTime getWeekStart(DateTime date) {
  return _mondayOnOrBefore(date);
}

/// Get the current week's Monday.
DateTime getCurrentWeekStart() {
  return _mondayOnOrBefore(DateTime.now());
}

/// Filter items that fall within a given week.
/// [weekStart] is the Monday, week ends on Sunday.
List<T> filterByWeek<T>(
    List<T> items, DateTime weekStart, DateTime Function(T) getDate) {
  final weekEnd = weekStart.add(const Duration(days: 7));
  return items.where((item) {
    final d = getDate(item);
    return !d.isBefore(weekStart) && d.isBefore(weekEnd);
  }).toList();
}
