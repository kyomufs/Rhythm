import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tulgusch/core/api/api_exception.dart';
import 'package:tulgusch/core/models/schedule.dart';
import 'package:tulgusch/core/api/api_providers.dart';
import 'package:tulgusch/core/api/schedule_api.dart';

/// Provider for the lesson group resolver
final lessonGroupResolverProvider = Provider<LessonGroupResolver>((ref) {
  return LessonGroupResolver(ref.watch(scheduleApiProvider));
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

  final ScheduleApi _api;
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

  /// Дописывает полные списки групп к парам недели, начиная с [weekStart].
  ///
  /// Возвращает исходный список без изменений, если добирать нечего: новый
  /// список отдаётся только тогда, когда хоть одна пара получила группы, —
  /// иначе состояние экрана перерисовывалось бы зря.
  Future<List<ScheduleItem>> enrich(
    List<ScheduleItem> items, {
    required DateTime weekStart,
    int parallel = 6,
    int maxRooms = 32,
  }) async {
    final weekEnd = weekStart.add(const Duration(days: 7));
    final rooms = <String>{};
    for (final item in items) {
      if (item.groups.length > 1 || item.classroom.isEmpty) continue;
      final DateTime date;
      try {
        date = item.parsedDate;
      } catch (_) {
        continue;
      }
      if (date.isBefore(weekStart) || !date.isBefore(weekEnd)) continue;
      rooms.add(item.classroom);
      if (rooms.length >= maxRooms) break;
    }
    if (rooms.isEmpty) return items;

    final queue = rooms.toList();
    for (var i = 0; i < queue.length; i += parallel) {
      await Future.wait([
        for (final room in queue.skip(i).take(parallel)) _roomSchedule(room),
      ]);
    }

    var changed = false;
    final result = <ScheduleItem>[];
    for (final item in items) {
      if (item.groups.length > 1 || item.classroom.isEmpty) {
        result.add(item);
        continue;
      }
      final found = cachedGroups(
        date: item.date,
        time: item.time,
        subject: item.subject,
        classroom: item.classroom,
      );
      if (found == null || found.length <= item.groups.length) {
        result.add(item);
        continue;
      }
      changed = true;
      result.add(ScheduleItem(
        date: item.date,
        time: item.time,
        subject: item.subject,
        type: item.type,
        classroom: item.classroom,
        teacher: item.teacher,
        groups: found,
        cssClass: item.cssClass,
      ));
    }
    return changed ? result : items;
  }

  Future<List<ScheduleItem>> _roomSchedule(String classroom) async {
    final cached = _rooms[classroom];
    if (cached != null) return cached;

    try {
      final items = await _api.lessons(
        searchField: SearchField.auditorium.value,
        searchValue: classroom,
      );
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
