import 'dart:math' as math;

import 'package:rhythm/core/models/schedule.dart';

/// ═══════════════════════════════════════════════════════════════
/// Журнал успеваемости: семестр → дисциплина → шкала → записи.
/// Чистый Dart: ни Flutter, ни провайдеров, ни хранилища.
/// ═══════════════════════════════════════════════════════════════

enum TermKind { semester, trimester, module, custom }

enum CourseKind { exam, credit, differentiatedCredit }

enum Attendance { present, absent, excused, late }

enum AssessmentStatus { planned, graded, missed }

enum GradeRounding { none, half, up }

// ── Подписи ────────────────────────────────────────────────────

String termKindLabel(TermKind kind) {
  switch (kind) {
    case TermKind.semester:
      return 'Семестр';
    case TermKind.trimester:
      return 'Триместр';
    case TermKind.module:
      return 'Модуль';
    case TermKind.custom:
      return 'Период';
  }
}

String courseKindLabel(CourseKind kind) {
  switch (kind) {
    case CourseKind.exam:
      return 'Экзамен';
    case CourseKind.credit:
      return 'Зачёт';
    case CourseKind.differentiatedCredit:
      return 'Дифзачёт';
  }
}

String lessonTypeShortLabel(LessonType type) {
  switch (type) {
    case LessonType.lecture:
      return 'Лек';
    case LessonType.practice:
      return 'Пр';
    case LessonType.lab:
      return 'Лаб';
    case LessonType.seminar:
      return 'Сем';
    case LessonType.unknown:
      return 'Зан';
  }
}

/// Тип пары из расписания ТулГУ («Лекции», «Практические», «Лабораторные»).
LessonType? lessonTypeFromSchedule(String raw) {
  final value = raw.toLowerCase();
  if (value.contains('лекц')) return LessonType.lecture;
  if (value.contains('практ')) return LessonType.practice;
  if (value.contains('лаб')) return LessonType.lab;
  if (value.contains('семин')) return LessonType.seminar;
  if (value.isEmpty) return null;
  return LessonType.unknown;
}

String attendanceLabel(Attendance attendance) {
  switch (attendance) {
    case Attendance.present:
      return 'Был';
    case Attendance.absent:
      return 'Не был';
    case Attendance.excused:
      return 'Уважительная';
    case Attendance.late:
      return 'Опоздал';
  }
}

/// Номер пары по времени начала. Расписание отдаёт «HH:MM - HH:MM»,
/// журналу нужен устойчивый ключ, чтобы одна и та же пара не задвоилась
/// при повторном открытии карточки.
int lessonSlotFromTime(String time) {
  const rings = ['08:30', '10:15', '12:45', '14:30', '16:15', '18:00', '19:45'];
  final match = RegExp(r'\d{1,2}:\d{2}').firstMatch(time);
  if (match == null) return 0;
  final start = match.group(0)!;
  final index = rings.indexOf(start);
  if (index >= 0) return index + 1;
  return int.parse(start.split(':').first) - 7;
}

bool attendanceCountsAsVisited(Attendance attendance) =>
    attendance == Attendance.present || attendance == Attendance.late;

// ── Шкала ──────────────────────────────────────────────────────

class GradeCategory {
  final String id;
  final String name;
  final double maxPoints;

  /// Пары какого типа наполняют категорию баллами. null — только события.
  final LessonType? lessonType;
  final bool isExam;

  const GradeCategory({
    required this.id,
    required this.name,
    required this.maxPoints,
    this.lessonType,
    this.isExam = false,
  });

