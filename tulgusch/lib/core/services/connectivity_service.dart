import 'package:tulgusch/core/api/schedule_api.dart';

/// Проверка доступности API с кэшем на полминуты: один сбой сети не должен
/// запирать приложение в офлайне.
class ConnectivityService {
  ConnectivityService(this._api);

  final ScheduleApi _api;

  bool? _lastResult;
  DateTime? _lastCheckTime;

  static const int _cacheDurationSeconds = 30;

  Future<bool> checkConnectivity() async {
    if (_lastResult != null && _lastCheckTime != null) {
      final elapsed = DateTime.now().difference(_lastCheckTime!);
      if (elapsed.inSeconds < _cacheDurationSeconds) {
        return _lastResult!;
      }
    }

    _lastResult = await _api.ping();
    _lastCheckTime = DateTime.now();
    return _lastResult!;
  }

  /// Force invalidate the cached result
  void invalidateCache() {
    _lastResult = null;
    _lastCheckTime = null;
  }
}
