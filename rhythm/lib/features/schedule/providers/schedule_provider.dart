import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rhythm/core/demo/demo_schedule.dart';
import 'package:rhythm/core/domain/source.dart';
import 'package:rhythm/core/models/change_record.dart';
import 'package:rhythm/core/models/schedule.dart';
import 'package:rhythm/core/providers/clock_provider.dart';
import 'package:rhythm/core/utils/error_messages.dart';
import 'package:rhythm/core/services/connectivity_service.dart';
import 'package:rhythm/core/services/lesson_group_resolver.dart';
import 'package:rhythm/core/services/notification_service.dart';
import 'package:rhythm/core/services/schedule_service.dart';
import 'package:rhythm/core/services/storage_service.dart';
import 'package:rhythm/core/sources/source_store.dart';
import 'package:rhythm/core/services/update_coordinator.dart';
import 'package:rhythm/core/utils/week_utils.dart';
import 'package:rhythm/integrations/catalog.dart';

/// Schedule screen state
class ScheduleScreenState {
  final String? currentGroup;
  final List<FavoriteGroup> favoriteGroups;
  final ScheduleState schedule;
  final bool isLoadingGroup;
  final DateTime currentWeekStart;
  final DateTime? highlightedDate;

  /// The latest detected diff (session-only): feeds the AppBar badge
  /// count, the detail-sheet banner and the notification summary.
  final List<ChangeRecord> changeRecords;

  /// Persistent history of every detected change (newest first),
  /// backed by the Hive journal. Cleared only manually by the user.
  final List<ChangeRecord> changeJournal;

  /// Whether the journal contains entries the user has not reviewed yet.
  final bool hasUnseenChanges;

  /// Demo mode: a generated throwaway schedule is shown instead of
  /// real data; no API, no fingerprint, no persistence of changes.
  final bool isDemo;

  ScheduleScreenState({
    this.currentGroup,
    this.favoriteGroups = const [],
    this.schedule = const ScheduleState(searchValue: ''),
    this.isLoadingGroup = false,
    DateTime? currentWeekStart,
    this.highlightedDate,
    this.changeRecords = const [],
    this.changeJournal = const [],
    this.hasUnseenChanges = false,
    this.isDemo = false,
  }) : currentWeekStart = currentWeekStart ?? getCurrentWeekStart();

  /// Fingerprint row of each changed lesson → what changed
  /// (e.g. "Аудитория: 101 → 102" or "Новое занятие").
  Map<String, String> get changeNotes => {
        for (final r in changeRecords)
          if (r.kind != ChangeKind.removed) r.fingerprintRow: r.summaryNote,
      };

  /// Human-readable cancelled lessons of the latest detection batch.
  List<String> get removedLessons => [
        for (final r in changeRecords)
          if (r.kind == ChangeKind.removed)
            '${r.date} ${r.time.split('-').first.trim()} ${r.subject}',
      ];

  /// The most recent journal entry describing exactly this lesson row
  /// (used by the lesson detail sheet banner).
  ChangeRecord? latestChangeFor(String fingerprintRow) {
    for (final r in changeJournal) {
      if (r.kind != ChangeKind.removed && r.fingerprintRow == fingerprintRow) {
        return r;
      }
    }
    return null;
  }

  /// Items filtered to the current week
  List<ScheduleItem> get currentWeekItems {
    return filterByWeek(
      schedule.items,
      currentWeekStart,
      (item) => item.parsedDate,
    );
  }

  /// Items grouped by day for the current week
  Map<DateTime, List<ScheduleItem>> get currentWeekByDay {
    final map = <DateTime, List<ScheduleItem>>{};
    for (final item in currentWeekItems) {
      final date = item.parsedDate;
      final dayKey = DateTime(date.year, date.month, date.day);
      map[dayKey] = [...(map[dayKey] ?? []), item];
    }
    // Sort by date
    final sortedKeys = map.keys.toList()..sort();
    return {for (final key in sortedKeys) key: map[key]!};
  }

  /// Week info for the current view
  WeekInfo get weekInfo => getWeekInfo(currentWeekStart);

  /// Whether we're viewing the current (real) week
  bool get isCurrentWeek => currentWeekStart == getCurrentWeekStart();

