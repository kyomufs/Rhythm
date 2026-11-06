import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

/// Горизонтальная прокрутка колесом.
///
/// На десктопе вертикальное колесо над горизонтальной лентой по умолчанию
/// скроллит страницу, а не ленту. Здесь вертикальная дельта переводится в
/// горизонтальную; горизонтальная дельта трекпада проходит как есть.
class WheelScroll extends StatelessWidget {
  const WheelScroll({
    super.key,
    required this.controller,
    required this.child,
    this.axis = Axis.horizontal,
    this.step = 1,
  });

  final ScrollController controller;
  final Widget child;
  final Axis axis;

  /// Множитель дельты: колесо мыши даёт ~100px за щелчок, этого много для
  /// ленты чипов.
  final double step;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        if (event is! PointerScrollEvent) return;
        if (!controller.hasClients) return;
        final raw = axis == Axis.horizontal
            ? (event.scrollDelta.dx.abs() > event.scrollDelta.dy.abs()
                ? event.scrollDelta.dx
                : event.scrollDelta.dy)
            : event.scrollDelta.dy;
        final target = (controller.offset + raw * step)
            .clamp(0.0, controller.position.maxScrollExtent);
        if (target == controller.offset) return;
        controller.jumpTo(target);
      },
      child: child,
    );
  }
}

/// Панорамирование ленты зажатой ЛКМ: курсор превращается в «лапу», drag
/// двигает контроллер. Инерция не изобретается — отпустили, прокрутка встала.
class DragPan extends StatefulWidget {
  const DragPan({
    super.key,
    required this.controller,
    required this.child,
    this.axis = Axis.horizontal,
    this.enabled = true,
  });

  final ScrollController controller;
  final Widget child;
  final Axis axis;
  final bool enabled;

  @override
  State<DragPan> createState() => _DragPanState();
}

class _DragPanState extends State<DragPan> {
  bool _dragging = false;

  bool get _isDesktop {
    switch (defaultTargetPlatform) {
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return true;
      default:
        return false;
    }
  }

  void _move(double delta) {
    final controller = widget.controller;
    if (!controller.hasClients) return;
    final target = (controller.offset - delta)
        .clamp(0.0, controller.position.maxScrollExtent);
    controller.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || !_isDesktop) return widget.child;

    final horizontal = widget.axis == Axis.horizontal;
    return MouseRegion(
      cursor: _dragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart:
            horizontal ? (_) => setState(() => _dragging = true) : null,
        onHorizontalDragUpdate:
            horizontal ? (details) => _move(details.delta.dx) : null,
        onHorizontalDragEnd:
            horizontal ? (_) => setState(() => _dragging = false) : null,
        onHorizontalDragCancel:
            horizontal ? () => setState(() => _dragging = false) : null,
        onVerticalDragStart:
            horizontal ? null : (_) => setState(() => _dragging = true),
        onVerticalDragUpdate:
            horizontal ? null : (details) => _move(details.delta.dy),
        onVerticalDragEnd:
            horizontal ? null : (_) => setState(() => _dragging = false),
        onVerticalDragCancel:
            horizontal ? null : () => setState(() => _dragging = false),
        child: widget.child,
      ),
    );
  }
}

/// Карточка, которая подсвечивается под курсором: на десктопе без этого
/// непонятно, что элемент кликабельный.
class HoverRegion extends StatefulWidget {
  const HoverRegion({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.pressedScale = 0.98,
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final double pressedScale;

  @override
  State<HoverRegion> createState() => _HoverRegionState();
}

class _HoverRegionState extends State<HoverRegion> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor:
          widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) {
        setState(() {
          _hovered = false;
          _pressed = false;
        });
      },
      child: GestureDetector(
        onTapDown: widget.onTap == null
            ? null
            : (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: widget.onTap == null
            ? null
            : (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? widget.pressedScale : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              color: _hovered
                  ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.6)
                  : null,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Горячие клавиши оболочки: Ctrl+1…4 — вкладки, Esc — закрыть верхний лист.
/// Собраны в один виджет, чтобы экраны не дублировали таблицу биндингов.
class AppShortcuts extends StatelessWidget {
  const AppShortcuts({
    super.key,
    required this.tabCount,
    required this.onTab,
    required this.child,
    this.onEscape,
  });

  final int tabCount;
  final ValueChanged<int> onTab;
  final VoidCallback? onEscape;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        for (var i = 0; i < tabCount; i++)
          SingleActivator(LogicalKeyboardKey(0x31 + i), control: true): () =>
              onTab(i),
        if (onEscape != null)
          const SingleActivator(LogicalKeyboardKey.escape): onEscape!,
      },
      child: Focus(autofocus: true, child: child),
    );
  }
}
