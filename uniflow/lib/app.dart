import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uniflow/core/services/notification_service.dart';
import 'package:uniflow/core/services/storage_service.dart';
import 'package:uniflow/core/services/update_service.dart';
import 'package:uniflow/core/theme/theme_provider.dart';
import 'package:uniflow/core/widgets/update_dialog.dart';
import 'package:uniflow/shared/widgets/app_nav_bar.dart';
import 'package:uniflow/features/schedule/screens/schedule_screen.dart';
import 'package:uniflow/features/notes/screens/notes_screen.dart';
import 'package:uniflow/features/performance/screens/performance_screen.dart';
import 'package:uniflow/features/profile/screens/profile_screen.dart';
import 'package:uniflow/features/profile/screens/onboarding_screen.dart';

/// Current tab index
final currentTabProvider = StateProvider<int>((ref) => 0);

/// Main app widget
class UniFlowApp extends ConsumerWidget {
  final bool startScreen;

  const UniFlowApp({super.key, this.startScreen = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final lightTheme = ref.watch(themeDataProvider);
    final darkTheme = ref.watch(themeDataProviderDark);

    return MaterialApp(
      title: 'UniFlow',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: settings.parsedThemeMode,
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
    NotesScreen(),
    PerformanceScreen(),
    ProfileScreen(),
  ];

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  final _updateService = UpdateService();

  @override
  void initState() {
    super.initState();
    // Ask for the notification permission once the first frame is up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupNotifications();
      _checkForUpdate();
    });
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

    return Scaffold(
      body: IndexedStack(
        index: currentTab,
        children: MainShell._screens,
      ),
      // Solid bar, no floating rounded container: full-width surface color
      // with a tonal indicator pill, like Gmail's bottom navigation.
      // NavigationBar wraps its content in SafeArea itself, and its
      // Material paints the gesture inset (iOS home indicator) with the
      // bar color — adding padding/transform here would double the inset
      // and float the menu high above the bottom edge.
      bottomNavigationBar: AppNavBar(
        selectedIndex: currentTab,
        onSelected: (index) {
          HapticFeedback.lightImpact();
          ref.read(currentTabProvider.notifier).state = index;
        },
        destinations: const [
          AppNavDestination(
            icon: Icons.calendar_today_outlined,
            selectedIcon: Icons.calendar_today,
            label: 'Расписание',
          ),
          AppNavDestination(
            icon: Icons.note_alt_outlined,
            selectedIcon: Icons.note_alt,
            label: 'Заметки',
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
    );
  }
}
