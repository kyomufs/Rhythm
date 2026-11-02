import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:uniflow/core/services/storage_service.dart';
import 'package:uniflow/app.dart';
import 'package:uniflow/features/profile/providers/profile_providers.dart';
import 'package:uniflow/features/schedule/providers/schedule_provider.dart';

/// First-launch onboarding guide
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  final _groupController = TextEditingController();
  final _subgroupController = TextEditingController();
  final _studentIdController = TextEditingController();

  // Focus nodes so each input page can auto-focus its field.
  final _groupFocus = FocusNode();
  final _subgroupFocus = FocusNode();
  final _studentIdFocus = FocusNode();

  int _currentPage = 0;

  static const _totalPages = 5;

  @override
  void dispose() {
    _pageController.dispose();
    _groupController.dispose();
    _subgroupController.dispose();
    _studentIdController.dispose();
    _groupFocus.dispose();
    _subgroupFocus.dispose();
    _studentIdFocus.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      // Dismiss the keyboard before sliding back.
      FocusManager.instance.primaryFocus?.unfocus();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Auto-focus the input field of the page that just became active.
  void _focusFieldOfPage(int index) {
    FocusNode? node;
    switch (index) {
      case 1:
        node = _groupFocus;
        break;
      case 2:
        node = _subgroupFocus;
        break;
      case 3:
        node = _studentIdFocus;
        break;
      default:
        return; // Welcome / done pages have no input.
    }
    // Wait a frame so the page transition doesn't steal focus back.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) node?.requestFocus();
    });
  }

  void _finish() {
    final storage = ref.read(storageServiceProvider);

    // Save group if entered
    if (_groupController.text.isNotEmpty) {
      ref
          .read(scheduleScreenProvider.notifier)
          .setMyGroup(_groupController.text);
    }

    // Save subgroup if entered
    if (_subgroupController.text.isNotEmpty) {
      storage.setMySubgroup(_subgroupController.text);
    }

    // Save student ID if entered
    if (_studentIdController.text.isNotEmpty) {
      storage.setStudentId(_studentIdController.text);
    }

    // Let dependent providers (marks, profile card) pick up new values.
    ref.read(profileRevisionProvider.notifier).state++;

    storage.setOnboardingCompleted();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const MainShell()),
    );
  }

  void _skip() {
    ref.read(storageServiceProvider).setOnboardingCompleted();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const MainShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        // Back button (hidden on the first page).
        leading: _currentPage > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Назад',
                onPressed: _prevPage,
              )
            : null,
        actions: [
          if (_currentPage < _totalPages - 1)
            TextButton(
              onPressed: _skip,
              child: const Text('Пропустить'),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Page indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: List.generate(_totalPages, (i) {
                  final isActive = i == _currentPage;
                  return Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: isActive
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                  _focusFieldOfPage(index);
                },
                children: [
                  _buildWelcomePage(colorScheme),
                  _buildGroupPage(colorScheme),
                  _buildSubgroupPage(colorScheme),
                  _buildStudentIdPage(colorScheme),
                  _buildDonePage(colorScheme),
                ],
              ),
            ),

            // Bottom buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed:
                      _currentPage == _totalPages - 1 ? _finish : _nextPage,
                  child: Text(
                    _currentPage == _totalPages - 1 ? 'Начать' : 'Далее',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school,
              size: 96,
              color: colorScheme.primary,
            ),
            const Gap(32),
            Text(
              'Добро пожаловать\nв UniFlow!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const Gap(16),
            Text(
              'Расписание занятий, заметки и задачи\nвсегда под рукой',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupPage(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group_add,
              size: 72,
              color: colorScheme.primary,
            ),
            const Gap(24),
            Text(
              'Какая у тебя группа?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const Gap(8),
            Text(
              'Укажи номер группы для просмотра расписания',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const Gap(24),
            TextField(
              controller: _groupController,
              focusNode: _groupFocus,
              decoration: const InputDecoration(
                labelText: 'Номер группы',
                hintText: '111111',
                prefixIcon: Icon(Icons.group_outlined),
              ),
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubgroupPage(ColorScheme colorScheme) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.subdirectory_arrow_right,
                size: 80, color: colorScheme.secondary),
            const Gap(24),
            Text('Подгруппа',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const Gap(12),
            Text(
              'Укажите номер подгруппы (например, 01).\n'
              'Нужна для просмотра успеваемости.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const Gap(32),
            TextField(
              controller: _subgroupController,
              focusNode: _subgroupFocus,
              decoration: const InputDecoration(
                labelText: 'Подгруппа',
                hintText: '01',
                prefixIcon: Icon(Icons.subdirectory_arrow_right),
              ),
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 18),
            ),
            const Gap(16),
            Text('Можно пропустить',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentIdPage(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.badge_outlined,
              size: 72,
              color: colorScheme.primary,
            ),
            const Gap(24),
            Text(
              'Номер зачётки',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const Gap(8),
            Text(
              'Необязательно. Можно указать позже\nв настройках.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const Gap(24),
            TextField(
              controller: _studentIdController,
              focusNode: _studentIdFocus,
              decoration: const InputDecoration(
                labelText: 'Зачётная книжка',
                hintText: '123456',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonePage(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check,
                size: 48,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const Gap(32),
            Text(
              'Всё готово!',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const Gap(16),
            Text(
              'Группу и зачётку всегда можно\nпоменять в настройках.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
