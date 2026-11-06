import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:rhythm/core/domain/source.dart';
import 'package:rhythm/core/sources/source_store.dart';
import 'package:rhythm/core/theme/spacing.dart';
import 'package:rhythm/features/sources/widgets/connector_field_form.dart';
import 'package:rhythm/integrations/catalog.dart';
import 'package:rhythm/integrations/contract/connector.dart';

/// Добавление и правка источника.
///
/// Экран ничего не знает про конкретный вуз: список полей приходит из
/// дескриптора коннектора, подсказки — из его `search`. Новый источник
/// требует правки только в `integrations/`.
class SourceEditScreen extends ConsumerStatefulWidget {
  const SourceEditScreen({super.key, this.source});

  final Source? source;

  @override
  ConsumerState<SourceEditScreen> createState() => _SourceEditScreenState();
}

class _SourceEditScreenState extends ConsumerState<SourceEditScreen> {
  late final TextEditingController _title;
  late final TextEditingController _subtitle;
  late ScheduleConnector _connector;
  late SourceKind _kind;
  var _formKey = GlobalKey<ConnectorFieldFormState>();
  String? _error;

  bool get _isEdit => widget.source != null;

  @override
  void initState() {
    super.initState();
    final source = widget.source;
    _connector = source == null
        ? (selectableConnectors.isEmpty
            ? manualConnector
            : selectableConnectors.first)
        : connectorFor(source);
    _kind = source?.kind ?? _connector.descriptor.defaultKind;
    _title = TextEditingController(text: source?.title ?? _connector.label);
    _subtitle = TextEditingController(text: source?.subtitle ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    super.dispose();
  }

  void _selectConnector(ScheduleConnector connector) {
    setState(() {
      _connector = connector;
      _kind = connector.descriptor.defaultKind;
      // Поля нового коннектора другие — форма создаётся заново.
      _formKey = GlobalKey<ConnectorFieldFormState>();
      if (_title.text.isEmpty ||
          _title.text == manualConnector.label ||
          selectableConnectors.any((c) => c.label == _title.text)) {
        _title.text = connector.label;
      }
    });
  }

  Future<void> _save() async {
    final descriptor = _connector.descriptor;
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Название не может быть пустым');
      return;
    }
    final form = _formKey.currentState;
    final formError = form?.validate();
    if (formError != null) {
      setState(() => _error = formError);
      return;
    }

    final config = form?.config ?? const <String, String>{};
    final notifier = ref.read(sourcesProvider.notifier);
    final subtitle =
        _subtitle.text.trim().isEmpty ? null : _subtitle.text.trim();

    if (_isEdit) {
      await notifier.update(widget.source!.copyWith(
        kind: _kind,
        title: title,
        subtitle: subtitle,
        providerId: descriptor.id,
        config: config,
      ));
    } else {
      final source = Source(
        id: '${descriptor.id}-${DateTime.now().millisecondsSinceEpoch}',
        kind: _kind,
        title: title,
        subtitle: subtitle,
        providerId: descriptor.id,
        config: config,
        colorIndex: ref.read(sourcesProvider).sources.length,
        createdAt: DateTime.now(),
      );
      await notifier.add(source);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final descriptor = _connector.descriptor;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Изменить источник' : 'Новый источник'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Сохранить'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text('Тип источника', style: theme.textTheme.labelLarge),
          const Gap(AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final kind in SourceKind.values)
                ChoiceChip(
                  label: Text(sourceKindLabel(kind)),
                  selected: _kind == kind,
                  onSelected: (_) => setState(() => _kind = kind),
                ),
            ],
          ),
          const Gap(AppSpacing.lg),
          if (!_isEdit) ...[
            Text('Откуда данные', style: theme.textTheme.labelLarge),
            const Gap(AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final connector in selectableConnectors)
                  ChoiceChip(
                    label: Text(
                      '${connector.label} · ${connector.descriptor.kind.badge}',
                    ),
                    selected: _connector.id == connector.id,
                    onSelected: (_) => _selectConnector(connector),
                  ),
                ChoiceChip(
                  label: Text('${manualConnector.label} · без API'),
                  selected: _connector.id == manualConnector.id,
                  onSelected: (_) => _selectConnector(manualConnector),
                ),
              ],
            ),
            const Gap(AppSpacing.lg),
          ],
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Название',
              hintText: 'ТулГУ, Школа №8, Работа',
              border: OutlineInputBorder(),
            ),
          ),
          const Gap(AppSpacing.md),
          TextField(
            controller: _subtitle,
            decoration: const InputDecoration(
              labelText: 'Подпись',
              hintText: 'Группа, класс, отдел',
              border: OutlineInputBorder(),
            ),
          ),
          if (descriptor.fields.isNotEmpty) ...[
            const Gap(AppSpacing.md),
            ConnectorFieldForm(
              key: _formKey,
              connector: _connector,
              initialConfig: widget.source?.config ?? const {},
            ),
          ],
          if (_error != null) ...[
            const Gap(AppSpacing.md),
            Text(
              _error!,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ],
          const Gap(AppSpacing.lg),
          Text(
            descriptor.capabilities.isEmpty
                ? 'Источник без API: расписание и оценки вносятся вручную.'
                : 'Возможности: ${descriptor.capabilities.map(sourceCapabilityLabel).join(', ')}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
