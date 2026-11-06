import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tulgusch/core/services/storage_service.dart';

/// Версия профиля: меняется при сохранении группы, подгруппы или зачётки.
/// Провайдеры, кэширующие профильные данные, следят за ней и пересобираются.
final profileRevisionProvider = StateProvider<int>((ref) => 0);

/// Номер группы, по которой строится расписание.
final profileGroupProvider = Provider<String?>((ref) {
  ref.watch(profileRevisionProvider);
  final group = ref.watch(storageServiceProvider).getMyGroup();
  return group == null || group.isEmpty ? null : group;
});

final profileSubgroupProvider = Provider<String?>((ref) {
  ref.watch(profileRevisionProvider);
  final subgroup = ref.watch(storageServiceProvider).getMySubgroup();
  return subgroup == null || subgroup.isEmpty ? null : subgroup;
});

/// Номер зачётки: без него нет итоговых оценок.
final profileStudentIdProvider = Provider<String?>((ref) {
  ref.watch(profileRevisionProvider);
  final id = ref.watch(storageServiceProvider).getStudentId();
  return id == null || id.isEmpty ? null : id;
});

/// Версия сборки из pubspec (`version:` в pubspec.yaml).
///
/// Единственный источник правды: захардкоженная строка в «О приложении»
/// расходится с реальным APK сразу после релиза.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
});
