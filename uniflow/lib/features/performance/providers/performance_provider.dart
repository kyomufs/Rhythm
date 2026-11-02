import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uniflow/core/api/tulsu_api.dart';
import 'package:uniflow/core/demo/demo_marks.dart';
import 'package:uniflow/core/providers/clock_provider.dart';
import 'package:uniflow/core/utils/error_messages.dart';
import 'package:uniflow/core/services/storage_service.dart';
import 'package:uniflow/core/services/update_coordinator.dart';
import 'package:uniflow/features/profile/providers/profile_providers.dart';

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
  final ProgressApiClient _api;
  final StorageService _storage;
  final UpdateCoordinator _updates;
  final bool _demo;

  PerformanceNotifier(this._api, this._storage, this._updates,
      {bool demo = false})
      : _demo = demo,
        super(const PerformanceState()) {
    loadMarks();
  }

  /// Загружает оценки через единый путь обновления: проверка доступности API
  /// → запрос → результат. Офлайн молчит и оставляет сохранённые оценки.
  /// Демо-режим не ходит в сеть вовсе.
  Future<UpdateResult> loadMarks() async {
    if (_demo) {
      state = state.copyWith(marks: buildDemoMarks(), clearError: true);
      _autoSelectSemester();
      return const UpdateResult(UpdateOutcome.updated, 'Оценки обновлены');
    }

    final studentId = _storage.getStudentId();
    final group = _storage.getFullAcademicGroup();

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
    final cached = _storage.getCachedMarks(studentId: studentId, group: group);
    if (state.marks.isEmpty && cached != null && cached.isNotEmpty) {
      state = state.copyWith(marks: cached, clearError: true);
      _autoSelectSemester();
    }

    return _updates.run(() async {
      state = state.copyWith(isLoading: true, clearError: true);
      try {
        final marks = await _api.getMarks(
          personalAffair: studentId,
          groupTitle: group,
        );
        if (!mounted) {
          return const UpdateResult(
              UpdateOutcome.failed, 'Не удалось обновить оценки');
        }
        await _storage.cacheMarks(
            studentId: studentId, group: group, marks: marks);
        state = state.copyWith(marks: marks, isLoading: false);
        _autoSelectSemester();
        return const UpdateResult(UpdateOutcome.updated, 'Оценки обновлены');
      } catch (e) {
        if (!mounted) {
          return const UpdateResult(
              UpdateOutcome.failed, 'Не удалось обновить оценки');
        }
        // API ответил ошибкой — сохранённые оценки остаются на экране.
        final servedCache = cached != null && cached.isNotEmpty;
        if (servedCache) {
          state = state.copyWith(
              marks: cached, isLoading: false, clearError: true);
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

/// Whether performance is configured (student ID + group)
final isPerformanceConfiguredProvider = Provider<bool>((ref) {
  // Demo mode never needs real profile fields — marks are generated.
  if (ref.watch(demoModeProvider)) return true;
  // Re-evaluate when profile fields change (group/subgroup/student ID).
  ref.watch(profileRevisionProvider);
  final storage = ref.watch(storageServiceProvider);
  return storage.getStudentId() != null &&
      storage.getFullAcademicGroup() != null;
});

final performanceProvider =
    StateNotifierProvider<PerformanceNotifier, PerformanceState>((ref) {
  // Recreate the notifier (and reload marks) whenever profile data changes.
  ref.watch(profileRevisionProvider);
  final demo = ref.watch(demoModeProvider);
  return PerformanceNotifier(
    ref.watch(progressApiClientProvider),
    ref.watch(storageServiceProvider),
    ref.watch(updateCoordinatorProvider),
    demo: demo,
  );
});
