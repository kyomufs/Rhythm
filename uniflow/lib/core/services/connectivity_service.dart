import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uniflow/core/api/endpoints.dart';

/// Provider for connectivity service
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

/// Service for checking API connectivity with caching
class ConnectivityService {
  bool? _lastResult;
  DateTime? _lastCheckTime;

  /// Cache duration in seconds
  static const int _cacheDurationSeconds = 30;

  /// Check if the API is reachable
  /// Returns cached result if checked within the last 30 seconds
  Future<bool> checkConnectivity() async {
    // Return cached result if still valid
    if (_lastResult != null && _lastCheckTime != null) {
      final elapsed = DateTime.now().difference(_lastCheckTime!);
      if (elapsed.inSeconds < _cacheDurationSeconds) {
        return _lastResult!;
      }
    }

    // Perform actual connectivity check
    try {
      final dio = Dio(BaseOptions(
        baseUrl: TulsuEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        headers: {'Accept': 'application/json'},
      ));

      // Try a lightweight GET to the dictionaries endpoint with empty query
      await dio.get<Map<String, dynamic>>(TulsuEndpoints.dictionaries,
          queryParameters: {'term': ''});
      _lastResult = true;
    } catch (e) {
      // Any error (timeout, DNS, network) means offline
      _lastResult = false;
    }

    _lastCheckTime = DateTime.now();
    return _lastResult!;
  }

  /// Force invalidate the cached result
  void invalidateCache() {
    _lastResult = null;
    _lastCheckTime = null;
  }
}
