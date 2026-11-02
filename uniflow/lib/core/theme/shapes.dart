import 'package:flutter/material.dart';

/// Шкала радиусов Material 3 Expressive.
///
/// 0 / 4 / 8 / 12 / 16 / 20 / 28 / 32 / 48 / full. Шаги 20, 32 и 48 добавлены
/// в M3E (`CornerLargeIncreased`, `CornerExtraLargeIncreased`,
/// `CornerExtraExtraLarge`).
///
/// Правило вложенности: `inner = outer − padding`. Радиус ребёнка никогда не
/// равен радиусу родителя — иначе на стыке дуги расходятся.
class AppShapes {
  AppShapes._();

  static const double none = 0;
  static const double extraSmall = 4;
  static const double small = 8;
  static const double medium = 12;
  static const double large = 16;
  static const double largeIncreased = 20;
  static const double extraLarge = 28;
  static const double extraLargeIncreased = 32;
  static const double extraExtraLarge = 48;

  /// Радиус вложенного контейнера.
  ///
  /// [outer] — радиус родителя, [padding] — отступ между ними. Отрицательный
  /// результат невозможен: минимум — прямой угол.
  static double inner(double outer, double padding) =>
      (outer - padding).clamp(0, outer);

  static BorderRadius circular(double radius) => BorderRadius.circular(radius);

  static BorderRadius get cardRadius => circular(largeIncreased);
  static BorderRadius get dialogRadius => circular(extraLarge);
  static BorderRadius get sheetRadius =>
      const BorderRadius.vertical(top: Radius.circular(extraLarge));
  static BorderRadius get chipRadius => circular(small);
  static BorderRadius get buttonRadius => circular(largeIncreased);
}
