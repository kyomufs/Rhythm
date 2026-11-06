import 'package:uniflow/core/api/api_exception.dart';
import 'package:uniflow/core/models/schedule.dart';

/// Канонические модели источников. Провайдер (вуз, школа, работа)
/// приводит свои ответы к этому виду, экраны видят только их.

class SourceSuggestion {
  final String value;
  final String sort;

  const SourceSuggestion({required this.value, this.sort = ''});
}

class SourceDateRange {
  final DateTime minDate;
  final DateTime maxDate;
  final SearchField searchField;

  const SourceDateRange({
    required this.minDate,
    required this.maxDate,
    required this.searchField,
  });
}

class SourceSchedule {
  final SourceDateRange dateRange;
  final List<ScheduleItem> lessons;
  final List<CalendarItem> calendar;

  const SourceSchedule({
    required this.dateRange,
    required this.lessons,
    required this.calendar,
  });
}

/// Итоговая оценка из API. Баллы за пары сюда не входят: их в API нет.
class FinalMark {
  final String term;
  final String discipline;
  final String markTitle;
  final String teacherMark;
  final String retake;
  final bool recredit;

  const FinalMark({
    required this.term,
    required this.discipline,
    required this.markTitle,
    this.teacherMark = '',
    this.retake = '',
    this.recredit = false,
  });

  int get termNumber => int.tryParse(term) ?? 0;
  bool get isAttested => markTitle.isNotEmpty;
}

abstract class ScheduleApi {
  const ScheduleApi();


  Future<List<SourceSuggestion>> search(String query);
  Future<SourceDateRange> dateRange(String searchValue);
  Future<List<ScheduleItem>> lessons({
    required String searchField,
    required String searchValue,
  });
  Future<List<CalendarItem>> calendar(String searchValue);

  /// Полный набор: диапазон + пары + календарь. Провайдеру достаточно
  /// реализовать четыре метода выше.
  Future<SourceSchedule> fullSchedule(String searchValue) async {
    final range = await dateRange(searchValue);
    final lessons = await this.lessons(
      searchField: range.searchField.value,
      searchValue: searchValue,
    );
    final calendar = await this.calendar(searchValue);
    return SourceSchedule(
      dateRange: range,
      lessons: lessons,
      calendar: calendar,
    );
  }
}

abstract class FinalMarksApi {
  Future<List<FinalMark>> finalMarks({
    required String studentId,
    required String group,
  });
}

/// Источник без расписания: экран покажет сообщение, а не упадёт.
class UnavailableScheduleApi extends ScheduleApi {
  final String reason;

  const UnavailableScheduleApi([
    this.reason = 'У этого источника нет API расписания',
  ]);

  Never _fail() => throw ApiException(reason);

  @override
  Future<List<SourceSuggestion>> search(String query) async => _fail();

  @override
  Future<SourceDateRange> dateRange(String searchValue) async => _fail();

  @override
  Future<List<ScheduleItem>> lessons({
    required String searchField,
    required String searchValue,
  }) async =>
      _fail();

  @override
  Future<List<CalendarItem>> calendar(String searchValue) async => _fail();
}
