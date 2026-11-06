import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:rhythm/core/domain/journal.dart';
import 'package:rhythm/core/domain/source.dart';
import 'package:rhythm/core/models/app_settings.dart';
import 'package:rhythm/core/models/marks.dart';
import 'package:rhythm/core/models/note_models.dart';
import 'package:rhythm/core/models/schedule.dart';

// ============================================================
// Storage Keys
// ============================================================
class StorageKeys {
  StorageKeys._();
  static const String myGroup = 'my_group';
  static const String mySubgroup = 'my_subgroup';
  static const String favoriteGroups = 'favorite_groups';
  static const String studyFolders = 'study_folders';
  // Legacy keys (kept for migration reference, no longer used)
  static const String subjects = 'subjects';
  static const String tasks = 'tasks';
  static const String notes = 'notes';
  static const String lastSearch = 'last_search';
  static const String scheduleCache = 'schedule_cache';
  static const String studentId = 'student_id';
  static const String onboardingCompleted = 'onboarding_completed';
  static const String appSettings = 'app_settings';
  static const String notificationsAsked = 'notifications_asked';
  static const String scheduleFingerprint = 'schedule_fingerprint';
  static const String scheduleChangeLog = 'schedule_changes_log';
  static const String changesSeenAt = 'schedule_changes_seen_at';
  static const String marksCache = 'marks_cache';
  static const String sources = 'sources';
  static const String activeSourceId = 'active_source_id';
  static const String journalPrefix = 'journal_v1';
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
  late Box<dynamic> _box;
  bool _opened = false;