  GradeCategory copyWith({
    String? name,
    double? maxPoints,
    LessonType? lessonType,
    bool? isExam,
  }) {
    return GradeCategory(
      id: id,
      name: name ?? this.name,
      maxPoints: maxPoints ?? this.maxPoints,
      lessonType: lessonType ?? this.lessonType,
      isExam: isExam ?? this.isExam,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'maxPoints': maxPoints,
        'lessonType': lessonType?.name,
        'isExam': isExam,
      };

  factory GradeCategory.fromJson(Map<String, dynamic> json) {
    return GradeCategory(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Категория',
      maxPoints: (json['maxPoints'] as num?)?.toDouble() ?? 0,
      lessonType: _firstWhereOrNull(
        LessonType.values,
        (t) => t.name == json['lessonType'],
      ),
      isExam: json['isExam'] as bool? ?? false,
    );
  }
}

class GradeScale {
  final List<GradeCategory> categories;

  /// Минимум баллов для зачёта/экзамена.
  final double passThreshold;
  final GradeRounding rounding;

  const GradeScale({
    this.categories = const [],
    this.passThreshold = 60,
    this.rounding = GradeRounding.none,
  });

  double get totalMax =>
      categories.fold(0, (sum, category) => sum + category.maxPoints);

  double get examMax => categories
      .where((c) => c.isExam)
      .fold(0, (sum, category) => sum + category.maxPoints);

  double get currentMax => categories
      .where((c) => !c.isExam)
      .fold(0, (sum, category) => sum + category.maxPoints);

  double get examThreshold => math.max(0, passThreshold - currentMax);

  bool get isConsistent => totalMax > 0 && (totalMax - 100).abs() < 0.01;

  GradeCategory? categoryById(String id) =>
      _firstWhereOrNull(categories, (c) => c.id == id);

  GradeCategory? categoryForLesson(LessonType type) =>
      _firstWhereOrNull(categories, (c) => c.lessonType == type);

  /// Оценка по проценту; порог 5/4/3 вынесен в шкалу, чтобы «зачёт»
  /// не притворялся пятибалльной оценкой.
  int gradeForPercent(double percent) {
    if (percent >= 85) return 5;
    if (percent >= 70) return 4;
    if (percent >= 50) return 3;
    return 2;
  }

  GradeScale copyWith({
    List<GradeCategory>? categories,
    double? passThreshold,
    GradeRounding? rounding,
  }) {
    return GradeScale(
      categories: categories ?? this.categories,
      passThreshold: passThreshold ?? this.passThreshold,
      rounding: rounding ?? this.rounding,
    );
  }

  Map<String, dynamic> toJson() => {
        'categories': categories.map((c) => c.toJson()).toList(),
        'passThreshold': passThreshold,
        'rounding': rounding.name,
      };

  factory GradeScale.fromJson(Map<String, dynamic> json) {
    return GradeScale(
      categories: (json['categories'] as List<dynamic>?)
              ?.map((e) =>
                  GradeCategory.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      passThreshold: (json['passThreshold'] as num?)?.toDouble() ?? 60,
      rounding: GradeRounding.values.firstWhere(
        (r) => r.name == json['rounding'],
        orElse: () => GradeRounding.none,
      ),
    );
  }
}

class GradeScalePreset {
  final String id;
  final String label;
  final String hint;
  final GradeScale Function() build;

  const GradeScalePreset({
    required this.id,
    required this.label,
    required this.hint,
    required this.build,
  });
}

T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T) test) {
  for (final item in items) {
    if (test(item)) return item;
  }
  return null;
}

String _newId(String prefix) =>
    '$prefix-${DateTime.now().microsecondsSinceEpoch}';

