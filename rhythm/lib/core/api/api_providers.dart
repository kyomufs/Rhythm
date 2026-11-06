import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tulgusch/core/api/schedule_api.dart';
import 'package:tulgusch/core/api/tulsu_api.dart';
import 'package:tulgusch/core/services/connectivity_service.dart';

/// Единственный вуз приложения. Провайдеры ниже — точка, где экраны
/// получают API, не зная, чей он.
final scheduleApiProvider = Provider<ScheduleApi>((ref) => TulsuScheduleApi());

final finalMarksApiProvider =
    Provider<FinalMarksApi>((ref) => TulsuFinalMarksApi());

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService(ref.watch(scheduleApiProvider));
});
