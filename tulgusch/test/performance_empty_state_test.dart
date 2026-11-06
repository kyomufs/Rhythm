// Экран успеваемости при пустом ответе вуза: пользователь должен увидеть,
// какие зачётка и группа ушли в запрос, и кнопки «Загрузить»/«Профиль».
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tulgusch/core/api/api_providers.dart';
import 'package:tulgusch/core/api/schedule_api.dart';
import 'package:tulgusch/core/models/app_settings.dart';
import 'package:tulgusch/core/models/marks.dart';
import 'package:tulgusch/core/services/connectivity_service.dart';
import 'package:tulgusch/core/services/storage_service.dart';
import 'package:tulgusch/features/performance/screens/performance_screen.dart';

class _Storage extends StorageService {
  @override
  bool get isInitialized => true;

  @override
  AppSettings getAppSettings() => const AppSettings();

  @override
  Future<void> saveAppSettings(AppSettings settings) async {}

  @override
  String? getMyGroup() => '221341';

  @override
  String? getMySubgroup() => '01';

  @override
  String? getStudentId() => '000000';

  @override
  List<MarksItem>? getCachedMarks({
    required String studentId,
    required String group,
  }) =>
      null;

  @override
  Future<void> cacheMarks({
    required String studentId,
    required String group,
    required List<MarksItem> marks,
  }) async {}
}

class _EmptyMarksApi implements FinalMarksApi {
  @override
  Future<List<FinalMark>> finalMarks({
    required String studentId,
    required String group,
  }) async =>
      const [];
}

class _Online implements ConnectivityService {
  @override
  Future<bool> checkConnectivity() async => true;

  @override
  void invalidateCache() {}
}

void main() {
  testWidgets('пустой ответ показывает зачётку, группу и действия',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(_Storage()),
          finalMarksApiProvider.overrideWithValue(_EmptyMarksApi()),
          connectivityServiceProvider.overrideWithValue(_Online()),
        ],
        child: const MaterialApp(
          locale: Locale('ru'),
          supportedLocales: [Locale('ru')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: PerformanceScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Оценок нет'), findsOneWidget);
    expect(
      find.textContaining('зачётка 000000'),
      findsOneWidget,
      reason: 'пользователь должен видеть, какие данные ушли в запрос',
    );
    expect(find.textContaining('группа 221341'), findsOneWidget);
    expect(find.text('Загрузить'), findsOneWidget);
    expect(find.text('Профиль'), findsOneWidget);
  });
}
