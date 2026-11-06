import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uniflow/core/models/app_settings.dart';
import 'package:uniflow/core/services/storage_service.dart';
import 'package:uniflow/core/theme/shapes.dart';
import 'package:uniflow/core/theme/typography.dart';

/// App settings state notifier
class AppSettingsNotifier extends StateNotifier<AppSettings> {
  final StorageService _storage;

  AppSettingsNotifier(this._storage) : super(_storage.getAppSettings());

  void updateSeedColor(int colorValue) {
    state = state.copyWith(seedColorValue: colorValue);
    _save();
  }

  void updateThemeMode(String mode) {
    state = state.copyWith(themeMode: mode);
    _save();
  }

  void updateShowGroups(bool value) {
    state = state.copyWith(showGroupsInSchedule: value);
    _save();
  }

  void updateDemoMode(bool value) {
    state = state.copyWith(demoMode: value);
    _save();
  }

  void updateBackgroundCheckMinutes(int minutes) {
    state = state.copyWith(backgroundCheckMinutes: minutes);
    _save();
  }

  void reset() {
    state = const AppSettings();
    _save();
  }

  void _save() {
    _storage.saveAppSettings(state);
  }
}

/// Provider for app settings
final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  return AppSettingsNotifier(ref.watch(storageServiceProvider));
});

InputDecorationTheme _inputDecoration(ColorScheme colorScheme) =>
    InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(
        borderRadius: AppShapes.circular(AppShapes.extraSmall),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppShapes.circular(AppShapes.extraSmall),
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppShapes.circular(AppShapes.extraSmall),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppShapes.circular(AppShapes.extraSmall),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppShapes.circular(AppShapes.extraSmall),
        borderSide: BorderSide(color: colorScheme.error, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: AppShapes.circular(AppShapes.extraSmall),
        borderSide: BorderSide(
          color: colorScheme.onSurface.withValues(alpha: 0.12),
        ),
      ),
      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );

/// Форма кнопки: `CornerFull` в покое, `CornerSmall` при нажатии.
///
/// Это морф формы из M3E (`ContainerShapeRound` → `PressedContainerShape`),
/// а не анимация цвета: размер и положение не меняются.
WidgetStateProperty<OutlinedBorder> _buttonShape() =>
    WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.pressed)) {
        return RoundedRectangleBorder(
          borderRadius: AppShapes.pressedButtonRadius,
        );
      }
      return const StadiumBorder();
    });

/// Базовая геометрия кнопки: `ContainerHeight` 40dp, `LeadingSpace` /
/// `TrailingSpace` 24dp, `IconSize` 20dp.
ButtonStyle _buttonStyle({
  required TextTheme textTheme,
  required FontWeight labelWeight,
}) {
  return ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(64, 40)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 24, vertical: 10),
    ),
    shape: _buttonShape(),
    textStyle: WidgetStatePropertyAll(
      textTheme.labelLarge?.copyWith(fontWeight: labelWeight),
    ),
    iconSize: const WidgetStatePropertyAll(20),
  );
}

/// Единый сборщик темы (публичный — тесты проверяют геометрию и формы). Светлая и тёмная схемы раньше дублировались двумя
/// почти одинаковыми билдерами — расхождения между ними были неизбежны.
ThemeData buildAppTheme({
  required ColorScheme colorScheme,
  required Brightness brightness,
}) {
  final textTheme = AppTypography.textTheme(colorScheme);
  final isDark = brightness == Brightness.dark;

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    brightness: brightness,
    textTheme: textTheme,
    scaffoldBackgroundColor: colorScheme.surface,
    inputDecorationTheme: _inputDecoration(colorScheme),
    cardTheme: CardThemeData(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: AppShapes.cardRadius,
        side: BorderSide(
          color:
              colorScheme.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.4),
        ),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: AppShapes.chipRadius),
      showCheckmark: false,
      side: BorderSide.none,
      labelStyle: textTheme.labelLarge,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    appBarTheme: AppBarTheme(
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ),
      scrolledUnderElevation: 0,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: colorScheme.onSurface,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      height: 64,
      backgroundColor: colorScheme.surfaceContainer,
      indicatorColor: colorScheme.secondaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        // M3E: активная подпись — secondary, а не onSurfaceVariant.
        return textTheme.labelMedium?.copyWith(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color:
              selected ? colorScheme.secondary : colorScheme.onSurfaceVariant,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 24,
          color: selected
              ? colorScheme.onSecondaryContainer
              : colorScheme.onSurfaceVariant,
        );
      }),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      surfaceTintColor: Colors.transparent,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primaryContainer,
      foregroundColor: colorScheme.onPrimaryContainer,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: AppShapes.circular(AppShapes.large),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: _buttonStyle(
        textTheme: textTheme,
        labelWeight: FontWeight.w700,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: _buttonStyle(
        textTheme: textTheme,
        labelWeight: FontWeight.w500,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: _buttonStyle(
        textTheme: textTheme,
        labelWeight: FontWeight.w500,
      ),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: AppShapes.dialogRadius),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      showDragHandle: true,
      backgroundColor: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: AppShapes.sheetRadius),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: AppShapes.circular(AppShapes.extraSmall),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
      thickness: 1,
      space: 1,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colorScheme.primary,
      linearTrackColor: colorScheme.surfaceContainerHighest,
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: AppShapes.circular(AppShapes.large),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    ),
  );
}

/// Кэш сгенерированных схем.
///
/// `ColorScheme.fromSeed` — самый дорогой шаг сборки темы: квантизация seed и
/// пересчёт всей палитры в HCT. Набор seed-цветов фиксирован палитрой, поэтому
/// схему достаточно посчитать один раз на пару «цвет + яркость»: повторный
/// выбор того же акцента и переключение светлая/тёмная больше не пересчитывают
/// палитру.
final Map<(int, Brightness), ColorScheme> _schemeCache = {};

ColorScheme _schemeOf(int seedColorValue, Brightness brightness) =>
    _schemeCache.putIfAbsent(
      (seedColorValue, brightness),
      () => ColorScheme.fromSeed(
        seedColor: Color(seedColorValue),
        brightness: brightness,
      ),
    );

/// Derived provider that builds light ThemeData from AppSettings.
///
/// Следит только за seed-цветом: смена `themeMode` не должна пересобирать
/// обе ThemeData — MaterialApp и так рисует одну из них.
final themeDataProvider = Provider<ThemeData>((ref) {
  final seed = ref.watch(appSettingsProvider.select((s) => s.seedColorValue));
  return buildAppTheme(
    colorScheme: _schemeOf(seed, Brightness.light),
    brightness: Brightness.light,
  );
});

/// Derived provider that builds dark ThemeData from AppSettings
final themeDataProviderDark = Provider<ThemeData>((ref) {
  final seed = ref.watch(appSettingsProvider.select((s) => s.seedColorValue));
  return buildAppTheme(
    colorScheme: _schemeOf(seed, Brightness.dark),
    brightness: Brightness.dark,
  );
});
