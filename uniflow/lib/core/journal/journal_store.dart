import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uniflow/core/domain/journal.dart';
import 'package:uniflow/core/models/schedule.dart';
import 'package:uniflow/core/services/storage_service.dart';
import 'package:uniflow/core/sources/source_store.dart';

class JournalState {
  final JournalData data;
  final bool isReady;

  const JournalState({this.data = const JournalData(), this.isReady = false});

  JournalState copyWith({JournalData? data, bool? isReady}) =>
      JournalState(data: data ?? this.data, isReady: isReady ?? this.isReady);
}

/// Журнал активного источника. Всё пишется сразу: балл на паре и
/// посещаемость не должно теряться из-за незакрытого экрана.
class JournalNotifier extends StateNotifier<JournalState> {
  final StorageService _storage;
  final String sourceId;

  JournalNotifier(this._storage, this.sourceId) : super(const JournalState()) {
    state = JournalState(
      data: sourceId.isEmpty ? const JournalData() : _storage.getJournal(sourceId),
      isReady: true,
    );
  }

  void _write(JournalData data) {
    state = state.copyWith(data: data);
    if (sourceId.isNotEmpty) _storage.saveJournal(sourceId, data);
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
      sourceId: sourceId,
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
  final source = ref.watch(activeSourceProvider);
  return JournalNotifier(
    ref.watch(storageServiceProvider),
    source?.id ?? '',
  );
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
