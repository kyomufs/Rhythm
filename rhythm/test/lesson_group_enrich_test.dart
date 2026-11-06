import 'package:flutter_test/flutter_test.dart';
import 'package:rhythm/core/models/schedule.dart';
import 'package:rhythm/core/sources/source_api.dart';
import 'package:rhythm/core/services/lesson_group_resolver.dart';

/// API-заглушка: расписание группы отдаёт одну свою группу, расписание
/// аудитории — все группы пары. Второй ответ и есть источник полного списка.
class _FakeApi extends ScheduleApi {
  _FakeApi({required this.roomItems});

  final List<ScheduleItem> roomItems;
  int roomCalls = 0;

  @override
  Future<List<ScheduleItem>> lessons({
    required String searchField,
    required String searchValue,
  }) async {
    if (searchField == SearchField.auditorium.value) {
      roomCalls++;
      return roomItems;
    }
    return const [];
  }

  @override
  Future<SourceDateRange> dateRange(String searchValue) async => SourceDateRange(
        minDate: DateTime(2026, 9, 1),
        maxDate: DateTime(2027, 1, 25),
        searchField: SearchField.group,
      );

  @override
  Future<List<CalendarItem>> calendar(String searchValue) async => [];

  @override
  Future<List<SourceSuggestion>> search(String query) async => [];
}

ScheduleItem _item({
  required String subject,
  String date = '05.11.2026',
  String time = '10:00 - 11:30',
  String classroom = 'Гл.-408',
  List<GroupInfo> groups = const [GroupInfo(number: '221341:01')],
}) {
  return ScheduleItem(
    date: date,
    time: time,
    subject: subject,
    type: 'Лекции',
    classroom: classroom,
    teacher: 'Двоенко Сергей Данилович',
    groups: groups,
    cssClass: 'lecture',
  );
}

void main() {
  final weekStart = DateTime(2026, 11, 2);

  test('добор групп дописывает полный список в пары недели', () async {
    final api = _FakeApi(roomItems: [
      _item(
        subject: 'Математический анализ',
        groups: const [
          GroupInfo(number: '221341:01'),
          GroupInfo(number: '221341:02'),
          GroupInfo(number: '220431'),
        ],
      ),
    ]);
    final resolver = LessonGroupResolver(api);

    final items = await resolver.enrich(
      [_item(subject: 'Математический анализ')],
      weekStart: weekStart,
    );

    expect(items.single.groups, hasLength(3),
        reason: 'группы пришли вместе с расписанием, без открытия карточки');
    expect(items.single.groups.map((g) => g.number),
        containsAll(<String>['221341:02', '220431']));
    expect(api.roomCalls, 1, reason: 'одна аудитория — один запрос');
  });

  test('пары вне недели и пары с готовым списком не запрашиваются', () async {
    final api = _FakeApi(roomItems: const []);
    final resolver = LessonGroupResolver(api);

    final items = await resolver.enrich(
      [
        _item(subject: 'Вне недели', date: '20.11.2026'),
        _item(
          subject: 'Полный список',
          groups: const [
            GroupInfo(number: '221341:01'),
            GroupInfo(number: '221341:02'),
          ],
        ),
      ],
      weekStart: weekStart,
    );

    expect(api.roomCalls, 0);
    expect(identical(items, items), isTrue);
  });

  test('без найденной пары в аудитории исходный список не меняется', () async {
    final api = _FakeApi(roomItems: [_item(subject: 'Другая пара')]);
    final resolver = LessonGroupResolver(api);

    final original = [_item(subject: 'Математический анализ')];
    final items = await resolver.enrich(original, weekStart: weekStart);

    expect(items.single.groups, hasLength(1));
    expect(items.single.groups.single.number, '221341:01');
  });
}
