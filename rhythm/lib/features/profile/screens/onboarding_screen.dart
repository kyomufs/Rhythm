import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:tulgusch/app.dart';
import 'package:tulgusch/core/services/storage_service.dart';
import 'package:tulgusch/core/theme/spacing.dart';
import 'package:tulgusch/core/theme/typography.dart';
import 'package:tulgusch/features/profile/providers/profile_providers.dart';
import 'package:tulgusch/features/profile/widgets/tulgu_profile_form.dart';

/// Первый запуск: группа ТулГУ — и всё.
///
/// Приложение работает с одним вузом, поэтому спрашивать «откуда
/// расписание?» больше не у кого: остался один экран с одной формой.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<TulguProfileFormState>();
  String? _error;
  bool _saving = false;

  Future<void> _finish() async {
    if (_saving) return;
    final form = _formKey.currentState;
    if (form == null) return;

    final error = form.validate();
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final storage = ref.read(storageServiceProvider);
    await storage.setMyGroup(form.group);
    final subgroup = form.subgroup;
    if (subgroup != null) await storage.setMySubgroup(subgroup);
    final studentId = form.studentId;
    if (studentId != null) await storage.setStudentId(studentId);
    await storage.setOnboardingCompleted();
    ref.read(profileRevisionProvider.notifier).state++;

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const MainShell()),
    );
  }

  void _later() {
    ref.read(storageServiceProvider).setOnboardingCompleted();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const MainShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройка'),
        actions: [
          TextButton(onPressed: _saving ? null : _later, child: const Text('Позже')),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                children: [
                  Text(
                    'Ваша группа',
                    style: AppTypography.emphasizedHeadlineSmall(
                      theme.textTheme.headlineSmall!,
                    ),
                  ),
                  const Gap(AppSpacing.xs),
                  Text(
                    'Расписание ТулГУ подтянется само. Подгруппа и зачётка '
                    'нужны не всем — их можно оставить пустыми.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const Gap(AppSpacing.lg),
                  TulguProfileForm(
                    key: _formKey,
                    autofocus: true,
                    onChanged: () {
                      if (_error != null) setState(() => _error = null);
                    },
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style:
                      theme.textTheme.bodyMedium?.copyWith(color: scheme.error),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _saving ? null : _finish,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Открыть расписание',
                          style: theme.textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
