import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:uniflow/core/input/desktop_input.dart';

/// Горизонтальный скроллер-пикер балла: чипы 0…max, которые тянутся пальцем
/// или мышью, плюс степпер для точной правки. `null` — балл не выставлен.
class ScoreScroller extends StatefulWidget {
  const ScoreScroller({
    super.key,
    required this.max,
    required this.value,
    required this.onChanged,
    this.label = 'Балл',
  });

  final int max;
  final int? value;
  final ValueChanged<int?> onChanged;
  final String label;

  @override
  State<ScoreScroller> createState() => _ScoreScrollerState();
}

class _ScoreScrollerState extends State<ScoreScroller> {
  static const double _itemExtent = 44;
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelected());
  }

  @override
  void didUpdateWidget(covariant ScoreScroller oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _revealSelected();
  }

  void _revealSelected() {
    if (!mounted || !_controller.hasClients) return;
    final index = widget.value;
    if (index == null) return;
    final target =
        (index * _itemExtent - _controller.position.viewportDimension / 2)
            .clamp(0.0, _controller.position.maxScrollExtent);
    _controller.animateTo(target,
        duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = widget.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(widget.label, style: theme.textTheme.labelLarge),
            const Spacer(),
            Text(
              value == null ? '—' : '$value / ${widget.max}',
              style: theme.textTheme.titleSmall,
            ),
          ],
        ),
        const Gap(8),
        Row(
          children: [
            IconButton.filledTonal(
              tooltip: 'Минус один',
              onPressed: value == null || value == 0
                  ? null
                  : () => widget.onChanged(value - 1),
              icon: const Icon(Icons.remove),
            ),
            const Gap(8),
            Expanded(
              child: SizedBox(
                height: 48,
                child: WheelScroll(
                  controller: _controller,
                  child: DragPan(
                    controller: _controller,
                    child: ListView.separated(
                      controller: _controller,
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.max + 1,
                      separatorBuilder: (_, __) => const Gap(4),
                      itemBuilder: (context, index) {
                        final selected = index == value;
                        return SizedBox(
                          width: _itemExtent - 4,
                          child: selected
                              ? FilledButton(
                                  style: FilledButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    shape: const CircleBorder(),
                                  ),
                                  onPressed: () => widget.onChanged(index),
                                  child: Text('$index'),
                                )
                              : OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    shape: const CircleBorder(),
                                  ),
                                  onPressed: () => widget.onChanged(index),
                                  child: Text('$index'),
                                ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const Gap(8),
            IconButton.filledTonal(
              tooltip: 'Плюс один',
              onPressed: value == null || value >= widget.max
                  ? null
                  : () => widget.onChanged(value + 1),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        if (value != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => widget.onChanged(null),
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Сбросить'),
            ),
          ),
      ],
    );
  }
}