  ScheduleScreenState copyWith({
    String? currentGroup,
    bool clearGroup = false,
    List<FavoriteGroup>? favoriteGroups,
    ScheduleState? schedule,
    bool? isLoadingGroup,
    DateTime? currentWeekStart,
    DateTime? highlightedDate,
    bool clearHighlighted = false,
    List<ChangeRecord>? changeRecords,
    List<ChangeRecord>? changeJournal,
    bool? hasUnseenChanges,
    bool? isDemo,
    bool clearChanges = false,
  }) {
    return ScheduleScreenState(
      currentGroup: clearGroup ? null : (currentGroup ?? this.currentGroup),
      favoriteGroups: favoriteGroups ?? this.favoriteGroups,
      schedule: schedule ?? this.schedule,
      isLoadingGroup: isLoadingGroup ?? this.isLoadingGroup,
      currentWeekStart: currentWeekStart ?? this.currentWeekStart,
      highlightedDate:
          clearHighlighted ? null : (highlightedDate ?? this.highlightedDate),
      // Fresh review clears only the session batch — the journal and the
      // unseen flag survive refreshes and app restarts.
      changeRecords:
          clearChanges ? const [] : (changeRecords ?? this.changeRecords),
      changeJournal: changeJournal ?? this.changeJournal,
      hasUnseenChanges: hasUnseenChanges ?? this.hasUnseenChanges,
      isDemo: isDemo ?? this.isDemo,
    );
  }
}

/// One row of a previously stored fingerprint. Rows written before the
/// teacher column existed have [hasTeacher] == false and the teacher
/// field is never diffed for them (avoid mass false positives).
class _OldRow {
  final String date;
  final String time;
  final String subject;
  final String teacher;
  final String classroom;
  final String type;
  final bool hasTeacher;

  const _OldRow({
    required this.date,
    required this.time,
    required this.subject,
    required this.teacher,
    required this.classroom,
    required this.type,
    required this.hasTeacher,
  });
}

class ScheduleScreenNotifier extends StateNotifier<ScheduleScreenState> {
  final ScheduleService _service;
  final StorageService _storage;
  final ConnectivityService _connectivity;
  final NotificationService _notifications;
  final UpdateCoordinator _updates;

  /// Добор групп пар; в тестах не нужен, поэтому необязателен.
  final LessonGroupResolver? _resolver;
  final bool _demo;

  /// Группа/uuid активного источника и пространство имён его снимков.
  final String? _target;
  final String _namespace;

  /// Journal size and age limits (plan: cap 50, TTL 14 days).
  static const _journalLimit = 50;
  static const _journalTtl = Duration(days: 14);

  ScheduleScreenNotifier(
    this._service,
    this._storage,
    this._connectivity,
    this._notifications,
    this._updates, {
    LessonGroupResolver? resolver,
    bool demo = false,
    String? target,
    String namespace = '',
  })  : _resolver = resolver,
        _demo = demo,
        _target = target,
        _namespace = namespace,
        super(ScheduleScreenState(
          currentWeekStart: getCurrentWeekStart(),
        )) {
    _init();
  }

  /// Журнал изменений, отпечаток и автообновление при входе.
  ///
  /// Завершается `true`, когда автообновление при старте реально сходило в
  /// API и данные получены: по этому флагу оболочка показывает плашку
  /// «Расписание успешно обновлено» без нажатия пользователя.
  final Completer<bool> _bootRefresh = Completer<bool>();
  Future<bool> get bootRefresh => _bootRefresh.future;

