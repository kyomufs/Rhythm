import 'package:flutter/material.dart';

/// Типографика Material 3 Expressive.
///
/// Baseline-шкала остаётся, emphasized — не замена, а разметка акцента:
/// размер и line height совпадают, отличаются только вес и tracking.
///
/// Во Flutter emphasized-стилей нет, поэтому они собираются здесь из значений
/// токенов. Значения не пересчитываются эвристикой: у каждой роли свой tracking,
/// и «+0.05 к baseline» даёт неверный результат для body-ролей.
class AppTypography {
  AppTypography._();

  // Baseline: размер / line height / tracking.
  static const _displayLarge = (57.0, 64.0, -0.2);
  static const _displayMedium = (45.0, 52.0, 0.0);
  static const _displaySmall = (36.0, 44.0, 0.0);
  static const _headlineLarge = (32.0, 40.0, 0.0);
  static const _headlineMedium = (28.0, 36.0, 0.0);
  static const _headlineSmall = (24.0, 32.0, 0.0);
  static const _titleLarge = (22.0, 28.0, 0.0);
  static const _titleMedium = (16.0, 24.0, 0.2);
  static const _titleSmall = (14.0, 20.0, 0.1);
  static const _bodyLarge = (16.0, 24.0, 0.5);
  static const _bodyMedium = (14.0, 20.0, 0.2);
  static const _bodySmall = (12.0, 16.0, 0.4);
  static const _labelLarge = (14.0, 20.0, 0.1);
  static const _labelMedium = (12.0, 16.0, 0.5);
  static const _labelSmall = (11.0, 16.0, 0.5);

  // Emphasized: tracking и вес. Размер и line height — те же, что в baseline.
  // display/headline/title-large/body: Regular → Medium, tracking нормализуется.
  // title medium/small и все label: Medium → Bold.
  static const _emphDisplay = (0.0, FontWeight.w500);
  static const _emphHeadline = (0.0, FontWeight.w500);
  static const _emphTitleLarge = (0.0, FontWeight.w500);
  static const _emphTitleMedium = (0.15, FontWeight.w700);
  static const _emphTitleSmall = (0.1, FontWeight.w700);
  static const _emphBodyLarge = (0.15, FontWeight.w500);
  static const _emphBodyMedium = (0.25, FontWeight.w500);
  static const _emphBodySmall = (0.4, FontWeight.w500);
  static const _emphLabelLarge = (0.1, FontWeight.w700);
  static const _emphLabelMedium = (0.5, FontWeight.w700);
  static const _emphLabelSmall = (0.5, FontWeight.w700);

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

  /// Полная emphasized-шкала: те же размеры, другой вес и tracking.
  ///
  /// Применять точечно (заголовки блоков, выбранные элементы, primary-действия),
  /// а не вместо baseline.
  static TextTheme emphasizedTextTheme(ColorScheme scheme) {
    final base = textTheme(scheme);
    TextStyle emph(TextStyle? s, (double, FontWeight) spec) {
      final (tracking, weight) = spec;
      return s!.copyWith(fontWeight: weight, letterSpacing: tracking);
    }

    return TextTheme(
      displayLarge: emph(base.displayLarge, _emphDisplay),
      displayMedium: emph(base.displayMedium, _emphDisplay),
      displaySmall: emph(base.displaySmall, _emphDisplay),
      headlineLarge: emph(base.headlineLarge, _emphHeadline),
      headlineMedium: emph(base.headlineMedium, _emphHeadline),
      headlineSmall: emph(base.headlineSmall, _emphHeadline),
      titleLarge: emph(base.titleLarge, _emphTitleLarge),
      titleMedium: emph(base.titleMedium, _emphTitleMedium),
      titleSmall: emph(base.titleSmall, _emphTitleSmall),
      bodyLarge: emph(base.bodyLarge, _emphBodyLarge),
      bodyMedium: emph(base.bodyMedium, _emphBodyMedium),
      bodySmall: emph(base.bodySmall, _emphBodySmall),
      labelLarge: emph(base.labelLarge, _emphLabelLarge),
      labelMedium: emph(base.labelMedium, _emphLabelMedium),
      labelSmall: emph(base.labelSmall, _emphLabelSmall),
    );
  }

  /// Ролевые emphasized-геттеры для мест, где нужен конкретный акцент.
  static TextStyle emphasizedHeadlineLarge(TextStyle base) => base.copyWith(
      fontWeight: _emphHeadline.$2, letterSpacing: _emphHeadline.$1);
  static TextStyle emphasizedHeadlineMedium(TextStyle base) => base.copyWith(
      fontWeight: _emphHeadline.$2, letterSpacing: _emphHeadline.$1);
  static TextStyle emphasizedHeadlineSmall(TextStyle base) => base.copyWith(
      fontWeight: _emphHeadline.$2, letterSpacing: _emphHeadline.$1);
  static TextStyle emphasizedTitleLarge(TextStyle base) => base.copyWith(
      fontWeight: _emphTitleLarge.$2, letterSpacing: _emphTitleLarge.$1);
  static TextStyle emphasizedTitleMedium(TextStyle base) => base.copyWith(
      fontWeight: _emphTitleMedium.$2, letterSpacing: _emphTitleMedium.$1);
  static TextStyle emphasizedTitleSmall(TextStyle base) => base.copyWith(
      fontWeight: _emphTitleSmall.$2, letterSpacing: _emphTitleSmall.$1);
  static TextStyle emphasizedBodyMedium(TextStyle base) => base.copyWith(
      fontWeight: _emphBodyMedium.$2, letterSpacing: _emphBodyMedium.$1);
  static TextStyle emphasizedLabelLarge(TextStyle base) => base.copyWith(
      fontWeight: _emphLabelLarge.$2, letterSpacing: _emphLabelLarge.$1);
  static TextStyle emphasizedLabelMedium(TextStyle base) => base.copyWith(
      fontWeight: _emphLabelMedium.$2, letterSpacing: _emphLabelMedium.$1);
  static TextStyle emphasizedLabelSmall(TextStyle base) => base.copyWith(
      fontWeight: _emphLabelSmall.$2, letterSpacing: _emphLabelSmall.$1);
}
