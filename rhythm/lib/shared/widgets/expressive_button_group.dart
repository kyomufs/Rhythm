import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:rhythm/core/theme/motion.dart';
import 'package:rhythm/core/theme/shapes.dart';
import 'package:rhythm/core/theme/typography.dart';

/// Размерный ряд кнопок M3E: XS / S / M / L / XL.
///
/// Высота — `ContainerHeight` из спеки, [innerRadius] — радиус скругления
/// выбранной кнопки внутри связной группы (4 / 8 / 8 / 16 / 20).
enum ExpressiveButtonSize {
  extraSmall(height: 32, innerRadius: 4, iconSize: 16, labelSize: 11),
  small(height: 40, innerRadius: 8, iconSize: 18, labelSize: 14),
  medium(height: 56, innerRadius: 8, iconSize: 20, labelSize: 16),
  large(height: 96, innerRadius: 16, iconSize: 24, labelSize: 22),
  extraLarge(height: 136, innerRadius: 20, iconSize: 32, labelSize: 24);

  const ExpressiveButtonSize({
    required this.height,
    required this.innerRadius,
    required this.iconSize,
    required this.labelSize,
  });

  final double height;
  final double innerRadius;
  final double iconSize;
  final double labelSize;

  /// Высота связной группы: кнопка плюс 2dp отступа сверху и снизу.
  double get groupHeight => height + 4;
}

