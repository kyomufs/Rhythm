// Sanity check for the launcher icons: фиолетово-синий градиент и белый
// глиф университета. Ловит случайную замену иконки на чужую/пустую.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

Future<({int r, int g, int b, int a})> pixel(String path, int x, int y) async {
  final bytes = File(path).readAsBytesSync();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final i = (y * frame.image.width + x) * 4;
  return (
    r: data!.getUint8(i),
    g: data.getUint8(i + 1),
    b: data.getUint8(i + 2),
    a: data.getUint8(i + 3),
  );
}

/// Counts near-white pixels on a sparse grid (the glyph is white).
Future<int> countWhite(String path) async {
  final bytes = File(path).readAsBytesSync();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final data =
      (await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final w = frame.image.width;
  var white = 0;
  for (var y = 0; y < w; y += 8) {
    for (var x = 0; x < w; x += 8) {
      final i = (y * w + x) * 4;
      if (data.getUint8(i) > 220 &&
          data.getUint8(i + 1) > 220 &&
          data.getUint8(i + 2) > 220) {
        white++;
      }
    }
  }
  return white;
}

void main() {
  test('icon pixels', () async {
    const path =
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png';
    final topLeft = await pixel(path, 8, 8);
    final bottomRight = await pixel(path, 1015, 1015);
    stdout.writeln('topLeft=$topLeft (expect ~123,103,176)');
    stdout.writeln('bottomRight=$bottomRight (expect ~59,70,204)');

    // Градиент: сиреневый левый верх → синий правый низ.
    expect(topLeft.r, inInclusiveRange(111, 135));
    expect(topLeft.g, inInclusiveRange(91, 115));
    expect(topLeft.b, inInclusiveRange(164, 188));
    expect(bottomRight.r, inInclusiveRange(47, 71));
    expect(bottomRight.g, inInclusiveRange(58, 82));
    expect(bottomRight.b, inInclusiveRange(192, 216));

    // Белый глиф должен присутствовать в заметном количестве.
    final white = await countWhite(path);
    stdout.writeln('white samples: $white (grid stride8, expect > 100)');
    expect(white, greaterThan(100));

    // Alpha channel must be opaque everywhere (App Store requirement).
    final bytes = File(path).readAsBytesSync();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final data =
        (await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    var transparent = 0;
    for (var i = 3; i < data.lengthInBytes; i += 4) {
      if (data.getUint8(i) != 255) transparent++;
    }
    stdout.writeln('non-opaque pixels: $transparent');
    expect(transparent, 0);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('adaptive foreground: transparent bg, white glyph', () async {
    const path = 'android/app/src/main/res/drawable/ic_launcher_foreground.png';
    final corner = await pixel(path, 2, 2);
    stdout.writeln('foreground corner=$corner (expect alpha0)');
    expect(corner.a, 0);

    final white = await countWhite(path);
    stdout.writeln('foreground white samples: $white (expect > 40)');
    expect(white, greaterThan(40));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
