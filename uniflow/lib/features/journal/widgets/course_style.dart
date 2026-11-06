import 'package:flutter/material.dart';

/// Акцент дисциплины: тот же тон, что у темы, со сдвигом по кругу.
///
/// Отдельной палитры нет — журнал не должен выглядеть как чужая тема, а
/// различимость предметов нужна только на уровне точки/иконки.
Color courseAccent(ColorScheme scheme, int index) {
  final base = HSLColor.fromColor(scheme.primary);
  final hue = (base.hue + index * 47) % 360;
  return base
      .withHue(hue)
      .withSaturation((base.saturation + 0.1).clamp(0.0, 1.0))
      .withLightness((base.lightness + 0.06).clamp(0.0, 1.0))
      .toColor();
}
