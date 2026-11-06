import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tulgusch/core/input/desktop_input.dart';
import 'package:tulgusch/core/services/notification_service.dart';
import 'package:tulgusch/core/services/storage_service.dart';
import 'package:tulgusch/core/services/update_service.dart';
import 'package:tulgusch/core/theme/theme_provider.dart';
import 'package:tulgusch/core/widgets/background_sync_host.dart';
import 'package:tulgusch/core/widgets/update_dialog.dart';
import 'package:tulgusch/core/widgets/update_feedback.dart';
import 'package:tulgusch/features/performance/providers/performance_provider.dart';
import 'package:tulgusch/features/performance/screens/performance_screen.dart';
import 'package:tulgusch/features/profile/screens/onboarding_screen.dart';
import 'package:tulgusch/features/profile/screens/profile_screen.dart';
import 'package:tulgusch/features/schedule/providers/schedule_provider.dart';
import 'package:tulgusch/features/schedule/screens/schedule_changes_screen.dart';
import 'package:tulgusch/features/schedule/screens/schedule_screen.dart';
import 'package:tulgusch/shared/widgets/app_nav_bar.dart';

/// Индексы вкладок оболочки — единственный источник истины для переходов
/// между экранами. Раньше переходы писали числа напрямую, и после удаления
/// вкладки журнала «Открыть профиль» уводило за пределы списка.
abstract final class AppTabs {
  static const int schedule = 0;
  static const int performance = 1;
  static const int profile = 2;
}

/// Current tab index
final currentTabProvider = StateProvider<int>((ref) => AppTabs.schedule);

/// Main app widget
class TulguschApp extends ConsumerWidget {
  final bool startScreen;

  const TulguschApp({super.key, this.startScreen = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Только то, от чего зависит MaterialApp: тема и режим. Раньше здесь
    // читались настройки целиком, поэтому любая галочка в настройках
    // пересобирала MaterialApp с обеими темами.
    final themeMode =
        ref.watch(appSettingsProvider.select((s) => s.parsedThemeMode));
    final lightTheme = ref.watch(themeDataProvider);
    final darkTheme = ref.watch(themeDataProviderDark);

    return MaterialApp(
      title: 'tulgusch',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      // Переход цвета не анимируется вовсе. Даже 120 мс — это семь кадров,
      // каждый из которых перестраивает всё дерево (IndexedStack с тремя
      // экранами), и смена темы читалась как зависание. Мгновенная подмена
      // палитры стоит одной перестройки.
      themeAnimationDuration: Duration.zero,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ru', 'RU'),
        Locale('en', 'US'),
      ],
      locale: const Locale('ru'),
      home: startScreen ? const MainShell() : const OnboardingScreen(),
    );
  }
}

