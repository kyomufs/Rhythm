import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tulgusch/core/theme/spacing.dart';
import 'package:tulgusch/core/theme/typography.dart';

/// Значения ниже — из таблиц `references/tokens.md` скилла `m3-expressive`
/// (baseline и emphasized type scale). Тест ловит расхождение при правке
/// шкалы: подогнать число «на глаз» он не даст.
void main() {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4));
  final base = AppTypography.textTheme(scheme);
  final emph = AppTypography.emphasizedTextTheme(scheme);

  void expectStyle(
    TextStyle? style, {
    required double size,
    required double height,
    required double tracking,
    required FontWeight weight,
  }) {
    expect(style, isNotNull);
    expect(style!.fontSize, size);
    expect(style.height, closeTo(height / size, 1e-9));
    expect(style.letterSpacing, closeTo(tracking, 1e-9));
    expect(style.fontWeight, weight);
  }

  group('baseline type scale', () {
    test('display and headline roles', () {
      expectStyle(base.displayLarge,
          size: 57, height: 64, tracking: -0.2, weight: FontWeight.w400);
      expectStyle(base.displayMedium,
          size: 45, height: 52, tracking: 0, weight: FontWeight.w400);
      expectStyle(base.displaySmall,
          size: 36, height: 44, tracking: 0, weight: FontWeight.w400);
      expectStyle(base.headlineLarge,
          size: 32, height: 40, tracking: 0, weight: FontWeight.w400);
      expectStyle(base.headlineMedium,
          size: 28, height: 36, tracking: 0, weight: FontWeight.w400);
      expectStyle(base.headlineSmall,
          size: 24, height: 32, tracking: 0, weight: FontWeight.w400);
    });

    test('title, body and label roles', () {
      expectStyle(base.titleLarge,
          size: 22, height: 28, tracking: 0, weight: FontWeight.w400);
      expectStyle(base.titleMedium,
          size: 16, height: 24, tracking: 0.2, weight: FontWeight.w500);
      expectStyle(base.titleSmall,
          size: 14, height: 20, tracking: 0.1, weight: FontWeight.w500);
      expectStyle(base.bodyLarge,
          size: 16, height: 24, tracking: 0.5, weight: FontWeight.w400);
      expectStyle(base.bodyMedium,
          size: 14, height: 20, tracking: 0.2, weight: FontWeight.w400);
      expectStyle(base.bodySmall,
          size: 12, height: 16, tracking: 0.4, weight: FontWeight.w400);
      expectStyle(base.labelLarge,
          size: 14, height: 20, tracking: 0.1, weight: FontWeight.w500);
      expectStyle(base.labelMedium,
          size: 12, height: 16, tracking: 0.5, weight: FontWeight.w500);
      expectStyle(base.labelSmall,
          size: 11, height: 16, tracking: 0.5, weight: FontWeight.w500);
    });
  });

  group('emphasized type scale', () {
    test('keeps size and line height, changes weight and tracking', () {
      expectStyle(emph.bodyLarge,
          size: 16, height: 24, tracking: 0.15, weight: FontWeight.w500);
      expectStyle(emph.bodyMedium,
          size: 14, height: 20, tracking: 0.25, weight: FontWeight.w500);
      expectStyle(emph.bodySmall,
          size: 12, height: 16, tracking: 0.4, weight: FontWeight.w500);
      expectStyle(emph.titleMedium,
          size: 16, height: 24, tracking: 0.15, weight: FontWeight.w700);
      expectStyle(emph.titleSmall,
          size: 14, height: 20, tracking: 0.1, weight: FontWeight.w700);
      expectStyle(emph.labelLarge,
          size: 14, height: 20, tracking: 0.1, weight: FontWeight.w700);
      expectStyle(emph.labelMedium,
          size: 12, height: 16, tracking: 0.5, weight: FontWeight.w700);
    });

    test('display and headline keep tracking at zero', () {
      expectStyle(emph.displayLarge,
          size: 57, height: 64, tracking: 0, weight: FontWeight.w500);
      expectStyle(emph.headlineSmall,
          size: 24, height: 32, tracking: 0, weight: FontWeight.w500);
      expectStyle(emph.titleLarge,
          size: 22, height: 28, tracking: 0, weight: FontWeight.w500);
    });

    test('role helpers match the emphasized scale', () {
      expect(AppTypography.emphasizedLabelMedium(base.labelMedium!).letterSpacing,
          0.5);
      expect(AppTypography.emphasizedLabelMedium(base.labelMedium!).fontWeight,
          FontWeight.w700);
      expect(AppTypography.emphasizedHeadlineSmall(base.headlineSmall!).fontWeight,
          FontWeight.w500);
    });
  });

  group('spacing scale', () {
    test('every step is a multiple of 4dp', () {
      for (final value in [
        AppSpacing.xxs,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.touchTarget,
      ]) {
        expect(value % 4, 0, reason: '$value не кратен 4');
      }
    });

    test('touch target matches Material minimum', () {
      expect(AppSpacing.touchTarget, 48);
    });
  });
}
