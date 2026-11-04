import 'package:flutter_test/flutter_test.dart';
import 'package:uniflow/core/models/app_settings.dart';

void main() {
  test('период фоновой проверки переживает сохранение и чтение', () {
    const settings = AppSettings(backgroundCheckMinutes: 60);
    final restored = AppSettings.fromJson(settings.toJson());

    expect(restored.backgroundCheckMinutes, 60);
  });

  test('старые настройки без периода получают значение по умолчанию', () {
    final json = const AppSettings().toJson()
      ..remove('backgroundCheckMinutes');

    expect(AppSettings.fromJson(json).backgroundCheckMinutes,
        AppSettings.defaultBackgroundCheckMinutes);
  });

  test('подписи периодов и их порядок в настройках', () {
    expect(AppSettings.backgroundCheckPresets, [0, 15, 30, 60, 180]);
    expect(AppSettings.backgroundCheckLabel(0), 'Выкл');
    expect(AppSettings.backgroundCheckLabel(15), '15 мин');
    expect(AppSettings.backgroundCheckLabel(30), '30 мин');
    expect(AppSettings.backgroundCheckLabel(60), '1 час');
    expect(AppSettings.backgroundCheckLabel(180), '3 часа');
    // Значение вне пресетов не теряется и показывается как есть.
    expect(AppSettings.backgroundCheckLabel(45), '45 мин');
  });
}
