import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:rhythm/app.dart';
import 'package:rhythm/core/domain/source.dart';
import 'package:rhythm/core/services/storage_service.dart';
import 'package:rhythm/core/sources/source_store.dart';
import 'package:rhythm/core/theme/motion.dart';
import 'package:rhythm/core/theme/shapes.dart';
import 'package:rhythm/core/theme/typography.dart';
import 'package:rhythm/features/profile/providers/profile_providers.dart';
import 'package:rhythm/features/sources/widgets/connector_field_form.dart';
import 'package:rhythm/integrations/catalog.dart';
import 'package:rhythm/integrations/contract/connector.dart';

/// First-launch onboarding guide.
///
/// Порядок как в Дневаче и Кампусе: сначала способ получения данных, потом
/// учреждение, потом то, по чему строится расписание. Экраны не знают, какой
/// вуз выбран, — список источников приходит из каталога.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  final _titleController = TextEditingController();

  late ScheduleConnector _connector;
  ConnectorKind _method = ConnectorKind.api;
  var _formKey = GlobalKey<ConnectorFieldFormState>();
  String? _error;
  int _currentPage = 0;

  static const _totalPages = 5;

  /// Способы получения, которые реально есть в каталоге.
  List<ConnectorKind> get _methods {
    final methods = selectableConnectors
        .map((connector) => connector.descriptor.kind)
        .toSet()
        .toList();
    methods.add(ConnectorKind.manual);
    return methods;
  }

  List<ScheduleConnector> get _institutions {
    if (_method == ConnectorKind.manual) return const [manualConnector];
    return selectableConnectors
        .where((connector) => connector.descriptor.kind == _method)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _connector = selectableConnectors.isEmpty
        ? manualConnector
        : selectableConnectors.first;
    _method = _connector.descriptor.kind;
    _titleController.text = _connector.label;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _nextPage() {
    final error = _validatePage();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() => _error = null);
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: springDuration(MotionScheme.of(context).slowSpatial),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _prevPage() {
    if (_currentPage == 0) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _pageController.previousPage(
      duration: springDuration(MotionScheme.of(context).slowSpatial),
      curve: Curves.easeOutCubic,
    );
  }

  /// Проверка страницы перед переходом: пустая группа дальше не пускает.
  String? _validatePage() {
    if (_currentPage == 2 && _titleController.text.trim().isEmpty) {
      return 'Укажите название источника';
    }
    if (_currentPage == 3 && _connector.descriptor.fields.isNotEmpty) {
      return _formKey.currentState?.validate();
    }
    return null;
  }

  void _selectMethod(ConnectorKind method) {
    setState(() {
      _method = method;
      final institutions = _institutions;
      _connector = institutions.isEmpty ? manualConnector : institutions.first;
      _formKey = GlobalKey<ConnectorFieldFormState>();
      _titleController.text = _connector.label;
      _error = null;
    });
  }

  void _selectConnector(ScheduleConnector connector) {
    setState(() {
      _connector = connector;
      _formKey = GlobalKey<ConnectorFieldFormState>();
      _titleController.text = connector.label;
      _error = null;
    });
  }

  Future<void> _finish() async {
    final descriptor = _connector.descriptor;
    final config = descriptor.fields.isEmpty
        ? const <String, String>{}
        : _formKey.currentState?.config ?? const <String, String>{};
    final source = Source(
      id: '${descriptor.id}-${DateTime.now().millisecondsSinceEpoch}',
      kind: descriptor.defaultKind,
      title: _titleController.text.trim().isEmpty
          ? descriptor.title
          : _titleController.text.trim(),
      subtitle: _subtitleFor(config),
      providerId: descriptor.id,
      config: config,
      createdAt: DateTime.now(),
    );

    await ref.read(sourcesProvider.notifier).add(source);
    ref.read(profileRevisionProvider.notifier).state++;
    await ref.read(storageServiceProvider).setOnboardingCompleted();

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const MainShell()),
    );
  }

  /// Подпись источника — то, по чему он отличается от соседнего: группа.
  String? _subtitleFor(Map<String, String> config) {
    final descriptor = _connector.descriptor;
    final field = descriptor.field(descriptor.targetField);
    final displayKey = field?.displayKey;
    if (displayKey != null && (config[displayKey] ?? '').isNotEmpty) {
      return config[displayKey];
    }
    final target = config[descriptor.targetField];
    return (target == null || target.isEmpty) ? null : target;
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: List.generate(_totalPages, (i) {
                  final isActive = i == _currentPage;
                  return Expanded(
                    child: AnimatedContainer(
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
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  _buildWelcomePage(colorScheme),
                  _buildMethodPage(colorScheme),
                  _buildInstitutionPage(colorScheme),
                  _buildTargetPage(colorScheme),
                  _buildDonePage(colorScheme),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: colorScheme.error),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
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

  Widget _buildMethodPage(ColorScheme colorScheme) {
    return _PageBody(
      children: [
        const _HeroSpot(
            icon: Icons.cloud_download_outlined, size: 92, iconSize: 40),
        const Gap(24),
        Text(
          'Откуда данные?',
          textAlign: TextAlign.center,
          style: AppTypography.emphasizedHeadlineSmall(
            Theme.of(context).textTheme.headlineSmall!,
          ),
        ),
        const Gap(8),
        Text(
          'Способ получения определяет, что придётся чинить, если вуз '
          'обновит сайт.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        const Gap(24),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final method in _methods)
              ChoiceChip(
                label: Text(method.label),
                selected: _method == method,
                onSelected: (_) => _selectMethod(method),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildInstitutionPage(ColorScheme colorScheme) {
    final theme = Theme.of(context);
    final institutions = _institutions;

    return _PageBody(
      children: [
        const _HeroSpot(icon: Icons.account_balance, size: 92, iconSize: 40),
        const Gap(24),
        Text(
          'Учреждение',
          style: AppTypography.emphasizedHeadlineSmall(
            theme.textTheme.headlineSmall!,
          ),
        ),
        const Gap(8),
        Text(
          _method == ConnectorKind.manual
              ? 'Назовите источник — расписание будете вести сами.'
              : 'Выберите из списка поддерживаемых.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const Gap(24),
        if (institutions.length > 1)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final connector in institutions)
                ChoiceChip(
                  label: Text(
                    '${connector.label} · ${connector.descriptor.kind.badge}',
                  ),
                  selected: _connector.id == connector.id,
                  onSelected: (_) => _selectConnector(connector),
                ),
            ],
          ),
        if (institutions.length > 1) const Gap(16),
        TextField(
          controller: _titleController,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.sentences,
          style: theme.textTheme.titleLarge,
          decoration: const InputDecoration(
            labelText: 'Название',
            hintText: 'ТулГУ, Школа №8, Работа',
          ),
        ),
      ],
    );
  }

  Widget _buildTargetPage(ColorScheme colorScheme) {
    final theme = Theme.of(context);
    final descriptor = _connector.descriptor;
    final field = descriptor.field(descriptor.targetField);

    return _PageBody(
      children: [
        const _HeroSpot(icon: Icons.group_outlined, size: 92, iconSize: 40),
        const Gap(24),
        Text(
          field?.label ?? 'Почти готово',
          style: AppTypography.emphasizedHeadlineSmall(
            theme.textTheme.headlineSmall!,
          ),
        ),
        const Gap(8),
        Text(
          field == null
              ? 'У этого источника нет сетевого расписания: '
                  'занятия и оценки вносятся вручную.'
              : 'По этому значению будет строиться расписание.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        if (descriptor.fields.isNotEmpty) ...[
          const Gap(24),
          ConnectorFieldForm(
            key: _formKey,
            connector: _connector,
            onlyTargetField: true,
            autofocus: true,
          ),
        ],
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
          'Источник добавлен. Его всегда можно\nпоменять в настройках.',
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
/// Контент центрируется по вертикали, но живёт в прокручиваемой области:
/// при поднятой клавиатуре Scaffold сжимает тело, и страница с заголовком,
/// подсказкой и полем ввода не влезала — RenderFlex ломался полосой
/// переполнения прямо над нижней кнопкой.
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
