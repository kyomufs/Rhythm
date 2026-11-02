import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uniflow/core/api/endpoints.dart';
import 'package:uniflow/core/models/schedule.dart';
import 'package:uniflow/core/utils/error_messages.dart';

/// Provider for API client
final apiClientProvider = Provider<TulsuApiClient>((ref) {
  return TulsuApiClient();
});

/// TULSU Schedule API Client
class TulsuApiClient {
  late final Dio _dio;

  TulsuApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: TulsuEndpoints.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Accept': 'application/json'},
    ));
  }

  /// Search for groups, teachers, or auditoriums
  Future<List<SearchSuggestion>> search(String query) async {
    if (query.isEmpty) return [];
    try {
      final response = await _dio.get<List<dynamic>>(
        TulsuEndpoints.dictionaries,
        queryParameters: {'term': query},
      );
      final data = (response.data as List).cast<Map<String, dynamic>>();
      return data.map((item) => SearchSuggestion.fromJson(item)).toList();
    } on DioException catch (e) {
      throw ApiException(ErrorMessages.fromException(e));
    }
  }

  /// Get date range for schedule
  Future<ApiDateRange> getDateRange(String searchValue) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        TulsuEndpoints.dates,
        queryParameters: {'search_value': searchValue},
      );
      return ApiDateRange.fromJson(
          Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (e) {
      throw ApiException(ErrorMessages.fromException(e));
    }
  }

  /// Get schedule data
  Future<List<ScheduleItem>> getSchedule(
      String searchField, String searchValue) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        TulsuEndpoints.schedule,
        queryParameters: {
          'search_field': searchField,
          'search_value': searchValue,
        },
      );
      final data = (response.data as List).cast<Map<String, dynamic>>();
      return data.map((item) => ScheduleItem.fromJson(item)).toList();
    } on DioException catch (e) {
      throw ApiException(ErrorMessages.fromException(e));
    }
  }

  /// Get academic calendar
  Future<List<CalendarItem>> getCalendar(String searchValue) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        TulsuEndpoints.calendar,
        queryParameters: {'search_value': searchValue},
      );
      final data = (response.data as List).cast<Map<String, dynamic>>();
      return data.map((item) => CalendarItem.fromJson(item)).toList();
    } on DioException catch (e) {
      throw ApiException(ErrorMessages.fromException(e));
    }
  }

  /// Get complete schedule with all data
  Future<ScheduleData> getFullSchedule(String searchValue) async {
    final dateRange = await getDateRange(searchValue);
    final schedule =
        await getSchedule(dateRange.searchField.value, searchValue);
    final calendar = await getCalendar(searchValue);
    return ScheduleData(
      dateRange: dateRange,
      items: schedule,
      calendar: calendar,
    );
  }
}

/// Date range from API
class ApiDateRange {
  final DateTime minDate;
  final DateTime maxDate;
  final SearchFieldType searchField;

  const ApiDateRange({
    required this.minDate,
    required this.maxDate,
    required this.searchField,
  });

  factory ApiDateRange.fromJson(Map<String, dynamic> json) {
    return ApiDateRange(
      minDate: DateTime.parse(json['MIN_DATE'] as String),
      maxDate: DateTime.parse(json['MAX_DATE'] as String),
      searchField: SearchFieldType.values.firstWhere(
        (e) => e.value == json['SEARCH_FIELD'],
      ),
    );
  }
}

/// Search suggestion model
class SearchSuggestion {
  final String value;
  final String sort;

  const SearchSuggestion({required this.value, required this.sort});

  factory SearchSuggestion.fromJson(Map<String, dynamic> json) {
    return SearchSuggestion(
      value: json['value'] as String,
      sort: json['SORT'] as String,
    );
  }
}

/// Complete schedule data
class ScheduleData {
  final ApiDateRange dateRange;
  final List<ScheduleItem> items;
  final List<CalendarItem> calendar;

  const ScheduleData({
    required this.dateRange,
    required this.items,
    required this.calendar,
  });
}

/// API Exception
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}

// ============================================================
// Marks API (separate client for progress endpoint)
// ============================================================

/// Provider for progress API client
final progressApiClientProvider = Provider<ProgressApiClient>((ref) {
  return ProgressApiClient();
});

/// TULSU Progress API Client
class ProgressApiClient {
  late final Dio _dio;

  ProgressApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: TulsuProgressEndpoints.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Accept': 'application/json'},
    ));
  }

  /// Get marks for a student
  Future<List<MarksItem>> getMarks({
    required String personalAffair,
    required String groupTitle,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        TulsuProgressEndpoints.marks,
        queryParameters: {
          'PERSONALAFFAIR': personalAffair,
          'GROUP_TITLE': groupTitle,
        },
      );
      final data = (response.data as List).cast<Map<String, dynamic>>();
      return data.map((item) => MarksItem.fromJson(item)).toList();
    } on DioException catch (e) {
      throw ApiException(ErrorMessages.fromException(e));
    }
  }
}

/// Single marks entry from the progress API
class MarksItem {
  final String term;
  final String discipline;
  final String mark;
  final String markTitle;
  final String teacherMark;
  final String retake;
  final bool recredit;

  const MarksItem({
    required this.term,
    required this.discipline,
    required this.mark,
    required this.markTitle,
    required this.teacherMark,
    required this.retake,
    required this.recredit,
  });

  int get termNumber => int.tryParse(term) ?? 0;

  bool get isAttested => markTitle.isNotEmpty;

  factory MarksItem.fromJson(Map<String, dynamic> json) {
    return MarksItem(
      term: '${json['TERM'] ?? ''}',
      discipline: '${json['DISCIPLINE'] ?? ''}',
      mark: '${json['MARK'] ?? ''}',
      markTitle: '${json['MARK_TITLE'] ?? ''}',
      teacherMark: '${json['TEACHER_MARK'] ?? ''}',
      retake: '${json['RETAKE'] ?? ''}',
      recredit: '${json['RECREDIT']}' == '1',
    );
  }

  Map<String, dynamic> toJson() => {
        'TERM': term,
        'DISCIPLINE': discipline,
        'MARK': mark,
        'MARK_TITLE': markTitle,
        'TEACHER_MARK': teacherMark,
        'RETAKE': retake,
        'RECREDIT': recredit ? '1' : '0',
      };
}
