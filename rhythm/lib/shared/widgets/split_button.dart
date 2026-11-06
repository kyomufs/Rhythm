import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tulgusch/core/theme/motion.dart';
import 'package:tulgusch/core/theme/shapes.dart';
import 'package:tulgusch/core/theme/typography.dart';
import 'package:tulgusch/shared/widgets/expressive_button_group.dart';

/// Пункт меню разрезной кнопки.
class ExpressiveSplitAction {
  const ExpressiveSplitAction({
    required this.label,
    required this.icon,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final VoidCallback onSelected;
}

/// Разрезная кнопка (split button) M3E: основное действие плюс иконка
/// раскрытия меню, которая живёт отдельной кнопкой через 2dp зазора.
///
/// Геометрия из спеки: внешние углы полные, внутренние — 4dp (XS–M), 8dp (L)
/// и 12dp (XL); иконка меню смещена внутрь на 1–6dp в зависимости от размера.
/// Иконка проворачивается на 180° «внутрь», причём **стандартной** схемой
/// моушена: разворот меню — утилитарное движение, перелёт здесь выглядит
/// сбоем. Цвет при раскрытии не меняется, только 10 % state layer.
class ExpressiveSplitButton extends StatefulWidget {
  const ExpressiveSplitButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.actions = const [],
    this.size = ExpressiveButtonSize.small,
    this.filled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final List<ExpressiveSplitAction> actions;
  final ExpressiveButtonSize size;

  /// `true` — filled (primary), `false` — tonal (secondaryContainer).
  final bool filled;

  @override
  State<ExpressiveSplitButton> createState() => _ExpressiveSplitButtonState();
}

class _ExpressiveSplitButtonState extends State<ExpressiveSplitButton>
    with TickerProviderStateMixin {
  final MenuController _menu = MenuController();
  final GlobalKey _trailingKey = GlobalKey();
  late final AnimationController _rotation = AnimationController.unbounded(
    vsync: this,
  );

  /// Меню раскрывается в сторону, где есть место: у кнопки внизу шторки
  /// вниз открывать некуда.
  bool _openUpward = false;

  /// Сколько места нужно под список из 2–3 пунктов.
  static const double _menuRoom = 240;

  void _toggleMenu() {
    if (_menu.isOpen) {
      _menu.close();
      return;
    }
    final box = _trailingKey.currentContext?.findRenderObject();
    var upward = _openUpward;
    if (box is RenderBox) {
      final screenHeight = MediaQuery.sizeOf(context).height;
      final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
      upward = screenHeight - bottom < _menuRoom;
    }
    if (upward != _openUpward) {
      // Направление участвует в построении MenuAnchor, поэтому сначала
      // перестраиваемся, и только следующим кадром открываем меню.
      setState(() => _openUpward = upward);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _menu.open();
      });
      return;
    }
    _menu.open();
  }

  /// Внутренний радиус: 4dp до M включительно, 8dp на L, 12dp на XL.
  double get _innerRadius => switch (widget.size) {
        ExpressiveButtonSize.extraSmall ||
        ExpressiveButtonSize.small ||
        ExpressiveButtonSize.medium =>
          AppShapes.extraSmall,
        ExpressiveButtonSize.large => AppShapes.small,
        ExpressiveButtonSize.extraLarge => AppShapes.medium,
      };

  /// Смещение иконки меню к центру кнопки.
  double get _iconOffset => switch (widget.size) {
        ExpressiveButtonSize.extraSmall || ExpressiveButtonSize.small => -1,
        ExpressiveButtonSize.medium => -2,
        ExpressiveButtonSize.large => -3,
        ExpressiveButtonSize.extraLarge => -6,
      };

  void _rotate({required bool open}) {
    _rotation.animateWithSpring(
      MotionTokens.standardDefaultSpatial,
      to: open ? 1 : 0,
      velocity: _rotation.velocity,
    );
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final container = widget.filled
        ? colorScheme.primary
        : colorScheme.secondaryContainer;
    final foreground = widget.filled
        ? colorScheme.onPrimary
        : colorScheme.onSecondaryContainer;

    final height = widget.size.height;
    final outer = Radius.circular(height / 2);
    final inner = Radius.circular(_innerRadius);
    final leadingShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.horizontal(left: outer, right: inner),
    );
    final trailingShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.horizontal(left: inner, right: outer),
    );

    // Высоту ведёт сама кнопка: без SizedBox подпись сжимала бы ведущую
    // половину до высоты строки текста (~20dp) и рядом с квадратной
    // половиной меню она читалась бы тонкой полоской.
    final leading = SizedBox(
      height: height,
      child: Material(
        color: container,
        shape: leadingShape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onPressed,
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return foreground.withValues(alpha: 0.10);
            }
            return null;
          }),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal:
                  widget.size == ExpressiveButtonSize.extraSmall ? 12 : 16,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  size: widget.size.iconSize,
                  color: foreground,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.emphasizedLabelLarge(
                    theme.textTheme.labelLarge!.copyWith(
                      color: foreground,
                      fontSize: widget.size.labelSize,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final trailing = SizedBox(
      key: _trailingKey,
      width: height,
      height: height,
      child: Material(
        color: container,
        shape: trailingShape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _toggleMenu,
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return foreground.withValues(alpha: 0.10);
            }
            return null;
          }),
          child: Tooltip(
            message: 'Ещё',
            child: Center(
              child: AnimatedBuilder(
                animation: _rotation,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, _iconOffset / 2 * _rotation.value),
                  child: Transform.rotate(
                    angle: math.pi * _rotation.value,
                    child: child,
                  ),
                ),
                child: Icon(
                  Icons.expand_more,
                  size: widget.size.iconSize,
                  color: foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [leading, const SizedBox(width: 2), trailing],
    );

    if (widget.actions.isEmpty) {
      return SizedBox(height: height, child: leading);
    }

    return MenuAnchor(
      controller: _menu,
      // 4dp зазора от кнопки. Вверх — от верхней кромки: меню прижимается
      // нижним краем, поэтому смещение равно высоте кнопки плюс зазор.
      alignmentOffset:
          Offset(0, _openUpward ? -(widget.size.height + 4) : 4),
      onOpen: () => _rotate(open: true),
      onClose: () => _rotate(open: false),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(colorScheme.surfaceContainerHigh),
        elevation: const WidgetStatePropertyAll(2),
        // bottomLeft растит меню вверх от нижней кромки кнопки.
        alignment: _openUpward ? Alignment.bottomLeft : Alignment.topLeft,
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: AppShapes.circular(AppShapes.medium)),
        ),
      ),
      menuChildren: [
        for (final action in widget.actions)
          MenuItemButton(
            leadingIcon: Icon(action.icon, size: 20),
            onPressed: action.onSelected,
            child: Text(action.label),
          ),
      ],
      builder: (context, controller, _) => row,
    );
  }
}