/// Связная группа кнопок (connected button group) — замена `SegmentedButton`.
///
/// Отличия от штатного сегментированного переключателя, которые и делают
/// компонент «экспрессивным»:
///
/// * контейнер группы **невидим**: ни рамки, ни общей подложки — только 2dp
///   отступа, которые и разделяют кнопки (спека: inner padding 2dp на любом
///   размере). Именно поэтому у невыбранной кнопки есть собственная тихая
///   заливка `surfaceContainerHighest`: без рамки границы группы читаются
///   только по ней;
/// * силуэт группы читается по углам: у крайних кнопок внешняя сторона
///   круглая (таблетка), все внутренние стороны — малый радиус
///   [ExpressiveButtonSize.innerRadius]. Так ряд выглядит как одна связная
///   фигура с круглыми торцами;
/// * выбранная кнопка морфится в полную таблетку с обеих сторон — она
///   «вынимается» из связки; остальные кнопки форму не меняют;
/// * выбранная заливается `primary` по таблице toggle-кнопок стиля filled —
///   иконка и подпись меняют цвет вместе с контейнером;
/// * выбор не влияет на соседние кнопки: меняется только форма нажатой.
///
/// Форма едет spatial-пружиной, заливка — effects-пружиной: первая перелетает,
/// вторая обязана прийти точно.
class ExpressiveButtonGroup<T> extends StatelessWidget {
  const ExpressiveButtonGroup({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.iconOf,
    this.tooltipOf,
    this.size = ExpressiveButtonSize.small,
    this.enabledOf,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final ValueChanged<T> onChanged;
  final IconData? Function(T value)? iconOf;

  /// Подпись для семантики: у кнопки только с иконкой текста на экране нет.
  final String Function(T value)? tooltipOf;
  final ExpressiveButtonSize size;
  final bool Function(T value)? enabledOf;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Container(
        height: size.groupHeight,
        // Только отступы: контейнер связной группы прозрачен, а 2dp по краям
        // дают тот самый зазор до края экрана/карточки из спеки.
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, value) in values.indexed)
              Expanded(
                child: _GroupSegment(
                  label: labelOf(value),
                  tooltip: tooltipOf?.call(value),
                  icon: iconOf?.call(value),
                  selected: value == selected,
                  enabled: enabledOf?.call(value) ?? true,
                  isFirst: index == 0,
                  isLast: index == values.length - 1,
                  size: size,
                  onTap: () => onChanged(value),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GroupSegment extends StatefulWidget {
  const _GroupSegment({
    required this.label,
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.isFirst,
    required this.isLast,
    required this.size,
    required this.onTap,
  });

  final String label;
  final String? tooltip;
  final IconData? icon;
  final bool selected;
  final bool enabled;

  /// Крайние кнопки держат круглый внешний торец группы.
  final bool isFirst;
  final bool isLast;
  final ExpressiveButtonSize size;
  final VoidCallback onTap;

  @override
  State<_GroupSegment> createState() => _GroupSegmentState();
}

class _GroupSegmentState extends State<_GroupSegment>
    with TickerProviderStateMixin {
  /// 0 — угол связки, 1 — полная таблетка выбранной кнопки.
  late final AnimationController _morph = AnimationController.unbounded(
    vsync: this,
    value: widget.selected ? 1 : 0,
  );

  /// 0 — прозрачно, 1 — заливка выбранной кнопки.
  late final AnimationController _fill = AnimationController.unbounded(
    vsync: this,
    value: widget.selected ? 1 : 0,
  );

  @override
  void didUpdateWidget(covariant _GroupSegment oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected ||
        oldWidget.enabled != widget.enabled) {
      _retarget();
    }
  }

  void _retarget() {
    final scheme = MotionScheme.of(context);
    _morph.animateWithSpring(
      scheme.fastSpatial,
      to: widget.selected ? 1 : 0,
      velocity: _morph.velocity,
    );
    _fill.animateWithSpring(
      scheme.fastEffects,
      to: widget.selected ? 1 : 0,
      velocity: _fill.velocity,
    );
  }

  @override
  void dispose() {
    _morph.dispose();
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final round = widget.size.height / 2;
    final inner = widget.size.innerRadius;
    // Силуэт связки: круглый торец только с внешнего края крайних кнопок,
    // все стыки внутри ряда — малый радиус.
    final restLeft = widget.isFirst ? round : inner;
    final restRight = widget.isLast ? round : inner;

    return AnimatedBuilder(
      animation: Listenable.merge([_morph, _fill]),
      builder: (context, _) {
        final morph = _morph.value.clamp(0.0, 1.0);
        final fill = _fill.value.clamp(0.0, 1.0);
        final left = lerpDouble(restLeft, round, morph)!;
        final right = lerpDouble(restRight, round, morph)!;
        final radius = BorderRadius.only(
          topLeft: Radius.circular(left),
          bottomLeft: Radius.circular(left),
          topRight: Radius.circular(right),
          bottomRight: Radius.circular(right),
        );
        // Пара «тихая заливка → primary» из таблицы toggle-кнопок: фон кнопки
        // меняется вместе с цветом подписи и иконки, промежуточные кадры
        // интерполируются, поэтому переключение не мигает.
        final background = Color.lerp(
          colorScheme.surfaceContainerHighest,
          colorScheme.primary,
          fill,
        )!;
        final foreground = Color.lerp(
          colorScheme.onSurfaceVariant,
          colorScheme.onPrimary,
          fill,
        )!;

        final label = Text(
          widget.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: widget.selected
              ? AppTypography.emphasizedLabelLarge(
                  theme.textTheme.labelLarge!.copyWith(
                    color: foreground,
                    fontSize: widget.size.labelSize,
                  ),
                )
              : theme.textTheme.labelLarge!.copyWith(
                  color: foreground,
                  fontSize: widget.size.labelSize,
                ),
        );

        final Widget content;
        if (widget.label.isEmpty && widget.icon != null) {
          content = Icon(
            widget.icon,
            size: widget.size.iconSize,
            color: foreground,
          );
        } else if (widget.icon != null) {
          content = FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon,
                    size: widget.size.iconSize, color: foreground),
                const SizedBox(width: 8),
                label,
              ],
            ),
          );
        } else {
          // Подпись ужимается по ширине сегмента, а не режется многоточием:
          // в группах из пяти сегментов («Выкл … 12 часов») длинная подпись
          // иначе выглядела как ошибка вёрстки.
          content = FittedBox(fit: BoxFit.scaleDown, child: label);
        }

        final button = Padding(
          // 1dp с каждой стороны: между заливками соседних кнопок остаётся
          // ровно 2dp шва из спеки, а сами кнопки не слипаются.
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Material(
            color: background,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.enabled ? widget.onTap : null,
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) {
                  return foreground.withValues(alpha: 0.10);
                }
                return null;
              }),
              child: Center(
                child: Opacity(
                  opacity: widget.enabled ? 1 : 0.38,
                  child: Padding(
                    // 6dp по бокам, а не 10: длинные подписи вроде
                    // «К выполнению» в группе из трёх кнопок иначе режутся
                    // многоточием на 360dp.
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: content,
                  ),
                ),
              ),
            ),
          ),
        );

        return Semantics(
          button: true,
          selected: widget.selected,
          enabled: widget.enabled,
          inMutuallyExclusiveGroup: true,
          label: widget.label.isEmpty ? widget.tooltip : null,
          child: widget.label.isEmpty && widget.tooltip != null
              ? Tooltip(message: widget.tooltip!, child: button)
              : button,
        );
      },
    );
  }
}

