import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// Токены моушена Material 3 Expressive.
///
/// M3E заменил связку «кривая + длительность» физикой пружины. Значения взяты
/// из `md.sys.motion.spring.{speed}.{spatial|effects}.{damping|stiffness}`.
/// Схема (expressive/standard) задаётся на уровне продукта и в имя токена не
/// входит — поэтому здесь сразу целевые `SpringDescription`.
///
/// spatial — геометрия (позиция, размер, поворот, радиус): перелетает и
/// покачивается. effects — цвет и прозрачность: никогда не перелетает,
/// damping всегда 1.0.
class MotionTokens {
  MotionTokens._();

  // Expressive
  static final fastSpatial = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 800,
    ratio: 0.6,
  );
  static final defaultSpatial = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 380,
    ratio: 0.8,
  );
  static final slowSpatial = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 200,
    ratio: 0.8,
  );
  static final fastEffects = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 3800,
    ratio: 1,
  );
  static final defaultEffects = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 1600,
    ratio: 1,
  );
  static final slowEffects = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 800,
    ratio: 1,
  );

  // Standard — fallback при отключённых анимациях. Effects-пружины в обеих
  // схемах идентичны по определению.
  static final standardFastSpatial = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 1400,
    ratio: 0.9,
  );
  static final standardDefaultSpatial = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 700,
    ratio: 0.9,
  );
  static final standardSlowSpatial = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 300,
    ratio: 0.9,
  );
}

/// Набор пружин одного профиля: expressive или standard.
class MotionScheme {
  final SpringDescription fastSpatial;
  final SpringDescription defaultSpatial;
  final SpringDescription slowSpatial;
  final SpringDescription fastEffects;
  final SpringDescription defaultEffects;
  final SpringDescription slowEffects;

  const MotionScheme({
    required this.fastSpatial,
    required this.defaultSpatial,
    required this.slowSpatial,
    required this.fastEffects,
    required this.defaultEffects,
    required this.slowEffects,
  });

  static final expressive = MotionScheme(
    fastSpatial: MotionTokens.fastSpatial,
    defaultSpatial: MotionTokens.defaultSpatial,
    slowSpatial: MotionTokens.slowSpatial,
    fastEffects: MotionTokens.fastEffects,
    defaultEffects: MotionTokens.defaultEffects,
    slowEffects: MotionTokens.slowEffects,
  );

  static final standard = MotionScheme(
    fastSpatial: MotionTokens.standardFastSpatial,
    defaultSpatial: MotionTokens.standardDefaultSpatial,
    slowSpatial: MotionTokens.standardSlowSpatial,
    fastEffects: MotionTokens.fastEffects,
    defaultEffects: MotionTokens.defaultEffects,
    slowEffects: MotionTokens.slowEffects,
  );

  /// Профиль для контекста: expressive по умолчанию, standard при
  /// `MediaQuery.disableAnimations`.
  static MotionScheme of(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ? standard : expressive;
}

/// Прогон пружины на контроллере.
///
/// Контроллер обязан быть `unbounded`: ограниченный срезает перелёт, а
/// перелёт — весь смысл spatial-пружины.
extension SpringDrive on AnimationController {
  TickerFuture animateWithSpring(
    SpringDescription spring, {
    double from = 0,
    double to = 1,
    double velocity = 0,
  }) {
    return animateWith(
      SpringSimulation(spring, from, to, velocity),
    );
  }
}

/// Длительность «на глаз» для виджетов, которые принимают только `Duration`
/// (AnimatedContainer, AnimatedOpacity и прочие встроенные). Пружину туда не
/// подставить, поэтому берём время затухания той же пружины.
Duration springDuration(SpringDescription spring) {
  final simulation = SpringSimulation(spring, 0, 1, 0);
  // Шаг 1/120 c — точнее любого кадра; поиск линейный и дешёвый.
  const step = 1 / 120;
  var t = 0.0;
  while (t < 3) {
    if ((simulation.x(t) - 1).abs() < 0.005 && simulation.dx(t).abs() < 0.05) {
      return Duration(milliseconds: (t * 1000).round());
    }
    t += step;
  }
  return const Duration(milliseconds: 300);
}
