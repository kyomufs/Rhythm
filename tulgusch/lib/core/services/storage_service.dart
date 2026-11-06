import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:tulgusch/core/models/app_settings.dart';
import 'package:tulgusch/core/models/marks.dart';
import 'package:tulgusch/core/models/schedule.dart';

// ============================================================
// Storage Keys
// ============================================================
class StorageKeys {
  StorageKeys._();
  static const String myGroup = 'my_group';
  static const String mySubgroup = 'my_subgroup';
  static const String favoriteGroups = 'favorite_groups';
  static const String scheduleCache = 'schedule_cache';
  static const String marksGroup = 'marks_group';
  static const String studentId = 'student_id';
  static const String onboardingCompleted = 'onboarding_completed';
  static const String appSettings = 'app_settings';
  static const String notificationsAsked = 'notifications_asked';
  static const String scheduleFingerprint = 'schedule_fingerprint';
  static const String scheduleChangeLog = 'schedule_changes_log';
  static const String changesSeenAt = 'schedule_changes_seen_at';
  static const String marksCache = 'marks_cache';
}

// ============================================================
// Favorite Group
// ============================================================
class FavoriteGroup {
  final String groupNumber;
  final DateTime addedAt;

  const FavoriteGroup({
    required this.groupNumber,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => {
        'groupNumber': groupNumber,
        'addedAt': addedAt.toIso8601String(),
      };

  factory FavoriteGroup.fromJson(Map<String, dynamic> json) {
    return FavoriteGroup(
      groupNumber: json['groupNumber'] as String,
      addedAt: DateTime.parse(json['addedAt'] as String),
    );
  }
}

// ============================================================
// Cached Schedule
// ============================================================
class CachedSchedule {
  final String searchValue;
  final ScheduleData data;
  final DateTime cachedAt;

  const CachedSchedule({
    required this.searchValue,
    required this.data,
    required this.cachedAt,
  });

  bool get isValid => DateTime.now().difference(cachedAt).inHours < 24;
}

// ============================================================
// Storage Service Provider
// ============================================================
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

// ============================================================
// Storage Service
// ============================================================
class StorageService {
  StorageService();

  /// Ящик, открытый снаружи: нужен тестам, где Hive инициализируется
  /// во временном каталоге, а не через path_provider.
  @visibleForTesting
  StorageService.withBox(Box<dynamic> box)
      : _box = box,
        _opened = true;

  late Box<dynamic> _box;
  bool _opened = false;

  /// Доступен ли ящик. Провайдеры читают настройки на первом кадре — до
  /// этого момента обращение к ящику бросало бы LateError.
  bool get isInitialized => _opened;

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox('tulgusch');
    _opened = true;
  }

  // ── My Group ──────────────────────────────────────────────

  String? getMyGroup() => _box.get(StorageKeys.myGroup) as String?;

  String? getMySubgroup() => _box.get(StorageKeys.mySubgroup) as String?;

  /// Группа для итоговых оценок, если она отличается от группы расписания.
  /// Читается на первом кадре до открытия ящика — отсюда проверка `_opened`.
  String? getMarksGroup() =>
      _opened ? _box.get(StorageKeys.marksGroup) as String? : null;

  Future<void> setMyGroup(String groupNumber) async {
    await _box.put(StorageKeys.myGroup, groupNumber);
  }

  Future<void> setMySubgroup(String subgroup) async {
    await _box.put(StorageKeys.mySubgroup, subgroup);
  }

  Future<void> setMarksGroup(String groupNumber) async {
    await _box.put(StorageKeys.marksGroup, groupNumber);
  }

  Future<void> clearMarksGroup() async {
    await _box.delete(StorageKeys.marksGroup);
  }
  // ── Favorite Groups ───────────────────────────────────────

  List<FavoriteGroup> getFavoriteGroups() {
    final raw =
        _box.get(StorageKeys.favoriteGroups, defaultValue: <dynamic>[]);
    return (raw as List)
        .map((e) => FavoriteGroup.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> addFavoriteGroup(String groupNumber) async {
    final list = getFavoriteGroups();
    if (list.any((g) => g.groupNumber == groupNumber)) return;
    list.add(FavoriteGroup(groupNumber: groupNumber, addedAt: DateTime.now()));
    await _box.put(
      StorageKeys.favoriteGroups,
      list.map((g) => g.toJson()).toList(),
    );
  }

  Future<void> removeFavoriteGroup(String groupNumber) async {
    final list = getFavoriteGroups();
    list.removeWhere((g) => g.groupNumber == groupNumber);
    await _box.put(
      StorageKeys.favoriteGroups,
      list.map((g) => g.toJson()).toList(),
    );
  }

  bool isFavoriteGroup(String groupNumber) {
    return getFavoriteGroups().any((g) => g.groupNumber == groupNumber);
  }

  // ── Last Search ───────────────────────────────────────────

  // ── Schedule Cache ────────────────────────────────────────

  /// Кэш расписания — по номеру группы: вуз один, ключ простой.
  String _cacheKey(String searchValue) =>
      '${StorageKeys.scheduleCache}_$searchValue';

  CachedSchedule? getCachedSchedule(String searchValue) {
    try {
      final raw = _box.get(_cacheKey(searchValue));
      if (raw == null) return null;
      final map = Map<String, dynamic>.from(raw as Map);
      final items = (map['items'] as List)
          .map((item) =>
              ScheduleItem.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
      final calendar = (map['calendar'] as List)
          .map((item) =>
              CalendarItem.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();

      return CachedSchedule(
        searchValue: searchValue,
        data: ScheduleData(
          dateRange: ApiDateRange(
            minDate: DateTime.parse(map['minDate'] as String),
            maxDate: DateTime.parse(map['maxDate'] as String),
            searchField: SearchField.group,
          ),
          items: items,
          calendar: calendar,
        ),
        cachedAt: DateTime.parse(map['cachedAt'] as String),
      );
    } catch (_) {
      // Corrupted cache — delete and return null so API fetches fresh data
      _box.delete(_cacheKey(searchValue));
      return null;
    }
  }

  /// Дописывает полные списки групп в уже сохранённый снимок расписания.
  ///
  /// Группы приходят отдельным проходом после самой пары; переписывать снимок
  /// целиком ради них незачем — берём сохранённый и меняем только пары.
  Future<void> cacheScheduleGroups(
    String searchValue,
    List<ScheduleItem> items,
  ) async {
    final cached = getCachedSchedule(searchValue);
    if (cached == null) return;
    await cacheSchedule(
      searchValue,
      ScheduleData(
        dateRange: cached.data.dateRange,
        items: items,
        calendar: cached.data.calendar,
      ),
    );
  }

  Future<void> cacheSchedule(
    String searchValue,
    ScheduleData data,
  ) async {
    await _box.put(
      _cacheKey(searchValue),
      {
        'minDate': data.dateRange.minDate.toIso8601String(),
        'maxDate': data.dateRange.maxDate.toIso8601String(),
        'items': data.items
            .map((item) => <String, dynamic>{
                  'DATE_Z': item.date,
                  'TIME_Z': item.time,
                  'DISCIP': item.subject,
                  'KOW': item.type,
                  'AUD': item.classroom,
                  'PREP': item.teacher,
                  'GROUPS': item.groups
                      .map((g) => <String, dynamic>{
                            'GROUP_P': g.number,
                            'PRIM': g.subgroup,
                          })
                      .toList(),
                  'CLASS': item.cssClass,
                })
            .toList(),
        'calendar': data.calendar
            .map((item) => <String, dynamic>{
                  'BEGIN_DATE':
                      '${item.beginDate.day}.${item.beginDate.month}.${item.beginDate.year}',
                  'END_DATE':
                      '${item.endDate.day}.${item.endDate.month}.${item.endDate.year}',
                  'VID': item.type,
                })
            .toList(),
        'cachedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> clearOldCache() async {
    final keys = _box.keys
        .where((k) => k.toString().startsWith(StorageKeys.scheduleCache))
        .toList();
    for (final key in keys) {
      final raw = _box.get(key);
      if (raw != null) {
        final map = Map<String, dynamic>.from(raw as Map);
        final cachedAt = DateTime.parse(map['cachedAt'] as String);
        if (DateTime.now().difference(cachedAt).inDays > 7) {
          await _box.delete(key);
        }
      }
    }
  }

  /// Clear all cached schedule data (keeps user settings)
  Future<void> clearScheduleCache() async {
    final keys = _box.keys
        .where((k) => k.toString().startsWith(StorageKeys.scheduleCache))
        .toList();
    await _box.deleteAll(keys);
  }

  /// Reset everything — full wipe of all local data
  Future<void> clearAllData() async {
    await _box.clear();
  }

  // ── Student ID ───────────────────────────────────────────

  String? getStudentId() => _box.get(StorageKeys.studentId) as String?;

  Future<void> setStudentId(String id) async {
    await _box.put(StorageKeys.studentId, id);
  }

  Future<void> clearStudentId() async {
    await _box.delete(StorageKeys.studentId);
  }

  // ── Notifications ────────────────────────────────────────

  bool isNotificationsAsked() =>
      _box.get(StorageKeys.notificationsAsked, defaultValue: false) as bool;

  Future<void> setNotificationsAsked() async {
    await _box.put(StorageKeys.notificationsAsked, true);
  }

  // ── Schedule change detection ──────────────────────────

  String? getScheduleFingerprint() =>
      _box.get(StorageKeys.scheduleFingerprint) as String?;

  Future<void> setScheduleFingerprint(String? value) async {
    const key = StorageKeys.scheduleFingerprint;
    if (value == null) {
      await _box.delete(key);
    } else {
      await _box.put(key, value);
    }
  }

  /// Persistent journal of detected schedule changes (raw JSON maps,
  /// newest first). Enforced limits (50 entries / 14 days) live in the
  /// schedule provider; storage only persists what it is given.
  List<Map<String, dynamic>> getChangeLog() {
    final raw = _box.get(StorageKeys.scheduleChangeLog,
        defaultValue: <dynamic>[]);
    return (raw as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> saveChangeLog(List<Map<String, dynamic>> entries) async {
    await _box.put(StorageKeys.scheduleChangeLog, entries);
  }

  Future<void> clearChangeLog() async {
    await _box.delete(StorageKeys.scheduleChangeLog);
  }

  /// When the user last opened the «Изменения» screen (drives the badge).
  DateTime? getChangesSeenAt() {
    final raw = _box.get(StorageKeys.changesSeenAt)
        as String?;
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> setChangesSeenAt(DateTime value) async {
    await _box.put(StorageKeys.changesSeenAt, value.toIso8601String());
  }

  // ── Marks cache ────────────────────────────────────────

  /// Persist the latest marks snapshot (mirrors the schedule cache).
  Future<void> cacheMarks({
    required String studentId,
    required String group,
    required List<MarksItem> marks,
  }) async {
    await _box.put(StorageKeys.marksCache, {
      'studentId': studentId,
      'group': group,
      'cachedAt': DateTime.now().toIso8601String(),
      'marks': marks.map((m) => m.toJson()).toList(),
    });
  }

  /// Returns the cached marks only when they match the same student and
  /// are not older than 7 days; otherwise null.
  List<MarksItem>? getCachedMarks({
    required String studentId,
    required String group,
  }) {
    final raw = _box.get(StorageKeys.marksCache);
    if (raw == null) return null;
    try {
      final map = Map<String, dynamic>.from(raw as Map);
      if (map['studentId'] != studentId || map['group'] != group) {
        return null;
      }
      final cachedAt = DateTime.parse(map['cachedAt'] as String);
      if (DateTime.now().difference(cachedAt).inDays > 7) return null;
      final list = (map['marks'] as List).cast<Map<dynamic, dynamic>>();
      return list
          .map((m) => MarksItem.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      return null;
    }
  }

  // ── Onboarding ───────────────────────────────────────────

  bool isOnboardingCompleted() =>
      _box.get(StorageKeys.onboardingCompleted, defaultValue: false) as bool;

  Future<void> setOnboardingCompleted() async {
    await _box.put(StorageKeys.onboardingCompleted, true);
  }

  // ── App Settings ─────────────────────────────────────────

  AppSettings getAppSettings() {
    final raw = _box.get(StorageKeys.appSettings);
    if (raw == null) return const AppSettings();
    return AppSettings.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<void> saveAppSettings(AppSettings settings) async {
    await _box.put(StorageKeys.appSettings, settings.toJson());
  }
}
