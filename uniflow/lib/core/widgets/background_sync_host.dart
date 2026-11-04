import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:uniflow/core/theme/theme_provider.dart';
import 'package:uniflow/features/schedule/providers/schedule_provider.dart';

/// Держит фоновую проверку расписания: таймер по периоду из настроек плюс
/// внеочередной опрос при возврате приложения на передний план.
///
/// Отдельный виджет, а не логика внутри нотифаера: таймер живёт ровно столько,
/// сколько живёт оболочка, и пересоздаётся при смене периода в настройках.
class BackgroundSyncHost extends ConsumerStatefulWidget {
  final Widget child;

  const BackgroundSyncHost({super.key, required this.child});

  @override
  ConsumerState<BackgroundSyncHost> createState() => _BackgroundSyncHostState();
}

class _BackgroundSyncHostState extends ConsumerState<BackgroundSyncHost>
    with WidgetsBindingObserver {
  Timer? _timer;
  ProviderSubscription<int>? _intervalSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
    // Период меняется в настройках — таймер перезапускается сразу, без
    // перезапуска приложения.
    _intervalSub = ref.listenManual<int>(
      appSettingsProvider.select((s) => s.backgroundCheckMinutes),
      (_, __) => _schedule(),
    );
  }

  @override
  void dispose() {
    _intervalSub?.close();
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Возврат в приложение — самый вероятный момент, когда расписание уже
      // поменялось, а таймер ещё не дошёл.
      _poll();
    }
  }

  void _schedule() {
    _timer?.cancel();
    final minutes = ref.read(appSettingsProvider).backgroundCheckMinutes;
    if (minutes <= 0) return;
    _timer = Timer.periodic(Duration(minutes: minutes), (_) => _poll());
  }

  Future<void> _poll() async {
    if (!mounted) return;
    await ref.read(scheduleScreenProvider.notifier).pollForChanges();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
