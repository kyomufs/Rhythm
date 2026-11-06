/// Schedule item from TULSU API
class ScheduleItem {
  final String date;
  final String time;
  final String subject;
  final String type;
  final String classroom;
  final String teacher;
  final List<GroupInfo> groups;
  final String cssClass;

  const ScheduleItem({
    required this.date,
    required this.time,
    required this.subject,
    required this.type,
    required this.classroom,
    required this.teacher,
    required this.groups,
    required this.cssClass,
  });

  factory ScheduleItem.fromJson(Map<String, dynamic> json) {
    return ScheduleItem(
      date: '${json['DATE_Z'] ?? ''}',
      time: '${json['TIME_Z'] ?? ''}',
      subject: '${json['DISCIP'] ?? ''}',
      type: '${json['KOW'] ?? ''}',
      classroom: '${json['AUD'] ?? ''}',
      teacher: '${json['PREP'] ?? ''}',
      groups: (json['GROUPS'] as List?)
              ?.map((g) =>
                  GroupInfo.fromJson(Map<String, dynamic>.from(g as Map)))
              .toList() ??
          [],
      cssClass: '${json['CLASS'] ?? ''}',
    );
  }

  /// Parse date from DD.MM.YYYY format
  DateTime get parsedDate {
    final parts = date.split('.');
    return DateTime(
      int.parse(parts[2]),
      int.parse(parts[1]),
      int.parse(parts[0]),
    );
  }

  /// Lesson start parsed from "HH:MM - HH:MM" (null when unparseable).
  DateTime? get startsAt => _parseTimeRange()?.$1;

  /// Lesson end parsed from "HH:MM - HH:MM" (null when unparseable).
  DateTime? get endsAt => _parseTimeRange()?.$2;

  /// Whether this lesson is running at [now] (same calendar day).
  bool isOngoingAt(DateTime now) {
    final start = startsAt;
    final end = endsAt;
    if (start == null || end == null) return false;
    return !now.isBefore(start) && now.isBefore(end);
  }

