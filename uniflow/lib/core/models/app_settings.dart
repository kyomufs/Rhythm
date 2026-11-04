import 'package:flutter/material.dart';

/// Available accent color palette
class ColorOption {
  final String name;
  final int colorValue;

  const ColorOption({required this.name, required this.colorValue});
  Color get color => Color(colorValue);
}

const List<ColorOption> paletteOptions = [
  ColorOption(name: 'Фиолетовый', colorValue: 0xFF6750A4),
  ColorOption(name: 'Синий', colorValue: 0xFF0061A4),
  ColorOption(name: 'Зелёный', colorValue: 0xFF006D3C),
  ColorOption(name: 'Красный', colorValue: 0xFFBA1A1A),
  ColorOption(name: 'Оранжевый', colorValue: 0xFF9C4100),
  ColorOption(name: 'Бирюзовый', colorValue: 0xFF006A60),
  ColorOption(name: 'Жёлто-коричневый', colorValue: 0xFF7C5800),
  ColorOption(name: 'Розовый', colorValue: 0xFF984061),
];

/// Application settings model
class AppSettings {
  final int seedColorValue;
  final String themeMode; // 'system', 'light', 'dark'
  final bool showGroupsInSchedule;

  /// Demo mode: a throwaway generated schedule plus fun previews
  /// (live lesson countdown, sample change journal).
  final bool demoMode;

  /// Период фоновой проверки расписания в минутах. 0 — проверка выключена.
  final int backgroundCheckMinutes;

  const AppSettings({
    this.seedColorValue = 0xFF6750A4,
    this.themeMode = 'system',
    this.showGroupsInSchedule = true,
    this.demoMode = false,
    this.backgroundCheckMinutes = defaultBackgroundCheckMinutes,
  });

  /// 30 минут — компромисс: расписание меняется редко, а каждый опрос — это
  /// полный запрос недели на группу.
  static const int defaultBackgroundCheckMinutes = 30;

  /// Допустимые периоды: подписи задают порядок в настройках.
  static const List<int> backgroundCheckPresets = [0, 15, 30, 60, 180];

  /// Подпись для периода. [minutes] вне пресетов показывается как есть.
  static String backgroundCheckLabel(int minutes) {
    switch (minutes) {
      case 0:
        return 'Выкл';
      case 15:
        return '15 мин';
      case 30:
        return '30 мин';
      case 60:
        return '1 час';
      case 180:
        return '3 часа';
      default:
        return '$minutes мин';
    }
  }

  Color get seedColor => Color(seedColorValue);

  ThemeMode get parsedThemeMode {
    switch (themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  AppSettings copyWith({
    int? seedColorValue,
    String? themeMode,
    bool? showGroupsInSchedule,
    bool? demoMode,
    int? backgroundCheckMinutes,
  }) {
    return AppSettings(
      seedColorValue: seedColorValue ?? this.seedColorValue,
      themeMode: themeMode ?? this.themeMode,
      showGroupsInSchedule: showGroupsInSchedule ?? this.showGroupsInSchedule,
      demoMode: demoMode ?? this.demoMode,
      backgroundCheckMinutes:
          backgroundCheckMinutes ?? this.backgroundCheckMinutes,
    );
  }

  Map<String, dynamic> toJson() => {
        'seedColorValue': seedColorValue,
        'themeMode': themeMode,
        'showGroupsInSchedule': showGroupsInSchedule,
        'demoMode': demoMode,
        'backgroundCheckMinutes': backgroundCheckMinutes,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      seedColorValue: json['seedColorValue'] as int? ?? 0xFF6750A4,
      themeMode: json['themeMode'] as String? ?? 'system',
      showGroupsInSchedule: json['showGroupsInSchedule'] as bool? ?? true,
      demoMode: json['demoMode'] as bool? ?? false,
      backgroundCheckMinutes: json['backgroundCheckMinutes'] as int? ??
          defaultBackgroundCheckMinutes,
    );
  }
}
