import 'package:dio/dio.dart';
import 'package:rhythm/core/api/api_exception.dart';
import 'package:rhythm/core/models/schedule.dart';
import 'package:rhythm/core/sources/source_api.dart';
import 'package:rhythm/core/utils/error_messages.dart';
import 'package:rhythm/integrations/api/bmstu/week_grid.dart';

/// Эндпоинты ЛКС МГТУ. Префикс `/lks-back` — рабочий: публичный `/api/v1`
/// отдаёт SPA-заглушку.
class BmstuEndpoints {
  BmstuEndpoints._();

  static const String baseUrl = 'https://lks.bmstu.ru/lks-back/api/v1';
  static const String structure = '/structure';
  static const String current = '/schedules/current';

  static String groupSchedule(String groupUuid) =>
      '/schedules/groups/$groupUuid/public';
}

class BmstuGroup {
  final String uuid;
  final String abbr;
  final int course;

  const BmstuGroup({
    required this.uuid,
    required this.abbr,
    this.course = 0,
  });
}

class _BmstuCurrent {
  final DateTime semesterStart;
  final DateTime semesterEnd;

  const _BmstuCurrent({required this.semesterStart, required this.semesterEnd});
}

/// Расписание BMSTU: недельная сетка, которую надо развернуть в даты.
class BmstuScheduleApi extends ScheduleApi {
  final Dio _dio;

  /// Дерево вуза весит ~700 КБ и за сеанс не меняется: тянем один раз.
  static List<BmstuGroup>? _structureCache;

  BmstuScheduleApi({String baseUrl = BmstuEndpoints.baseUrl})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'Accept': 'application/json'},
        ));

  @override
  Future<List<SourceSuggestion>> search(String query) async {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const [];
    final groups = await _structure();
    return groups
        .where((g) => g.abbr.toLowerCase().contains(needle))
        .take(20)
        .map((g) => SourceSuggestion(value: g.uuid, sort: g.abbr))
        .toList();
  }

  @override
  Future<SourceDateRange> dateRange(String searchValue) async {
    final current = await _current();
    return SourceDateRange(
      minDate: current.semesterStart,
      maxDate: current.semesterEnd,
      searchField: SearchField.group,
    );
  }

  @override
  Future<List<ScheduleItem>> lessons({
    required String searchField,
    required String searchValue,
  }) async {
    final responses = await Future.wait([
      _current(),
      _groupSchedule(searchValue),
    ]);
    final current = responses[0] as _BmstuCurrent;
    final grid = responses[1] as List<Map<String, dynamic>>;

    final items = <ScheduleItem>[];
    for (final raw in grid) {
      final day = raw['day'];
      if (day is! int || day < 1 || day > 7) continue;
      final parity = parseWeekParity('${raw['week']}');
      final startTime = '${raw['startTime'] ?? ''}';
      final endTime = '${raw['endTime'] ?? ''}';
      final dates = datesForWeekday(
        from: current.semesterStart,
        to: current.semesterEnd,
        weekday: day,
        parity: parity,
        semesterStart: current.semesterStart,
      );
      for (final date in dates) {
        items.add(ScheduleItem(
          date: _dotted(date),
          time: startTime.isEmpty ? '' : '$startTime - $endTime',
          subject: _disciplineName(raw['discipline']),
          type: _actTypeLabel(raw['discipline']),
          classroom: _joinNames(raw['audiences']),
          teacher: _teacherNames(raw['teachers']),
          groups: _groups(raw['groups']),
          cssClass: _cssClass(raw['discipline']),
        ));
      }
    }
    items.sort((a, b) {
      final byDate = a.parsedDate.compareTo(b.parsedDate);
      if (byDate != 0) return byDate;
      return a.time.compareTo(b.time);
    });
    return items;
  }

  /// Праздников и каникул в API нет — календарь остаётся пустым.
  @override
  Future<List<CalendarItem>> calendar(String searchValue) async => const [];

  Future<_BmstuCurrent> _current() async {
    final response = await _guard(
      () => _dio.get<Map<String, dynamic>>(BmstuEndpoints.current),
    );
    final data = Map<String, dynamic>.from(
      (response.data?['data'] as Map?) ?? const {},
    );
    return _BmstuCurrent(
      semesterStart:
          DateTime.tryParse('${data['semesterStarts']}') ?? DateTime.now(),
      semesterEnd:
          DateTime.tryParse('${data['semesterEnds']}') ?? DateTime.now(),
    );
  }

  Future<List<Map<String, dynamic>>> _groupSchedule(String uuid) async {
    final response = await _guard(
      () => _dio.get<Map<String, dynamic>>(
        BmstuEndpoints.groupSchedule(uuid),
      ),
    );
    final data = response.data?['data'];
    if (data is! Map<String, dynamic>) return const [];
    final schedule = data['schedule'];
    if (schedule is! List) return const [];
    return schedule
        .whereType<Map<String, dynamic>>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<BmstuGroup>> _structure() async {
    final cached = _structureCache;
    if (cached != null) return cached;
    final response = await _guard(
      () => _dio.get<Map<String, dynamic>>(BmstuEndpoints.structure),
    );
    final groups = <BmstuGroup>[];
    _collectGroups(response.data?['data'], groups);
    _structureCache = groups;
    return groups;
  }

  void _collectGroups(Object? node, List<BmstuGroup> out) {
    if (node is! Map) return;
    if (node['nodeType'] == 'group') {
      final uuid = '${node['uuid'] ?? ''}';
      final abbr = '${node['abbr'] ?? ''}';
      if (uuid.isNotEmpty && abbr.isNotEmpty) {
        out.add(BmstuGroup(
          uuid: uuid,
          abbr: abbr,
          course: node['course'] is int ? node['course'] as int : 0,
        ));
      }
      return;
    }
    final children = node['children'];
    if (children is List) {
      for (final child in children) {
        _collectGroups(child, out);
      }
    }
  }

  Future<Response<T>> _guard<T>(Future<Response<T>> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw ApiException(ErrorMessages.fromException(e));
    }
  }
}

