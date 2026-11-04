import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uniflow/core/api/tulsu_api.dart';
import 'package:uniflow/core/theme/shapes.dart';
import 'package:uniflow/core/utils/mark_labels.dart';

/// Таблица успеваемости: липкая шапка, вертикальная прокрутка строк и
/// горизонтальная прокрутка столбцов, ширины столбцов тянутся мышью или
/// пальцем за разделитель в шапке (двойной тап возвращает исходную ширину).
///
/// Масштаб меняется кнопками в полосе над шапкой и Ctrl/⌘ + колесо; он
/// умножает и ширины столбцов, и кегль, поэтому вёрстка не разъезжается.
/// Кулачковый пинч не подключён намеренно: он отбирает жест у горизонтальной
/// прокрутки, а таблица на телефоне листается именно ею.
class MarksTable extends StatefulWidget {
  final List<MarksItem> items;

  const MarksTable({super.key, required this.items});

  @override
  State<MarksTable> createState() => _MarksTableState();
}

class _MarksTableState extends State<MarksTable> {
  /// Базовые (несжатые) ширины: компактные, чтобы на телефоне таблица
  /// влезала целиком без прокрутки.
  static const List<_ColumnSpec> _specs = [
    _ColumnSpec(_Col.discipline, 'Дисциплина', initial: 180, min: 150),
    _ColumnSpec(_Col.teacher, 'Преподаватель', initial: 120, min: 90),
    _ColumnSpec(_Col.mark, 'Оценка', initial: 64, min: 56),
    _ColumnSpec(_Col.attestation, 'Аттестация', initial: 84, min: 66),
    _ColumnSpec(_Col.retake, 'Пересдача', initial: 88, min: 68),
  ];

  static const double _minZoom = 0.85;
  static const double _maxZoom = 1.8;
  static const double _zoomStep = 0.15;

  final Map<_Col, double> _widths = {
    for (final spec in _specs) spec.col: spec.initial,
  };
  final ScrollController _horizontal = ScrollController();

  double _zoom = 1;

  @override
  void dispose() {
    _horizontal.dispose();
    super.dispose();
  }

  /// «Пересдача» нужна не всегда: пустой столбец только отнимает ширину.
  List<_ColumnSpec> get _columns =>
      widget.items.any((item) => item.retake.isNotEmpty)
          ? _specs
          : _specs.where((spec) => spec.col != _Col.retake).toList();

  double _base(_ColumnSpec spec) => _widths[spec.col] ?? spec.initial;

  /// Свободное место, которое сейчас отдано «Дисциплине» (в базовых
  /// единицах, как и ширины).
  double _stretch = 0;

  /// После первой ручной правки ширины растяжение выключается: иначе оно
  /// съедало бы ровно тот сдвиг, который делает пользователь.
  bool _frozen = false;

  void _resize(_ColumnSpec spec, double delta) {
    setState(() {
      if (!_frozen) {
        _widths[_Col.discipline] = _base(_specs.first) + _stretch;
        _frozen = true;
      }
      // Перетаскивание приходит в экранных пикселях, ширины хранятся
      // в базовых — делим на масштаб, иначе край «убегает» от курсора.
      _widths[spec.col] =
          math.max(spec.min, _base(spec) + delta / _zoom);
    });
  }

  void _reset(_ColumnSpec spec) {
    setState(() {
      _widths[spec.col] = spec.initial;
      _frozen = false;
    });
  }

