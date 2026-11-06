import 'package:flutter_test/flutter_test.dart';
import 'package:uniflow/core/domain/journal.dart';
import 'package:uniflow/core/models/schedule.dart';

Course _course({GradeScale? scale}) => Course(
      id: 'c1',
      termId: 't1',
      title: 'Математика',
      scale: scale ?? defaultGradeScale(),
    );

void main() {
  group('шкала', () {
    test('пресет 60 + 40 даёт сотню и экзаменационные 40', () {
      final scale = gradeScalePresets.first.build();
      expect(scale.totalMax, 100);
      expect(scale.examMax, 40);
      expect(scale.currentMax, 60);
      expect(scale.isConsistent, isTrue);
    });

    test('категория находится по типу пары', () {
      final scale = defaultGradeScale();
      expect(scale.categoryForLesson(LessonType.practice)?.maxPoints, 60);
      expect(scale.categoryForLesson(LessonType.lecture), isNull);
      expect(scale.categoryForLesson(LessonType.unknown), isNull);
    });

    test('оценка по проценту', () {
      final scale = defaultGradeScale();
      expect(scale.gradeForPercent(90), 5);
      expect(scale.gradeForPercent(70), 4);
      expect(scale.gradeForPercent(55), 3);
      expect(scale.gradeForPercent(20), 2);
    });
  });

  group('статистика дисциплины', () {
    final course = _course();
    final practiceId = course.scale.categories.first.id;
    final examId = course.scale.categories.last.id;
    final now = DateTime.now();

    final records = [
      LessonRecord(
        id: 'l1',
        courseId: course.id,
        date: now,
        slot: 1,
        type: LessonType.practice,
        points: 10,
      ),
      LessonRecord(
        id: 'l2',
        courseId: course.id,
        date: now,
        slot: 2,
        type: LessonType.practice,
        attendance: Attendance.late,
        points: 8,
      ),
      LessonRecord(
        id: 'l3',
        courseId: course.id,
        date: now,
        slot: 3,
        type: LessonType.practice,
        attendance: Attendance.absent,
      ),
      LessonRecord(
        id: 'l4',
        courseId: course.id,
        date: now,
        slot: 4,
        type: LessonType.practice,
        points: 5,
      ),
    ];

    final assessments = [
      Assessment(
        id: 'a1',
        courseId: course.id,
        categoryId: examId,
        title: 'Экзамен',
        maxPoints: 40,
        earnedPoints: 30,
        status: AssessmentStatus.graded,
      ),
      Assessment(
        id: 'a2',
        courseId: course.id,
        categoryId: practiceId,
        title: 'Контрольная',
        maxPoints: 10,
        dueDate: now.add(const Duration(days: 2)),
      ),
      Assessment(
        id: 'a3',
        courseId: course.id,
        categoryId: practiceId,
        title: 'Домашка',
        maxPoints: 5,
        dueDate: now.subtract(const Duration(days: 3)),
      ),
    ];

    test('баллы пар и событий сводятся по категориям', () {
      final stats = computeCourseStats(
        course: course,
        records: records,
        assessments: assessments,
      );
      expect(stats.categories.first.earned, 23);
      expect(stats.categories.last.earned, 30);
      expect(stats.total, 53);
      expect(stats.totalMax, 100);
      expect(stats.percent, closeTo(0.53, 0.001));
    });

    test('посещение, дедлайны и прогноз', () {
      final stats = computeCourseStats(
        course: course,
        records: records,
        assessments: assessments,
      );
      expect(stats.lessons, 4);
      expect(stats.visited, 3);
      expect(stats.missed, 1);
      expect(stats.overdue, 1);
      expect(
        stats.nextDeadline!.difference(now).inDays,
        inInclusiveRange(1, 2),
      );
      expect(stats.predictedGrade, 3);
      expect(stats.pointsToPass, 7);
    });

    test('баллы не превышают максимум категории', () {
      final stats = computeCourseStats(
        course: course,
        records: [
          LessonRecord(
            id: 'x',
            courseId: course.id,
            date: now,
            slot: 1,
            type: LessonType.practice,
            points: 80,
          ),
        ],
        assessments: const [],
      );
      expect(stats.categories.first.earned, 60);
      expect(stats.total, 60);
    });
  });

  group('номер пары', () {
    test('время начала переводится в номер', () {
      expect(lessonSlotFromTime('08:30 - 10:00'), 1);
      expect(lessonSlotFromTime('10:15 - 11:50'), 2);
      expect(lessonSlotFromTime('16:15 - 17:50'), 5);
      expect(lessonSlotFromTime(''), 0);
    });
  });

  group('json', () {
    test('журнал переживает сериализацию', () {
      final term = Term(
        id: 't1',
        sourceId: 's1',
        title: 'Осень',
        start: DateTime(2026, 9, 1),
        end: DateTime(2026, 12, 31),
      );
      final data = JournalData(
        terms: [term],
        courses: const [Course(id: 'c1', termId: 't1', title: 'Математика')],
        records: [
          LessonRecord(
            id: 'l1',
            courseId: 'c1',
            date: DateTime(2026, 9, 2),
            slot: 2,
            type: LessonType.lab,
            attendance: Attendance.absent,
            reason: 'Болезнь',
            points: 4,
          ),
        ],
      );
      final restored = JournalData.fromJson(data.toJson());
      expect(restored.terms.single.title, 'Осень');
      expect(restored.courses.single.title, 'Математика');
      expect(restored.records.single.reason, 'Болезнь');
      expect(restored.records.single.points, 4);
      expect(restored.records.single.attendance, Attendance.absent);
    });
  });
}