  Future<void> _init() async {
    final favGroups = _storage.getFavoriteGroups();
    if (_demo) {
      _initDemo(favGroups);
      _bootRefresh.complete(false);
      return;
    }
    // Цель источника главнее: у каждого вуза своя группа. Старая группа
    // из хранилища остаётся запасным путём, пока источников нет.
    final myGroup = _target ?? _storage.getMyGroup();
    final journal = _loadJournal();
    final seenAt = _storage.getChangesSeenAt();
    state = state.copyWith(
      currentGroup: myGroup,
      favoriteGroups: favGroups,
      changeJournal: journal,
      hasUnseenChanges:
          journal.any((r) => seenAt == null || r.detectedAt.isAfter(seenAt)),
    );
    if (myGroup != null) {
      // Fingerprint of the schedule the user last saw (for change alerts).
      final previousFingerprint = _storage.getScheduleFingerprint();
      // Stale-while-revalidate: paint the local copy synchronously,
      // BEFORE the connectivity probe — a slow network must never blank
      // an already-known schedule. The sync below replaces it in place.
      final hadLocalCopy = _applyCachedSchedule(myGroup);
      if (!hadLocalCopy) {
        // Nothing local: enter the loading state right away so the
        // empty view does not flash while the connectivity probe runs.
        state = state.copyWith(
          schedule: state.schedule.copyWith(
            searchValue: myGroup,
            isLoading: true,
          ),
        );
      }
      final isOnline = await _connectivity.checkConnectivity();
      if (isOnline) {
        // Sync with the API: fresh data replaces the painted copy.
        await loadSchedule(myGroup);
        final refreshed =
            state.schedule.error == null && state.schedule.items.isNotEmpty;
        if (refreshed) {
          // Silently compare with the last seen version and alert on changes.
          await _checkForScheduleChanges(myGroup, previousFingerprint);
          // Группы пар — сразу за расписанием, а не по факту открытия карточки.
          unawaited(_enrichGroups(myGroup));
        }
        _bootRefresh.complete(refreshed);
      } else if (!hadLocalCopy) {
        state = state.copyWith(
          schedule: state.schedule.copyWith(
            searchValue: myGroup,
            isLoading: false,
            error: 'Нет подключения к интернету',
          ),
        );
        _bootRefresh.complete(false);
      } else {
        _bootRefresh.complete(false);
      }
      // Offline with a painted local copy: keep showing it silently —
      // a stale timetable beats an error screen; pull-to-refresh still
      // reports "no internet" explicitly.
      return;
    }
    _bootRefresh.complete(false);
  }

  /// Paints the cached snapshot for [searchValue] into the state without
  /// any loading flag (the network revalidation runs separately).
  /// Returns true when a non-empty local copy is now shown. The snapshot
  /// is shown regardless of its age: stale content beats a blank screen
  /// when the revalidation cannot run.
  bool _applyCachedSchedule(String searchValue) {
    final cached =
        _storage.getCachedSchedule(searchValue, namespace: _namespace);
    if (cached == null || cached.data.items.isEmpty) return false;
    state = state.copyWith(schedule: _stateFromCache(searchValue, cached));
    return true;
  }

  /// Shared shape of a schedule state served from the local snapshot.
  static ScheduleState _stateFromCache(
      String searchValue, CachedSchedule cached) {
    return ScheduleState(
      searchValue: searchValue,
      dateRange: DateTimeRange(
        start: cached.data.dateRange.minDate,
        end: cached.data.dateRange.maxDate,
      ),
      items: cached.data.items,
    );
  }

  /// Демо-режим: сгенерированное расписание и ничего больше. Ни журнал
  /// изменений, ни отпечаток не подделываются — журнал в демо пуст, потому
  /// что менять там нечего. В хранилище демо не пишет.
  void _initDemo(List<FavoriteGroup> favGroups) {
    final now = DateTime.now();
    final items = buildDemoSchedule(now);
    state = state.copyWith(
      isDemo: true,
      favoriteGroups: favGroups,
      schedule: ScheduleState(
        searchValue: demoGroup,
        dateRange: _rangeOf(items),
        items: items,
      ),
    );
  }

  static DateTimeRange? _rangeOf(List<ScheduleItem> items) {
    final dates = <DateTime>[];
    for (final item in items) {
      try {
        dates.add(item.parsedDate);
      } catch (_) {
        // Skip malformed demo rows — range is cosmetic only.
      }
    }
    if (dates.isEmpty) return null;
    var min = dates.first;
    var max = dates.first;
    for (final d in dates) {
      if (d.isBefore(min)) min = d;
      if (d.isAfter(max)) max = d;
    }
    return DateTimeRange(start: min, end: max);
  }

