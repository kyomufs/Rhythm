import 'package:flutter/material.dart';
import 'package:rhythm/core/theme/motion.dart';

/// Отклик на нажатие в духе M3E: элемент слегка «проваливается» пружиной.
///
/// Встроенные `AnimatedScale`/`AnimatedContainer` идут по кривым, а M3E
/// описывает отклик пружиной — поэтому контроллер `unbounded` и
/// `animateWithSpring`. InkWell остаётся внутри: рябь и фокус не теряются.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.pressedScale = 0.97,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius? borderRadius;

  /// Насколько элемент уменьшается под пальцем.
  final double pressedScale;
  final String? semanticLabel;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController.unbounded(
    vsync: this,
    value: 0,
  );

  void _animateTo(double target) {
    _press.animateWithSpring(
      MediaQuery.disableAnimationsOf(context)
          ? MotionTokens.standardFastSpatial
          : MotionTokens.fastSpatial,
      to: target,
      velocity: _press.velocity,
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;

    return Semantics(
      button: enabled,
      label: widget.semanticLabel,
      child: AnimatedBuilder(
        animation: _press,
        builder: (context, child) {
          final t = _press.value.clamp(0.0, 1.0);
          return Transform.scale(
            scale: 1 - (1 - widget.pressedScale) * t,
            child: child,
          );
        },
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            borderRadius: widget.borderRadius,
            onHighlightChanged: (pressed) => _animateTo(pressed ? 1 : 0),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
