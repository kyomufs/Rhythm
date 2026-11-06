import 'package:flutter_test/flutter_test.dart';
import 'package:tulgusch/core/models/app_settings.dart';

void main() {
  test('период фоновой проверки переживает сохранение и чтение', () {
    const settings = AppSettings(backgroundCheckMinutes: 360);
    final restored = AppSettings.fromJson(settings.toJson());

    expect(restored.backgroundCheckMinutes, 360);
  });

  test('старые настройки без периода получают значение по умолчанию', () {
    final json = const AppSettings().toJson()..remove('backgroundCheckMinutes');

    expect(AppSettings.fromJson(json).backgroundCheckMinutes,
        AppSettings.defaultBackgroundCheckMinutes);
  });

  test('период вне пресетов приводится к умолчанию', () {
    // 15 и 30 минут были в прошлой версии пресетов: группа кнопок не должна
    // остаться без выбранного сегмента.
    expect(AppSettings.normalizeBackgroundCheckMinutes(15), 60);
    expect(AppSettings.normalizeBackgroundCheckMinutes(30), 60);
    final json = const AppSettings().toJson()..['backgroundCheckMinutes'] = 30;
    expect(AppSettings.fromJson(json).backgroundCheckMinutes, 60);
  });

  test('пресеты: час, три, шесть и двенадцать часов', () {
    expect(AppSettings.backgroundCheckPresets, [0, 60, 180, 360, 720]);
    expect(AppSettings.backgroundCheckLabel(0), 'Выкл');
    expect(AppSettings.backgroundCheckLabel(60), '1 час');
    expect(AppSettings.backgroundCheckLabel(180), '3 часа');
    expect(AppSettings.backgroundCheckLabel(360), '6 часов');
    expect(AppSettings.backgroundCheckLabel(720), '12 часов');
    // Значение вне пресетов не теряется и показывается как есть.
    expect(AppSettings.backgroundCheckLabel(45), '45 мин');
    expect(AppSettings.backgroundCheckLabel(90), '90 мин');
  });

  test('описание периода читается фразой', () {
    expect(AppSettings.backgroundCheckDescription(0), 'Проверка выключена');
    expect(AppSettings.backgroundCheckDescription(60), 'Каждый час');
    expect(AppSettings.backgroundCheckDescription(180), 'Каждые 3 часа');
    expect(AppSettings.backgroundCheckDescription(360), 'Каждые 6 часов');
    expect(AppSettings.backgroundCheckDescription(720), 'Каждые 12 часов');
    expect(AppSettings.backgroundCheckDescription(45), 'Каждые 45 мин');
  });
}
