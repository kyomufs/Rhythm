import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:rhythm/core/services/storage_service.dart';
import 'package:rhythm/core/theme/motion.dart';
import 'package:rhythm/core/theme/shapes.dart';
import 'package:rhythm/core/theme/typography.dart';
import 'package:rhythm/app.dart';
import 'package:rhythm/features/profile/providers/profile_providers.dart';
import 'package:rhythm/features/schedule/providers/schedule_provider.dart';

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
        // PageView принимает только Duration + Curve, поэтому длительность
        // берётся из времени затухания slow-пружины, а не из «400 мс».
        duration: springDuration(MotionScheme.of(context).slowSpatial),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      // Dismiss the keyboard before sliding back.
      FocusManager.instance.primaryFocus?.unfocus();
      _pageController.previousPage(
        duration: springDuration(MotionScheme.of(context).slowSpatial),
        curve: Curves.easeOutCubic,
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
                      // Меняется только цвет — значит effects-пружина.
                      duration: springDuration(
                        MotionScheme.of(context).defaultEffects,
                      ),
                      curve: Curves.easeOut,
                      height: isActive ? 6 : 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: isActive
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: AppShapes.circular(3),
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
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
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
    return _PageBody(
      children: [
        const _HeroSpot(icon: Icons.school, size: 124, iconSize: 58),
        const Gap(32),
        Text(
          'Добро пожаловать\nв Rhythm!',
          textAlign: TextAlign.center,
          style: AppTypography.emphasizedHeadlineMedium(
            Theme.of(context).textTheme.headlineMedium!,
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
    );
  }

  Widget _buildGroupPage(ColorScheme colorScheme) {
    return _PageBody(
      children: [
        const _HeroSpot(icon: Icons.group_add, size: 92, iconSize: 40),
        const Gap(24),
        Text(
          'Какая у тебя группа?',
          textAlign: TextAlign.center,
          style: AppTypography.emphasizedHeadlineSmall(
            Theme.of(context).textTheme.headlineSmall!,
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
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    );
  }

  Widget _buildSubgroupPage(ColorScheme colorScheme) {
    final theme = Theme.of(context);
    return _PageBody(
      children: [
        const _HeroSpot(
          icon: Icons.subdirectory_arrow_right,
          size: 92,
          iconSize: 40,
          tone: _SpotTone.secondary,
        ),
        const Gap(24),
        Text(
          'Подгруппа',
          style: AppTypography.emphasizedHeadlineSmall(
            theme.textTheme.headlineSmall!,
          ),
        ),
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
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Gap(16),
        Text('Можно пропустить',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildStudentIdPage(ColorScheme colorScheme) {
    return _PageBody(
      children: [
        const _HeroSpot(icon: Icons.badge_outlined, size: 92, iconSize: 40),
        const Gap(24),
        Text(
          'Номер зачётки',
          textAlign: TextAlign.center,
          style: AppTypography.emphasizedHeadlineSmall(
            Theme.of(context).textTheme.headlineSmall!,
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
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    );
  }

  Widget _buildDonePage(ColorScheme colorScheme) {
    return _PageBody(
      children: [
        const _HeroSpot(
          icon: Icons.check_rounded,
          size: 108,
          iconSize: 54,
          tone: _SpotTone.tertiary,
        ),
        const Gap(32),
        Text(
          'Всё готово!',
          style: AppTypography.emphasizedHeadlineMedium(
            Theme.of(context).textTheme.headlineMedium!,
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
    );
  }
}

/// Тело страницы онбординга.
///
/// Контент по-прежнему центрируется по вертикали, но живёт в прокручиваемой
/// области: при поднятой клавиатуре Scaffold сжимает тело, и страница с
/// заголовком, подсказкой и полем ввода не влезала — RenderFlex ломался
/// полосой переполнения прямо над нижней кнопкой.
class _PageBody extends StatelessWidget {
  const _PageBody({required this.children});

  final List<Widget> children;

  static const _padding = EdgeInsets.symmetric(horizontal: 32, vertical: 24);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight =
            (constraints.maxHeight - _padding.vertical).clamp(0.0, 1e6);
        return SingleChildScrollView(
          padding: _padding,
          // Тянуть страницу вниз — значит убрать клавиатуру: иначе поле
          // ввода остаётся в фокусе и экран не вернуть целиком.
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: children,
            ),
          ),
        );
      },
    );
  }
}

/// Тональное «пятно» с иконкой: появляется пружиной с перелётом.
///
/// Голые цветные иконки на пустом экране читались как заглушки; пятно даёт
/// странице точку опоры, а масштаб при появлении — ощущение, что экран
/// собрался, а не просто отрисовался.
enum _SpotTone { primary, secondary, tertiary }

class _HeroSpot extends StatelessWidget {
  const _HeroSpot({
    required this.icon,
    required this.size,
    required this.iconSize,
    this.tone = _SpotTone.primary,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final _SpotTone tone;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (tone) {
      _SpotTone.primary => (
          colorScheme.primaryContainer,
          colorScheme.onPrimaryContainer,
        ),
      _SpotTone.secondary => (
          colorScheme.secondaryContainer,
          colorScheme.onSecondaryContainer,
        ),
      _SpotTone.tertiary => (
          colorScheme.tertiaryContainer,
          colorScheme.onTertiaryContainer,
        ),
    };

    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final spot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppShapes.circular(size / 2),
      ),
      child: Icon(icon, size: iconSize, color: foreground),
    );

    if (reduceMotion) return spot;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.7, end: 1),
      duration: springDuration(MotionTokens.slowSpatial),
      curve: Curves.easeOutBack,
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
      child: spot,
    );
  }
}
