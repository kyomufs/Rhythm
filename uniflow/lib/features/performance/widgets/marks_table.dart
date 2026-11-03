import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:uniflow/core/api/tulsu_api.dart';
import 'package:uniflow/core/theme/shapes.dart';

/// Таблица успеваемости: липкая шапка, вертикальная прокрутка строк и
/// горизонтальная прокрутка столбцов, ширины столбцов тянутся мышью или
/// пальцем за разделитель в шапке (двойной тап возвращает исходную ширину).
class MarksTable extends StatefulWidget {
  final List<MarksItem> items;

  const MarksTable({super.key, required this.items});

  @override
  State<MarksTable> createState() => _MarksTableState();
}

class _MarksTableState extends State<MarksTable> {
  static const List<_ColumnSpec> _specs = [
    _ColumnSpec(_Col.discipline, 'Дисциплина', initial: 260, min: 150),
    _ColumnSpec(_Col.teacher, 'Преподаватель', initial: 200, min: 110),
    _ColumnSpec(_Col.mark, 'Оценка', initial: 96, min: 80),
    _ColumnSpec(_Col.attestation, 'Аттестация', initial: 160, min: 120),
    _ColumnSpec(_Col.retake, 'Пересдача', initial: 130, min: 96),
  ];

  final Map<_Col, double> _widths = {
    for (final spec in _specs) spec.col: spec.initial,
  };
  final ScrollController _horizontal = ScrollController();

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

  /// Свободное место, которое сейчас отдано «Дисциплине» (см. build).
  double _stretch = 0;

  /// После первой ручной правки ширины растяжение выключается: иначе оно
  /// съедало бы ровно тот сдвиг, который делает пользователь.
  bool _frozen = false;

  void _resize(_ColumnSpec spec, double delta) {
    setState(() {
      if (!_frozen) {
        _widths[_Col.discipline] =
            (_widths[_Col.discipline] ?? _specs.first.initial) + _stretch;
        _frozen = true;
      }
      _widths[spec.col] =
          math.max(spec.min, (_widths[spec.col] ?? spec.initial) + delta);
    });
  }

  void _reset(_ColumnSpec spec) {
    setState(() {
      _widths[spec.col] = spec.initial;
      _frozen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final columns = _columns;

    return LayoutBuilder(
      builder: (context, constraints) {
        var total = columns.fold<double>(
            0, (sum, spec) => sum + (_widths[spec.col] ?? spec.initial));
        // Узкая таблица не должна висеть у левого края: свободное место
        // отдаём «Дисциплине», остальные столбцы остаются по дефолту.
        final stretch = !_frozen && total < constraints.maxWidth
            ? constraints.maxWidth - total
            : 0.0;
        _stretch = stretch;
        total += stretch;

        return Scrollbar(
          controller: _horizontal,
          thumbVisibility: true,
          scrollbarOrientation: ScrollbarOrientation.bottom,
          child: SingleChildScrollView(
            controller: _horizontal,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: total,
              child: Column(
                children: [
                  _HeaderRow(
                    columns: columns,
                    widthOf: (spec) =>
                        (_widths[spec.col] ?? spec.initial) +
                        (spec.col == _Col.discipline ? stretch : 0),
                    onResize: _resize,
                    onReset: _reset,
                  ),
                  Divider(height: 1, color: colorScheme.outlineVariant),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: widget.items.length,
                      itemBuilder: (context, index) {
                        final item = widget.items[index];
                        return _TableRow(
                          key: ValueKey('${item.term}-${item.discipline}'),
                          item: item,
                          index: index,
                          columns: columns,
                          widthOf: (spec) =>
                              (_widths[spec.col] ?? spec.initial) +
                              (spec.col == _Col.discipline ? stretch : 0),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============================================================
// Header
// ============================================================
class _HeaderRow extends StatelessWidget {
  final List<_ColumnSpec> columns;
  final double Function(_ColumnSpec) widthOf;
  final void Function(_ColumnSpec, double) onResize;
  final void Function(_ColumnSpec) onReset;

  const _HeaderRow({
    required this.columns,
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
      height: 48,
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
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      child: Align(
                        alignment: columns[i].col.alignment,
                        child: Text(
                          columns[i].title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
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
  final double Function(_ColumnSpec) widthOf;

  const _TableRow({
    super.key,
    required this.item,
    required this.index,
    required this.columns,
    required this.widthOf,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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

    switch (col) {
      case _Col.discipline:
        return Text(
          item.discipline,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        );
      case _Col.teacher:
        return Text(
          item.teacherMark.isEmpty ? '—' : item.teacherMark,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        );
      case _Col.mark:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: markColor.withValues(alpha: 0.12),
            borderRadius: AppShapes.circular(AppShapes.small),
          ),
          child: Text(
            item.mark.isEmpty ? '—' : item.mark,
            maxLines: 1,
            style: theme.textTheme.labelLarge?.copyWith(
              color: markColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      case _Col.attestation:
        return Text(
          item.markTitle.isEmpty ? '—' : item.markTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: item.markTitle.isEmpty
                ? colorScheme.onSurfaceVariant
                : markColor,
            fontWeight: FontWeight.w600,
          ),
        );
      case _Col.retake:
        return Text(
          item.retake.isEmpty ? '—' : item.retake,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        );
    }
  }
}

/// Цвет оценки в схеме MD3 (перенесён из прежней плитки без изменений).
Color _markColor(ColorScheme colorScheme, MarksItem item) {
  if (item.markTitle.isEmpty) return colorScheme.onSurfaceVariant;
  switch (item.markTitle) {
    case 'Отлично':
    case 'Зачет':
      return colorScheme.primary;
    case 'Хорошо':
      return colorScheme.tertiary;
    case 'Удовлетворительно':
    case 'Незачет':
      return colorScheme.secondary;
    case 'Не аттестован':
      return colorScheme.error;
    default:
      return colorScheme.onSurface;
  }
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
