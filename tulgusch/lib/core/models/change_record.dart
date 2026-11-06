/// Kind of a detected schedule change.
enum ChangeKind { modified, added, removed }

/// One field-level difference inside a modified lesson
/// (e.g. «Аудитория: 305 → 407»).
class FieldChange {
  final String field;
  final String before;
  final String after;

  const FieldChange({
    required this.field,
    required this.before,
    required this.after,
  });

  Map<String, dynamic> toJson() => {
        'field': field,
        'before': before,
        'after': after,
      };

  factory FieldChange.fromJson(Map<String, dynamic> json) {
    return FieldChange(
      field: json['field'] as String,
      before: json['before'] as String,
      after: json['after'] as String,
    );
  }
}

/// A journal entry describing one lesson change between two versions of
/// the schedule («было → стало»).
///
/// `time/classroom/teacher` hold the NEW values for modified and added
/// lessons and the OLD values for removed ones. [fieldChanges] is only
/// non-empty for [ChangeKind.modified].
class ChangeRecord {
  final DateTime detectedAt;
  final ChangeKind kind;
  final String date; // Lesson date, DD.MM.YYYY
  final String subject;
  final String type;
  final String time;
  final String classroom;
  final String teacher;
  final List<FieldChange> fieldChanges;
  final bool isDemo;

  const ChangeRecord({
    required this.detectedAt,
    required this.kind,
    required this.date,
    required this.subject,
    required this.type,
    required this.time,
    required this.classroom,
    required this.teacher,
    this.fieldChanges = const [],
    this.isDemo = false,
  });

  Map<String, dynamic> toJson() => {
        'detectedAt': detectedAt.toIso8601String(),
        'kind': kind.name,
        'date': date,
        'subject': subject,
        'type': type,
        'time': time,
        'classroom': classroom,
        'teacher': teacher,
        'fieldChanges': fieldChanges.map((c) => c.toJson()).toList(),
        'isDemo': isDemo,
      };

  /// Row key in the same format as [ScheduleItem.fingerprintRow]
  /// (date|time|subject|teacher|classroom|type) — lets the detail sheet
  /// look up a record by the lesson it describes.
  String get fingerprintRow => '$date|$time|$subject|$teacher|$classroom|$type';

  /// Human-readable one-liner for banners and legacy lookups:
  /// modified → «Аудитория: 305 → 407», added → «Новое занятие»,
  /// removed → «Занятие отменено».
  String get summaryNote {
    switch (kind) {
      case ChangeKind.added:
        return 'Новое занятие';
      case ChangeKind.removed:
        return 'Занятие отменено';
      case ChangeKind.modified:
        if (fieldChanges.isEmpty) return 'Изменено расписание';
        return fieldChanges
            .map((c) => '${c.field}: ${c.before} → ${c.after}')
            .join('; ');
    }
  }

  factory ChangeRecord.fromJson(Map<String, dynamic> json) {
    return ChangeRecord(
      detectedAt: DateTime.parse(json['detectedAt'] as String),
      kind: ChangeKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => ChangeKind.modified,
      ),
      date: json['date'] as String,
      subject: json['subject'] as String,
      type: json['type'] as String,
      time: json['time'] as String,
      classroom: json['classroom'] as String,
      teacher: json['teacher'] as String,
      fieldChanges: (json['fieldChanges'] as List? ?? const [])
          .map((c) => FieldChange.fromJson(Map<String, dynamic>.from(c as Map)))
          .toList(),
      isDemo: json['isDemo'] as bool? ?? false,
    );
  }
}
