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

/// Пара, по которой вуз ищет оценки: `221341` или `221341:01`.
///
/// Отдельная группа включается тумблером; иначе берётся группа расписания
/// вместе с подгруппой, введённой прямо в её поле.
final profileMarksGroupProvider = Provider<String?>((ref) {
  ref.watch(profileRevisionProvider);
  final storage = ref.watch(storageServiceProvider);

  final separate = storage.getMarksGroup();
  if (separate != null && separate.isNotEmpty) {
    final subgroup = storage.getMarksSubgroup();
    return subgroup == null || subgroup.isEmpty
        ? separate
        : '$separate:$subgroup';
  }

  final group = storage.getMyGroup();
  if (group == null || group.isEmpty) return null;
  final subgroup = storage.getMySubgroup();
  return subgroup == null || subgroup.isEmpty ? group : '$group:$subgroup';
});

/// Подгруппа: 01/02. Влияет только на запрос оценок, расписание — по группе.
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
