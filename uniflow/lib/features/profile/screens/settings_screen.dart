import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:uniflow/core/models/app_settings.dart';
import 'package:uniflow/core/services/notification_service.dart';
import 'package:uniflow/core/services/storage_service.dart';
import 'package:uniflow/core/theme/color_utils.dart';
import 'package:uniflow/core/theme/motion.dart';
import 'package:uniflow/core/theme/theme_provider.dart';
import 'package:uniflow/core/theme/typography.dart';
import 'package:uniflow/features/profile/screens/onboarding_screen.dart';
import 'package:uniflow/features/profile/screens/student_profile_screen.dart';
import 'package:uniflow/shared/widgets/app_segmented_selector.dart';

/// Settings screen for app customization
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ── Profile: group / subgroup / student ID in one place ──
          const _SectionHeader('Профиль'),
          _SectionCard(
            children: [
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('Группа, подгруппа, зачётка'),
                subtitle: const Text('Все поля на одном экране'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const StudentProfileScreen()),
                  );
                },
              ),
            ],
          ),
          const Gap(20),

          // ── Theme Mode ──
          const _SectionHeader('Тема'),
          _SectionCard(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            children: [
              AppSegmentedSelector<String>(
                values: const ['system', 'light', 'dark'],
                selected: settings.themeMode,
                labelOf: (mode) => switch (mode) {
                  'light' => 'Светлая',
                  'dark' => 'Тёмная',
                  _ => 'Системная',
                },
                iconOf: (mode) => switch (mode) {
                  'light' => Icons.light_mode,
                  'dark' => Icons.dark_mode,
                  _ => Icons.brightness_auto,
                },
                onSelected: notifier.updateThemeMode,
              ),
            ],
          ),
          const Gap(20),

          // ── Accent Color ──
          const _SectionHeader('Цвет акцента'),
          _SectionCard(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            children: [
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: paletteOptions.map((option) {
                  final isSelected =
                      settings.seedColorValue == option.colorValue;
                  return GestureDetector(
                    onTap: () => notifier.updateSeedColor(option.colorValue),
                    child: AnimatedContainer(
                      // Выбор цвета — только цвет и толщина рамки: effects.
                      duration: springDuration(
                        MotionScheme.of(context).defaultEffects,
                      ),
                      curve: Curves.easeOut,
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: option.color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: theme.colorScheme.onSurface,
                                width: 3,
                              )
                            : null,
                      ),
                      child: isSelected
                          ? Icon(Icons.check,
                              color: onColorFor(option.color), size: 22)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const Gap(20),

          // ── Schedule Options ──
          const _SectionHeader('Расписание'),
          _SectionCard(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.theaters_outlined),
                title: const Text('Демо-режим'),
                subtitle: const Text(
                    'Выдуманное расписание, оценки и изменения без API'),
                value: settings.demoMode,
                onChanged: notifier.updateDemoMode,
              ),
            ],
          ),
          const Gap(20),

          // ── Notifications ──
          const _SectionHeader('Уведомления'),
          _SectionCard(
            children: [
              ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('Разрешение на уведомления'),
                subtitle: FutureBuilder<bool?>(
                  future: ref
                      .read(notificationServiceProvider)
                      .areNotificationsEnabled(),
                  builder: (context, snapshot) {
                    if (snapshot.data == false) {
                      return const Text(
                          'Заблокированы — разрешите в системных настройках');
                    }
                    return const Text('Уведомления разрешены');
                  },
                ),
                onTap: () async {
                  final granted = await ref
                      .read(notificationServiceProvider)
                      .requestPermission();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          granted
                              ? 'Уведомления разрешены'
                              : 'Разрешение не выдано',
                        ),
                      ),
                    );
                  }
                },
              ),
              const _TileDivider(),
              ListTile(
                leading: const Icon(Icons.autorenew),
                title: const Text('Фоновая проверка расписания'),
                subtitle: Text(
                  settings.backgroundCheckMinutes == 0
                      ? 'Выключена — изменения придут только при обновлении'
                      : 'Каждые ${AppSettings.backgroundCheckLabel(settings.backgroundCheckMinutes).toLowerCase()}'
                          '. При изменениях придёт уведомление',
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: AppSegmentedSelector<int>(
                  values: AppSettings.backgroundCheckPresets,
                  selected: settings.backgroundCheckMinutes,
                  labelOf: AppSettings.backgroundCheckLabel,
                  onSelected: notifier.updateBackgroundCheckMinutes,
                ),
              ),
            ],
          ),
          const Gap(20),

          // ── Data Management ──
          const _SectionHeader('Данные'),
          _SectionCard(
            children: [
              ListTile(
                leading: const Icon(Icons.cleaning_services_outlined),
                title: const Text('Очистить кэш расписания'),
                subtitle: const Text('Удалить сохранённое расписание'),
                onTap: () {
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Очистить кэш?'),
                      content: const Text(
                          'Сохранённое расписание будет загружено заново.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Отмена'),
                        ),
                        FilledButton(
                          onPressed: () async {
                            final storage = ref.read(storageServiceProvider);
                            await storage.clearScheduleCache();
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Кэш расписания очищен')),
                              );
                            }
                          },
                          child: const Text('Очистить'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const _TileDivider(),
              ListTile(
                leading: Icon(Icons.delete_forever_outlined,
                    color: theme.colorScheme.error),
                title: Text('Удалить все данные',
                    style: TextStyle(color: theme.colorScheme.error)),
                subtitle:
                    const Text('Полный сброс — группа, зачётка, настройки'),
                onTap: () {
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Удалить все данные?'),
                      content: const Text(
                          'Все данные приложения будут удалены: группа, '
                          'зачётка, подгруппа, настройки, кэш. '
                          'Приложение запустится как в первый раз.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Отмена'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.error,
                          ),
                          onPressed: () async {
                            final storage = ref.read(storageServiceProvider);
                            await storage.clearAllData();
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute<void>(
                                  builder: (_) => const OnboardingScreen(),
                                ),
                                (_) => false,
                              );
                            }
                          },
                          child: const Text('Удалить всё'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const Gap(24),

          // ── Reset ──
          OutlinedButton(
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Сбросить настройки?'),
                  content: const Text(
                      'Все настройки будут сброшены к значениям по умолчанию.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Отмена'),
                    ),
                    FilledButton(
                      onPressed: () {
                        notifier.reset();
                        Navigator.pop(ctx);
                      },
                      child: const Text('Сбросить'),
                    ),
                  ],
                ),
              );
            },
            child: const Text('Сбросить настройки'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Section chrome helpers (M3 card-grouped settings)
// ============================================================

/// Section caption above a card.
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(
        title.toUpperCase(),
        style: AppTypography.emphasizedLabelMedium(
          theme.textTheme.labelMedium!.copyWith(
            color: theme.colorScheme.primary,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

/// Card that groups settings tiles like the M3 settings pattern.
class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  const _SectionCard({
    required this.children,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: Column(children: children)),
    );
  }
}

/// Hairline divider between tiles inside a card.
class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

