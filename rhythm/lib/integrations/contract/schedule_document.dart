import 'package:rhythm/core/models/schedule.dart';
import 'package:rhythm/core/sources/source_api.dart';

/// Версия канонического документа. Растёт только при несовместимом
/// изменении формы: приложение обязано отвергнуть чужую версию, а не
/// разбирать её «как получится».
const int kScheduleSchemaVersion = 1;

class ScheduleDocumentException implements Exception {
  final String message;

  const ScheduleDocumentException(this.message);

  @override
  String toString() => 'ScheduleDocumentException: $message';
}

/// Канонический документ расписания — то единственное, что пересекает
/// границу коннектора.
///
/// Сериализуется один в один, поэтому локальный коннектор и будущий серверный
/// отдают одинаковую форму, и перенос вуза наружу не трогает приложение.
class ScheduleDocument {
  final int schemaVersion;
  final String sourceId;
  final String sourceTitle;
  final String targetField;
  final String targetValue;
  final DateTime? rangeFrom;
  final DateTime? rangeTo;
  final List<ScheduleItem> lessons;
  final List<CalendarItem> events;

  /// `local` — коннектор работал на телефоне, `remote` — на нашем сервере.
  final String origin;
  final DateTime fetchedAt;

  const ScheduleDocument({
    required this.sourceId,
    required this.sourceTitle,
    required this.targetField,
    required this.targetValue,
    required this.lessons,
    required this.events,
    required this.fetchedAt,
    this.rangeFrom,
    this.rangeTo,
    this.schemaVersion = kScheduleSchemaVersion,
    this.origin = 'local',
  });

  bool get hasRange => rangeFrom != null && rangeTo != null;

  factory ScheduleDocument.fromJson(Map<String, dynamic> json) {
    final version = json['schemaVersion'];
    if (version is! int) {
      throw const ScheduleDocumentException('Нет версии схемы расписания');
    }
    if (version != kScheduleSchemaVersion) {
      throw ScheduleDocumentException(
        'Неизвестная версия схемы: $version (ожидается $kScheduleSchemaVersion)',
      );
    }
    final target = json['target'];
    final range = json['range'];
    try {
      return ScheduleDocument(
        sourceId: '${json['sourceId'] ?? ''}',
        sourceTitle: '${json['sourceTitle'] ?? ''}',
        targetField:
            target is Map<String, dynamic> ? '${target['field'] ?? ''}' : '',
        targetValue:
            target is Map<String, dynamic> ? '${target['value'] ?? ''}' : '',
        rangeFrom:
            range is Map<String, dynamic> ? _parseIsoDate(range['from']) : null,
        rangeTo:
            range is Map<String, dynamic> ? _parseIsoDate(range['to']) : null,
        lessons: (json['lessons'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map((item) => _lessonFromJson(Map<String, dynamic>.from(item)))
            .toList(),
        events: (json['events'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map((item) => _eventFromJson(Map<String, dynamic>.from(item)))
            .toList(),
        origin: '${json['origin'] ?? 'local'}',
        fetchedAt: _parseTimestamp(json['fetchedAt']),
      );
    } catch (e) {
      throw ScheduleDocumentException('Не удалось разобрать расписание: $e');
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'sourceId': sourceId,
      'sourceTitle': sourceTitle,
      'target': {'field': targetField, 'value': targetValue},
      'range': hasRange
          ? {'from': _isoDate(rangeFrom!), 'to': _isoDate(rangeTo!)}
          : null,
      'lessons': lessons.map(_lessonToJson).toList(),
      'events': events.map(_eventToJson).toList(),
      'origin': origin,
      'fetchedAt': fetchedAt.toIso8601String(),
    };
  }

  /// Документ в привычные экранам модели. Отсутствующие поля остаются
  /// пустыми: вуз без групп пар не ломает карточку.
  SourceSchedule toSourceSchedule() {
    final from = rangeFrom ?? DateTime(2000, 1, 1);
    final to = rangeTo ?? DateTime(2100, 1, 1);
    return SourceSchedule(
      dateRange: SourceDateRange(
        minDate: from,
        maxDate: to,
        searchField: SearchField.group,
      ),
      lessons: lessons,
      calendar: events,
    );
  }
}

Map<String, dynamic> _lessonToJson(ScheduleItem item) {
  final start = _timePart(item.time, 0);
  final end = _timePart(item.time, 1);
  return {
    'date': _isoDate(item.parsedDate),
    'start': start,
    'end': end,
    'subject': item.subject,
    'type': item.type,
    'kind': item.cssClass.isEmpty ? 'unknown' : item.cssClass,
    'room': item.classroom.isEmpty ? null : item.classroom,
    'teachers': item.teacher.isEmpty ? <String>[] : [item.teacher],
    'groups': item.groups
        .map((g) => {
              'title': g.number,
              'subgroup': int.tryParse(g.subgroup ?? ''),
            })
        .toList(),
    'stream': null,
  };
}

ScheduleItem _lessonFromJson(Map<String, dynamic> json) {
  final start = '${json['start'] ?? ''}';
  final end = '${json['end'] ?? ''}';
  final kind = '${json['kind'] ?? ''}';
  final date = _parseIsoDate(json['date']);
  final groups = (json['groups'] as List? ?? const [])
      .whereType<Map<String, dynamic>>()
      .map((g) => GroupInfo(
            number: '${g['title'] ?? ''}',
            subgroup: g['subgroup']?.toString(),
          ))
      .toList();
  final teachers = (json['teachers'] as List? ?? const [])
      .map((t) => '$t')
      .where((t) => t.isNotEmpty)
      .toList();

  return ScheduleItem(
    date: date == null ? '' : _dottedDate(date),
    time: start.isEmpty ? '' : '$start - $end',
    subject: '${json['subject'] ?? ''}',
    type: '${json['type'] ?? ''}',
    classroom: json['room'] == null ? '' : '${json['room']}',
    teacher: teachers.join(', '),
    groups: groups,
    cssClass: kind == 'unknown' ? '' : kind,
  );
}

Map<String, dynamic> _eventToJson(CalendarItem item) {
  return {
    'date': _isoDate(item.beginDate),
    'end': _isoDate(item.endDate),
    'title': item.type,
  };
}

CalendarItem _eventFromJson(Map<String, dynamic> json) {
  final start = _parseIsoDate(json['date']) ??
      _parseIsoDate(json['end']) ??
      DateTime.now();
  return CalendarItem(
    beginDate: start,
    endDate: _parseIsoDate(json['end']) ?? start,
    type: '${json['title'] ?? ''}',
  );
}

DateTime? _parseIsoDate(Object? value) {
  if (value is! String || value.isEmpty) return null;
  final parts = value.split('-');
  if (parts.length != 3) return DateTime.tryParse(value);
  return DateTime(
    int.tryParse(parts[0]) ?? 0,
    int.tryParse(parts[1]) ?? 1,
    int.tryParse(parts[2]) ?? 1,
  );
}

DateTime _parseTimestamp(Object? value) {
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  return DateTime.now();
}

String _isoDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _dottedDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}

/// ТулГУ отдаёт время строкой «10:10 - 11:40», документ — двумя полями.
String _timePart(String time, int index) {
  final parts = time.split('-');
  if (parts.isEmpty) return '';
  if (index >= parts.length) return parts.first.trim();
  return parts[index].trim();
}
