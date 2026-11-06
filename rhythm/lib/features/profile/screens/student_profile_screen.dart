import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:rhythm/core/sources/source_store.dart';
import 'package:rhythm/core/theme/shapes.dart';
import 'package:rhythm/core/theme/typography.dart';
import 'package:rhythm/features/profile/providers/profile_providers.dart';
import 'package:rhythm/features/sources/widgets/connector_field_form.dart';
import 'package:rhythm/integrations/catalog.dart';

/// Профиль ученика: группа, подгруппа, зачётка.
///
/// Поля принадлежат активному источнику, а не приложению: у ТулГУ своя
/// зачётка, у Бауманки её нет вовсе. Форму рисует дескриптор коннектора.
class StudentProfileScreen extends ConsumerStatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  ConsumerState<StudentProfileScreen> createState() =>
      _StudentProfileScreenState();
}

class _StudentProfileScreenState extends ConsumerState<StudentProfileScreen> {
  final _formKey = GlobalKey<ConnectorFieldFormState>();
  late final Map<String, String> _initialConfig;

  @override
  void initState() {
    super.initState();
    final source = ref.read(activeSourceProvider);
    _initialConfig = Map<String, String>.from(
      source?.config ?? const <String, String>{},
    );
  }

  Future<void> _save() async {
    final source = ref.read(activeSourceProvider);
    if (source == null) return;
    final error = _formKey.currentState?.validate();
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    final config = {
      ...source.config,
      ...?_formKey.currentState?.config,
    };
    await ref.read(sourcesProvider.notifier).update(
          source.copyWith(config: config),
        );
    // Оценки и карточка профиля пересобираются по этому счётчику.
    ref.read(profileRevisionProvider.notifier).state++;

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Профиль сохранён')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final source = ref.watch(activeSourceProvider);
    final connector = connectorFor(source);
    final descriptor = connector.descriptor;

    return Scaffold(
      appBar: AppBar(title: const Text('Профиль ученика'), centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: AppShapes.circular(AppShapes.largeIncreased),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.school_outlined,
                        size: 18, color: colorScheme.primary),
                    const Gap(8),
                    Expanded(
                      child: Text(
                        source?.title ?? descriptor.title,
                        style: AppTypography.emphasizedTitleSmall(
                          theme.textTheme.titleSmall!,
                        ),
                      ),
                    ),
                    Text(
                      descriptor.kind.badge,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const Gap(8),
                Text(
                  descriptor.fields.isEmpty
                      ? 'У источника нет профиля: данные вносятся вручную.'
                      : 'Эти поля принадлежат источнику «${source?.title ?? descriptor.title}».',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                if (descriptor.fields.isNotEmpty) ...[
                  const Gap(16),
                  ConnectorFieldForm(
                    key: _formKey,
                    connector: connector,
                    initialConfig: _initialConfig,
                  ),
                ],
              ],
            ),
          ),
          const Gap(24),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Сохранить'),
            ),
          ),
        ],
      ),
    );
  }
}
