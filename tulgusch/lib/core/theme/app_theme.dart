import 'package:flutter/material.dart';

/// Lesson type colors — used by LessonTile
class AppTheme {
  AppTheme._();

  // Custom colors for lesson types (surface-tinted variants are in theme_provider)
  static const Color lectureColor = Color(0xFF6750A4);
  static const Color practiceColor = Color(0xFF006D3C);
  static const Color labColor = Color(0xFF9C4100);

  /// Get color based on lesson CSS class
  static Color getColor(String cssClass) {
    switch (cssClass) {
      case 'lecture':
        return lectureColor;
      case 'practice':
        return practiceColor;
      case 'lab':
        return labColor;
      default:
        return lectureColor;
    }
  }
}
