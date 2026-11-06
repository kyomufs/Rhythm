import 'package:flutter_test/flutter_test.dart';
import 'package:rhythm/core/domain/journal.dart';
import 'package:rhythm/core/journal/journal_store.dart';
import 'package:rhythm/core/models/schedule.dart';
import 'package:rhythm/core/services/storage_service.dart';

class _FakeStorage extends StorageService {
  JournalData data = const JournalData();

  @override
  bool get isInitialized => true;

  @override
  JournalData getJournal(String sourceId) => data;

  @override
  Future<void> saveJournal(String sourceId, JournalData value) async {
    data = value;
  }
}

ScheduleItem _item(
  String date,
  String time,
  String subject, {
  String type = 'Практические',
  String teacher = 'Иванов И.И.',
}) {
  return ScheduleItem(
    date: date,
    time: time,
    subject: subject,
    type: type,
    classroom: '1-101',
    teacher: teacher,
    groups: const [],
    cssClass: '',
  );
}

void main() {
  test('импорт заводит семестр, дисциплины и пары из расписания', () {
    final storage = _FakeStorage();
    final notifier = JournalNotifier(storage, 's1');

    final result = notifier.importSchedule([
      _item('10.09.2026', '08:30 - 10:00', 'Математика'),
      _item('17.09.2026', '10:15 - 11:45', 'Математика'),
      _item('11.09.2026', '12:00 - 13:30', 'Физика', type: 'Лекции'),
      _item('12.09.2026', '12:00 - 13:30', ''),
    ]);

    expect(result.courses, 2);
    expect(result.lessons, 3);

    final data = notifier.state.data;
    expect(data.terms, hasLength(1));
    expect(data.terms.single.title, 'Осенний семестр 2026/27');
    expect(data.terms.single.start, DateTime(2026, 9, 10));
    expect(data.terms.single.end, DateTime(2026, 9, 17));

    final math = data.courses.firstWhere((c) => c.title == 'Математика');
    expect(data.recordsOf(math.id), hasLength(2));
    expect(data.recordsOf(math.id).map((r) => r.slot), [1, 2]);
    expect(storage.data.courses, hasLength(2));
  });

  test('повторный импорт ничего не дублирует', () {
    final storage = _FakeStorage();
    final notifier = JournalNotifier(storage, 's1');
    final items = [
      _item('10.09.2026', '08:30 - 10:00', 'Математика'),
      _item('11.09.2026', '10:15 - 11:45', 'Физика'),
    ];

    notifier.importSchedule(items);
    final again = notifier.importSchedule(items);

    expect(again.courses, 0);
    expect(again.lessons, 0);
    expect(notifier.state.data.courses, hasLength(2));
    expect(notifier.state.data.records, hasLength(2));
  });

  test('импорт не стирает ручные правки и баллы', () {
    final storage = _FakeStorage();
    final notifier = JournalNotifier(storage, 's1');
    notifier.importSchedule([_item('10.09.2026', '08:30 - 10:00', 'Математика')]);

    final course = notifier.state.data.courses.single;
    final record = notifier.state.data.records.single;
    notifier.setPoints(record.id, 7);
    notifier.saveAssessment(Assessment(
      id: 'a1',
      courseId: course.id,
      categoryId: course.scale.categories.first.id,
      title: 'Контрольная',
      maxPoints: 20,
      dueDate: DateTime(2026, 10, 1),
    ));

    final result =
        notifier.importSchedule([_item('17.09.2026', '10:15 - 11:45', 'Математика')]);

    expect(result.courses, 0);
    expect(result.lessons, 1);
    final data = notifier.state.data;
    expect(data.recordsOf(course.id), hasLength(2));
    expect(data.records.firstWhere((r) => r.id == record.id).points, 7);
    expect(data.assessments, hasLength(1));
  });

  test('импорт за весь учебный год делит его на два семестра', () {
    final storage = _FakeStorage();
    final notifier = JournalNotifier(storage, 's1');

    final result = notifier.importSchedule([
      _item('05.09.2026', '08:30 - 10:00', 'Математика'),
      _item('15.01.2027', '08:30 - 10:00', 'Математика'),
      _item('10.02.2027', '08:30 - 10:00', 'Математика'),
      _item('20.05.2027', '08:30 - 10:00', 'Математика'),
    ]);

    final data = notifier.state.data;
    expect(result.courses, 2);
    expect(result.lessons, 4);
    expect(data.terms, hasLength(2));
    expect(data.terms.map((t) => t.title), [
      'Осенний семестр 2026/27',
      'Весенний семестр 2026/27',
    ]);
    expect(data.courses.map((c) => c.termId).toSet(), hasLength(2));
    expect(
      data.terms.map((t) => data.coursesOf(t.id).length),
      [1, 1],
    );
  });

  test('удаление пары убирает только её', () {
    final storage = _FakeStorage();
    final notifier = JournalNotifier(storage, 's1');
    notifier.importSchedule([
      _item('10.09.2026', '08:30 - 10:00', 'Математика'),
      _item('17.09.2026', '10:15 - 11:45', 'Математика'),
    ]);

    notifier.deleteLesson(notifier.state.data.records.first.id);

    expect(notifier.state.data.records, hasLength(1));
    expect(notifier.state.data.courses, hasLength(1));
  });
}
