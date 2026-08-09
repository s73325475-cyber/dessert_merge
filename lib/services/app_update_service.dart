import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app_release_config.dart';

/// 원격 manifest JSON 스키마
class UpdateManifest {
  const UpdateManifest({
    required this.version,
    required this.buildNumber,
    required this.apkUrl,
    this.releaseNotes = '',
    this.forceUpdate = false,
  });

  factory UpdateManifest.fromJson(Map<String, dynamic> json) {
    return UpdateManifest(
      version: json['version'] as String? ?? '0.0.0',
      buildNumber: (json['buildNumber'] as num?)?.toInt() ?? 0,
      apkUrl: json['apkUrl'] as String? ?? '',
      releaseNotes: json['releaseNotes'] as String? ?? '',
      forceUpdate: json['forceUpdate'] as bool? ?? false,
    );
  }

  final String version;
  final int buildNumber;
  final String apkUrl;
  final String releaseNotes;
  final bool forceUpdate;
}

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.currentVersion,
    required this.currentBuild,
    required this.manifest,
  });

  final String currentVersion;
  final int currentBuild;
  final UpdateManifest manifest;
}

enum AppUpdateStatus {
  idle,
  checking,
  downloading,
  installing,
  upToDate,
  skipped,
  error,
}

class AppUpdateService {
  AppUpdateService(this._prefs);

  static const _channel =
      MethodChannel('com.dessertmerge.dessert_merge/install');
  static const _skippedBuildKey = 'app_update_skipped_build';

  final SharedPreferences _prefs;
  AppUpdateStatus status = AppUpdateStatus.idle;
  String? lastError;
  double downloadProgress = 0;

  bool get isConfigured => AppReleaseConfig.updateManifestUrl.isNotEmpty;

  Future<PackageInfo> packageInfo() => PackageInfo.fromPlatform();

  Future<AppUpdateInfo?> checkForUpdate() async {
    if (!isConfigured) {
      lastError = '업데이트 URL이 설정되지 않았습니다.';
      return null;
    }
    if (kIsWeb || !Platform.isAndroid) {
      lastError = 'Android 앱에서만 업데이트를 지원합니다.';
      return null;
    }

    status = AppUpdateStatus.checking;
    lastError = null;
    try {
      final info = await packageInfo();
      final currentBuild = int.tryParse(info.buildNumber) ?? 0;
      final uri = Uri.parse(AppReleaseConfig.updateManifestUrl);
      final res = await http
          .get(uri)
          .timeout(AppReleaseConfig.manifestTimeout);
      if (res.statusCode != 200) {
        throw HttpException('manifest HTTP ${res.statusCode}');
      }
      final json = jsonDecode(res.body);
      if (json is! Map<String, dynamic>) {
        throw const FormatException('manifest 형식 오류');
      }
      final manifest = UpdateManifest.fromJson(json);
      if (manifest.buildNumber <= currentBuild || manifest.apkUrl.isEmpty) {
        status = AppUpdateStatus.upToDate;
        return null;
      }
      if (!manifest.forceUpdate &&
          _prefs.getInt(_skippedBuildKey) == manifest.buildNumber) {
        status = AppUpdateStatus.skipped;
        return null;
      }
      status = AppUpdateStatus.idle;
      return AppUpdateInfo(
        currentVersion: info.version,
        currentBuild: currentBuild,
        manifest: manifest,
      );
    } catch (e) {
      lastError = e.toString();
      status = AppUpdateStatus.error;
      return null;
    }
  }

  void skipUpdate(int buildNumber) {
    _prefs.setInt(_skippedBuildKey, buildNumber);
    status = AppUpdateStatus.skipped;
  }

  Future<void> downloadAndInstall(
    UpdateManifest manifest, {
    void Function(double progress)? onProgress,
  }) async {
    if (kIsWeb || !Platform.isAndroid) {
      throw UnsupportedError('Android 전용');
    }
    status = AppUpdateStatus.downloading;
    downloadProgress = 0;
    lastError = null;

    final uri = Uri.parse(manifest.apkUrl);
    final request = http.Request('GET', uri);
    final client = http.Client();
    try {
      final response =
          await client.send(request).timeout(AppReleaseConfig.downloadTimeout);
      if (response.statusCode != 200) {
        throw HttpException('APK HTTP ${response.statusCode}');
      }
      final total = response.contentLength ?? 0;
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/dessert_merge_${manifest.buildNumber}.apk',
      );
      final sink = file.openWrite();
      var received = 0;
      await for (final chunk in response.stream) {
        received += chunk.length;
        sink.add(chunk);
        if (total > 0) {
          downloadProgress = received / total;
          onProgress?.call(downloadProgress);
        }
      }
      await sink.close();
      if (!await file.exists() || await file.length() < 1024) {
        throw const FileSystemException('다운로드 파일이 비어 있습니다.');
      }

      status = AppUpdateStatus.installing;
      await _channel.invokeMethod<void>('installApk', {'path': file.path});
      status = AppUpdateStatus.idle;
    } catch (e) {
      lastError = e.toString();
      status = AppUpdateStatus.error;
      rethrow;
    } finally {
      client.close();
    }
  }
}