/// Пресеты, которые реально встречаются: 60 текущих + 40 экзамен,
/// вариант с лабораторными и зачёт без экзамена.
final List<GradeScalePreset> gradeScalePresets = [
  GradeScalePreset(
    id: '60-40',
    label: '60 + 40',
    hint: 'Практики 60, экзамен 40',
    build: () => GradeScale(
      categories: [
        GradeCategory(
          id: _newId('cat'),
          name: 'Практики',
          maxPoints: 60,
          lessonType: LessonType.practice,
        ),
        GradeCategory(
          id: _newId('cat'),
          name: 'Экзамен',
          maxPoints: 40,
          isExam: true,
        ),
      ],
    ),
  ),
  GradeScalePreset(
    id: '30-30-40',
    label: '30 + 30 + 40',
    hint: 'Практики 30, лабораторные 30, экзамен 40',
    build: () => GradeScale(
      categories: [
        GradeCategory(
          id: _newId('cat'),
          name: 'Практики',
          maxPoints: 30,
          lessonType: LessonType.practice,
        ),
        GradeCategory(
          id: _newId('cat'),
          name: 'Лабораторные',
          maxPoints: 30,
          lessonType: LessonType.lab,
        ),
        GradeCategory(
          id: _newId('cat'),
          name: 'Экзамен',
          maxPoints: 40,
          isExam: true,
        ),
      ],
    ),
  ),
  GradeScalePreset(
    id: '100-credit',
    label: '100 без экзамена',
    hint: 'Зачёт: 60 баллов за практики и лабы по 30',
    build: () => GradeScale(
      categories: [
        GradeCategory(
          id: _newId('cat'),
          name: 'Практики',
          maxPoints: 60,
          lessonType: LessonType.practice,
        ),
        GradeCategory(
          id: _newId('cat'),
          name: 'Лабораторные',
          maxPoints: 40,
          lessonType: LessonType.lab,
        ),
      ],
      passThreshold: 60,
    ),
  ),
];

/// Шкала по умолчанию для новой дисциплины.
GradeScale defaultGradeScale() => gradeScalePresets.first.build();

// ── Семестр ────────────────────────────────────────────────────

class Term {
  final String id;
  final String sourceId;
  final String title;
  final DateTime start;
  final DateTime end;
  final TermKind kind;

  const Term({
    required this.id,
    required this.sourceId,
    required this.title,
    required this.start,
    required this.end,
    this.kind = TermKind.semester,
  });

  bool contains(DateTime date) => !date.isBefore(start) && !date.isAfter(end);

  bool isCurrentAt(DateTime now) => contains(now);

  Term copyWith({
    String? title,
    DateTime? start,
    DateTime? end,
    TermKind? kind,
  }) {
    return Term(
      id: id,
      sourceId: sourceId,
      title: title ?? this.title,
      start: start ?? this.start,
      end: end ?? this.end,
      kind: kind ?? this.kind,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourceId': sourceId,
        'title': title,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'kind': kind.name,
      };

  factory Term.fromJson(Map<String, dynamic> json) {
    return Term(
      id: json['id'] as String,
      sourceId: json['sourceId'] as String? ?? '',
      title: json['title'] as String? ?? 'Семестр',
      start: DateTime.parse(json['start'] as String),
      end: DateTime.parse(json['end'] as String),
      kind: TermKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => TermKind.semester,
      ),
    );
  }
}

// ── Дисциплина ─────────────────────────────────────────────────

class Course {
  final String id;
  final String termId;
  final String title;
  final String? teacher;
  final CourseKind kind;
  final int colorIndex;
  final GradeScale scale;

  const Course({
    required this.id,
    required this.termId,
    required this.title,
    this.teacher,
    this.kind = CourseKind.exam,
    this.colorIndex = 0,
    this.scale = const GradeScale(),
  });

  Course copyWith({
    String? title,
    String? teacher,
    CourseKind? kind,
    int? colorIndex,
    GradeScale? scale,
  }) {
    return Course(
      id: id,
      termId: termId,
      title: title ?? this.title,
      teacher: teacher ?? this.teacher,
      kind: kind ?? this.kind,
      colorIndex: colorIndex ?? this.colorIndex,
      scale: scale ?? this.scale,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'termId': termId,
        'title': title,
        'teacher': teacher,
        'kind': kind.name,
        'colorIndex': colorIndex,
        'scale': scale.toJson(),
      };

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] as String,
      termId: json['termId'] as String? ?? '',
      title: json['title'] as String? ?? 'Дисциплина',
      teacher: json['teacher'] as String?,
      kind: CourseKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => CourseKind.exam,
      ),
      colorIndex: (json['colorIndex'] as num?)?.toInt() ?? 0,
      scale: json['scale'] == null
          ? defaultGradeScale()
          : GradeScale.fromJson(
              Map<String, dynamic>.from(json['scale'] as Map)),
    );
  }
}

