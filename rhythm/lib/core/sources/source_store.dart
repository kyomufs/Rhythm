import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rhythm/core/domain/source.dart';
import 'package:rhythm/core/services/storage_service.dart';
import 'package:rhythm/core/sources/registry.dart';
import 'package:rhythm/core/sources/source_api.dart';

/// Список источников и один активный. Активный ровно один: так проще
/// объяснить, куда попадут баллы, и не размывать статистику.
class SourcesState {
  final List<Source> sources;
  final String? activeId;
  final bool isReady;

  const SourcesState({
    this.sources = const [],
    this.activeId,
    this.isReady = false,
  });

  Source? get active {
    if (sources.isEmpty) return null;
    for (final source in sources) {
      if (source.id == activeId) return source;
    }
    return sources.first;
  }

  bool get hasMany => sources.length > 1;

  SourcesState copyWith({
    List<Source>? sources,
    String? activeId,
    bool? isReady,
    bool clearActive = false,
  }) {
    return SourcesState(
      sources: sources ?? this.sources,
      activeId: clearActive ? null : (activeId ?? this.activeId),
      isReady: isReady ?? this.isReady,
    );
  }
}

class SourcesNotifier extends StateNotifier<SourcesState> {
  final StorageService _storage;

  SourcesNotifier(this._storage) : super(const SourcesState()) {
    _load();
  }

  void _load() {
    // Ящик ещё не открыт: источник появится после init, а не упадёт
    // LateError на первом кадре.
    if (!_storage.isInitialized) {
      state = const SourcesState();
      return;
    }
    final stored = _storage.getSources();
    if (stored.isEmpty) {
      final bootstrapped = _bootstrap();
      state = SourcesState(
        sources: bootstrapped,
        activeId: bootstrapped.isEmpty ? null : bootstrapped.first.id,
        isReady: true,
      );
      if (bootstrapped.isNotEmpty) {
        _storage.saveSources(bootstrapped);
        _storage.setActiveSourceId(bootstrapped.first.id);
      }
      return;
    }

    final activeId = _storage.getActiveSourceId();
    final valid = stored.any((s) => s.id == activeId);
    state = SourcesState(
      sources: stored,
      activeId: valid ? activeId : stored.first.id,
      isReady: true,
    );
    if (!valid) _storage.setActiveSourceId(stored.first.id);
  }

  /// Первый запуск: источников ещё нет, но группа в профиле может быть —
  /// тогда ТулГУ становится источником по умолчанию.
  List<Source> _bootstrap() {
    final group = _storage.getMyGroup();
    if (group == null || group.isEmpty) return const [];
    return [
      Source(
        id: 'tulsu-${DateTime.now().millisecondsSinceEpoch}',
        kind: SourceKind.university,
        title: 'ТулГУ',
        subtitle: group,
        providerId: tulsuSourceProvider.id,
        config: {'group': _storage.getFullAcademicGroup() ?? group},
        createdAt: DateTime.now(),
      ),
    ];
  }

  Future<void> add(Source source) async {
    final next = [...state.sources, source];
    state = state.copyWith(sources: next, activeId: source.id);
    await _storage.saveSources(next);
    await _storage.setActiveSourceId(source.id);
  }

  Future<void> update(Source source) async {
    final next = [
      for (final item in state.sources) item.id == source.id ? source : item,
    ];
    state = state.copyWith(sources: next);
    await _storage.saveSources(next);
  }

  /// Удаление источника уносит его журнал: данные не должны висеть сиротами.
  Future<void> remove(String id) async {
    final next = state.sources.where((s) => s.id != id).toList();
    final nextActive = state.activeId == id
        ? (next.isEmpty ? null : next.first.id)
        : state.activeId;
    state = SourcesState(
      sources: next,
      activeId: nextActive,
      isReady: true,
    );
    await _storage.saveSources(next);
    await _storage.setActiveSourceId(nextActive);
    await _storage.deleteJournal(id);
  }

  Future<void> select(String id) async {
    if (state.activeId == id) return;
    state = state.copyWith(activeId: id);
    await _storage.setActiveSourceId(id);
  }
}

final sourcesProvider =
    StateNotifierProvider<SourcesNotifier, SourcesState>((ref) {
  return SourcesNotifier(ref.watch(storageServiceProvider));
});

final activeSourceProvider = Provider<Source?>((ref) {
  return ref.watch(sourcesProvider.select((s) => s.active));
});

/// Расписание активного источника. Источник без расписания отдаёт
/// заглушку, которая отвечает понятной ошибкой вместо падения.
final scheduleApiProvider = Provider<ScheduleApi>((ref) {
  final source = ref.watch(activeSourceProvider);
  return providerFor(source).scheduleApi(source ?? _fallbackSource);
});

/// Итоговые оценки активного источника; null — источник их не отдаёт.
final finalMarksApiProvider = Provider<FinalMarksApi?>((ref) {
  final source = ref.watch(activeSourceProvider);
  if (source == null) return null;
  return providerFor(source).marksApi(source);
});

/// Заглушка нужна только пока источников нет: провайдер требует объект.
final _fallbackSource = Source(
  id: '_none',
  kind: SourceKind.other,
  title: '',
  providerId: manualSourceProvider.id,
  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
);
