import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Incremented whenever profile data (group, subgroup, student ID) changes.
/// Providers that cache profile-derived state watch this to rebuild/reload.
final profileRevisionProvider = StateProvider<int>((ref) => 0);

/// Версия сборки из pubspec (`version:` в pubspec.yaml).
///
/// Единственный источник правды: захардкоженная строка в «О приложении»
/// расходится с реальным APK сразу после релиза.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
});
