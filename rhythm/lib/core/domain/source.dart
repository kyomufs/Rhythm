import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════
/// Источник — университет, школа, работа, курсы. Всё содержимое
/// приложения (расписание, журнал) скоупится источником.
/// ═══════════════════════════════════════════════════════════════

enum SourceKind { university, school, work, courses, other }

/// Что источник умеет. Журнал баллов сюда не входит: он всегда
/// локальный и работает без провайдера.
enum SourceCapability { directory, schedule, calendar, finalMarks, profile }

class Source {
  final String id;
  final SourceKind kind;
  final String title;
  final String? subtitle;

  /// null — источник без API, всё ведётся вручную.
  final String? providerId;
  final Map<String, String> config;
  final int colorIndex;
  final DateTime createdAt;

  const Source({
    required this.id,
    required this.kind,
    required this.title,
    this.subtitle,
    this.providerId,
    this.config = const {},
    this.colorIndex = 0,
    required this.createdAt,
  });

  bool get isManual => providerId == null;

  /// Начальная буква/аббревиатура для бейджа в шапке.
  String get badge {
    final words = title.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return '?';
    if (words.length > 1) {
      return words.take(2).map((w) => w[0].toUpperCase()).join();
    }
    final first = words.first;
    return (first.length >= 2 ? first.substring(0, 2) : first).toUpperCase();
  }

  Source copyWith({
    SourceKind? kind,
    String? title,
    String? subtitle,
    String? providerId,
    Map<String, String>? config,
    int? colorIndex,
  }) {
    return Source(
      id: id,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      providerId: providerId ?? this.providerId,
      config: config ?? this.config,
      colorIndex: colorIndex ?? this.colorIndex,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'title': title,
        'subtitle': subtitle,
        'providerId': providerId,
        'config': config,
        'colorIndex': colorIndex,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Source.fromJson(Map<String, dynamic> json) {
    return Source(
      id: json['id'] as String,
      kind: SourceKind.values.firstWhere(
        (e) => e.name == json['kind'],
        orElse: () => SourceKind.other,
      ),
      title: json['title'] as String? ?? 'Источник',
      subtitle: json['subtitle'] as String?,
      providerId: json['providerId'] as String?,
      config: (json['config'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          ) ??
          const {},
      colorIndex: (json['colorIndex'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

String sourceKindLabel(SourceKind kind) {
  switch (kind) {
    case SourceKind.university:
      return 'Университет';
    case SourceKind.school:
      return 'Школа';
    case SourceKind.work:
      return 'Работа';
    case SourceKind.courses:
      return 'Курсы';
    case SourceKind.other:
      return 'Другое';
  }
}

IconData sourceKindIcon(SourceKind kind) {
  switch (kind) {
    case SourceKind.university:
      return Icons.school_outlined;
    case SourceKind.school:
      return Icons.local_library_outlined;
    case SourceKind.work:
      return Icons.work_outline;
    case SourceKind.courses:
      return Icons.auto_stories_outlined;
    case SourceKind.other:
      return Icons.folder_outlined;
  }
}

String sourceCapabilityLabel(SourceCapability capability) {
  switch (capability) {
    case SourceCapability.directory:
      return 'поиск';
    case SourceCapability.schedule:
      return 'расписание';
    case SourceCapability.calendar:
      return 'календарь';
    case SourceCapability.finalMarks:
      return 'оценки';
    case SourceCapability.profile:
      return 'профиль';
  }
}