// ── Записи ─────────────────────────────────────────────────────

class LessonRecord {
  final String id;
  final String courseId;
  final DateTime date;
  final int slot;
  final LessonType type;
  final Attendance attendance;
  final String? reason;
  final String? comment;
  final double? points;

  const LessonRecord({
    required this.id,
    required this.courseId,
    required this.date,
    required this.slot,
    required this.type,
    this.attendance = Attendance.present,
    this.reason,
    this.comment,
    this.points,
  });

  bool get visited => attendanceCountsAsVisited(attendance);

  LessonRecord copyWith({
    Attendance? attendance,
    String? reason,
    String? comment,
    double? points,
    bool clearReason = false,
    bool clearPoints = false,
  }) {
    return LessonRecord(
      id: id,
      courseId: courseId,
      date: date,
      slot: slot,
      type: type,
      attendance: attendance ?? this.attendance,
      reason: clearReason ? null : (reason ?? this.reason),
      comment: comment ?? this.comment,
      points: clearPoints ? null : (points ?? this.points),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'courseId': courseId,
        'date': date.toIso8601String(),
        'slot': slot,
        'type': type.name,
        'attendance': attendance.name,
        'reason': reason,
        'comment': comment,
        'points': points,
      };

  factory LessonRecord.fromJson(Map<String, dynamic> json) {
    return LessonRecord(
      id: json['id'] as String,
      courseId: json['courseId'] as String? ?? '',
      date: DateTime.parse(json['date'] as String),
      slot: (json['slot'] as num?)?.toInt() ?? 0,
      type: LessonType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => LessonType.unknown,
      ),
      attendance: Attendance.values.firstWhere(
        (a) => a.name == json['attendance'],
        orElse: () => Attendance.present,
      ),
      reason: json['reason'] as String?,
      comment: json['comment'] as String?,
      points: (json['points'] as num?)?.toDouble(),
    );
  }
}

class Assessment {
  final String id;
  final String courseId;
  final String categoryId;
  final String title;
  final DateTime? dueDate;
  final DateTime? heldDate;
  final double maxPoints;
  final double? earnedPoints;
  final AssessmentStatus status;
  final String? comment;
  final String? lessonId;

  const Assessment({
    required this.id,
    required this.courseId,
    required this.categoryId,
    required this.title,
    this.dueDate,
    this.heldDate,
    required this.maxPoints,
    this.earnedPoints,
    this.status = AssessmentStatus.planned,
    this.comment,
    this.lessonId,
  });

  bool get isGraded =>
      status == AssessmentStatus.graded || earnedPoints != null;

  bool get isOverdue =>
      dueDate != null &&
      !isGraded &&
      dueDate!.isBefore(DateTime.now()) &&
      status != AssessmentStatus.missed;