  /// Stable fingerprint of schedule items used to detect changes.
  /// Uses the full 6-field row (teacher included); legacy 5-field
  /// fingerprints are still accepted by the diff.
  static String _fingerprint(List<ScheduleItem> items) {
    final rows = items.map((i) => i.fingerprintRow).toList()..sort();
    return rows.join('\n');
  }

  /// Field-level diff between a stored fingerprint snapshot and the
  /// current items, as journal records.
  ///
  /// Pass 1 pairs rows inside the same occurrence slot
  /// (date|subject|type) in time order and reports field changes
  /// (Время/Преподаватель/Аудитория). Pass 2 pairs leftovers by
  /// date+time to catch subject/type renames (→ modified). Everything
  /// unmatched becomes removed (old values) or added (new values).
  static List<ChangeRecord> _diffSchedule(
      String oldFingerprint, List<ScheduleItem> items,
      {DateTime? now}) {
    final detectedAt = now ?? DateTime.now();

    // Normalize legacy (5-field) and current (6-field) fingerprint rows.
    final oldRows = <_OldRow>[];
    for (final line in oldFingerprint.split('\n')) {
      if (line.isEmpty) continue;
      final parts = line.split('|');
      if (parts.length == 6) {
        oldRows.add(_OldRow(
          date: parts[0],
          time: parts[1],
          subject: parts[2],
          teacher: parts[3],
          classroom: parts[4],
          type: parts[5],
          hasTeacher: true,
        ));
      } else if (parts.length == 5) {
        oldRows.add(_OldRow(
          date: parts[0],
          time: parts[1],
          subject: parts[2],
          teacher: '',
          classroom: parts[3],
          type: parts[4],
          hasTeacher: false,
        ));
      }
    }

    final records = <ChangeRecord>[];
    final matchedOld = List<bool>.filled(oldRows.length, false);
    final matchedNew = List<bool>.filled(items.length, false);

    // ── Pass 1: same occurrence slot → field-level changes ──
    final oldBySlot = <String, List<int>>{};
    for (var i = 0; i < oldRows.length; i++) {
      final r = oldRows[i];
      oldBySlot
          .putIfAbsent('${r.date}|${r.subject}|${r.type}', () => [])
          .add(i);
    }
    final newBySlot = <String, List<int>>{};
    for (var i = 0; i < items.length; i++) {
      newBySlot.putIfAbsent(items[i].slotKey, () => []).add(i);
    }

    for (final entry in newBySlot.entries) {
      final oldIdx = oldBySlot[entry.key];
      if (oldIdx == null) continue;
      final newIdx = entry.value;
      // Pair in time order so a moved lesson still matches its old row.
      oldIdx.sort((a, b) => oldRows[a].time.compareTo(oldRows[b].time));
      newIdx.sort((a, b) => items[a].time.compareTo(items[b].time));
      final pairs = min(oldIdx.length, newIdx.length);
      for (var p = 0; p < pairs; p++) {
        final old = oldRows[oldIdx[p]];
        final item = items[newIdx[p]];
        matchedOld[oldIdx[p]] = true;
        matchedNew[newIdx[p]] = true;
        final changes = _fieldDiff(old, item);
        if (changes.isNotEmpty) {
          records.add(ChangeRecord(
            detectedAt: detectedAt,
            kind: ChangeKind.modified,
            date: item.date,
            subject: item.subject,
            type: item.type,
            time: item.time,
            classroom: item.classroom,
            teacher: item.teacher,
            fieldChanges: changes,
          ));
        }
      }
      // Surplus rows on either side of an otherwise matched slot.
      for (var p = pairs; p < newIdx.length; p++) {
        matchedNew[newIdx[p]] = true;
        records.add(_addedRecord(items[newIdx[p]], detectedAt));
      }
      for (var p = pairs; p < oldIdx.length; p++) {
        matchedOld[oldIdx[p]] = true;
        records.add(_removedRecord(oldRows[oldIdx[p]], detectedAt));
      }
    }

    // ── Pass 2: leftovers paired by date+time → renames ──
    for (var n = 0; n < items.length; n++) {
      if (matchedNew[n]) continue;
      final item = items[n];
      var found = -1;
      for (var o = 0; o < oldRows.length; o++) {
        if (matchedOld[o]) continue;
        if (oldRows[o].date == item.date && oldRows[o].time == item.time) {
          found = o;
          break;
        }
      }
      if (found < 0) continue;
      final old = oldRows[found];
      matchedOld[found] = true;
      matchedNew[n] = true;
      final changes = <FieldChange>[
        if (old.subject != item.subject)
          FieldChange(
              field: 'Предмет', before: old.subject, after: item.subject),
        if (old.type != item.type)
          FieldChange(field: 'Тип', before: old.type, after: item.type),
        ..._fieldDiff(old, item),
      ];
      records.add(ChangeRecord(
        detectedAt: detectedAt,
        kind: ChangeKind.modified,
        date: item.date,
        subject: item.subject,
        type: item.type,
        time: item.time,
        classroom: item.classroom,
        teacher: item.teacher,
        fieldChanges: changes,
      ));
    }

    // ── Everything left over is added or removed ──
    for (var o = 0; o < oldRows.length; o++) {
      if (!matchedOld[o]) records.add(_removedRecord(oldRows[o], detectedAt));
    }
    for (var n = 0; n < items.length; n++) {
      if (!matchedNew[n]) records.add(_addedRecord(items[n], detectedAt));
    }
    return records;
  }

