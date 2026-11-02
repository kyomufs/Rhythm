import 'package:flutter/material.dart';

/// Типографика Material 3 Expressive.
///
/// Baseline-шкала остаётся, emphasized — не замена, а разметка акцента:
/// размер и line height совпадают, отличаются только вес и tracking.
///
/// Во Flutter emphasized-стилей нет, поэтому они собираются здесь из значений
/// токенов.
class AppTypography {
  AppTypography._();

  // Baseline: размер / line height / tracking.
  static const _displayLarge = (57.0, 64.0, -0.25);
  static const _displayMedium = (45.0, 52.0, 0.0);
  static const _displaySmall = (36.0, 44.0, 0.0);
  static const _headlineLarge = (32.0, 40.0, 0.0);
  static const _headlineMedium = (28.0, 36.0, 0.0);
  static const _headlineSmall = (24.0, 32.0, 0.0);
  static const _titleLarge = (22.0, 28.0, 0.0);
  static const _titleMedium = (16.0, 24.0, 0.15);
  static const _titleSmall = (14.0, 20.0, 0.1);
  static const _bodyLarge = (16.0, 24.0, 0.5);
  static const _bodyMedium = (14.0, 20.0, 0.25);
  static const _bodySmall = (12.0, 16.0, 0.4);
  static const _labelLarge = (14.0, 20.0, 0.1);
  static const _labelMedium = (12.0, 16.0, 0.5);
  static const _labelSmall = (11.0, 16.0, 0.5);

  static TextStyle _style(
    (double, double, double) spec, {
    required FontWeight weight,
    Color? color,
  }) {
    final (size, height, tracking) = spec;
    return TextStyle(
      fontSize: size,
      height: height / size,
      letterSpacing: tracking,
      fontWeight: weight,
      color: color,
    );
  }

  /// Baseline-шкала: display/headline/title-large/body — Regular,
  /// title medium/small и все label — Medium.
  static TextTheme textTheme(ColorScheme scheme) {
    return TextTheme(
      displayLarge: _style(_displayLarge,
          weight: FontWeight.w400, color: scheme.onSurface),
      displayMedium: _style(_displayMedium,
          weight: FontWeight.w400, color: scheme.onSurface),
      displaySmall: _style(_displaySmall,
          weight: FontWeight.w400, color: scheme.onSurface),
      headlineLarge: _style(_headlineLarge,
          weight: FontWeight.w400, color: scheme.onSurface),
      headlineMedium: _style(_headlineMedium,
          weight: FontWeight.w400, color: scheme.onSurface),
      headlineSmall: _style(_headlineSmall,
          weight: FontWeight.w400, color: scheme.onSurface),
      titleLarge: _style(_titleLarge,
          weight: FontWeight.w400, color: scheme.onSurface),
      titleMedium: _style(_titleMedium,
          weight: FontWeight.w500, color: scheme.onSurface),
      titleSmall: _style(_titleSmall,
          weight: FontWeight.w500, color: scheme.onSurface),
      bodyLarge: _style(_bodyLarge,
          weight: FontWeight.w400, color: scheme.onSurface),
      bodyMedium: _style(_bodyMedium,
          weight: FontWeight.w400, color: scheme.onSurface),
      bodySmall: _style(_bodySmall,
          weight: FontWeight.w400, color: scheme.onSurfaceVariant),
      labelLarge: _style(_labelLarge,
          weight: FontWeight.w500, color: scheme.onSurface),
      labelMedium: _style(_labelMedium,
          weight: FontWeight.w500, color: scheme.onSurfaceVariant),
      labelSmall: _style(_labelSmall,
          weight: FontWeight.w500, color: scheme.onSurfaceVariant),
    );
  }

  /// Emphasized-вариант стиля: тот же размер, другой вес и tracking.
  ///
  /// display/headline/title-large/body: Regular → Medium.
  /// title medium/small и все label: Medium → Bold.
  static TextStyle emphasized(TextStyle base) {
    final size = base.fontSize ?? 14;
    final isSmall = size <= 16;
    return base.copyWith(
      fontWeight: isSmall ? FontWeight.w700 : FontWeight.w500,
      letterSpacing: (base.letterSpacing ?? 0) + (isSmall ? 0.05 : 0),
    );
  }

  // Явные геттеры для мест, где нужен конкретный акцентный стиль без
  // пересчёта веса на месте.
  static TextStyle emphasizedTitleSmall(TextStyle base) =>
      base.copyWith(fontWeight: FontWeight.w700);
  static TextStyle emphasizedTitleMedium(TextStyle base) =>
      base.copyWith(fontWeight: FontWeight.w700);
  static TextStyle emphasizedLabelLarge(TextStyle base) =>
      base.copyWith(fontWeight: FontWeight.w700);
  static TextStyle emphasizedLabelMedium(TextStyle base) =>
      base.copyWith(fontWeight: FontWeight.w700);
  static TextStyle emphasizedHeadlineSmall(TextStyle base) =>
      base.copyWith(fontWeight: FontWeight.w500);
}
