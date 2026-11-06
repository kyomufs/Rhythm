import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rhythm/integrations/catalog.dart';
import 'package:rhythm/integrations/contract/connector.dart';
import 'package:rhythm/core/sources/source_store.dart';

/// Provider for connectivity service
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService(connectorFor(ref.watch(activeSourceProvider)));
});

/// Проверка доступности API активного источника с кэшем на полминуты:
/// один сбой сети не должен запирать приложение в офлайне.
class ConnectivityService {
  final ScheduleConnector _provider;

  ConnectivityService(this._provider);

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

    _lastResult = await _provider.ping();
    _lastCheckTime = DateTime.now();
    return _lastResult!;
  }

  /// Force invalidate the cached result
  void invalidateCache() {
    _lastResult = null;
    _lastCheckTime = null;
  }
}
