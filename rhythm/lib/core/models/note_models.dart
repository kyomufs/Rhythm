library;

/// ═══════════════════════════════════════════════════════════════
/// Study Tracker Models — SubjectFolder → Subfolders → Tasks
/// ═══════════════════════════════════════════════════════════════

/// Task status
enum TaskStatus { todo, inProgress, done }

/// Task priority
enum TaskPriority { low, medium, high }

/// Default subfolder names for a newly created subject
const List<String> defaultSubfolderNames = [
  'Лекции',
  'Лабы',
  'Практики',
];

/// ── Subject Folder (top-level) ──────────────────────────────
class SubjectFolder {
  final String id;
  final String name;
  final String? teacher;
  final int colorIndex;
  final DateTime createdAt;
  final List<SubjectSubfolder> subfolders;

  const SubjectFolder({
    required this.id,
    required this.name,
    this.teacher,
    this.colorIndex = 0,
    required this.createdAt,
    this.subfolders = const [],
  });

  /// Total tasks across all subfolders
  int get totalTasks => subfolders.fold(0, (sum, sf) => sum + sf.tasks.length);

  /// Completed tasks across all subfolders
  int get completedTasks => subfolders.fold(
      0,
      (sum, sf) =>
          sum + sf.tasks.where((t) => t.status == TaskStatus.done).length);

  /// Completion percentage (0.0–1.0)
  double get completionPercent =>
      totalTasks == 0 ? 0.0 : completedTasks / totalTasks;

  /// All tasks flattened
  List<StudyTask> get allTasks => subfolders.expand((sf) => sf.tasks).toList();

  /// Upcoming deadlines (todo or inProgress tasks with due date in the future)
  List<StudyTask> get upcomingDeadlines {
    final now = DateTime.now();
    return allTasks
        .where((t) =>
            t.dueDate != null &&
            t.dueDate!.isAfter(now) &&
            t.status != TaskStatus.done)
        .toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'teacher': teacher,
        'colorIndex': colorIndex,
        'createdAt': createdAt.toIso8601String(),
        'subfolders': subfolders.map((sf) => sf.toJson()).toList(),
      };