  /// Field differences between one old fingerprint row and its new
  /// counterpart. Teacher is skipped for legacy rows that predate the
  /// teacher column.
  static List<FieldChange> _fieldDiff(_OldRow old, ScheduleItem item) {
    return <FieldChange>[
      if (old.time != item.time)
        FieldChange(field: 'Время', before: old.time, after: item.time),
      if (old.hasTeacher && old.teacher != item.teacher)
        FieldChange(
            field: 'Преподаватель', before: old.teacher, after: item.teacher),
      if (old.classroom != item.classroom)
        FieldChange(
            field: 'Аудитория', before: old.classroom, after: item.classroom),
    ];
  }

  static ChangeRecord _addedRecord(ScheduleItem item, DateTime detectedAt) {
    return ChangeRecord(
      detectedAt: detectedAt,
      kind: ChangeKind.added,
      date: item.date,
      subject: item.subject,
      type: item.type,
      time: item.time,
      classroom: item.classroom,
      teacher: item.teacher,
    );
  }

  static ChangeRecord _removedRecord(_OldRow row, DateTime detectedAt) {
    return ChangeRecord(
      detectedAt: detectedAt,
      kind: ChangeKind.removed,
      date: row.date,
      subject: row.subject,
      type: row.type,
      time: row.time,
      classroom: row.classroom,
      teacher: row.teacher,
    );
  }

  /// Drop entries older than 14 days and enforce the 50-entry cap.
  /// The journal is kept newest-first.
  static List<ChangeRecord> pruneJournal(List<ChangeRecord> journal,
      {DateTime? now}) {
    final cutoff = (now ?? DateTime.now()).subtract(_journalTtl);
    final fresh = journal
        .where((r) => r.detectedAt.isAfter(cutoff))
        .toList(growable: false);
    if (fresh.length <= _journalLimit) return fresh;
    return fresh.sublist(0, _journalLimit);
  }