String _dotted(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}

String _disciplineName(Object? discipline) {
  if (discipline is! Map) return '';
  final full = '${discipline['fullName'] ?? ''}'.trim();
  if (full.isNotEmpty) return full;
  return '${discipline['abbr'] ?? ''}'.trim();
}

String _cssClass(Object? discipline) {
  if (discipline is! Map) return '';
  return '${discipline['actType'] ?? ''}';
}

String _actTypeLabel(Object? discipline) {
  if (discipline is! Map) return '';
  switch ('${discipline['actType'] ?? ''}') {
    case 'lecture':
      return 'Лекция';
    case 'lab':
      return 'Лабораторная';
    case 'practice':
      return 'Практика';
    case 'seminar':
      return 'Семинар';
    default:
      return '';
  }
}

String _joinNames(Object? list) {
  if (list is! List) return '';
  final names = list
      .whereType<Map<String, dynamic>>()
      .map((item) => '${item['name'] ?? ''}'.trim())
      .where((name) => name.isNotEmpty)
      .toList();
  return names.join(', ');
}

String _teacherNames(Object? list) {
  if (list is! List) return '';
  final names = list
      .whereType<Map<String, dynamic>>()
      .map((item) {
        final last = '${item['lastName'] ?? ''}'.trim();
        final first = '${item['firstName'] ?? ''}'.trim();
        final middle = '${item['middleName'] ?? ''}'.trim();
        final initials = [
          if (first.isNotEmpty) '${first[0]}.',
          if (middle.isNotEmpty) '${middle[0]}.',
        ].join(' ');
        return '$last $initials'.trim();
      })
      .where((name) => name.isNotEmpty)
      .toList();
  return names.join(', ');
}

List<GroupInfo> _groups(Object? list) {
  if (list is! List) return const [];
  return list
      .whereType<Map<String, dynamic>>()
      .map((item) => GroupInfo(number: '${item['name'] ?? ''}'.trim()))
      .where((group) => group.number.isNotEmpty)
      .toList();
}
