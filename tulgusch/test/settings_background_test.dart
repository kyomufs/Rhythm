import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tulgusch/core/models/app_settings.dart';
import 'package:tulgusch/core/services/notification_service.dart';
import 'package:tulgusch/core/services/storage_service.dart';
import 'package:tulgusch/features/profile/screens/settings_screen.dart';

class _FakeStorage extends StorageService {
  AppSettings settings = const AppSettings();
  AppSettings? saved;

  @override
  AppSettings getAppSettings() => settings;

  @override
  Future<void> saveAppSettings(AppSettings value) async {
    saved = value;
    settings = value;
  }
}

class _FakeNotifications implements NotificationService {
  @override
  void Function(String? payload)? onTap;

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> areNotificationsEnabled() async => true;

  @override
  Future<void> show(int id, String title, String body,
      {String? payload}) async {}
}

Widget _app(_FakeStorage storage) {
  return ProviderScope(
    overrides: [
      storageServiceProvider.overrideWithValue(storage),
      notificationServiceProvider.overrideWithValue(_FakeNotifications()),
    ],
    child: const MaterialApp(
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [Locale('ru', 'RU')],
      locale: Locale('ru'),
      home: SettingsScreen(),
    ),
  );
}

void main() {
  testWidgets('в настройках есть период фоновой проверки расписания',
      (tester) async {
    await tester.pumpWidget(_app(_FakeStorage()));
    await tester.pumpAndSettle();

    // Секция уведомлений ниже первого экрана — до неё нужно доскроллить.
    await tester.scrollUntilVisible(
      find.text('Фоновая проверка расписания'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Фоновая проверка расписания'), findsOneWidget);
    expect(
      find.text('Каждый час. При изменениях придёт уведомление'),
      findsOneWidget,
    );
    for (final minutes in AppSettings.backgroundCheckPresets) {
      expect(
          find.text(AppSettings.backgroundCheckLabel(minutes)), findsOneWidget);
    }
  });

  testWidgets('выбор периода сохраняется в настройках', (tester) async {
    final storage = _FakeStorage();
    await tester.pumpWidget(_app(storage));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Выкл'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Выкл'));
    await tester.pumpAndSettle();

    expect(storage.saved?.backgroundCheckMinutes, 0,
        reason: '0 минут = проверка выключена');

    await tester.tap(find.text('12 часов'));
    await tester.pumpAndSettle();

    expect(storage.saved?.backgroundCheckMinutes, 720);
    expect(
      find.text('Каждые 12 часов. При изменениях придёт уведомление'),
      findsOneWidget,
    );
  });
}
