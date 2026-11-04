import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uniflow/core/api/endpoints.dart';
import 'package:uniflow/core/api/tulsu_api.dart';
import 'package:uniflow/core/models/schedule.dart';

/// Provider for the lesson group resolver
final lessonGroupResolverProvider = Provider<LessonGroupResolver>((ref) {
  return LessonGroupResolver(ref.watch(apiClientProvider));
});

/// Восстанавливает полный список групп пары.
///
/// API на запрос по группе возвращает `GROUPS` только с этой группой, а на
/// запрос по аудитории или преподавателю — все группы пары. Поэтому при
/// поиске по группе недостающие группы добираются запросом по аудитории;
/// расписание аудитории кэшируется на сессию, чтобы одна и та же пара не
/// стоила двух запросов.
class LessonGroupResolver {
  LessonGroupResolver(this._api);

  final TulsuApiClient _api;
  final Map<String, List<ScheduleItem>> _rooms = {};

  static const int _roomCacheLimit = 24;

  /// Группы пары из уже загруженного расписания аудитории.
  ///
  /// `null` — расписание этой аудитории ещё не запрашивали, `[]` — запросили,
  /// но пары там нет. Карточка берёт значение синхронно на первом кадре,
  /// поэтому прогретые пары открываются без мигания блока «Группы».
  List<GroupInfo>? cachedGroups({
    required String date,
    required String time,
    required String subject,
    required String classroom,
  }) {
    if (classroom.isEmpty) return null;
    final items = _rooms[classroom];
    if (items == null) return null;
    for (final item in items) {
      if (item.date == date && item.time == time && item.subject == subject) {
        return item.groups;
      }
    }
    return const [];
  }

  /// Группы пары; пустой список — добрать не удалось (нет аудитории, нет
  /// сети, пара не нашлась в расписании аудитории).
  Future<List<GroupInfo>> resolve({
    required String date,
    required String time,
    required String subject,
    required String classroom,
  }) async {
    if (classroom.isEmpty) return const [];

    final cached = cachedGroups(
      date: date,
      time: time,
      subject: subject,
      classroom: classroom,
    );
    if (cached != null) return cached;

    await _roomSchedule(classroom);
    return cachedGroups(
          date: date,
          time: time,
          subject: subject,
          classroom: classroom,
        ) ??
        const [];
  }

  /// Тянет расписание аудитории в кэш (для фонового прогрева).
  Future<void> prefetch(String classroom) async {
    if (classroom.isEmpty) return;
    await _roomSchedule(classroom);
  }

  Future<List<ScheduleItem>> _roomSchedule(String classroom) async {
    final cached = _rooms[classroom];
    if (cached != null) return cached;

    try {
      final items =
          await _api.getSchedule(SearchFieldType.auditorium.value, classroom);
      // Ручной LRU без зависимости: список аудиторий за сессию маленький,
      // важен лишь верхний предел памяти.
      if (_rooms.length >= _roomCacheLimit) {
        _rooms.remove(_rooms.keys.first);
      }
      _rooms[classroom] = items;
      return items;
    } on ApiException {
      return const [];
    }
  }
}