/// Пункт стандартной группы кнопок: только действие, без состояния выбора.
class ExpressiveActionItem {
  const ExpressiveActionItem({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final Widget icon;
  final String tooltip;

  /// `null` — кнопка недоступна (например, идёт загрузка).
  final VoidCallback? onPressed;
}

/// Стандартная группа кнопок: соседние кнопки отвечают на нажатие.
///
/// Здесь работает противоположный связной группе принцип — нажатая кнопка
/// раздувается пружиной, а соседние ужимаются на ту же величину, поэтому
/// ширина ряда не меняется и шапка не «дышит». Форма нажатой кнопки при этом
/// морфится из таблетки в квадрат.
class ExpressiveActionGroup extends StatefulWidget {
  const ExpressiveActionGroup({
    super.key,
    required this.items,
    this.itemSize = 40,
    this.gap = 4,
  });

  final List<ExpressiveActionItem> items;
  final double itemSize;
  final double gap;

  @override
  State<ExpressiveActionGroup> createState() => _ExpressiveActionGroupState();
}

class _ExpressiveActionGroupState extends State<ExpressiveActionGroup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spread = AnimationController.unbounded(
    vsync: this,
  );

  /// Индекс раздутой кнопки. После отпускания не сбрасывается: ширину
  /// возвращает пружина, а не мгновенное переключение состояния.
  int _pressed = 0;
  int? _active;

  void _down(int index) {
    if (widget.items[index].onPressed == null) return;
    setState(() {
      _pressed = index;
      _active = index;
    });
    _spring(1);
  }

  void _up() {
    if (_active == null) return;
    setState(() => _active = null);
    _spring(0);
  }

  void _spring(double to) {
    _spread.animateWithSpring(
      MotionScheme.of(context).fastSpatial,
      to: to,
      velocity: _spread.velocity,
    );
  }

  @override
  void dispose() {
    _spread.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.items.length;
    if (count == 0) return const SizedBox.shrink();
    final base = widget.itemSize;
    // Насколько раздувается нажатая кнопка: 45 % ширины.
    final extra = base * 0.45;

    return AnimatedBuilder(
      animation: _spread,
      builder: (context, _) {
        final spread = _spread.value.clamp(0.0, 1.0);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) SizedBox(width: widget.gap),
              _ActionButton(
                item: widget.items[i],
                width: i == _pressed
                    ? base + extra * spread
                    : base - extra * spread / math.max(1, count - 1),
                height: base,
                // Радиус возвращается вместе с шириной, поэтому нажатая
                // кнопка остаётся квадратной до конца пружины.
                radius: lerpDouble(base / 2, AppShapes.extraSmall, spread)!,
                onTapDown: () => _down(i),
                onTapUp: _up,
                onTapCancel: _up,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.item,
    required this.width,
    required this.height,
    required this.radius,
    required this.onTapDown,
    required this.onTapUp,
    required this.onTapCancel,
  });

  final ExpressiveActionItem item;
  final double width;
  final double height;
  final double radius;
  final VoidCallback onTapDown;
  final VoidCallback onTapUp;
  final VoidCallback onTapCancel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = item.onPressed != null;
    final foreground = colorScheme.onSurfaceVariant;

    return Semantics(
      button: true,
      enabled: enabled,
      label: item.tooltip,
      child: Tooltip(
        message: item.tooltip,
        child: SizedBox(
          width: width,
          height: height,
          child: Material(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(radius),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: item.onPressed,
              onTapDown: (_) => onTapDown(),
              onTapUp: (_) => onTapUp(),
              onTapCancel: onTapCancel,
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) {
                  return foreground.withValues(alpha: 0.10);
                }
                return null;
              }),
              child: Center(
                child: IconTheme.merge(
                  data: IconThemeData(
                    size: 20,
                    color: enabled
                        ? colorScheme.onSurface
                        : colorScheme.onSurface.withValues(alpha: 0.38),
                  ),
                  child: item.icon,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
