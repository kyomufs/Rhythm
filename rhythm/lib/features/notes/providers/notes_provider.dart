import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tulgusch/core/models/note_models.dart';
import 'package:tulgusch/core/services/storage_service.dart';

// ── Notes State ─────────────────────────────────────────────

class NotesState {
  final List<SubjectFolder> folders;
  final bool isLoading;

  const NotesState({
    this.folders = const [],
    this.isLoading = false,
  });

  NotesState copyWith({List<SubjectFolder>? folders, bool? isLoading}) {
    return NotesState(
      folders: folders ?? this.folders,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class NotesNotifier extends StateNotifier<NotesState> {
  final StorageService _storage;

  NotesNotifier(this._storage) : super(const NotesState()) {
    _init();
  }

  Future<void> _init() async {
    // Run migration from legacy data if needed
    await _storage.migrateFromLegacy();
    _load();
  }

  void _load() {
    final folders = _storage.getStudyFolders();
    state = NotesState(folders: folders);
  }

  // ── Subject CRUD ────────────────────────────────────────────

  Future<void> addSubject(SubjectFolder folder) async {
    final folders = [...state.folders, folder];
    await _storage.saveStudyFolders(folders);
    _load();
  }

  Future<void> updateSubject(SubjectFolder folder) async {
    final folders =
        state.folders.map((f) => f.id == folder.id ? folder : f).toList();
    await _storage.saveStudyFolders(folders);
    _load();
  }

  Future<void> deleteSubject(String id) async {
    final folders = state.folders.where((f) => f.id != id).toList();
    await _storage.saveStudyFolders(folders);
    _load();
  }

  SubjectFolder? getSubjectById(String id) {
    try {
      return state.folders.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── Subfolder CRUD ──────────────────────────────────────────

  Future<void> addSubfolder(
      String subjectId, SubjectSubfolder subfolder) async {
    final folder = getSubjectById(subjectId);
    if (folder == null) return;
    final updated = folder.copyWith(
      subfolders: [...folder.subfolders, subfolder],
    );
    await updateSubject(updated);
  }

  Future<void> deleteSubfolder(String subjectId, String subfolderId) async {
    final folder = getSubjectById(subjectId);
    if (folder == null) return;
    final updated = folder.copyWith(
      subfolders:
          folder.subfolders.where((sf) => sf.id != subfolderId).toList(),
    );
    await updateSubject(updated);
  }

  /// Show/hide a subfolder without touching its tasks.
  Future<void> setSubfolderHidden(
      String subjectId, String subfolderId, bool hidden) async {
    final folder = getSubjectById(subjectId);
    if (folder == null) return;
    final updated = folder.copyWith(
      subfolders: folder.subfolders
          .map(
              (sf) => sf.id == subfolderId ? sf.copyWith(isHidden: hidden) : sf)
          .toList(),
    );
    await updateSubject(updated);
  }

  // ── Task CRUD ───────────────────────────────────────────────

  Future<void> addTask(
      String subjectId, String subfolderId, StudyTask task) async {
    final folder = getSubjectById(subjectId);
    if (folder == null) return;
    final subfolders = folder.subfolders.map((sf) {
      if (sf.id == subfolderId) {
        return sf.copyWith(tasks: [...sf.tasks, task]);
      }
      return sf;
    }).toList();
    await updateSubject(folder.copyWith(subfolders: subfolders));
  }

  Future<void> updateTask(
    String subjectId,
    String subfolderId,
    StudyTask updatedTask,
  ) async {
    final folder = getSubjectById(subjectId);
    if (folder == null) return;
    final subfolders = folder.subfolders.map((sf) {
      if (sf.id == subfolderId) {
        return sf.copyWith(
          tasks: sf.tasks
              .map((t) => t.id == updatedTask.id ? updatedTask : t)
              .toList(),
        );
      }
      return sf;
    }).toList();
    await updateSubject(folder.copyWith(subfolders: subfolders));
  }

  /// Unified create/edit: upsert [task] into [targetSubfolderId],
  /// removing any copy with the same id from other subfolders (move).
  Future<void> saveTask(
    String subjectId,
    String targetSubfolderId,
    StudyTask task,
  ) async {
    final folder = getSubjectById(subjectId);
    if (folder == null) return;
    final subfolders = folder.subfolders.map((sf) {
      final without = sf.tasks.where((t) => t.id != task.id).toList();
      if (sf.id == targetSubfolderId) {
        return sf.copyWith(tasks: [...without, task]);
      }
      return without.length == sf.tasks.length
          ? sf
          : sf.copyWith(tasks: without);
    }).toList();
    await updateSubject(folder.copyWith(subfolders: subfolders));
  }

  Future<void> updateTaskStatus(
    String subjectId,
    String subfolderId,
    String taskId,
    TaskStatus status,
  ) async {
    final folder = getSubjectById(subjectId);
    if (folder == null) return;
    final subfolders = folder.subfolders.map((sf) {
      if (sf.id == subfolderId) {
        return sf.copyWith(
          tasks: sf.tasks.map((t) {
            if (t.id == taskId) return t.copyWith(status: status);
            return t;
          }).toList(),
        );
      }
      return sf;
    }).toList();
    await updateSubject(folder.copyWith(subfolders: subfolders));
  }

  Future<void> deleteTask(
    String subjectId,
    String subfolderId,
    String taskId,
  ) async {
    final folder = getSubjectById(subjectId);
    if (folder == null) return;
    final subfolders = folder.subfolders.map((sf) {
      if (sf.id == subfolderId) {
        return sf.copyWith(
          tasks: sf.tasks.where((t) => t.id != taskId).toList(),
        );
      }
      return sf;
    }).toList();
    await updateSubject(folder.copyWith(subfolders: subfolders));
  }

  // ── Helpers ─────────────────────────────────────────────────

  /// Find which subfolder contains a task
  String? findSubfolderForTask(String subjectId, String taskId) {
    final folder = getSubjectById(subjectId);
    if (folder == null) return null;
    for (final sf in folder.subfolders) {
      if (sf.tasks.any((t) => t.id == taskId)) return sf.id;
    }
    return null;
  }

  void refresh() => _load();
}

final notesProvider = StateNotifierProvider<NotesNotifier, NotesState>((ref) {
  return NotesNotifier(ref.watch(storageServiceProvider));
});
