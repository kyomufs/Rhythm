import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Индикатор загрузки Material 3 Expressive.
///
/// Морфящаяся фигура: последовательность из семи форм, каждая живёт 650 мс,
/// поверх идёт независимое вращение на 4666 мс. Два контроллера не
/// синхронизируются — синхронизация ломает тайминг спецификации.
///
/// Фигуры заданы полярными функциями радиуса, а не готовыми SVG-путями: так у
/// всех полигонов одинаковое число точек, и морф — это линейная интерполяция
/// радиусов, без «дыхания» масштаба.
class ExpressiveLoadingIndicator extends StatefulWidget {
  const ExpressiveLoadingIndicator({
    super.key,
    this.size = 48,
    this.contained = false,
    this.color,
  });

  /// Внешний размер контейнера. Глиф занимает 38/48 от него.
  final double size;

  /// `true` — фигура на подложке `primaryContainer` (для пустых состояний).
  final bool contained;

  /// Переопределение цвета глифа; по умолчанию `primary`.
  final Color? color;

  @override
  State<ExpressiveLoadingIndicator> createState() =>
      _ExpressiveLoadingIndicatorState();
}

class _ExpressiveLoadingIndicatorState extends State<ExpressiveLoadingIndicator>
    with TickerProviderStateMixin {
  static const _morphDuration = Duration(milliseconds: 650);
  static const _spinDuration = Duration(milliseconds: 4666);
  static const _glyphScale = 38 / 48;

  late final AnimationController _morph = AnimationController(
    vsync: this,
    duration: _morphDuration,
  );
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: _spinDuration,
  );

  int _shapeIndex = 0;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _morph.stop();
      _spin.stop();
      return;
    }
    if (_started) {
      // Пользователь мог выключить и снова включить анимации в системе.
      if (!_morph.isAnimating) {
        _morph.forward(from: _morph.value >= 1 ? 0 : _morph.value);
      }
      if (!_spin.isAnimating) _spin.repeat();
      return;
    }
    _started = true;
    _morph.addStatusListener(_onMorphStatus);
    _morph.forward();
    _spin.repeat();
  }

  void _onMorphStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    setState(() => _shapeIndex = (_shapeIndex + 1) % ExpressiveShapes.sequence.length);
    _morph.forward(from: 0);
  }

  @override
  void dispose() {
    _morph.removeStatusListener(_onMorphStatus);
    _morph.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final glyphColor = widget.color ??
        (widget.contained
            ? colorScheme.onPrimaryContainer
            : colorScheme.primary);

    return Semantics(
      label: 'Загрузка',
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: DecoratedBox(
          decoration: widget.contained
              ? BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                )
              : const BoxDecoration(),
          child: reduceMotion
              // Одна статичная фигура: движение отключено пользователем.
              ? CustomPaint(
                  painter: _ExpressiveShapePainter(
                    from: ExpressiveShapes.sequence[_shapeIndex],
                    to: ExpressiveShapes.sequence[_shapeIndex],
                    t: 1,
                    angle: 0,
                    color: glyphColor,
                    glyphScale: _glyphScale,
                  ),
                )
              : AnimatedBuilder(
                  animation: Listenable.merge([_morph, _spin]),
                  builder: (context, _) {
                    final t = Curves.easeInOutCubicEmphasized
                        .transform(_morph.value.clamp(0.0, 1.0));
                    final angle =
                        _spin.value * 2 * math.pi + t * (math.pi / 2);
                    return CustomPaint(
                      painter: _ExpressiveShapePainter(
                        from: ExpressiveShapes
                            .sequence[_shapeIndex],
                        to: ExpressiveShapes.sequence[
                            (_shapeIndex + 1) % ExpressiveShapes.sequence.length],
                        t: t,
                        angle: angle,
                        color: glyphColor,
                        glyphScale: _glyphScale,
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

/// Набор фигур индикатора: та же последовательность, что в Material.
class ExpressiveShapes {
  ExpressiveShapes._();

  static const int samples = 64;

  static final List<List<Offset>> sequence = [
    _normalize(_polar((t) => 0.92 + 0.08 * math.cos(8 * t))), // soft burst
    _normalize(_polar((t) => _regularPolygon(t, 9))), // cookie 9-sided
    _normalize(_polar((t) => _regularPolygon(t, 5))), // pentagon
    _normalize(_polar((t) => _superellipse(t, 4), aspectX: 1.35)), // pill
    _normalize(_polar((t) => _sunny(t))), // sunny
    _normalize(_polar((t) => _superellipse(t, 4))), // cookie 4-sided
    _normalize(_polar((t) => _superellipse(t, 2), aspectX: 1.28)), // oval
  ];

  static List<Offset> _polar(
    double Function(double theta) radius, {
    double aspectX = 1.0,
  }) {
    return List<Offset>.generate(samples, (i) {
      final theta = 2 * math.pi * i / samples;
      final r = radius(theta);
      return Offset(math.cos(theta) * r * aspectX, math.sin(theta) * r);
    });
  }

  /// Радиус правильного многоугольника: вписанная окружность / cos сдвига.
  static double _regularPolygon(double theta, int sides) {
    final segment = 2 * math.pi / sides;
    final shifted = (theta % segment) - segment / 2;
    return math.cos(math.pi / sides) / math.cos(shifted);
  }

  /// Суперэллипс: n=2 — эллипс, n=4 — скруглённый прямоугольник.
  static double _superellipse(double theta, double n) {
    final c = math.cos(theta).abs();
    final s = math.sin(theta).abs();
    return 1 / math.pow(math.pow(c, n) + math.pow(s, n), 1 / n);
  }

  static double _sunny(double theta) {
    final lobes = 0.5 + 0.5 * math.cos(12 * theta);
    return 0.78 + 0.22 * math.pow(lobes, 0.35);
  }

  /// Приводит фигуру в квадрат 0..1 с сохранением пропорций.
  static List<Offset> _normalize(List<Offset> points) {
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final p in points) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    final longest = math.max(maxX - minX, maxY - minY);
    final cx = (minX + maxX) / 2;
    final cy = (minY + maxY) / 2;
    return List<Offset>.generate(
      points.length,
      (i) => Offset(
        (points[i].dx - cx) / longest + 0.5,
        (points[i].dy - cy) / longest + 0.5,
      ),
    );
  }
}

class _ExpressiveShapePainter extends CustomPainter {
  _ExpressiveShapePainter({
    required this.from,
    required this.to,
    required this.t,
    required this.angle,
    required this.color,
    required this.glyphScale,
  });

  final List<Offset> from;
  final List<Offset> to;
  final double t;
  final double angle;
  final Color color;
  final double glyphScale;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide * glyphScale;
    final paint = Paint()..color = color;
    final path = Path();
    for (var i = 0; i < from.length; i++) {
      final p = Offset.lerp(from[i], to[i], t)!;
      final point = Offset(p.dx * side, p.dy * side);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(angle);
    canvas.translate(-side / 2, -side / 2);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ExpressiveShapePainter old) =>
      old.t != t ||
      old.angle != angle ||
      old.color != color ||
      old.from != from ||
      old.to != to;
}
