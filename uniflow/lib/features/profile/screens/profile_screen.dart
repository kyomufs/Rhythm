import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uniflow/core/services/storage_service.dart';
import 'package:uniflow/features/schedule/providers/schedule_provider.dart';
import 'package:uniflow/features/profile/providers/profile_providers.dart';
import 'package:uniflow/features/profile/screens/settings_screen.dart';
import 'package:uniflow/features/profile/screens/student_profile_screen.dart';

/// Profile screen — main tab for group/student settings
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final storage = ref.read(storageServiceProvider);
    // Rebuild when profile fields change so subtitles stay in sync.
    ref.watch(profileRevisionProvider);
    final group = ref.watch(scheduleScreenProvider).currentGroup;
    final studentId = storage.getStudentId();
    final subgroup = storage.getMySubgroup();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // My Group / subgroup / student ID — one combined editor
          // (three fields on a single screen, per UX review).
          _ProfileCard(
            icon: Icons.badge_outlined,
            title: 'Мои данные',
            subtitle: [
              group ?? 'Группа не выбрана',
              if (subgroup != null && subgroup.isNotEmpty)
                '$group:$subgroup'
              else
                'Подгруппа не указана',
              if (studentId != null && studentId.isNotEmpty)
                'Зачётка $studentId'
              else
                'Зачётка не указана',
            ].join(' · '),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const StudentProfileScreen()),
              );
            },
          ),

          const Gap(8),

          // Settings
          _ProfileCard(
            icon: Icons.settings_outlined,
            title: 'Настройки',
            subtitle: 'Тема, цвет, расписание',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              );
            },
          ),

          const Gap(8),

          // About
          _ProfileCard(
            icon: Icons.info_outline,
            title: 'О приложении',
            subtitle: 'UniFlow v1.0.0',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'UniFlow',
                applicationVersion: '1.0.0',
                applicationIcon: Icon(
                  Icons.school,
                  size: 48,
                  color: colorScheme.primary,
                ),
                children: [
                  const Text(
                    'Приложение для просмотра расписания '
                    'Тульского государственного университета.',
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
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Reusable profile list card
class _ProfileCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
