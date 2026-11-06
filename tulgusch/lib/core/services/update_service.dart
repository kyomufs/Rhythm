import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// One available app update parsed from the GitHub "latest release".
class UpdateInfo {
  final String version;
  final String apkUrl;

  const UpdateInfo({required this.version, required this.apkUrl});
}

/// Checks the GitHub repo for a newer release and downloads its APK.
///
/// Flow (Android only, checked once per app start when online):
/// `check` → dialog → `download` (progress callback) → `installApk`
/// (system installer prompt). All failures are swallowed by the caller —
/// an update check must never break normal startup.
class UpdateService {
  static const _repo = 'kyomufs/tulgusch';
  static const _apiBase = 'https://api.github.com/repos/$_repo';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: const {'Accept': 'application/vnd.github+json'},
  ));

  static const MethodChannel _installer =
      MethodChannel('com.kyomufs.tulgusch/installer');

  /// Returns the newer release, or null when up-to-date/offline/API404.
  Future<UpdateInfo?> check() async {
    final response = await _dio.get<dynamic>('$_apiBase/releases/latest');
    final data = response.data;
    if (data is! Map<String, dynamic>) return null;

    final tag = (data['tag_name'] as String? ?? '').replaceFirst('v', '');
    if (tag.isEmpty) return null;

    final package = await PackageInfo.fromPlatform();
    if (compareVersions(tag, package.version) <= 0) return null;

    final assets = data['assets'];
    if (assets is! List) return null;
    String? apkUrl;
    for (final asset in assets) {
      final name = asset is Map ? asset['name'] : null;
      if (name is String && name.endsWith('.apk')) {
        apkUrl = asset['browser_download_url'] as String?;
        break;
      }
    }
    if (apkUrl == null || apkUrl.isEmpty) return null;

    return UpdateInfo(version: tag, apkUrl: apkUrl);
  }

  /// Downloads the APK to the temp dir; [onProgress] receives0..1.
  Future<String> download(
      UpdateInfo info, void Function(double) onProgress) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/tulgusch-${info.version}.apk';
    await _dio.download(
      info.apkUrl,
      path,
      deleteOnError: true,
      onReceiveProgress: (received, total) {
        if (total > 0) onProgress((received / total).clamp(0.0, 1.0));
      },
    );
    return path;
  }

  /// Asks the system to install a downloaded APK (shows the standard
  /// "Install this app?" prompt).
  Future<void> installApk(String path) {
    return _installer.invokeMethod<void>('installApk', path);
  }

  /// Compares dotted numeric versions ("1.10.0" > "1.2.9"). Each
  /// segment contributes its leading digits ("1-beta" counts as 1,
  /// "rc1" as 0). Returns positive when [a] is newer than [b].
  static int compareVersions(String a, String b) {
    final pa = _segments(a);
    final pb = _segments(b);
    final length = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < length; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va != vb) return va - vb;
    }
    return 0;
  }

  static List<int> _segments(String version) {
    return version.split('.').map((segment) {
      final match = RegExp(r'^\d+').firstMatch(segment);
      return match == null ? 0 : int.parse(match.group(0)!);
    }).toList();
  }
}
