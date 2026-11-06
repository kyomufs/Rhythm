import 'package:dio/dio.dart';
import 'package:rhythm/core/api/api_exception.dart';
import 'package:rhythm/core/domain/source.dart';
import 'package:rhythm/core/models/schedule.dart';
import 'package:rhythm/core/sources/source_api.dart';
import 'package:rhythm/core/sources/source_provider.dart';
import 'package:rhythm/core/utils/error_messages.dart';

/// Эндпоинты ТулГУ. Всё, что знает про конкретный вуз, живёт здесь.
class TulsuEndpoints {
  TulsuEndpoints._();

  static const String baseUrl = 'https://tulsu.ru/schedule/queries';
  static const String progressBaseUrl = 'https://tulsu.ru/progress/queries';

  static const String dictionaries = '/GetDictionaries.php';
  static const String dates = '/GetDates.php';
  static const String schedule = '/GetSchedule.php';
  static const String calendar = '/GetCalendar.php';
  static const String marks = '/GetMarks.php';
}

Dio _newDio(String baseUrl) => Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Accept': 'application/json'},
    ));

/// Расписание ТулГУ.
class TulsuScheduleApi extends ScheduleApi {
  final Dio _dio;
  final String baseUrl;

  TulsuScheduleApi({this.baseUrl = TulsuEndpoints.baseUrl})
      : _dio = _newDio(baseUrl);

  @override
  Future<List<SourceSuggestion>> search(String query) async {
    if (query.isEmpty) return const [];
    final response = await _guard(
      () => _dio.get<List<dynamic>>(
        TulsuEndpoints.dictionaries,
        queryParameters: {'term': query},
      ),
    );
    return (response.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map((item) => SourceSuggestion(
              value: '${item['value'] ?? ''}',
              sort: '${item['SORT'] ?? ''}',
            ))
        .toList();
  }

  @override
  Future<SourceDateRange> dateRange(String searchValue) async {
    final response = await _guard(
      () => _dio.get<Map<String, dynamic>>(
        TulsuEndpoints.dates,
        queryParameters: {'search_value': searchValue},
      ),
    );
    final data = Map<String, dynamic>.from(response.data ?? const {});
    return SourceDateRange(
      minDate: DateTime.parse(data['MIN_DATE'] as String),
      maxDate: DateTime.parse(data['MAX_DATE'] as String),
      searchField: SearchField.values.firstWhere(
        (f) => f.value == data['SEARCH_FIELD'],
        orElse: () => SearchField.group,
      ),
    );
  }

  @override
  Future<List<ScheduleItem>> lessons({
    required String searchField,
    required String searchValue,
  }) async {
    final response = await _guard(
      () => _dio.get<List<dynamic>>(
        TulsuEndpoints.schedule,
        queryParameters: {
          'search_field': searchField,
          'search_value': searchValue,
        },
      ),
    );
    return (response.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(_parseLesson)
        .toList();
  }

  @override
  Future<List<CalendarItem>> calendar(String searchValue) async {
    final response = await _guard(
      () => _dio.get<List<dynamic>>(
        TulsuEndpoints.calendar,
        queryParameters: {'search_value': searchValue},
      ),
    );
    return (response.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(_parseCalendar)
        .toList();
  }

  Future<Response<T>> _guard<T>(Future<Response<T>> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw ApiException(ErrorMessages.fromException(e));
    }
  }
}

ScheduleItem _parseLesson(Map<String, dynamic> json) {
  return ScheduleItem(
    date: '${json['DATE_Z'] ?? ''}',
    time: '${json['TIME_Z'] ?? ''}',
    subject: '${json['DISCIP'] ?? ''}',
    type: '${json['KOW'] ?? ''}',
    classroom: '${json['AUD'] ?? ''}',
    teacher: '${json['PREP'] ?? ''}',
    groups: (json['GROUPS'] as List?)
            ?.map((g) => GroupInfo.fromJson(Map<String, dynamic>.from(g as Map)))
            .toList() ??
        const [],
    cssClass: '${json['CLASS'] ?? ''}',
  );
}

CalendarItem _parseCalendar(Map<String, dynamic> json) {
  return CalendarItem.fromJson(json);
}

/// Итоговые оценки ТулГУ.
class TulsuFinalMarksApi implements FinalMarksApi {
  final Dio _dio;

  TulsuFinalMarksApi({String baseUrl = TulsuEndpoints.progressBaseUrl})
      : _dio = _newDio(baseUrl);

  @override
  Future<List<FinalMark>> finalMarks({
    required String studentId,
    required String group,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        TulsuEndpoints.marks,
        queryParameters: {
          'PERSONALAFFAIR': studentId,
          'GROUP_TITLE': group,
        },
      );
      return (response.data ?? const [])
          .cast<Map<String, dynamic>>()
          .map((json) => FinalMark(
                term: '${json['TERM'] ?? ''}',
                discipline: '${json['DISCIPLINE'] ?? ''}',
                markTitle: '${json['MARK_TITLE'] ?? ''}',
                teacherMark: '${json['TEACHER_MARK'] ?? ''}',
                retake: '${json['RETAKE'] ?? ''}',
                recredit: '${json['RECREDIT']}' == '1',
              ))
          .toList();
    } on DioException catch (e) {
      throw ApiException(ErrorMessages.fromException(e));
    }
  }
}

/// Возможности источника ТулГУ — единственное место, где перечислены
/// его API-поверхности.
class TulsuSourceProvider extends SourceProvider {
  const TulsuSourceProvider();

  @override
  String get id => 'tulsu';

  @override
  String get label => 'ТулГУ';

  @override
  Set<SourceCapability> get capabilities => const {
        SourceCapability.directory,
        SourceCapability.schedule,
        SourceCapability.calendar,
        SourceCapability.finalMarks,
        SourceCapability.profile,
      };

  @override
  ScheduleApi scheduleApi(Source source) => TulsuScheduleApi(
        baseUrl: source.config['baseUrl'] ?? TulsuEndpoints.baseUrl,
      );

  @override
  FinalMarksApi? marksApi(Source source) => TulsuFinalMarksApi(
        baseUrl: source.config['progressBaseUrl'] ?? TulsuEndpoints.progressBaseUrl,
      );

  @override
  String? groupOf(Source source) =>
      source.config['group'] ?? source.config['groupId'];

  @override
  Future<bool> ping() async {
    try {
      await _newDio(TulsuEndpoints.baseUrl).get<dynamic>(
        TulsuEndpoints.dates,
        queryParameters: {'search_value': ''},
      );
      return true;
    } on DioException {
      return false;
    }
  }
}