  /// Exact time left until the lesson ends (zero when over).
  Duration timeLeftAt(DateTime now) {
    final end = endsAt;
    if (end == null) return Duration.zero;
    final left = end.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  /// Exact time until the lesson starts (zero when it is already
  /// running or over).
  Duration timeUntilStartAt(DateTime now) {
    final start = startsAt;
    if (start == null) return Duration.zero;
    final left = start.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  (DateTime, DateTime)? _parseTimeRange() {
    final match =
        RegExp(r'(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})').firstMatch(time);
    if (match == null) return null;
    final day = parsedDate;
    final start = DateTime(day.year, day.month, day.day,
        int.parse(match.group(1)!), int.parse(match.group(2)!));
    var end = DateTime(day.year, day.month, day.day, int.parse(match.group(3)!),
        int.parse(match.group(4)!));
    if (end.isBefore(start)) {
      end = end.add(const Duration(days: 1));
    }
    return (start, end);
  }

  /// Get lesson type enum
  LessonType get lessonType {
    switch (cssClass) {
      case 'lecture':
        return LessonType.lecture;
      case 'practice':
        return LessonType.practice;
      case 'lab':
        return LessonType.lab;
      default:
        return LessonType.unknown;
    }
  }

  /// Get unique key for this lesson
  String get key => '$date-$time-$subject-$classroom';

  /// Row format used by the schedule-change fingerprint
  /// (date|time|subject|teacher|classroom|type).
  String get fingerprintRow => '$date|$time|$subject|$teacher|$classroom|$type';

  /// Occurrence slot matching the same lesson across schedule versions.
  String get slotKey => '$date|$subject|$type';
}

/// Group information
class GroupInfo {
  final String number;
  final String? subgroup;

  const GroupInfo({
    required this.number,
    this.subgroup,
  });

  factory GroupInfo.fromJson(Map<String, dynamic> json) {
    return GroupInfo(
      number: '${json['GROUP_P'] ?? ''}',
      subgroup: json['PRIM']?.toString(),
    );
  }

  String get displayName {
    if (subgroup != null && subgroup!.isNotEmpty) {
      return '$number ($subgroup)';
    }
    return number;
  }
}

/// Compact label for the vertical type strip in lesson tiles.
/// Long names like "Практическое занятие" are shortened so the strip
/// never overflows; the detail sheet keeps the full text.
String shortLessonType(String type, {String cssClass = ''}) {
  final t = type.toLowerCase();
  if (t.contains('практическ')) return 'Практика';
  if (t.contains('практик')) return 'Практика';
  if (t.contains('лабораторн')) return 'Лабораторная';
  if (t.contains('лекци')) return 'Лекция';
  if (t.contains('семинар')) return 'Семинар';
  if (t.contains('консультаци')) return 'Консультация';
  if (t.contains('контрольн')) return 'Контрольная';
  if (t.contains('дифференц')) return 'Дифф. зачёт';
  if (t.contains('диффер')) return 'Дифф. зачёт';
  if (t.contains('экзамен')) return 'Экзамен';
  if (t.contains('зач')) return 'Зачёт';
  if (t.contains('курсов')) return 'Курсовая';
  if (t.contains('педагогическ')) return 'Пед. практика';
  if (t.contains('музыкальн')) return 'Музыкальная';
  if (t.contains('выездн')) return 'Выездная';
  if (t.contains('производственн')) return 'Производств.';
  if (t.contains('самостоятельн')) return 'Самост.';
  if (t.contains('внутренн')) return 'Внутр. зачёт';
  // Unknown but long: fall back to the API CLASS (lecture/lab/practice…).
  if (t.length > 12) {
    switch (cssClass) {
      case 'lecture':
        return 'Лекция';
      case 'lab':
        return 'Лабораторная';
      case 'practice':
        return 'Практика';
    }
    return '${t.substring(0, 11)}…';
  }
  return type;
}

/// Lesson type enum
enum LessonType {
  lecture,
  practice,
  lab,
  seminar,
  unknown;

  String get displayName {
    switch (this) {
      case LessonType.lecture:
        return 'Лекция';
      case LessonType.practice:
        return 'Практика';
      case LessonType.lab:
        return 'Лабораторная';
      case LessonType.seminar:
        return 'Семинар';
      case LessonType.unknown:
        return 'Другое';
    }
  }

  String get icon {
    switch (this) {
      case LessonType.lecture:
        return '📖';
      case LessonType.practice:
        return '💻';
      case LessonType.lab:
        return '🔬';
      case LessonType.seminar:
        return '🗣';
      case LessonType.unknown:
        return '📚';
    }
  }
}

/// Search result type
enum SearchResultType {
  group,
  teacher,
  auditorium,
  subject;

  String get displayName {
    switch (this) {
      case SearchResultType.group:
        return 'Группа';
      case SearchResultType.teacher:
        return 'Преподаватель';
      case SearchResultType.auditorium:
        return 'Аудитория';
      case SearchResultType.subject:
        return 'Предмет';
    }
  }
}

/// Search result item
class SearchResult {
  final String value;
  final SearchResultType type;

  const SearchResult({
    required this.value,
    required this.type,
  });

  /// Detect type from value
  factory SearchResult.fromValue(String value) {
    final type = _detectType(value);
    return SearchResult(value: value, type: type);
  }

  static SearchResultType _detectType(String value) {
    if (RegExp(r'^\d').hasMatch(value)) {
      return SearchResultType.group;
    }
    if (value.contains('-') ||
        value.startsWith('Гл') ||
        value.startsWith('Спорт') ||
        value.startsWith('12-')) {
      return SearchResultType.auditorium;
    }
    return SearchResultType.teacher;
  }
}

/// Schedule state for a specific search
class ScheduleState {
  final String searchValue;
  final DateTimeRange? dateRange;
  final List<ScheduleItem> items;
  final bool isLoading;
  final String? error;

  const ScheduleState({
    required this.searchValue,
    this.dateRange,
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  ScheduleState copyWith({
    String? searchValue,
    DateTimeRange? dateRange,
    List<ScheduleItem>? items,
    bool? isLoading,
    String? error,
  }) {
    return ScheduleState(
      searchValue: searchValue ?? this.searchValue,
      dateRange: dateRange ?? this.dateRange,
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Get items grouped by date
  Map<DateTime, List<ScheduleItem>> get itemsByDate {
    final map = <DateTime, List<ScheduleItem>>{};
    for (final item in items) {
      final date = item.parsedDate;
      final dayKey = DateTime(date.year, date.month, date.day);
      map[dayKey] = [...(map[dayKey] ?? []), item];
    }
    return map;
  }

  /// Get unique subjects
  List<String> get uniqueSubjects {
    return items.map((e) => e.subject).toSet().toList();
  }

  /// Get unique teachers
  List<String> get uniqueTeachers {
    return items
        .map((e) => e.teacher)
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  /// Get unique auditoriums
  List<String> get uniqueClassrooms {
    return items
        .map((e) => e.classroom)
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }
}

/// DateTimeRange helper
class DateTimeRange {
  final DateTime start;
  final DateTime end;

  const DateTimeRange({required this.start, required this.end});
}

/// Calendar item from TULSU API
class CalendarItem {
  final DateTime beginDate;
  final DateTime endDate;
  final String type;

  const CalendarItem({
    required this.beginDate,
    required this.endDate,
    required this.type,
  });

  factory CalendarItem.fromJson(Map<String, dynamic> json) {
    return CalendarItem(
      beginDate: _parseDate('${json['BEGIN_DATE'] ?? ''}'),
      endDate: _parseDate('${json['END_DATE'] ?? ''}'),
      type: '${json['VID'] ?? ''}',
    );
  }

  static DateTime _parseDate(String dateStr) {
    if (dateStr.isEmpty) return DateTime.now();
    // Format: "DD.MM.YYYY"
    final parts = dateStr.split('.');
    if (parts.length == 3) {
      try {
        return DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
      } catch (_) {}
    }
    return DateTime.tryParse(dateStr) ?? DateTime.now();
  }
}

/// Exact countdown text with seconds: "34 с", "12 мин 34 с",
/// "1 ч 05 мин 09 с". Values are truncated, never rounded up, so the
/// label never overstates the time actually left.
String formatCountdown(Duration remaining) {
  final total = remaining.isNegative ? Duration.zero : remaining;
  final hours = total.inHours;
  final minutes = total.inMinutes.remainder(60);
  final seconds = total.inSeconds.remainder(60);
  String two(int value) => value.toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours ч ${two(minutes)} мин ${two(seconds)} с';
  }
  if (minutes > 0) return '$minutes мин ${two(seconds)} с';
  return '$seconds с';
}

/// Поле поиска расписания: группа, преподаватель, аудитория.
enum SearchField {
  group('GROUP_P'),
  teacher('PREP'),
  auditorium('AUD');

  final String value;
  const SearchField(this.value);
}

/// Диапазон дат, в котором источник отдаёт расписание.
class ApiDateRange {
  final DateTime minDate;
  final DateTime maxDate;
  final SearchField searchField;

  const ApiDateRange({
    required this.minDate,
    required this.maxDate,
    required this.searchField,
  });
}

/// Снимок расписания: диапазон, пары и академический календарь.
class ScheduleData {
  final ApiDateRange dateRange;
  final List<ScheduleItem> items;
  final List<CalendarItem> calendar;

  const ScheduleData({
    required this.dateRange,
    required this.items,
    required this.calendar,
  });
}