  List<ChangeRecord> _loadJournal() {
    try {
      final raw = _storage.getChangeLog();
      final records = <ChangeRecord>[];
      for (final map in raw) {
        try {
          records.add(ChangeRecord.fromJson(map));
        } catch (_) {
          // Skip corrupt entries rather than dropping the whole journal.
        }
      }
      records.sort((a, b) => b.detectedAt.compareTo(a.detectedAt));
      return pruneJournal(records);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _persistJournal() async {
    if (_demo) return; // Demo records live in memory only.
    await _storage.saveChangeLog(
      state.changeJournal.map((r) => r.toJson()).toList(),
    );
  }

  /// Summary for the schedule-change notification (zero parts omitted).
  static String _changeSummary(List<ChangeRecord> records) {
    final modified = records.where((r) => r.kind == ChangeKind.modified).length;
    final added = records.where((r) => r.kind == ChangeKind.added).length;
    final removed = records.where((r) => r.kind == ChangeKind.removed).length;
    final parts = <String>[
      if (modified > 0) 'изменено: $modified',
      if (added > 0) 'новых: $added',
      if (removed > 0) 'отменено: $removed',
    ];
    return parts.isEmpty ? 'данные обновлены' : parts.join(', ');
  }

  /// Silently fetch the freshest schedule on app open and notify the user
  /// when it differs from the version they last saw. No server involved:
  /// we compare a local fingerprint against a fresh pull from TULSU.
  Future<bool> _checkForScheduleChanges(
      String group, String? previousFingerprint) async {
    try {
      final fresh = await _service.getSchedule(group, forceRefresh: true);
      if (!mounted) return false;
      if (fresh.error != null || fresh.items.isEmpty) return false;
      final newFingerprint = _fingerprint(fresh.items);
      await _storage.setScheduleFingerprint(newFingerprint);
      if (previousFingerprint == null ||
          previousFingerprint == newFingerprint) {
        return false; // First run or no changes — nothing to report.
      }
      final records = _diffSchedule(previousFingerprint, fresh.items);
      if (records.isEmpty) {
        // Only the fingerprint format changed (e.g. teacher column
        // added) — update the baseline silently.
        return false;
      }
      final journal = pruneJournal([...records, ...state.changeJournal]);
      // Show the updated data immediately along with the alert.
      state = state.copyWith(
        schedule: fresh,
        changeRecords: records,
        changeJournal: journal,
        hasUnseenChanges: true,
      );
      await _persistJournal();
      // id фиксирован на тип события: повторный опрос не плодит уведомления
      // в шторке, а заменяет прошлое про тот же журнал.
      await _notifications.show(
        2,
        'Расписание изменилось',
        'Для группы $group: ${_changeSummary(records)}. '
            'Откройте значок «Изменения» в расписании.',
        payload: changesNotificationPayload,
      );
      return true;
    } catch (_) {
      // Background check is best-effort — ignore failures.
      return false;
    }
  }

  /// Один фоновый опрос: сверяет расписание с API по сохранённому
  /// отпечатку. Вызывается таймером из [BackgroundSyncHost] и при возврате
  /// приложения на передний план. Возвращает true, если журнал пополнился.
  ///
  /// Демо и пустая группа не опрашиваются: в демо менять нечего, а без
  /// группы запрос ушёл бы в пустоту.
  bool _polling = false;

  Future<bool> pollForChanges() async {
    if (_demo || _polling) return false;
    final group = state.currentGroup;
    if (group == null || group.isEmpty) return false;
    if (state.schedule.items.isEmpty) return false;
    _polling = true;
    try {
      return await _checkForScheduleChanges(
        group,
        _storage.getScheduleFingerprint(),
      );
    } finally {
      _polling = false;
    }
  }

  /// The user has reviewed the fresh batch (opened the «Изменения»
  /// screen): clear the badge but keep the journal history.
  Future<void> markChangesSeen() async {
    state = state.copyWith(clearChanges: true, hasUnseenChanges: false);
    await _storage.setChangesSeenAt(DateTime.now());
  }

  /// Manual journal clear from the «Изменения» screen.
  Future<void> clearChangeJournal() async {
    state = state.copyWith(
      changeJournal: const [],
      clearChanges: true,
      hasUnseenChanges: false,
    );
    if (!_demo) await _storage.clearChangeLog();
  }

  Future<void> addFavoriteGroup(String groupNumber) async {
    await _storage.addFavoriteGroup(groupNumber);
    state = state.copyWith(favoriteGroups: _storage.getFavoriteGroups());
  }

  Future<void> removeFavoriteGroup(String groupNumber) async {
    await _storage.removeFavoriteGroup(groupNumber);
    state = state.copyWith(favoriteGroups: _storage.getFavoriteGroups());
  }

  bool isFavoriteGroup(String groupNumber) {
    return _storage.isFavoriteGroup(groupNumber);
  }

  /// Раскладывает снимки избранных групп в Hive, чтобы они открывались без
  /// сети. Вызывается после успешного обновления своего расписания — молча и
  /// без влияния на состояние экрана.
  Future<void> prefetchFavorites() async {
    if (_demo) return;
    final groups = state.favoriteGroups;
    if (groups.isEmpty) return;
    for (final fav in groups) {
      if (fav.groupNumber == state.currentGroup) continue;
      await _service.prefetch(fav.groupNumber);
    }
  }

  /// Loads the schedule. Returns a note when data had to be served from
  /// cache after a failed refresh (explicit offline report); null when
  /// fresh data was loaded or [ScheduleState.error] was set.
  Future<String?> loadSchedule(String searchValue,
      {bool forceRefresh = false}) async {
    if (_demo) return null; // Demo never touches the API.

    state = state.copyWith(
      schedule: state.schedule.copyWith(
        searchValue: searchValue,
        isLoading: true,
        error: null,
      ),
    );

    // Try API first
    try {
      final result =
          await _service.getSchedule(searchValue, forceRefresh: forceRefresh);

      // If the API returned an error, try cache as fallback
      if (result.error != null) {
        final cached =
            _storage.getCachedSchedule(searchValue, namespace: _namespace);
        if (cached != null && cached.data.items.isNotEmpty) {
          state =
              state.copyWith(schedule: _stateFromCache(searchValue, cached));
          return await _fallbackNote(result.error!);
        }
        state = state.copyWith(schedule: result);
        return null;
      }
      state = state.copyWith(schedule: result);
      return null;
    } catch (e) {
      // Unexpected error — try cache
      final cached =
          _storage.getCachedSchedule(searchValue, namespace: _namespace);
      if (cached != null && cached.data.items.isNotEmpty) {
        state = state.copyWith(schedule: _stateFromCache(searchValue, cached));
        return await _fallbackNote(ErrorMessages.fromException(e));
      }
      state = state.copyWith(
        schedule: state.schedule.copyWith(
          searchValue: searchValue,
          isLoading: false,
          error: ErrorMessages.fromException(e),
        ),
      );
      return null;
    }
  }

  /// Message for a silent cache fallback: re-check connectivity freshly
  /// (30s probe cache bypassed) so "no internet" is stated explicitly.
  Future<String> _fallbackNote(String fallback) async {
    _connectivity.invalidateCache();
    final online = await _connectivity.checkConnectivity();
    if (online) return fallback;
    return 'Нет подключения к интернету — показано сохранённое расписание';
  }

  /// Признак идущего добора групп: повторный запуск не нужен, второй проход
  /// сделал бы те же запросы.
  bool _enrichingGroups = false;

  /// Догружает полные списки групп к уже показанному расписанию.
  ///
  /// API отдаёт все группы пары только в ответе по аудитории, поэтому при
  /// поиске по группе чипы в карточке появлялись позже расписания. Здесь они
  /// подтягиваются сразу после загрузки — пакетом и с записью в снимок, чтобы
  /// следующий запуск показывал их без сети.
  Future<void> _enrichGroups(String searchValue) async {
    final resolver = _resolver;
    if (_demo || _enrichingGroups || resolver == null) return;
    final items = state.schedule.items;
    if (items.isEmpty) return;
    _enrichingGroups = true;
    try {
      final enriched =
          await resolver.enrich(items, weekStart: state.currentWeekStart);
      if (!mounted || identical(enriched, items)) return;
      // Пока шёл добор, пользователь мог сменить группу.
      if (state.schedule.searchValue != searchValue) return;
      state = state.copyWith(
        schedule: state.schedule.copyWith(items: enriched),
      );
      await _storage.cacheScheduleGroups(searchValue, enriched);
    } finally {
      _enrichingGroups = false;
    }
  }

  /// Обновляет расписание через единый путь: проверка доступности API →
  /// загрузка → результат. Офлайн возвращает `unavailable` без сообщения и без
  /// изменения состояния.
  Future<UpdateResult> refresh() async {
    if (_demo) {
      // В демо нечего обновлять: данные те же, изменений не выдумываем.
      return const UpdateResult(UpdateOutcome.updated, scheduleUpdatedText);
    }

    final group = state.currentGroup;
    if (group == null) {
      return const UpdateResult(UpdateOutcome.failed, 'Группа не выбрана');
    }

    return _updates.run(() async {
      // Bypass the local cache so the user actually gets fresh data.
      final note = await loadSchedule(group, forceRefresh: true);
      // The user has just seen this data — use it as the new baseline.
      if (state.schedule.error == null && state.schedule.items.isNotEmpty) {
        await _storage
            .setScheduleFingerprint(_fingerprint(state.schedule.items));
        // Fresh data reviewed → drop the session batch. The journal and
        // the unseen flag are cleared only from the «Изменения» screen.
        state = state.copyWith(clearChanges: true);
        // Снимки избранного и группы пар догружаются фоном: они не должны
        // задерживать уведомление об успехе.
        unawaited(prefetchFavorites());
        unawaited(_enrichGroups(group));
        return const UpdateResult(UpdateOutcome.updated, scheduleUpdatedText);
      }
      return UpdateResult(
        UpdateOutcome.failed,
        note ?? state.schedule.error ?? 'Не удалось обновить расписание',
      );
    });
  }

  // ── Week Navigation ──────────────────────────────────────

  void goToNextWeek() {
    state = state.copyWith(
      currentWeekStart: getNextWeekStart(state.currentWeekStart),
    );
  }

  void goToPrevWeek() {
    state = state.copyWith(
      currentWeekStart: getPrevWeekStart(state.currentWeekStart),
    );
  }

  void goToToday() {
    state = state.copyWith(
      currentWeekStart: getCurrentWeekStart(),
    );
  }

  void goToWeek(DateTime date) {
    state = state.copyWith(
      currentWeekStart: getWeekStart(date),
    );
  }

  void selectDate(DateTime date) {
    final dayKey = DateTime(date.year, date.month, date.day);
    state = state.copyWith(
      currentWeekStart: getWeekStart(date),
      highlightedDate: dayKey,
    );
    // Auto-clear highlight after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && state.highlightedDate == dayKey) {
        state = state.copyWith(clearHighlighted: true);
      }
    });
  }

  // ── Subjects ─────────────────────────────────────────────

  List<String> getUniqueSubjects() {
    return state.schedule.uniqueSubjects;
  }

  /// Look up teacher name by subject name from schedule items
  String? getScheduleTeacherByName(String subjectName) {
    for (final item in state.schedule.items) {
      if (item.subject == subjectName && item.teacher.isNotEmpty) {
        return item.teacher;
      }
    }
    return null;
  }
}

