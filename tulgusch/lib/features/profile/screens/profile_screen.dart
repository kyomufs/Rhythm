import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tulgusch/core/services/storage_service.dart';
import 'package:tulgusch/core/theme/shapes.dart';
import 'package:tulgusch/core/theme/typography.dart';
import 'package:tulgusch/features/schedule/providers/schedule_provider.dart';
import 'package:tulgusch/features/profile/providers/profile_providers.dart';
import 'package:tulgusch/features/profile/screens/settings_screen.dart';
import 'package:tulgusch/features/profile/screens/student_profile_screen.dart';

/// Профиль: карточка-удостоверение и два перехода.
///
/// Вкладка не список равнозначных строк: сверху — крупная тональная карточка
/// с группой, подгруппой и зачёткой (это то, ради чего вкладку открывают),
/// ниже — компактные переходы в настройки и «О приложении».
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final storage = ref.read(storageServiceProvider);
    // Rebuild when profile fields change so subtitles stay in sync.
    ref.watch(profileRevisionProvider);
    final group = ref.watch(scheduleScreenProvider).currentGroup;
    final studentId = storage.getStudentId();
    final subgroup = storage.getMySubgroup();
    // Успеваемость может смотреться по другой паре — показываем её пилюлей.
    final marksGroup = ref.watch(profileMarksGroupProvider);
    final myPair = group == null
        ? null
        : (subgroup == null || subgroup.isEmpty ? group : '$group:$subgroup');
    final version = ref.watch(appVersionProvider).valueOrNull;
    final versionLabel = version == null ? 'О приложении' : 'tulgusch v$version';

    return Scaffold(
      appBar: AppBar(
        title: Text('Профиль', style: Theme.of(context).textTheme.titleLarge),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _IdentityCard(
            group: group,
            subgroup: subgroup,
            // Только когда успеваемость правда смотрится по другой паре.
            marksTarget: marksGroup == myPair ? null : marksGroup,
            studentId: studentId,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const StudentProfileScreen(),
                ),
              );
            },
          ),
          const Gap(16),
          _NavCard(
            icon: Icons.settings_outlined,
            title: 'Настройки',
            subtitle: 'Тема, цвет, расписание',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          const Gap(10),
          _NavCard(
            icon: Icons.info_outline,
            title: 'О приложении',
            subtitle: versionLabel,
            onTap: () => _showAbout(context, colorScheme, version),
          ),
        ],
      ),
    );
  }

  void _showAbout(
    BuildContext context,
    ColorScheme colorScheme,
    String? version,
  ) {
    showAboutDialog(
      context: context,
      applicationName: 'tulgusch',
      applicationVersion: version ?? '',
      applicationIcon: Icon(
        Icons.school,
        size: 48,
        color: colorScheme.primary,
      ),
      children: [
        const Text(
          'Расписание ТулГУ, журнал успеваемости и дедлайны.',
        ),
        const Gap(16),
        const ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.code),
          title: Text('Разработчик'),
          subtitle: Text('kyomufs'),
        ),
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.language),
          title: const Text('GitHub'),
          subtitle: const Text('github.com/kyomufs'),
          onTap: () async {
            final uri = Uri.parse('https://github.com/kyomufs');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
        ),
      ],
    );
  }
}

/// Карточка-удостоверение: монограмма группы, название и факты пилюлями.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.group,
    required this.subgroup,
    required this.marksTarget,
    required this.studentId,
    required this.onTap,
  });

  final String? group;
  final String? subgroup;

  /// Пара, по которой ищутся оценки, если она отличается от группы.
  final String? marksTarget;
  final String? studentId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasSubgroup = subgroup != null && subgroup!.isNotEmpty;
    final monogram = (group != null && group!.isNotEmpty) ? group! : 'tulgusch';

    return Material(
      color: colorScheme.primaryContainer,
      borderRadius: AppShapes.circular(AppShapes.extraLarge),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Монограмма — первая буква группы. Тот же приём, что
                  // аватар в списке контактов: узнаётся без чтения.
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius:
                          AppShapes.circular(AppShapes.largeIncreased),
                    ),
                    child: Text(
                      monogram.substring(0, 1).toUpperCase(),
                      style: AppTypography.emphasizedHeadlineSmall(
                        theme.textTheme.headlineSmall!
                            .copyWith(color: colorScheme.onPrimary),
                      ),
                    ),
                  ),
                  const Gap(14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'МОИ ДАННЫЕ',
                          style: AppTypography.emphasizedLabelSmall(
                            theme.textTheme.labelSmall!.copyWith(
                              color: colorScheme.onPrimaryContainer
                                  .withValues(alpha: 0.75),
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const Gap(2),
                        Text(
                          group ?? 'Группа не выбрана',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.emphasizedTitleLarge(
                            theme.textTheme.titleLarge!.copyWith(
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ],
              ),
              const Gap(14),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _FactPill(
                    icon: Icons.groups_2_outlined,
                    label:
                        hasSubgroup ? 'Подгруппа $subgroup' : 'Без подгруппы',
                    muted: !hasSubgroup,
                  ),
                  if (marksTarget != null)
                    _FactPill(
                      icon: Icons.assessment_outlined,
                      label: 'Оценки $marksTarget',
                      muted: false,
                    ),
                  _FactPill(
                    icon: Icons.badge_outlined,
                    label: (studentId != null && studentId!.isNotEmpty)
                        ? 'Зачётка $studentId'
                        : 'Зачётка не указана',
                    muted: studentId == null || studentId!.isEmpty,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Пилюля факта внутри карточки-удостоверения.
class _FactPill extends StatelessWidget {
  const _FactPill({
    required this.icon,
    required this.label,
    required this.muted,
  });

  final IconData icon;
  final String label;

  /// Пустое значение: тот же размер, но приглушённый тон.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground = muted
        ? colorScheme.onPrimaryContainer.withValues(alpha: 0.6)
        : colorScheme.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.onPrimaryContainer.withValues(alpha: 0.08),
        borderRadius: AppShapes.circular(AppShapes.medium),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const Gap(6),
          Text(
            label,
            style: AppTypography.emphasizedLabelMedium(
              theme.textTheme.labelMedium!.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// Компактный переход: иконка в тонкой плитке, заголовок, пояснение.
class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: AppShapes.circular(AppShapes.largeIncreased),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: AppShapes.circular(AppShapes.medium + 2),
                ),
                child:
                    Icon(icon, size: 22, color: colorScheme.onSurfaceVariant),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.emphasizedTitleSmall(
                        theme.textTheme.titleSmall!,
                      ),
                    ),
                    const Gap(1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(8),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