  /// Доступен ли ящик. Провайдеры читают настройки на первом кадре — до
  /// этого момента обращение к ящику бросало бы LateError.
  bool get isInitialized => _opened;

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox('rhythm');
    _opened = true;
  }

  // ── My Group ──────────────────────────────────────────────

  String? getMyGroup() => _box.get(StorageKeys.myGroup) as String?;

  String? getMySubgroup() => _box.get(StorageKeys.mySubgroup) as String?;

  Future<void> setMyGroup(String groupNumber) async {
    await _box.put(StorageKeys.myGroup, groupNumber);
  }

  Future<void> setMySubgroup(String subgroup) async {
    await _box.put(StorageKeys.mySubgroup, subgroup);
  }

  /// Full academic group with subgroup: "221341:01"
  String? getFullAcademicGroup() {
    final group = getMyGroup();
    final subgroup = getMySubgroup();
    if (group == null) return null;
    if (subgroup != null && subgroup.isNotEmpty) return '$group:$subgroup';
    return group;
  }

  Future<void> clearMyGroup() async {
    await _box.delete(StorageKeys.myGroup);
    await _box.delete(StorageKeys.mySubgroup);
  }

  // ── Favorite Groups ───────────────────────────────────────

  List<FavoriteGroup> getFavoriteGroups() {
    final raw = _box.get(StorageKeys.favoriteGroups, defaultValue: <dynamic>[]);
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

  // ── Study Folders (Subjects) ───────────────────────────────

  List<SubjectFolder> getStudyFolders() {
    final raw = _box.get(StorageKeys.studyFolders, defaultValue: <dynamic>[]);
    return (raw as List)
        .map((e) => SubjectFolder.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> saveStudyFolders(List<SubjectFolder> folders) async {
    await _box.put(
      StorageKeys.studyFolders,
      folders.map((f) => f.toJson()).toList(),
    );
  }

  SubjectFolder? getStudyFolderById(String id) {
    try {
      return getStudyFolders().firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Migrate legacy subjects/tasks/notes to new study folders format
  Future<void> migrateFromLegacy() async {
    final rawSubjects = _box.get(StorageKeys.subjects);
    if (rawSubjects == null) return; // Already migrated or fresh install

    final legacySubjects = (rawSubjects as List)
        .map((e) => Subject.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final legacyTasks = getLegacyTasks();

    if (legacySubjects.isEmpty) {
      await _box.delete(StorageKeys.subjects);
      await _box.delete(StorageKeys.tasks);
      await _box.delete(StorageKeys.notes);
      return;
    }

    final folders = <SubjectFolder>[];
    for (final subj in legacySubjects) {
      final subjTasks =
          legacyTasks.where((t) => t.subjectId == subj.id).toList();

      // Create default subfolders
      final subfolders = <SubjectSubfolder>[
        SubjectSubfolder(
          id: '${subj.id}_lectures',
          name: 'Лекции',
          isDefault: true,
          tasks: [],
        ),
        SubjectSubfolder(
          id: '${subj.id}_labs',
          name: 'Лабы',
          isDefault: true,
          tasks: [],
        ),
        SubjectSubfolder(
          id: '${subj.id}_practice',
          name: 'Практики',
          isDefault: true,
          tasks: [],
        ),
      ];

      // Map legacy tasks into appropriate subfolder
      for (final task in subjTasks) {
        // Determine subfolder by subject type
        String subfolderId;
        switch (subj.type) {
          case 'lab':
            subfolderId = '${subj.id}_labs';
            break;
          case 'lecture':
            subfolderId = '${subj.id}_lectures';
            break;
          case 'practice':
            subfolderId = '${subj.id}_practice';
            break;
          default:
            subfolderId = '${subj.id}_lectures';
        }

        final sfIdx = subfolders.indexWhere((sf) => sf.id == subfolderId);
        if (sfIdx != -1) {
          final existing = subfolders[sfIdx];
          subfolders[sfIdx] = existing.copyWith(
            tasks: [
              ...existing.tasks,
              StudyTask(
                id: task.id,
                title: task.title,
                status: task.isCompleted ? TaskStatus.done : TaskStatus.todo,
                dueDate: task.dueDate,
                createdAt: task.createdAt,
              ),
            ],
          );
        }
      }

      folders.add(SubjectFolder(
        id: subj.id,
        name: subj.name,
        colorIndex: subj.colorIndex,
        createdAt: subj.createdAt,
        subfolders: subfolders,
      ));
    }

    await saveStudyFolders(folders);

    // Clean up legacy data
    await _box.delete(StorageKeys.subjects);
    await _box.delete(StorageKeys.tasks);
    await _box.delete(StorageKeys.notes);
  }

  // Legacy helpers (only for migration)
  List<Subject> getLegacySubjects() {
    final raw = _box.get(StorageKeys.subjects, defaultValue: <dynamic>[]);
    return (raw as List)
        .map((e) => Subject.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  List<Task> getLegacyTasks() {
    final raw = _box.get(StorageKeys.tasks, defaultValue: <dynamic>[]);
    return (raw as List)
        .map((e) => Task.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  List<Note> getLegacyNotes() {
    final raw = _box.get(StorageKeys.notes, defaultValue: <dynamic>[]);
    return (raw as List)
        .map((e) => Note.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ── Last Search ───────────────────────────────────────────

  String? getLastSearch() => _box.get(StorageKeys.lastSearch) as String?;

  Future<void> saveLastSearch(String value) async {
    await _box.put(StorageKeys.lastSearch, value);
  }

  // ── Schedule Cache ────────────────────────────────────────

  CachedSchedule? getCachedSchedule(String searchValue) {
    try {
      final raw = _box.get('${StorageKeys.scheduleCache}_$searchValue');
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
      _box.delete('${StorageKeys.scheduleCache}_$searchValue');
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

  Future<void> cacheSchedule(String searchValue, ScheduleData data) async {
    await _box.put(
      '${StorageKeys.scheduleCache}_$searchValue',
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
    if (value == null) {
      await _box.delete(StorageKeys.scheduleFingerprint);
    } else {
      await _box.put(StorageKeys.scheduleFingerprint, value);
    }
  }

  /// Persistent journal of detected schedule changes (raw JSON maps,
  /// newest first). Enforced limits (50 entries / 14 days) live in the
  /// schedule provider; storage only persists what it is given.
  List<Map<String, dynamic>> getChangeLog() {
    final raw =
        _box.get(StorageKeys.scheduleChangeLog, defaultValue: <dynamic>[]);
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
    final raw = _box.get(StorageKeys.changesSeenAt) as String?;
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

  // ── Sources ──────────────────────────────────────────────

  List<Source> getSources() {
    if (!_opened) return const [];
    final raw = _box.get(StorageKeys.sources);
    if (raw == null) return const [];
    try {
      return (raw as List)
          .map((e) => Source.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveSources(List<Source> sources) async {
    if (!_opened) return;
    await _box.put(
      StorageKeys.sources,
      sources.map((s) => s.toJson()).toList(),
    );
  }

  String? getActiveSourceId() =>
      _opened ? _box.get(StorageKeys.activeSourceId) as String? : null;

  Future<void> setActiveSourceId(String? id) async {
    if (!_opened) return;
    if (id == null) {
      await _box.delete(StorageKeys.activeSourceId);
    } else {
      await _box.put(StorageKeys.activeSourceId, id);
    }
  }

  // ── Journal ──────────────────────────────────────────────

  JournalData getJournal(String sourceId) {
    if (!_opened) return const JournalData();
    final raw = _box.get('${StorageKeys.journalPrefix}_$sourceId');
    if (raw == null) return const JournalData();
    try {
      return JournalData.fromJson(Map<String, dynamic>.from(raw as Map));
    } catch (_) {
      return const JournalData();
    }
  }

  Future<void> saveJournal(String sourceId, JournalData data) async {
    if (!_opened) return;
    await _box.put(
      '${StorageKeys.journalPrefix}_$sourceId',
      data.toJson(),
    );
  }

  Future<void> deleteJournal(String sourceId) async {
    if (!_opened) return;
    await _box.delete('${StorageKeys.journalPrefix}_$sourceId');
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