  void _setZoom(double value) {
    final next = value.clamp(_minZoom, _maxZoom);
    if (next == _zoom) return;
    setState(() => _zoom = next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final columns = _columns;

    return LayoutBuilder(
      builder: (context, constraints) {
        final intrinsic = columns.fold<double>(
            0, (sum, spec) => sum + _base(spec) * _zoom);
        // Узкая таблица не должна висеть у левого края: свободное место
        // отдаём «Дисциплине», остальные столбцы остаются по дефолту.
        final freeSpace = constraints.maxWidth - intrinsic;
        final stretch = !_frozen && freeSpace > 0 ? freeSpace / _zoom : 0.0;
        _stretch = stretch;

        double widthOf(_ColumnSpec spec) =>
            (_base(spec) +
                (spec.col == _Col.discipline ? stretch : 0)) *
            _zoom;

        return Column(
          children: [
            _ZoomBar(
              zoom: _zoom,
              onZoomOut: () => _setZoom(_zoom - _zoomStep),
              onZoomIn: () => _setZoom(_zoom + _zoomStep),
              onReset: () => _setZoom(1),
            ),
            Expanded(
              child: Listener(
                // Ctrl/⌘ + колесо — привычный зум: без модификатора колесо
                // должно прокручивать таблицу, а не масштабировать её.
                onPointerSignal: (event) {
                  if (event is! PointerScrollEvent) return;
                  final keys = HardwareKeyboard.instance;
                  if (!keys.isControlPressed && !keys.isMetaPressed) return;
                  _setZoom(_zoom - event.scrollDelta.dy / 400);
                },
                child: MediaQuery.withNoTextScaling(
                  // Кегль масштабируется вместе с ширинами, но системный
                  // text scale здесь не нужен: он ломал бы расчёт столбцов.
                  child: Builder(
                    builder: (context) => Scrollbar(
                      controller: _horizontal,
                      thumbVisibility: true,
                      scrollbarOrientation: ScrollbarOrientation.bottom,
                      child: SingleChildScrollView(
                        controller: _horizontal,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: constraints.maxWidth > intrinsic + stretch * _zoom
                              ? constraints.maxWidth
                              : intrinsic + stretch * _zoom,
                          child: Column(
                            children: [
                              _HeaderRow(
                                columns: columns,
                                zoom: _zoom,
                                widthOf: widthOf,
                                onResize: _resize,
                                onReset: _reset,
                              ),
                              Divider(
                                  height: 1,
                                  color: colorScheme.outlineVariant),
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.only(bottom: 100),
                                  itemCount: widget.items.length,
                                  itemBuilder: (context, index) {
                                    final item = widget.items[index];
                                    return _TableRow(
                                      key: ValueKey(
                                          '${item.term}-${item.discipline}'),
                                      item: item,
                                      index: index,
                                      columns: columns,
                                      zoom: _zoom,
                                      widthOf: widthOf,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Полоса масштаба: «−», текущий процент, «+» и сброс.
class _ZoomBar extends StatelessWidget {
  final double zoom;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onReset;

  const _ZoomBar({
    required this.zoom,
    required this.onZoomOut,
    required this.onZoomIn,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(
        children: [
          _ZoomButton(
            icon: Icons.remove,
            tooltip: 'Мельче',
            onTap: onZoomOut,
          ),
          SizedBox(
            width: 52,
            child: Text(
              '${(zoom * 100).round()}%',
              key: const ValueKey('marks-zoom-label'),
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          _ZoomButton(
            icon: Icons.add,
            tooltip: 'Крупнее',
            onTap: onZoomIn,
          ),
          const Spacer(),
          _ZoomButton(
            icon: Icons.restart_alt,
            tooltip: 'Сбросить масштаб',
            onTap: onReset,
          ),
        ],
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ZoomButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon),
      iconSize: 18,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        minimumSize: const Size(36, 32),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

// ============================================================
// Header
// ============================================================
class _HeaderRow extends StatelessWidget {
  final List<_ColumnSpec> columns;
  final double zoom;
  final double Function(_ColumnSpec) widthOf;
  final void Function(_ColumnSpec, double) onResize;
  final void Function(_ColumnSpec) onReset;

  const _HeaderRow({
    required this.columns,
    required this.zoom,
    required this.widthOf,
    required this.onResize,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Высота фиксирована: в Column с Expanded шапка получает бесконечную
    // высоту, и stretch-строка внутри неё падает на раскладке.
    return SizedBox(
      height: 36 * zoom,
      child: ColoredBox(
        color: colorScheme.surfaceContainerHigh,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < columns.length; i++)
              SizedBox(
                key: ValueKey('marks-header-${columns[i].col.name}'),
                width: widthOf(columns[i]),
                child: Stack(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8 * zoom,
                        vertical: 8 * zoom,
                      ),
                      child: Align(
                        alignment: columns[i].col.alignment,
                        child: Text(
                          columns[i].title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                            fontSize:
                                (theme.textTheme.labelSmall?.fontSize ?? 11) *
                                    zoom,
                          ),
                        ),
                      ),
                    ),
                    if (i < columns.length - 1)
                      Positioned(
                        top: 0,
                        bottom: 0,
                        right: 0,
                        child: _ResizeHandle(
                          onDrag: (delta) => onResize(columns[i], delta),
                          onReset: () => onReset(columns[i]),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Разделитель-захват: 12dp ширины под палец, внутри — линия 1dp.
class _ResizeHandle extends StatelessWidget {
  final ValueChanged<double> onDrag;
  final VoidCallback onReset;

  const _ResizeHandle({required this.onDrag, required this.onReset});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Столбец идёт за пальцем с первого пикселя, без мёртвой зоны
        // в размер touch slop.
        dragStartBehavior: DragStartBehavior.down,
        onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
        onDoubleTap: onReset,
        child: SizedBox(
          width: 12,
          child: Center(
            child: Container(width: 1, color: colorScheme.outlineVariant),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Rows
// ============================================================
class _TableRow extends StatelessWidget {
  final MarksItem item;
  final int index;
  final List<_ColumnSpec> columns;
  final double zoom;
  final double Function(_ColumnSpec) widthOf;

  const _TableRow({
    super.key,
    required this.item,
    required this.index,
    required this.columns,
    required this.zoom,
    required this.widthOf,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Полосы по чётности: без них длинная таблица читается хуже, а рамки
    // между ячейками добавляют визуального шума.
    final background = index.isOdd
        ? colorScheme.surfaceContainerLow.withValues(alpha: 0.6)
        : Colors.transparent;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final spec in columns)
              SizedBox(
                width: widthOf(spec),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10 * zoom,
                    vertical: 8 * zoom,
                  ),
                  child: Align(
                    alignment: spec.col.alignment,
                    child: _cell(context, spec.col),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cell(BuildContext context, _Col col) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final markColor = _markColor(colorScheme, item);
    final small = theme.textTheme.bodySmall?.copyWith(
      fontSize: (theme.textTheme.bodySmall?.fontSize ?? 12) * zoom,
    );

    switch (col) {
      case _Col.discipline:
        // Название не обрезаем: предмет должен читаться целиком, высота
        // строки растёт по содержимому (IntrinsicHeight выше).
        return Text(
          item.discipline,
          style: small?.copyWith(
            fontWeight: FontWeight.w500,
            height: 1.25,
          ),
        );
      case _Col.teacher:
        return Text(
          item.teacherMark.isEmpty ? '—' : item.teacherMark,
          style: small?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.2,
          ),
        );
      case _Col.mark:
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: 8 * zoom,
            vertical: 2 * zoom,
          ),
          decoration: BoxDecoration(
            color: markColor.withValues(alpha: 0.12),
            borderRadius: AppShapes.circular(AppShapes.small),
          ),
          child: Text(
            item.mark.isEmpty ? '—' : item.mark,
            maxLines: 1,
            style: small?.copyWith(
              color: markColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      case _Col.attestation:
        return Text(
          item.markTitle.isEmpty ? '—' : shortMarkTitle(item.markTitle),
          style: small?.copyWith(
            color:
                item.markTitle.isEmpty ? colorScheme.onSurfaceVariant : markColor,
            fontWeight: FontWeight.w600,
          ),
        );
      case _Col.retake:
        return Text(
          item.retake.isEmpty ? '—' : item.retake,
          style: small?.copyWith(color: colorScheme.onSurfaceVariant),
        );
    }
  }
}

/// Цвет оценки в схеме MD3; сравниваем по нормализованной подписи, потому что
/// API отдаёт «зачёт»/«Зачет»/«Незачет» вразнобой.
Color _markColor(ColorScheme colorScheme, MarksItem item) {
  if (item.markTitle.isEmpty) return colorScheme.onSurfaceVariant;
  return switch (normalizeMarkTitle(item.markTitle)) {
    'отлично' || 'зачет' => colorScheme.primary,
    'хорошо' => colorScheme.tertiary,
    'удовлетворительно' || 'незачет' => colorScheme.secondary,
    'не аттестован' => colorScheme.error,
    _ => colorScheme.onSurface,
  };
}

// ============================================================
// Column model
// ============================================================
enum _Col {
  discipline,
  teacher,
  mark,
  attestation,
  retake;

  /// Числовые и статусные столбцы выравниваем по центру, текстовые — слева.
  Alignment get alignment => switch (this) {
        _Col.discipline || _Col.teacher => Alignment.centerLeft,
        _ => Alignment.center,
      };
}

class _ColumnSpec {
  final _Col col;
  final String title;
  final double initial;
  final double min;

  const _ColumnSpec(this.col, this.title,
      {required this.initial, required this.min});
}
