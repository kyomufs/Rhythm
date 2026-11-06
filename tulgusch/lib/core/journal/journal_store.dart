import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tulgusch/core/domain/journal.dart';
import 'package:tulgusch/core/models/schedule.dart';
import 'package:tulgusch/core/services/storage_service.dart';

class JournalState {
  final JournalData data;
  final bool isReady;

  const JournalState({this.data = const JournalData(), this.isReady = false});

  JournalState copyWith({JournalData? data, bool? isReady}) =>
      JournalState(data: data ?? this.data, isReady: isReady ?? this.isReady);
}

/// Журнал. Всё пишется сразу: балл на паре и посещаемость не должно
/// теряться из-за незакрытого экрана.
class JournalNotifier extends StateNotifier<JournalState> {
  final StorageService _storage;

  JournalNotifier(this._storage) : super(const JournalState()) {
    state = JournalState(data: _storage.getJournal(), isReady: true);
  }

  void _write(JournalData data) {
    state = state.copyWith(data: data);
    _storage.saveJournal(data);
  }

  // ── Семестры ─────────────────────────────────────────────

  /// Текущий семестр источника; создаётся при первом обращении.
  Term ensureTerm() {
    final data = state.data;
    final now = DateTime.now();
    for (final term in data.terms) {
      if (term.isCurrentAt(now)) return term;
    }
    if (data.terms.isNotEmpty) return data.terms.last;

    final term = _buildDefaultTerm(now);
    _write(data.copyWith(terms: [...data.terms, term]));
    return term;
  }

  Term _buildDefaultTerm(DateTime now) {
    // Учебный год начинается в сентябре; до февраля это ещё осень.
    final isAutumn = now.month >= 8;
    final start = isAutumn
        ? DateTime(now.year, 9, 1)
        : DateTime(now.year, 2, 7);
    final end = isAutumn
        ? DateTime(now.year, 12, 31)
        : DateTime(now.year, 6, 30);
    return Term(
      id: 'term-${now.microsecondsSinceEpoch}',
      title: isAutumn ? 'Осенний семестр' : 'Весенний семестр',
      start: start,
      end: end,
    );
  }

  void addTerm(Term term) => _write(state.data.copyWith(terms: [...state.data.terms, term]));

  void updateTerm(Term term) {
    _write(state.data.copyWith(
      terms: [
        for (final item in state.data.terms) item.id == term.id ? term : item,
      ],
    ));
  }

  void deleteTerm(String termId) {
    final courses = state.data.courses.where((c) => c.termId != termId).toList();
    final courseIds = state.data.courses
        .where((c) => c.termId == termId)
        .map((c) => c.id)
        .toSet();
    _write(JournalData(
      terms: state.data.terms.where((t) => t.id != termId).toList(),
      courses: courses,
      records: state.data.records
          .where((r) => !courseIds.contains(r.courseId))
          .toList(),
      assessments: state.data.assessments
          .where((a) => !courseIds.contains(a.courseId))
          .toList(),
    ));
  }

  // ── Дисциплины ───────────────────────────────────────────

  void addCourse(Course course) =>
      _write(state.data.copyWith(courses: [...state.data.courses, course]));

  void updateCourse(Course course) {
    _write(state.data.copyWith(
      courses: [
        for (final item in state.data.courses)
          item.id == course.id ? course : item,
      ],
    ));
  }

  void deleteCourse(String courseId) {
    _write(JournalData(
      terms: state.data.terms,
      courses: state.data.courses.where((c) => c.id != courseId).toList(),
      records: state.data.records.where((r) => r.courseId != courseId).toList(),
      assessments:
          state.data.assessments.where((a) => a.courseId != courseId).toList(),
    ));
  }

  /// Дисциплина для пары из расписания: ищем по названию, иначе заводим.
  /// Нужна, чтобы балл и посещение ставились прямо из карточки пары.
  Course courseForLesson(ScheduleItem item) {
    final term = ensureTerm();
    final title = item.subject.trim();
    for (final course in state.data.courses) {
      if (course.termId != term.id) continue;
      if (course.title.toLowerCase() == title.toLowerCase()) return course;
    }
    final course = Course(
      id: 'course-${DateTime.now().microsecondsSinceEpoch}',
      termId: term.id,
      title: title,
      teacher: item.teacher.isEmpty ? null : item.teacher,
      kind: CourseKind.exam,
      colorIndex: state.data.courses.length,
      scale: defaultGradeScale(),
    );
    addCourse(course);
    return course;
  }

