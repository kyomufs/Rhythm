import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rhythm/app.dart';
import 'package:rhythm/core/services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Phones are portrait-only; tablets (shortest side >= 600dp) keep
  // all orientations. View metrics are read before the first frame.
  final views = WidgetsBinding.instance.platformDispatcher.views;
  Future<void>? orientation;
  if (views.isNotEmpty) {
    final view = views.first;
    final shortestSide = view.physicalSize.shortestSide / view.devicePixelRatio;
    if (shortestSide < 600) {
      orientation =
          SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  // Draw edge-to-edge so the UI extends behind the gesture pill instead
  // of leaving a system inset strip below the navigation bar.
  // System bar colors are applied per app theme in RhythmApp.build —
  // a hard-coded style here would not follow theme/seed changes.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));

  final storageService = StorageService();

  // Три независимые инициализации — локальное хранилище, таблицы дат для
  // ru-локали и ориентация — раньше шли тремя последовательными await, и
  // сплэш висел на их сумме. Первому кадру нужны все три, поэтому запускаем
  // их вместе и ждём самую долгую.
  await Future.wait<void>([
    if (orientation != null) orientation,
    initializeDateFormatting('ru'),
    storageService.init(),
  ]);

  final onboardingDone = storageService.isOnboardingCompleted();

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storageService),
      ],
      child: RhythmApp(startScreen: onboardingDone),
    ),
  );

  // Чистка протухшего кэша расписания не нужна первому кадру: раньше она
  // стояла перед runApp и задерживала запуск на проход по всем снапшотам.
  unawaited(storageService.clearOldCache());
}