/// Shell with a solid, edge-to-edge bottom navigation bar (Gmail-style).
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  static const _screens = <Widget>[
    ScheduleScreen(),
    PerformanceScreen(),
    ProfileScreen(),
  ];

  /// Число вкладок: по нему проверяются переходы (см. `AppTabs`) и
  /// раскладка горячих клавиш.
  static final int tabCount = _screens.length;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  final _updateService = UpdateService();

  /// Вкладки строятся при первом показе. IndexedStack держал в дереве все
  /// экраны с первого кадра — расписание, таблицу оценок и профиль, — хотя
  /// виден один.
  final Set<int> _visited = {AppTabs.schedule};

  @override
  void initState() {
    super.initState();
    // Плашка автообновления живёт на результатах сетевых запросов, которые
    // стартуют сами провайдеры: её можно вешать сразу после первого кадра.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showStartupUpdateNotice();
    });
    // Плагин уведомлений тянет системный диалог разрешения, проверка
    // обновлений — платформенный канал и сеть. Оба запускались сразу после
    // первого кадра и отнимали главный поток у расписания, поэтому первый
    // экран дёргался. Разносим их по времени.
    Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      _setupNotifications();
    });
    Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      _checkForUpdate();
    });
  }

  /// Плашка автообновления при входе: расписание и оценки подтягиваются на
  /// старте сами, поэтому пользователь должен увидеть, что это отработало.
  /// Ждём оба результата — так «обновлено и то, и другое» сообщается одной
  /// плашкой, а не двумя подряд.
  Future<void> _showStartupUpdateNotice() async {
    final scheduleNotifier = ref.read(scheduleScreenProvider.notifier);
    final marksNotifier = ref.read(performanceProvider.notifier);
    final results = await Future.wait([
      scheduleNotifier.bootRefresh,
      marksNotifier.bootRefresh,
    ]);
    if (!mounted) return;
    showUpdateSuccessNotification(
      context,
      schedule: results[0],
      marks: results[1],
    );
  }

  /// Android in-app updater: check the GitHub latest release once per
  /// start and offer the new version when online. Any failure (offline,
  /// private repo, rate limit) is silent — never blocks startup.
  Future<void> _checkForUpdate() async {
    if (!Platform.isAndroid || !mounted) return;
    try {
      final info = await _updateService.check();
      if (info == null || !mounted) return;
      final package = await PackageInfo.fromPlatform();
      if (!mounted) return;
      showUpdateDialog(context, _updateService, info, package.version);
    } catch (_) {
      // Offline / API unavailable — nothing to show.
    }
  }

  Future<void> _setupNotifications() async {
    if (!mounted) return;
    final service = ref.read(notificationServiceProvider);
    final storage = ref.read(storageServiceProvider);
    await service.init();
    // Тап по уведомлению «Расписание изменилось» ведёт прямо в список
    // изменений: плашка поверх чужого экрана была бы тупиком.
    service.onTap = (payload) {
      if (!mounted) return;
      ref.read(currentTabProvider.notifier).state = AppTabs.schedule;
      if (payload == changesNotificationPayload) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const ScheduleChangesScreen(),
          ),
        );
      }
    };
    final granted = await service.requestPermission();
    // One-time confirmation so the user sees that notifications work.
    if (granted && mounted && !storage.isNotificationsAsked()) {
      await storage.setNotificationsAsked();
      await service.show(
        1,
        'Уведомления включены',
        'tulgusch сообщит об изменениях расписания и оценок',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTab = ref.watch(currentTabProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // Вкладку переключает не только нижняя панель: кнопка «Открыть профиль»
    // на пустых оценках пишет в провайдер напрямую. Без этой подписки такой
    // переход не попадал в `_visited`, и IndexedStack честно показывал
    // заглушку — пустой экран профиля.
    ref.listen<int>(currentTabProvider, (_, next) {
      if (_visited.add(next)) setState(() {});
    });

    // Keep system bars aligned with the APP theme (the user may run the
    // app dark while the system is light): the gesture/system strip under
    // the navigation bar must follow the seed color like everything else.
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: colorScheme.surfaceContainer,
      systemNavigationBarIconBrightness:
          colorScheme.brightness == Brightness.light
              ? Brightness.dark
              : Brightness.light,
    ));

    void selectTab(int index) {
      if (index < 0 || index >= MainShell.tabCount) return;
      HapticFeedback.lightImpact();
      if (_visited.add(index)) setState(() {});
      ref.read(currentTabProvider.notifier).state = index;
    }

    // Ctrl+1…3 переключают вкладки: клики по нижней панели — путь для
    // планшета, но на ПК это медленно.
    return BackgroundSyncHost(
      child: AppShortcuts(
        tabCount: MainShell.tabCount,
        onTab: selectTab,
        onEscape: () => Navigator.of(context).maybePop(),
        child: Scaffold(
          body: IndexedStack(
            index: currentTab,
            children: [
              for (var i = 0; i < MainShell.tabCount; i++)
                _visited.contains(i)
                    ? MainShell._screens[i]
                    : const SizedBox.shrink(),
            ],
          ),
          // Solid bar, no floating rounded container: full-width surface color
          // with a tonal indicator pill, like Gmail's bottom navigation.
          // NavigationBar wraps its content in SafeArea itself, and its
          // Material paints the gesture inset (iOS home indicator) with the
          // bar color — adding padding/transform here would double the inset
          // and float the menu high above the bottom edge.
          bottomNavigationBar: AppNavBar(
            selectedIndex: currentTab,
            onSelected: selectTab,
            destinations: const [
              AppNavDestination(
                icon: Icons.calendar_today_outlined,
                selectedIcon: Icons.calendar_today,
                label: 'Расписание',
              ),
              AppNavDestination(
                icon: Icons.assessment_outlined,
                selectedIcon: Icons.assessment,
                label: 'Оценки',
              ),
              AppNavDestination(
                icon: Icons.person_outline,
                selectedIcon: Icons.person,
                label: 'Профиль',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