  /// Переносит расписание в журнал: семестр по датам занятий, дисциплины по
  /// названиям, пары — записями без отметок. Ручные данные и уже
  /// существующие записи не затрагиваются, повторный импорт не создаёт дублей.
  ///
  /// Возвращает, сколько объектов появилось: по этим числам экран решает,
  /// показать «добавлено» или «всё уже на месте».
  ({int courses, int lessons}) importSchedule(List<ScheduleItem> items) {
    final parsed = <({
      DateTime date,
      int slot,
      LessonType type,
      String subject,
      String teacher
    })>[];
    for (final item in items) {
      final subject = item.subject.trim();
      if (subject.isEmpty) continue;
      final slot = lessonSlotFromTime(item.time);
      if (slot <= 0) continue;
      DateTime date;
      try {
        date = item.parsedDate;
      } on Object {
        continue;
      }
      if (date.year < 2000) continue;
      parsed.add((
        date: DateTime(date.year, date.month, date.day),
        slot: slot,
        type: lessonTypeFromSchedule(item.type) ?? LessonType.unknown,
        subject: subject,
        teacher: item.teacher.trim(),
      ));
    }
    if (parsed.isEmpty) return (courses: 0, lessons: 0);

    parsed.sort((a, b) => a.date.compareTo(b.date));
    final data = state.data;
    var terms = data.terms;
    final courses = [...data.courses];
    final records = [...data.records];

    // Дисциплины сопоставляются без учёта регистра: в API название может
    // прийти с другим регистром, а дисциплина — та же. Ключ включает
    // семестр: «Математика» осенью и весной — разные ведомости.
    final byKey = <String, Course>{
      for (final course in courses)
        '${course.termId}|${course.title.toLowerCase()}': course,
    };
    var createdCourses = 0;
    var createdLessons = 0;

    // Расписание может прийти сразу за весь учебный год: сентябрь и май
    // относятся к разным семестрам, поэтому пары раскладываются по сезонам.
    final groups = <String, List<({
      DateTime date,
      int slot,
      LessonType type,
      String subject,
      String teacher
    })>>{};
    for (final lesson in parsed) {
      groups.putIfAbsent(_seasonKey(lesson.date), () => []).add(lesson);
    }
    final ordered = groups.values.toList()
      ..sort((a, b) => a.first.date.compareTo(b.first.date));

    for (final group in ordered) {
      final resolved = _termForRange(terms, group.first.date, group.last.date);
      terms = resolved.terms;
      final term = resolved.term;

      for (final lesson in group) {
        final key = '${term.id}|${lesson.subject.toLowerCase()}';
        var course = byKey[key];
        if (course == null) {
          course = Course(
            id:
                'course-${DateTime.now().microsecondsSinceEpoch}-$createdCourses',
            termId: term.id,
            title: lesson.subject,
            teacher: lesson.teacher.isEmpty ? null : lesson.teacher,
            kind: CourseKind.exam,
            colorIndex: courses.length,
            scale: defaultGradeScale(),
          );
          byKey[key] = course;
          courses.add(course);
          createdCourses++;
        }
        final exists = records.any((r) =>
            r.courseId == course!.id &&
            r.slot == lesson.slot &&
            r.date.year == lesson.date.year &&
            r.date.month == lesson.date.month &&
            r.date.day == lesson.date.day);
        if (exists) continue;
        records.add(LessonRecord(
          id:
              'lesson-${lesson.date.millisecondsSinceEpoch}-${lesson.slot}-${records.length}',
          courseId: course.id,
          date: lesson.date,
          slot: lesson.slot,
          type: lesson.type,
        ));
        createdLessons++;
      }
    }

    _write(JournalData(
      terms: terms,
      courses: courses,
      records: records,
      assessments: data.assessments,
    ));
    return (courses: createdCourses, lessons: createdLessons);
  }

  /// Учебный сезон пары: осень (сентябрь–январь) и весна (февраль–июль)
  /// одного учебного года. Нужен, чтобы импорт за весь год не склеивал
  /// два семестра в один.
  String _seasonKey(DateTime date) {
    final year = date.month >= 8 ? date.year : date.year - 1;
    final autumn = date.month >= 8 || date.month <= 1;
    return '$year-${autumn ? 'autumn' : 'spring'}';
  }