  factory SubjectFolder.fromJson(Map<String, dynamic> json) {
    return SubjectFolder(
      id: json['id'] as String,
      name: json['name'] as String,
      teacher: json['teacher'] as String?,
      colorIndex: json['colorIndex'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      subfolders: (json['subfolders'] as List<dynamic>?)
              ?.map((e) => SubjectSubfolder.fromJson(
                  Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
    );
  }

  SubjectFolder copyWith({
    String? name,
    String? teacher,
    int? colorIndex,
    List<SubjectSubfolder>? subfolders,
  }) {
    return SubjectFolder(
      id: id,
      name: name ?? this.name,
      teacher: teacher ?? this.teacher,
      colorIndex: colorIndex ?? this.colorIndex,
      createdAt: createdAt,
      subfolders: subfolders ?? this.subfolders,
    );
  }
}

/// ── Subfolder (inside a subject) ────────────────────────────
class SubjectSubfolder {
  final String id;
  final String name;
  final bool isDefault;
  final bool isHidden;
  final List<StudyTask> tasks;

  const SubjectSubfolder({
    required this.id,
    required this.name,
    this.isDefault = false,
    this.isHidden = false,
    this.tasks = const [],
  });

  int get completedCount =>
      tasks.where((t) => t.status == TaskStatus.done).length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isDefault': isDefault,
        'isHidden': isHidden,
        'tasks': tasks.map((t) => t.toJson()).toList(),
      };

  factory SubjectSubfolder.fromJson(Map<String, dynamic> json) {
    return SubjectSubfolder(
      id: json['id'] as String,
      name: json['name'] as String,
      isDefault: json['isDefault'] as bool? ?? false,
      isHidden: json['isHidden'] as bool? ?? false,
      tasks: (json['tasks'] as List<dynamic>?)
              ?.map((e) =>
                  StudyTask.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
    );
  }

  SubjectSubfolder copyWith({
    String? name,
    bool? isHidden,
    List<StudyTask>? tasks,
  }) {
    return SubjectSubfolder(
      id: id,
      name: name ?? this.name,
      isDefault: isDefault,
      isHidden: isHidden ?? this.isHidden,
      tasks: tasks ?? this.tasks,
    );
  }
}

/// ── Study Task ──────────────────────────────────────────────
class StudyTask {
  final String id;
  final String title;
  final String? description;
  final TaskStatus status;
  final DateTime? dueDate;
  final String? grade;
  final TaskPriority priority;
  final DateTime createdAt;

  const StudyTask({
    required this.id,
    required this.title,
    this.description,
    this.status = TaskStatus.todo,
    this.dueDate,
    this.grade,
    this.priority = TaskPriority.medium,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'status': status.name,
        'dueDate': dueDate?.toIso8601String(),
        'grade': grade,
        'priority': priority.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory StudyTask.fromJson(Map<String, dynamic> json) {
    return StudyTask(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      status: TaskStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TaskStatus.todo,
      ),
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'] as String)
          : null,
      grade: json['grade'] as String?,
      priority: TaskPriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => TaskPriority.medium,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  StudyTask copyWith({
    String? title,
    String? description,
    TaskStatus? status,
    DateTime? dueDate,
    String? grade,
    TaskPriority? priority,
  }) {
    return StudyTask(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      grade: grade ?? this.grade,
      priority: priority ?? this.priority,
      createdAt: createdAt,
    );
  }
}

/// ═══════════════════════════════════════════════════════════════
/// Display helpers
/// ═══════════════════════════════════════════════════════════════

/// Predefined colors for subjects
const List<int> subjectColors = [
  0xFF6750A4, // Purple
  0xFF006D3C, // Green
  0xFF9C4100, // Orange
  0xFF0061A4, // Blue
  0xFFBA1A1A, // Red
  0xFF006A60, // Teal
  0xFF7C5800, // Yellow-ish
  0xFF8B4513, // Brown
  0xFF6A1B9A, // Deep Purple
  0xFF00838F, // Cyan
];

/// Task status display name (Russian)
String taskStatusDisplayName(TaskStatus status) {
  switch (status) {
    case TaskStatus.todo:
      return 'К выполнению';
    case TaskStatus.inProgress:
      return 'В работе';
    case TaskStatus.done:
      return 'Выполнено';
  }
}

/// Task status icon name (use with IconData in Flutter)
/// Returns a string identifier: 'radio_unchecked', 'play_circle', 'check_circle'
String taskStatusIconName(TaskStatus status) {
  switch (status) {
    case TaskStatus.todo:
      return 'radio_unchecked';
    case TaskStatus.inProgress:
      return 'play_circle';
    case TaskStatus.done:
      return 'check_circle';
  }
}

/// Priority display name (Russian)
String taskPriorityDisplayName(TaskPriority priority) {
  switch (priority) {
    case TaskPriority.low:
      return 'Низкий';
    case TaskPriority.medium:
      return 'Средний';
    case TaskPriority.high:
      return 'Высокий';
  }
}

/// Priority color index (into a set of colors, not subjectColors)
int taskPriorityColorIndex(TaskPriority priority) {
  switch (priority) {
    case TaskPriority.low:
      return 0; // green
    case TaskPriority.medium:
      return 1; // orange
    case TaskPriority.high:
      return 2; // red
  }
}

/// ═══════════════════════════════════════════════════════════════
/// Legacy models (kept for migration only — will be removed later)
/// ═══════════════════════════════════════════════════════════════

/// Legacy Subject model
class Subject {
  final String id;
  final String name;
  final String type;
  final int colorIndex;
  final DateTime createdAt;

  const Subject({
    required this.id,
    required this.name,
    required this.type,
    this.colorIndex = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'colorIndex': colorIndex,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      colorIndex: json['colorIndex'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// Legacy Task model
class Task {
  final String id;
  final String subjectId;
  final String title;
  final bool isCompleted;
  final DateTime? dueDate;
  final DateTime createdAt;

  const Task({
    required this.id,
    required this.subjectId,
    required this.title,
    this.isCompleted = false,
    this.dueDate,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'subjectId': subjectId,
        'title': title,
        'isCompleted': isCompleted,
        'dueDate': dueDate?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      subjectId: json['subjectId'] as String,
      title: json['title'] as String,
      isCompleted: json['isCompleted'] as bool? ?? false,
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// Legacy Note model
class Note {
  final String id;
  final String subjectId;
  final String content;
  final DateTime createdAt;

  const Note({
    required this.id,
    required this.subjectId,
    required this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'subjectId': subjectId,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String,
      subjectId: json['subjectId'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