final scheduleScreenProvider =
    StateNotifierProvider<ScheduleScreenNotifier, ScheduleScreenState>((ref) {
  final demo = ref.watch(demoModeProvider);
  final source = ref.watch(activeSourceProvider);
  // Добор групп пар — только для источников, которые умеют искать по
  // аудитории. У остальных resolver молча выключен.
  final canResolve = ref.watch(activeSourceCapabilitiesProvider).contains(
        SourceCapability.directory,
      );
  return ScheduleScreenNotifier(
    ref.watch(scheduleServiceProvider),
    ref.watch(storageServiceProvider),
    ref.watch(connectivityServiceProvider),
    ref.watch(notificationServiceProvider),
    ref.watch(updateCoordinatorProvider),
    resolver: canResolve ? ref.watch(lessonGroupResolverProvider) : null,
    demo: demo,
    target: source == null ? null : connectorFor(source).targetValue(source),
    namespace: ref.watch(activeSourceNamespaceProvider),
  );
});

/// Ключ пары для запроса полного списка групп. Набор полей, а не объект:
/// у `ScheduleItem` нет равенства, а `family` сравнивает аргумент.
typedef LessonGroupsKey = ({
  String date,
  String time,
  String subject,
  String classroom,
});

/// Полный список групп пары — добирается запросом по аудитории.
///
/// Без `autoDispose`: карточка пары открывается и закрывается постоянно, а
/// результат уже известен — повторный запрос каждый раз показывал «пустые»
/// группы и подгружал их заново.
final lessonGroupsProvider =
    FutureProvider.family<List<GroupInfo>, LessonGroupsKey>((ref, key) {
  return ref.watch(lessonGroupResolverProvider).resolve(
        date: key.date,
        time: key.time,
        subject: key.subject,
        classroom: key.classroom,
      );
});