  /// Семестр, в который попадает диапазон занятий. Если такого нет, он
  /// строится по фактическим датам: учебный год начинается в августе.
  /// Найденный семестр расширяется, а не дублируется: импорт по одной паре
  /// не должен плодить по семестру на каждую новую дату.
  ({Term term, List<Term> terms}) _termForRange(
    List<Term> terms,
    DateTime first,
    DateTime last,
  ) {
    for (final term in terms) {
      final matches = term.contains(first) ||
          term.contains(last) ||
          _seasonKey(term.start) == _seasonKey(first);
      if (!matches) continue;
      final start = first.isBefore(term.start) ? first : term.start;
      final end = last.isAfter(term.end) ? last : term.end;
      if (start == term.start && end == term.end) {
        return (term: term, terms: terms);
      }
      final updated = term.copyWith(start: start, end: end);
      return (
        term: updated,
        terms: [
          for (final item in terms) item.id == term.id ? updated : item,
        ],
      );
    }
    final year = first.month >= 8 ? first.year : first.year - 1;
    final title = first.month >= 8
        ? 'Осенний семестр $year/${(year + 1) % 100}'
        : 'Весенний семестр $year/${(year + 1) % 100}';
    final term = Term(
      id: 'term-${first.microsecondsSinceEpoch}-$year',
      title: title,
      start: DateTime(first.year, first.month, first.day),
      end: DateTime(last.year, last.month, last.day),
    );
    return (term: term, terms: [...terms, term]);
  }

  // ── Пары ─────────────────────────────────────────────────

  LessonRecord lessonFor({
    required Course course,
    required DateTime date,
    required int slot,
    required LessonType type,
  }) {
    final existing = state.data.findLesson(
      courseId: course.id,
      date: date,
      slot: slot,
    );
    if (existing != null) return existing;

    final record = LessonRecord(
      id: 'lesson-${date.millisecondsSinceEpoch}-$slot',
      courseId: course.id,
      date: DateTime(date.year, date.month, date.day),
      slot: slot,
      type: type,
    );
    _write(state.data.copyWith(records: [...state.data.records, record]));
    return record;
  }

  void saveLesson(LessonRecord record) {
    final exists = state.data.records.any((r) => r.id == record.id);
    _write(state.data.copyWith(
      records: exists
          ? [
              for (final item in state.data.records)
                item.id == record.id ? record : item,
            ]
          : [...state.data.records, record],
    ));
  }

  void deleteLesson(String lessonId) {
    _write(state.data.copyWith(
      records: state.data.records.where((r) => r.id != lessonId).toList(),
    ));
  }

  void setPoints(String lessonId, double? points) {
    final record = _firstOrNull(state.data.records.where((r) => r.id == lessonId));
    if (record == null) return;
    saveLesson(record.copyWith(
      points: points,
      clearPoints: points == null,
    ));
  }

  void setAttendance(String lessonId, Attendance attendance, {String? reason}) {
    final record = _firstOrNull(state.data.records.where((r) => r.id == lessonId));
    if (record == null) return;
    saveLesson(record.copyWith(
      attendance: attendance,
      reason: reason,
      clearReason: reason == null || reason.isEmpty,
    ));
  }

  // ── События ──────────────────────────────────────────────

  void saveAssessment(Assessment assessment) {
    final exists = state.data.assessments.any((a) => a.id == assessment.id);
    _write(state.data.copyWith(
      assessments: exists
          ? [
              for (final item in state.data.assessments)
                item.id == assessment.id ? assessment : item,
            ]
          : [...state.data.assessments, assessment],
    ));
  }

  void deleteAssessment(String id) {
    _write(state.data.copyWith(
      assessments: state.data.assessments.where((a) => a.id != id).toList(),
    ));
  }

  JournalData get data => state.data;

  CourseStats statsOf(Course course) => computeCourseStats(
        course: course,
        records: state.data.recordsOf(course.id),
        assessments: state.data.assessmentsOf(course.id),
      );
}

final journalProvider =
    StateNotifierProvider<JournalNotifier, JournalState>((ref) {
  return JournalNotifier(ref.watch(storageServiceProvider));
});

/// Статистика дисциплины: пересчитывается при любом изменении журнала.
final courseStatsProvider =
    Provider.family<CourseStats, String>((ref, courseId) {
  // Слушаем состояние, а не notifier: иначе статистика не пересчитается
  // после изменения балла.
  ref.watch(journalProvider);
  final notifier = ref.read(journalProvider.notifier);
  final course = _firstOrNull(
    notifier.data.courses.where((c) => c.id == courseId),
  );
  if (course == null) return const CourseStats();
  return notifier.statsOf(course);
});

T? _firstOrNull<T>(Iterable<T> items) => items.isEmpty ? null : items.first;
