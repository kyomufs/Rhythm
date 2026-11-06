import 'package:flutter/material.dart';

/// Контрастный цвет содержимого для произвольного фона.
///
/// Палитра предметов в приложении задана числами, а не ролями `on*`, поэтому
/// пару «фон → текст» приходится выбирать по яркости. Порог — тот же, что во
/// `ThemeData.estimateBrightnessForColor`, то есть проверка контраста к
/// чёрному и белому по WCAG.
Color onColorFor(Color background) =>
    ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : Colors.black;
