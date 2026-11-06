import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:rhythm/core/theme/spacing.dart';
import 'package:rhythm/integrations/contract/connector.dart';

/// Форма полей источника, построенная по дескриптору коннектора.
///
/// Знает только про [ConfigField]: какие поля есть, какие обязательны и
/// какие подсказываются поиском. Конкретный вуз сюда не проникает, поэтому
/// форма одна на онбординг и на правку источника.
class ConnectorFieldForm extends StatefulWidget {
  const ConnectorFieldForm({
    super.key,
    required this.connector,
    this.initialConfig = const {},
    this.onlyTargetField = false,
    this.autofocus = false,
  });

  final ScheduleConnector connector;
  final Map<String, String> initialConfig;

  /// Онбординг спрашивает только то, без чего нет расписания.
  final bool onlyTargetField;
  final bool autofocus;

  @override
  State<ConnectorFieldForm> createState() => ConnectorFieldFormState();
}

class ConnectorFieldFormState extends State<ConnectorFieldForm> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String> _values = {};
  final Map<String, List<ConfigOption>> _options = {};
  Timer? _debounce;
  bool _searching = false;

  List<ConfigField> get _fields {
    final descriptor = widget.connector.descriptor;
    if (!widget.onlyTargetField) return descriptor.fields;
    return descriptor.fields
        .where((field) => field.key == descriptor.targetField)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    for (final field in _fields) {
      final displayKey = field.displayKey;
      final display = displayKey != null
          ? widget.initialConfig[displayKey] ??
              widget.initialConfig[field.key] ??
              ''
          : widget.initialConfig[field.key] ?? '';
      _controllers[field.key] = TextEditingController(text: display);
      _values[field.key] = widget.initialConfig[field.key] ?? '';
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Значения для [Source.config]; подписи выбранных вариантов идут в
  /// `displayKey`, чтобы список источников показывал номер группы, а не uuid.
  Map<String, String> get config {
    final config = <String, String>{
      for (final field in _fields)
        if ((_values[field.key] ?? '').isNotEmpty)
          field.key: _values[field.key]!,
    };
    for (final field in _fields) {
      final displayKey = field.displayKey;
      if (displayKey == null) continue;
      final text = _controllers[field.key]?.text.trim() ?? '';
      if (text.isNotEmpty) config[displayKey] = text;
    }
    return config;
  }

  /// Текст ошибки или null, если форма валидна.
  String? validate() {
    for (final field in _fields) {
      if (!field.required) continue;
      if ((_values[field.key] ?? '').isEmpty) {
        return 'Заполните поле «${field.label}»';
      }
    }
    return null;
  }

  void _onChanged(ConfigField field, String text) {
    if (!field.searchable) {
      _values[field.key] = text.trim();
      return;
    }
    // Свободный ввод не подтверждает значение с displayKey: идентификатор
    // приходит только с подсказкой.
    _values[field.key] = field.displayKey == null ? text.trim() : '';
    _debounce?.cancel();
    if (text.trim().length < 2) {
      setState(() => _options.remove(field.key));
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() => _searching = true);
      try {
        final result = await widget.connector.search(field.key, text.trim());
        if (!mounted) return;
        setState(() => _options[field.key] = result);
      } catch (_) {
        if (!mounted) return;
        setState(() => _options[field.key] = const []);
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  void _pick(ConfigField field, ConfigOption option) {
    setState(() {
      _controllers[field.key]?.text = option.label;
      _values[field.key] = option.value;
      _options.remove(field.key);
    });
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fields = _fields;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final field in fields) ...[
          if (field != fields.first) const Gap(AppSpacing.md),
          TextField(
            controller: _controllers[field.key],
            autofocus: widget.autofocus && field == fields.first,
            textCapitalization: TextCapitalization.characters,
            onChanged: (text) => _onChanged(field, text),
            decoration: InputDecoration(
              labelText: field.required ? '${field.label} *' : field.label,
              hintText: field.hint,
              helperText: field.helper,
              prefixIcon: field.searchable ? const Icon(Icons.search) : null,
              suffixIcon: field.searchable && _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              border: const OutlineInputBorder(),
            ),
          ),
          if (field.searchable && (_options[field.key] ?? []).isNotEmpty) ...[
            const Gap(AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final option in _options[field.key]!)
                  ActionChip(
                    label: Text(
                      option.label,
                      style: theme.textTheme.bodyMedium,
                    ),
                    onPressed: () => _pick(field, option),
                  ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}
