import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Волнистый индикатор прогресса M3E (`wavy progress indicator`).
///
/// Штатный `LinearProgressIndicator` — прямая полоса; в экспрессивной теме
/// прогресс рисуется «змейкой», а фаза волны медленно едет, поэтому индикатор
/// читается живым даже при неизменном значении.
///
/// Высота полосы должна вмещать `2 * amplitude + strokeWidth`, иначе волна
/// срезается по краям: при значениях по умолчанию это 7dp из 8dp.
class WavyProgressIndicator extends StatefulWidget {
  const WavyProgressIndicator({
    super.key,
    this.value,
    this.color,
    this.trackColor,
    this.height = 8,
    this.strokeWidth = 3,
    this.wavelength = 14,
    this.amplitude = 2,
  });

  /// `null` — неопределённый прогресс: по дорожке бежит яркий фрагмент.
  final double? value;
  final Color? color;
  final Color? trackColor;
  final double height;
  final double strokeWidth;
  final double wavelength;
  final double amplitude;

  @override
  State<WavyProgressIndicator> createState() => _WavyProgressIndicatorState();
}

class _WavyProgressIndicatorState extends State<WavyProgressIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _phase = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  bool _running = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPhase();
  }

  @override
  void didUpdateWidget(covariant WavyProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.value == null) != (widget.value == null)) _syncPhase();
  }

  /// Бегущая фаза нужна только неопределённому прогрессу: у определённого
  /// волна стоит на месте и значение читается, а бесконечная анимация зря
  /// жжёт кадры (и не даёт тестам доиграть `pumpAndSettle`).
  void _syncPhase() {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final shouldRun = widget.value == null && !reduceMotion;
    if (shouldRun && !_running) {
      // Одно колебание за 2.6 с: волна заметна, но не рябит в глазах.
      _phase.repeat();
      _running = true;
    } else if (!shouldRun && _running) {
      _phase.stop();
      _running = false;
    }
  }

  @override
  void dispose() {
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = widget.color ?? colorScheme.primary;
    final track = widget.trackColor ?? color.withValues(alpha: 0.18);

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: ClipRect(
        child: CustomPaint(
          painter: _WavePainter(
            phase: _phase,
            progress: widget.value,
            color: color,
            trackColor: track,
            strokeWidth: widget.strokeWidth,
            wavelength: widget.wavelength,
            amplitude: widget.amplitude,
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.phase,
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
    required this.wavelength,
    required this.amplitude,
  }) : super(repaint: phase);

  final Animation<double> phase;
  final double? progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;
  final double wavelength;
  final double amplitude;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final phaseValue = phase.value * 2 * math.pi;
    final wave = _path(size, phaseValue);

    paint.color = trackColor;
    canvas.drawPath(wave, paint);

    paint.color = color;
    final value = progress;
    if (value == null) {
      // Неопределённый: окно бежит по дорожке, а не заливает её целиком.
      final window = size.width * 0.38;
      final travel = size.width + window;
      final left = (phase.value * travel) - window;
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(left, 0, window, size.height));
      canvas.drawPath(wave, paint);
      canvas.restore();
      return;
    }

    if (value <= 0) return;
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(0, 0, size.width * value.clamp(0.0, 1.0), size.height),
    );
    canvas.drawPath(wave, paint);
    canvas.restore();
  }

  Path _path(Size size, double phaseValue) {
    final path = Path();
    final mid = size.height / 2;
    final k = 2 * math.pi / wavelength;
    // Шаг 1dp: на такой длине волны полилиния не отличима от кривой, а
    // строить кубические сегменты на каждом кадре дороже.
    for (double x = 0; x <= size.width; x += 1) {
      final y = mid + amplitude * math.sin(k * x + phaseValue);
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.wavelength != wavelength ||
      oldDelegate.amplitude != amplitude;
}
