import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tulgusch/core/models/marks.dart';
import 'package:tulgusch/core/demo/demo_marks.dart';
import 'package:tulgusch/core/providers/clock_provider.dart';
import 'package:tulgusch/core/utils/error_messages.dart';
import 'package:tulgusch/core/services/storage_service.dart';
import 'package:tulgusch/core/services/update_coordinator.dart';
import 'package:tulgusch/core/api/api_providers.dart';
import 'package:tulgusch/core/api/schedule_api.dart';
import 'package:tulgusch/features/profile/providers/profile_providers.dart';

/// Performance screen state
class PerformanceState {
  final List<MarksItem> marks;
  final bool isLoading;
  final String? error;
  final int selectedSemester;

  const PerformanceState({
    this.marks = const [],
    this.isLoading = false,
    this.error,
    this.selectedSemester = 0, // 0 = latest
  });

  /// Available semesters (sorted ascending: 1, 2, 3...)
  List<int> get availableSemesters {
    final terms = marks.map((m) => m.termNumber).toSet().toList();
    terms.sort((a, b) => a.compareTo(b));
    return terms;
  }

  /// Marks for the selected semester
  List<MarksItem> get semesterMarks {
    if (selectedSemester == 0 && marks.isNotEmpty) {
      final terms = availableSemesters;
      if (terms.isNotEmpty) {
        return marks.where((m) => m.termNumber == terms.first).toList();
      }
      return marks;
    }
    return marks.where((m) => m.termNumber == selectedSemester).toList();
  }

  /// Stats for selected semester
  int get totalSubjects => semesterMarks.length;
  int get attestedCount => semesterMarks.where((m) => m.isAttested).length;
  int get notAttestedCount => totalSubjects - attestedCount;

  /// The latest (highest) semester number
  int get latestSemester =>
      availableSemesters.isEmpty ? 0 : availableSemesters.last;

  PerformanceState copyWith({
    List<MarksItem>? marks,
    bool? isLoading,
    String? error,
    bool clearError = false,
    int? selectedSemester,
  }) {
    return PerformanceState(
      marks: marks ?? this.marks,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      selectedSemester: selectedSemester ?? this.selectedSemester,
    );
  }
}

class PerformanceNotifier extends StateNotifier<PerformanceState> {
  final FinalMarksApi? _api;
  final StorageService _storage;
  final UpdateCoordinator _updates;
  final bool _demo;
  final String? _studentId;
  final String? _group;

  /// Автообновление при входе: завершается `true`, если оценки реально
  /// подтянулись из API. По этому флагу оболочка показывает плашку без
  /// действий пользователя.
  final Completer<bool> _bootRefresh = Completer<bool>();
  Future<bool> get bootRefresh => _bootRefresh.future;

  PerformanceNotifier(
    this._api,
    this._storage,
    this._updates, {
    bool demo = false,
    String? studentId,
    String? group,
  })  : _demo = demo,
        _studentId = studentId,
        _group = group,
        super(const PerformanceState()) {
    loadMarks().then(
      (result) => _bootRefresh.complete(result.isSuccess && !_demo),
      onError: (_) => _bootRefresh.complete(false),
    );
  }

  /// Загружает оценки через единый путь обновления: проверка доступности API
  /// → запрос → результат. Офлайн молчит и оставляет сохранённые оценки.
  /// Демо-режим не ходит в сеть вовсе.
  Future<UpdateResult> loadMarks() async {
    if (_demo) {
      state = state.copyWith(marks: buildDemoMarks(), clearError: true);
      _autoSelectSemester();
      return const UpdateResult(UpdateOutcome.updated, marksUpdatedText);
    }

    final studentId = _studentId;
    final group = _group;

    if (studentId == null || group == null) {
      final msg = studentId == null
          ? 'Укажите номер зачётки в профиле'
          : 'Укажите подгруппу в профиле (например, 01)';
      state = state.copyWith(error: msg);
      return UpdateResult(UpdateOutcome.failed, msg);
    }

    // Stale-while-revalidate: paint the local snapshot first (this runs
    // synchronously during construction, before any network wait), then
    // sync with the API and swap the data in place.
    final cached = _storage.getCachedMarks(
      studentId: studentId,
      group: group,
    );
    if (state.marks.isEmpty && cached != null && cached.isNotEmpty) {
      state = state.copyWith(marks: cached, clearError: true);
      _autoSelectSemester();
    }

    return _updates.run(() async {
      state = state.copyWith(isLoading: true, clearError: true);
      try {
        final api = _api;
        if (api == null) {
          return const UpdateResult(
              UpdateOutcome.failed, 'Источник не отдаёт итоговые оценки');
        }
        final marks = (await api.finalMarks(studentId: studentId, group: group))
            .map(MarksItem.fromFinalMark)
            .toList();
        if (!mounted) {
          return const UpdateResult(
              UpdateOutcome.failed, 'Не удалось обновить оценки');
        }
        await _storage.cacheMarks(
          studentId: studentId,
          group: group,
          marks: marks,
        );
        state = state.copyWith(marks: marks, isLoading: false);
        _autoSelectSemester();
        return const UpdateResult(UpdateOutcome.updated, marksUpdatedText);
      } catch (e) {
        if (!mounted) {
          return const UpdateResult(
              UpdateOutcome.failed, 'Не удалось обновить оценки');
        }
        // API ответил ошибкой — сохранённые оценки остаются на экране.
        final servedCache = cached != null && cached.isNotEmpty;
        if (servedCache) {
          state =
              state.copyWith(marks: cached, isLoading: false, clearError: true);
          _autoSelectSemester();
        } else {
          state = state.copyWith(
              isLoading: false, error: ErrorMessages.fromException(e));
        }
        return UpdateResult(
            UpdateOutcome.failed, ErrorMessages.fromException(e));
      }
    });
  }

  void _autoSelectSemester() {
    if (state.availableSemesters.isNotEmpty) {
      state = state.copyWith(selectedSemester: state.availableSemesters.first);
    }
  }

  void selectSemester(int semester) {
    state = state.copyWith(selectedSemester: semester);
  }
}

/// Хватает ли профиля для итоговых оценок: нужны зачётка и группа.
final isPerformanceConfiguredProvider = Provider<bool>((ref) {
  // Demo mode never needs real profile fields — marks are generated.
  if (ref.watch(demoModeProvider)) return true;
  return ref.watch(profileStudentIdProvider) != null &&
      ref.watch(profileGroupProvider) != null;
});

final performanceProvider =
    StateNotifierProvider<PerformanceNotifier, PerformanceState>((ref) {
  // Пересоздаём notifier (и перечитываем оценки) при смене профиля.
  return PerformanceNotifier(
    ref.watch(finalMarksApiProvider),
    ref.watch(storageServiceProvider),
    ref.watch(updateCoordinatorProvider),
    demo: ref.watch(demoModeProvider),
    studentId: ref.watch(profileStudentIdProvider),
    group: ref.watch(profileGroupProvider),
  );
});
