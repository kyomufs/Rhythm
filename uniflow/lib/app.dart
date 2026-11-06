import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uniflow/core/input/desktop_input.dart';
import 'package:uniflow/core/services/notification_service.dart';
import 'package:uniflow/core/services/storage_service.dart';
import 'package:uniflow/core/services/update_service.dart';
import 'package:uniflow/core/theme/theme_provider.dart';
import 'package:uniflow/core/widgets/background_sync_host.dart';
import 'package:uniflow/core/widgets/update_dialog.dart';
import 'package:uniflow/core/widgets/update_feedback.dart';
import 'package:uniflow/features/journal/screens/journal_screen.dart';
import 'package:uniflow/features/performance/providers/performance_provider.dart';
import 'package:uniflow/features/performance/screens/performance_screen.dart';
import 'package:uniflow/features/profile/screens/onboarding_screen.dart';
import 'package:uniflow/features/profile/screens/profile_screen.dart';
import 'package:uniflow/features/schedule/providers/schedule_provider.dart';
import 'package:uniflow/features/schedule/screens/schedule_changes_screen.dart';
import 'package:uniflow/features/schedule/screens/schedule_screen.dart';
import 'package:uniflow/shared/widgets/app_nav_bar.dart';

/// Current tab index
final currentTabProvider = StateProvider<int>((ref) => 0);

/// Main app widget
class UniFlowApp extends ConsumerWidget {
  final bool startScreen;

  const UniFlowApp({super.key, this.startScreen = true});

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
      title: 'UniFlow',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      // 200 мс дефолта — это двенадцать перестроек всего дерева; на плотном
      // экране расписания переход цвета читался как подвисание.
      themeAnimationDuration: const Duration(milliseconds: 120),
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
    JournalScreen(),
    PerformanceScreen(),
    ProfileScreen(),
  ];

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  final _updateService = UpdateService();

  /// Вкладки строятся при первом показе. IndexedStack держал в дереве все
  /// четыре экрана с первого кадра — расписание, заметки, таблицу оценок и
  /// профиль, — хотя виден один.
  final Set<int> _visited = {0};

  @override
  void initState() {
    super.initState();
    // Ask for the notification permission once the first frame is up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupNotifications();
      _checkForUpdate();
      _showStartupUpdateNotice();
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
    // Тап по уведомлению «Расписание изменилось» ведёт прямо в журнал:
    // плашка поверх чужого экрана была бы тупиком.
    service.onTap = (payload) {
      if (!mounted) return;
      ref.read(currentTabProvider.notifier).state = 0;
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
        'UniFlow сообщит об изменениях расписания и оценок',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTab = ref.watch(currentTabProvider);
    final colorScheme = Theme.of(context).colorScheme;

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
      if (index < 0 || index >= MainShell._screens.length) return;
      HapticFeedback.lightImpact();
      if (_visited.add(index)) setState(() {});
      ref.read(currentTabProvider.notifier).state = index;
    }

    // Ctrl+1…4 переключают вкладки: клики по нижней панели — путь для
    // планшета, но на ПК это медленно.
    return BackgroundSyncHost(
      child: AppShortcuts(
        tabCount: MainShell._screens.length,
        onTab: selectTab,
        onEscape: () => Navigator.of(context).maybePop(),
        child: Scaffold(
          body: IndexedStack(
            index: currentTab,
            children: [
              for (var i = 0; i < MainShell._screens.length; i++)
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
                icon: Icons.menu_book_outlined,
                selectedIcon: Icons.menu_book,
                label: 'Журнал',
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
