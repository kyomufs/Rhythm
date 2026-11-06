import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:uniflow/core/domain/source.dart';
import 'package:uniflow/core/sources/registry.dart';
import 'package:uniflow/core/sources/source_provider.dart';
import 'package:uniflow/core/sources/source_store.dart';
import 'package:uniflow/core/theme/spacing.dart';

/// Добавление и правка источника.
///
/// Провайдер выбирается первым: от него зависит, какие поля вообще есть.
/// Источник без провайдера (школа, работа, курсы) сразу живёт по ручному вводу.
class SourceEditScreen extends ConsumerStatefulWidget {
  const SourceEditScreen({super.key, this.source});

  final Source? source;

  @override
  ConsumerState<SourceEditScreen> createState() => _SourceEditScreenState();
}

class _SourceEditScreenState extends ConsumerState<SourceEditScreen> {
  late final TextEditingController _title;
  late final TextEditingController _subtitle;
  late final TextEditingController _group;
  late SourceProvider _provider;
  late SourceKind _kind;
  String? _error;

  bool get _isEdit => widget.source != null;

  @override
  void initState() {
    super.initState();
    final source = widget.source;
    _provider = source == null
        ? (selectableProviders.isEmpty
            ? manualSourceProvider
            : selectableProviders.first)
        : providerFor(source);
    _kind = source?.kind ?? _kindForProvider(_provider);
    _title = TextEditingController(text: source?.title ?? _provider.label);
    _subtitle = TextEditingController(text: source?.subtitle ?? '');
    _group = TextEditingController(text: source?.config['group'] ?? '');
  }

  SourceKind _kindForProvider(SourceProvider provider) {
    return provider.id == 'tulsu' ? SourceKind.university : SourceKind.other;
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _group.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Название не может быть пустым');
      return;
    }
    final needsGroup =
        _provider.capabilities.contains(SourceCapability.schedule);
    final group = _group.text.trim();
    if (needsGroup && group.isEmpty) {
      setState(() => _error = 'Укажите группу — по ней строится расписание');
      return;
    }

    final config = <String, String>{
      if (_provider.id == 'tulsu') 'group': group,
    };
    final notifier = ref.read(sourcesProvider.notifier);

    if (_isEdit) {
      await notifier.update(widget.source!.copyWith(
        kind: _kind,
        title: title,
        subtitle: _subtitle.text.trim().isEmpty ? null : _subtitle.text.trim(),
        config: config,
      ));
    } else {
      final source = Source(
        id: '${_provider.id}-${DateTime.now().millisecondsSinceEpoch}',
        kind: _kind,
        title: title,
        subtitle: _subtitle.text.trim().isEmpty ? null : _subtitle.text.trim(),
        providerId:
            _provider.id == manualSourceProvider.id ? null : _provider.id,
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
            Text('Провайдер', style: theme.textTheme.labelLarge),
            const Gap(AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                for (final provider in selectableProviders)
                  ChoiceChip(
                    label: Text(provider.label),
                    selected: _provider.id == provider.id,
                    onSelected: (_) => setState(() {
                      _provider = provider;
                      _kind = _kindForProvider(provider);
                      if (_title.text == manualSourceProvider.label ||
                          _title.text.isEmpty) {
                        _title.text = provider.label;
                      }
                    }),
                  ),
                ChoiceChip(
                  label: const Text('Без API'),
                  selected: _provider.id == manualSourceProvider.id,
                  onSelected: (_) => setState(() {
                    _provider = manualSourceProvider;
                    if (_title.text.isEmpty) _title.text = '';
                  }),
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
          if (_provider.capabilities.contains(SourceCapability.schedule)) ...[
            const Gap(AppSpacing.md),
            TextField(
              controller: _group,
              decoration: const InputDecoration(
                labelText: 'Группа',
                hintText: '221341',
                helperText: 'По номеру группы загружается расписание',
                border: OutlineInputBorder(),
              ),
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
            _provider.id == manualSourceProvider.id
                ? 'Источник без API: расписание и оценки вносятся вручную.'
                : 'Возможности: ${_provider.capabilities.map(sourceCapabilityLabel).join(', ')}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