  Assessment copyWith({
    String? title,
    String? categoryId,
    DateTime? dueDate,
    DateTime? heldDate,
    double? maxPoints,
    double? earnedPoints,
    AssessmentStatus? status,
    String? comment,
    bool clearEarned = false,
    bool clearDueDate = false,
  }) {
    return Assessment(
      id: id,
      courseId: courseId,
      categoryId: categoryId ?? this.categoryId,
      title: title ?? this.title,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      heldDate: heldDate ?? this.heldDate,
      maxPoints: maxPoints ?? this.maxPoints,
      earnedPoints: clearEarned ? null : (earnedPoints ?? this.earnedPoints),
      status: status ?? this.status,
      comment: comment ?? this.comment,
      lessonId: lessonId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'courseId': courseId,
        'categoryId': categoryId,
        'title': title,
        'dueDate': dueDate?.toIso8601String(),
        'heldDate': heldDate?.toIso8601String(),
        'maxPoints': maxPoints,
        'earnedPoints': earnedPoints,
        'status': status.name,
        'comment': comment,
        'lessonId': lessonId,
      };

  factory Assessment.fromJson(Map<String, dynamic> json) {
    return Assessment(
      id: json['id'] as String,
      courseId: json['courseId'] as String? ?? '',
      categoryId: json['categoryId'] as String? ?? '',
      title: json['title'] as String? ?? 'Событие',
      dueDate: json['dueDate'] == null
          ? null
          : DateTime.parse(json['dueDate'] as String),
      heldDate: json['heldDate'] == null
          ? null
          : DateTime.parse(json['heldDate'] as String),
      maxPoints: (json['maxPoints'] as num?)?.toDouble() ?? 0,
      earnedPoints: (json['earnedPoints'] as num?)?.toDouble(),
      status: AssessmentStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => AssessmentStatus.planned,
      ),
      comment: json['comment'] as String?,
      lessonId: json['lessonId'] as String?,
    );
  }
}

// ── Производная статистика ─────────────────────────────────────

class CategoryProgress {
  final GradeCategory category;
  final double earned;

  const CategoryProgress({required this.category, required this.earned});

  double get max => category.maxPoints;
  double get percent => max <= 0 ? 0 : earned / max;
}

class CourseStats {
  final List<CategoryProgress> categories;
  final double total;
  final double totalMax;
  final int visited;
  final int lessons;
  final DateTime? nextDeadline;
  final int overdue;
  final GradeScale scale;

  const CourseStats({
    this.categories = const [],
    this.total = 0,
    this.totalMax = 0,
    this.visited = 0,
    this.lessons = 0,
    this.nextDeadline,
    this.overdue = 0,
    this.scale = const GradeScale(),
  });

  double get percent => totalMax <= 0 ? 0 : total / totalMax;

  double get current => categories
      .where((c) => !c.category.isExam)
      .fold(0, (s, c) => s + c.earned);

  double get currentMax =>
      categories.where((c) => !c.category.isExam).fold(0, (s, c) => s + c.max);

  double get exam => categories
      .where((c) => c.category.isExam)
      .fold(0, (s, c) => s + c.earned);

  double get examMax =>
      categories.where((c) => c.category.isExam).fold(0, (s, c) => s + c.max);

  int get attendancePercent =>
      lessons == 0 ? 0 : ((visited / lessons) * 100).round();

  int get missed => math.max(0, lessons - visited);

  int get predictedGrade => scale.gradeForPercent(percent * 100);

  /// Сколько баллов не хватает до порога; null — уже набрано.
  double? get pointsToPass {
    if (total >= scale.passThreshold) return null;
    final remaining = totalMax - total;
    if (remaining < scale.passThreshold - total) return null;
    return scale.passThreshold - total;
  }

  /// Максимум, который ещё можно набрать (для «до зачёта реально добрать»).
  double get pointsRemaining => math.max(0, totalMax - total);

  bool get isPassed => total >= scale.passThreshold;
}

