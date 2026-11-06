// One-off generator for the Rhythm launcher icons (iOS + Android).
// Composes the university glyph (tool/app_icon_glyph.png, white PNG
// rasterized from university-svgrepo-com.svg via rsvg-convert) on the
// brand gradient, and writes every required PNG size. Run locally:
//   nix develop -c flutter test test/icon_generator_test.dart
// The file is intentionally NOT part of the regular test suite in CI
// (guarded by the env var).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Design canvas side (all coordinates below are in this space).
const double kCanvas = 1024;

/// Glyph source (white, transparent bg,1024px) rasterized from the SVG.
const String kGlyphPath = 'tool/app_icon_glyph.png';

/// Brand gradient endpoints (seed color -> indigo, matches launcher bg).
const Color kGradStart = Color(0xFF6750A4);
const Color kGradEnd = Color(0xFF3B46CD);

/// Fraction of the canvas the glyph occupies (full-bleed icons).
const double kGlyphScaleFull = 0.68;

/// Fraction of the canvas for the adaptive-icon foreground: the visible
/// area is a circle of66/108 ≈0.61, so stay safely inside the safe zone.
const double kGlyphScaleAdaptive = 0.54;

Future<ui.Image> loadGlyph() async {
  final bytes = File(kGlyphPath).readAsBytesSync();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}

/// Paints the icon: optional gradient background + centered glyph.
void paintIcon(
  Canvas canvas,
  ui.Image glyph, {
  required bool withBackground,
  double glyphScale = kGlyphScaleFull,
}) {
  if (withBackground) {
    canvas.drawRect(
      Offset.zero & const Size(kCanvas, kCanvas),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kGradStart, kGradEnd],
        ).createShader(Offset.zero & const Size(kCanvas, kCanvas)),
    );
    // Soft radial highlight in the top-left corner for depth.
    canvas.drawRect(
      Offset.zero & const Size(kCanvas, kCanvas),
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.55, -0.65),
          radius: 0.9,
          colors: [Color(0x33FFFFFF), Color(0x00FFFFFF)],
        ).createShader(Offset.zero & const Size(kCanvas, kCanvas)),
    );
  }

  final box = kCanvas * glyphScale;
  final dx = (kCanvas - box) / 2;
  canvas.drawImageRect(
    glyph,
    Rect.fromLTWH(0, 0, glyph.width.toDouble(), glyph.height.toDouble()),
    Rect.fromLTWH(dx, dx, box, box),
    Paint()..filterQuality = FilterQuality.high,
  );
}

Future<void> writePng(
  double size,
  String path,
  ui.Image glyph,
  bool withBackground, {
  double? glyphScale,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(size / kCanvas);
  paintIcon(
    canvas,
    glyph,
    withBackground: withBackground,
    glyphScale: glyphScale ??
        (withBackground ? kGlyphScaleFull : kGlyphScaleAdaptive),
  );
  final image = await recorder.endRecording().toImage(
        size.round(),
        size.round(),
      );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
  stdout.writeln('  wrote $path (${size.round()}x${size.round()})');
}

void main() {
  test('generate launcher icons', () async {
    if (Platform.environment['RHYTHM_GEN_ICONS'] != '1') {
      // Not a real test run: just skip silently (guarded one-off tool).
      return;
    }

    final glyph = await loadGlyph();

    const ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    const iosIcons = <String, double>{
      'Icon-App-20x20@1x.png': 20,
      'Icon-App-20x20@2x.png': 40,
      'Icon-App-20x20@3x.png': 60,
      'Icon-App-29x29@1x.png': 29,
      'Icon-App-29x29@2x.png': 58,
      'Icon-App-29x29@3x.png': 87,
      'Icon-App-40x40@1x.png': 40,
      'Icon-App-40x40@2x.png': 80,
      'Icon-App-40x40@3x.png': 120,
      'Icon-App-60x60@2x.png': 120,
      'Icon-App-60x60@3x.png': 180,
      'Icon-App-76x76@1x.png': 76,
      'Icon-App-76x76@2x.png': 152,
      'Icon-App-83.5x83.5@2x.png': 167,
      'Icon-App-1024x1024@1x.png': 1024,
    };
    stdout.writeln('iOS icons:');
    for (final e in iosIcons.entries) {
      await writePng(e.value, '$ios/${e.key}', glyph, true);
    }

    const androidDensities = <String, double>{
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    };
    const res = 'android/app/src/main/res';
    stdout.writeln('Android icons:');
    for (final e in androidDensities.entries) {
      final dir = '$res/mipmap-${e.key}';
      await writePng(e.value, '$dir/ic_launcher.png', glyph, true);
      await writePng(e.value, '$dir/ic_launcher_round.png', glyph, true);
    }
    // Adaptive icon foreground (108dp canvas, glyph fits the safe zone).
    await writePng(
        432, '$res/drawable/ic_launcher_foreground.png', glyph, false);

    // ── Splash ────────────────────────────────────────────────────────
    // Один и тот же вид на всех платформах: белый глиф на фирменном цвете.
    // Android (и до 12, и с 12) рисует холст 288dp, внутри которого глиф
    // занимает 128dp → 128/288 = 0.444. iOS показывает глиф напрямую в
    // рамке 128pt, поэтому там масштаб 1.0.
    const splashGlyphScale = 128 / 288;
    stdout.writeln('iOS launch image:');
    const launchImages = <String, double>{
      'LaunchImage.png': 128,
      'LaunchImage@2x.png': 256,
      'LaunchImage@3x.png': 384,
    };
    for (final e in launchImages.entries) {
      await writePng(
        e.value,
        'ios/Runner/Assets.xcassets/LaunchImage.imageset/${e.key}',
        glyph,
        false,
        glyphScale: 1,
      );
    }

    stdout.writeln('Android splash icon:');
    const splashDensities = <String, double>{
      'mdpi': 288,
      'hdpi': 432,
      'xhdpi': 576,
      'xxhdpi': 864,
      'xxxhdpi': 1152,
    };
    for (final e in splashDensities.entries) {
      await writePng(
        e.value,
        '$res/drawable-${e.key}/splash_icon.png',
        glyph,
        false,
        glyphScale: splashGlyphScale,
      );
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
