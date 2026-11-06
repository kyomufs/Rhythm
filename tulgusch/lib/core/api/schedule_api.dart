import 'package:tulgusch/core/models/schedule.dart';

/// Что API ТулГУ отдаёт наружу. Реализация одна — [TulsuScheduleApi];
/// интерфейс нужен тестам и экранам, которые не должны знать про HTTP.
abstract class ScheduleApi {
  const ScheduleApi();

  Future<List<ScheduleSuggestion>> search(String query);

  /// Доступен ли API прямо сейчас — дешёвый запрос без разбора ответа.
  Future<bool> ping();
  Future<ScheduleDateRange> dateRange(String searchValue);
  Future<List<ScheduleItem>> lessons({
    required String searchField,
    required String searchValue,
  });
  Future<List<CalendarItem>> calendar(String searchValue);

  /// Диапазон + пары + календарь одним заходом.
  Future<ScheduleBundle> fullSchedule(String searchValue) async {
    final range = await dateRange(searchValue);
    final lessons = await this.lessons(
      searchField: range.searchField.value,
      searchValue: searchValue,
    );
    final calendar = await this.calendar(searchValue);
    return ScheduleBundle(
      dateRange: range,
      lessons: lessons,
      calendar: calendar,
    );
  }
}

/// Подсказка автодополнения: номер группы из справочника вуза.
class ScheduleSuggestion {
  final String value;
  final String sort;

  const ScheduleSuggestion({required this.value, this.sort = ''});
}

class ScheduleDateRange {
  final DateTime minDate;
  final DateTime maxDate;
  final SearchField searchField;

  const ScheduleDateRange({
    required this.minDate,
    required this.maxDate,
    required this.searchField,
  });
}

class ScheduleBundle {
  final ScheduleDateRange dateRange;
  final List<ScheduleItem> lessons;
  final List<CalendarItem> calendar;

  const ScheduleBundle({
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

abstract class FinalMarksApi {
  Future<List<FinalMark>> finalMarks({
    required String studentId,
    required String group,
  });
}
