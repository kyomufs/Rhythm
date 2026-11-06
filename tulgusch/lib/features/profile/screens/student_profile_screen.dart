import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:tulgusch/core/services/storage_service.dart';
import 'package:tulgusch/core/theme/shapes.dart';
import 'package:tulgusch/core/theme/typography.dart';
import 'package:tulgusch/features/profile/providers/profile_providers.dart';
import 'package:tulgusch/features/profile/widgets/tulgu_profile_form.dart';

/// Профиль ученика ТулГУ: группа, подгруппа, зачётка.
class StudentProfileScreen extends ConsumerStatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  ConsumerState<StudentProfileScreen> createState() =>
      _StudentProfileScreenState();
}

class _StudentProfileScreenState extends ConsumerState<StudentProfileScreen> {
  final _formKey = GlobalKey<TulguProfileFormState>();
  String? _error;

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null) return;

    final error = form.validate();
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    final storage = ref.read(storageServiceProvider);
    await storage.setMyGroup(form.group);
    final subgroup = form.subgroup;
    if (subgroup == null) {
      await storage.setMySubgroup('');
    } else {
      await storage.setMySubgroup(subgroup);
    }
    final marksGroup = form.marksGroup;
    if (marksGroup == null) {
      await storage.clearMarksGroup();
    } else {
      await storage.setMarksGroup(marksGroup);
    }
    final studentId = form.studentId;
    if (studentId == null) {
      await storage.clearStudentId();
    } else {
      await storage.setStudentId(studentId);
    }
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
    final storage = ref.watch(storageServiceProvider);

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
                        'ТулГУ',
                        style: AppTypography.emphasizedTitleSmall(
                          theme.textTheme.titleSmall!,
                        ),
                      ),
                    ),
                  ],
                ),
                const Gap(8),
                Text(
                  'Номер группы приходит из API вуза: расписание строится по '
                  'нему, остальные поля — уточнения.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const Gap(16),
                TulguProfileForm(
                  key: _formKey,
                  initialGroup: storage.getMyGroup(),
                  initialSubgroup: storage.getMySubgroup(),
                  initialMarksGroup: storage.getMarksGroup(),
                  initialStudentId: storage.getStudentId(),
                  onChanged: () {
                    if (_error != null) setState(() => _error = null);
                  },
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const Gap(12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.error),
            ),
          ],
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