CourseStats computeCourseStats({
  required Course course,
  required List<LessonRecord> records,
  required List<Assessment> assessments,
}) {
  final scale = course.scale;
  final progress = <CategoryProgress>[];

  for (final category in scale.categories) {
    var earned = 0.0;
    for (final assessment in assessments) {
      if (assessment.categoryId != category.id) continue;
      earned += assessment.earnedPoints ?? 0;
    }
    if (category.lessonType != null) {
      for (final record in records) {
        if (record.type != category.lessonType) continue;
        earned += record.points ?? 0;
      }
    }
    progress.add(CategoryProgress(
      category: category,
      earned: math.min(earned, category.maxPoints),
    ));
  }

  final visited = records.where((r) => r.visited).length;
  final now = DateTime.now();
  DateTime? nextDeadline;
  var overdue = 0;
  for (final assessment in assessments) {
    if (assessment.isGraded) continue;
    final due = assessment.dueDate;
    if (due == null) continue;
    if (due.isBefore(now)) {
      overdue++;
      continue;
    }
    if (nextDeadline == null || due.isBefore(nextDeadline)) {
      nextDeadline = due;
    }
  }

  return CourseStats(
    categories: progress,
    total: progress.fold(0, (s, c) => s + c.earned),
    totalMax: scale.totalMax,
    visited: visited,
    lessons: records.length,
    nextDeadline: nextDeadline,
    overdue: overdue,
    scale: scale,
  );
}

/// Данные одного источника: семестры, дисциплины и все записи.
class JournalData {
  final List<Term> terms;
  final List<Course> courses;
  final List<LessonRecord> records;
  final List<Assessment> assessments;

  const JournalData({
    this.terms = const [],
    this.courses = const [],
    this.records = const [],
    this.assessments = const [],
  });

  bool get isEmpty => terms.isEmpty && courses.isEmpty;

  List<Course> coursesOf(String termId) =>
      courses.where((c) => c.termId == termId).toList();

  List<LessonRecord> recordsOf(String courseId) =>
      records.where((r) => r.courseId == courseId).toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  List<Assessment> assessmentsOf(String courseId) =>
      assessments.where((a) => a.courseId == courseId).toList()
        ..sort((a, b) {
          final ad = a.dueDate;
          final bd = b.dueDate;
          if (ad == null && bd == null) return a.title.compareTo(b.title);
          if (ad == null) return 1;
          if (bd == null) return -1;
          return ad.compareTo(bd);
        });

  LessonRecord? findLesson({
    required String courseId,
    required DateTime date,
    required int slot,
  }) {
    for (final record in records) {
      if (record.courseId != courseId) continue;
      if (record.slot != slot) continue;
      if (record.date.year != date.year ||
          record.date.month != date.month ||
          record.date.day != date.day) {
        continue;
      }
      return record;
    }
    return null;
  }

  /// Ближайшие дедлайны по всем дисциплинам источника.
  List<Assessment> get upcomingDeadlines {
    final now = DateTime.now();
    final list = assessments
        .where((a) =>
            !a.isGraded &&
            a.dueDate != null &&
            a.dueDate!.isAfter(now.subtract(const Duration(days: 1))))
        .toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    return list;
  }

  int get overdueCount => assessments.where((a) => a.isOverdue).length;

  JournalData copyWith({
    List<Term>? terms,
    List<Course>? courses,
    List<LessonRecord>? records,
    List<Assessment>? assessments,
  }) {
    return JournalData(
      terms: terms ?? this.terms,
      courses: courses ?? this.courses,
      records: records ?? this.records,
      assessments: assessments ?? this.assessments,
    );
  }

  Map<String, dynamic> toJson() => {
        'terms': terms.map((t) => t.toJson()).toList(),
        'courses': courses.map((c) => c.toJson()).toList(),
        'records': records.map((r) => r.toJson()).toList(),
        'assessments': assessments.map((a) => a.toJson()).toList(),
      };

  factory JournalData.fromJson(Map<String, dynamic> json) {
    List<T> parse<T>(String key, T Function(Map<String, dynamic>) build) {
      return (json[key] as List<dynamic>?)
              ?.map((e) => build(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [];
    }

    return JournalData(
      terms: parse('terms', Term.fromJson),
      courses: parse('courses', Course.fromJson),
      records: parse('records', LessonRecord.fromJson),
      assessments: parse('assessments', Assessment.fromJson),
    );
  }
}
