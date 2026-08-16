import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_update_info.dart';
import 'version_comparator.dart';

class AppUpdateService {
  static const _availableKey = 'appUpdateAvailable';
  static const _currentVersionKey = 'appCurrentVersion';
  static const _latestVersionKey = 'appLatestVersion';
  static const _latestVersionCodeKey = 'appLatestVersionCode';
  static const _downloadUrlKey = 'appDownloadUrl';
  static const _checkedAtKey = 'appVersionCheckedAt';

  static AppUpdateInfo _current =
      const AppUpdateInfo(status: AppUpdateStatus.notStarted);
  static Future<AppUpdateInfo>? _inFlight;
  static bool _sessionCompleted = false;
  static int _requestCounter = 0;

  static AppUpdateInfo get current => _current;

  static Future<AppUpdateInfo> checkForUpdate({bool force = false}) {
    debugPrint('[AppUpdate] verificacao_solicitada');
    if (_inFlight != null) {
      debugPrint('[AppUpdate] verificacao_reutilizada_em_andamento');
      return _inFlight!;
    }
    if (_sessionCompleted && !force) {
      debugPrint('[AppUpdate] resultado_da_sessao_reutilizado');
      return Future.value(_current);
    }
    _current = const AppUpdateInfo(status: AppUpdateStatus.checking);
    debugPrint('[AppUpdate] verificacao_iniciada');
    final future = _performCheck();
    _inFlight = future;
    return future.whenComplete(() => _inFlight = null);
  }

  static Future<AppUpdateInfo> _performCheck() async {
    PackageInfo? packageInfo;
    try {
      packageInfo = await PackageInfo.fromPlatform();
      debugPrint('[AppUpdate] package_info_carregado');
      debugPrint('[AppUpdate] current_version=${packageInfo.version}');
      debugPrint('[AppUpdate] current_build=${packageInfo.buildNumber}');
      debugPrint(
          '[Version] package=${packageInfo.version} build=${packageInfo.buildNumber}');
      final response = await _getAppVersion();
      final decoded = jsonDecode(response.body);
      debugPrint('[API.AppVersion] raiz=' +
          (decoded is Map
              ? 'map'
              : decoded is List
                  ? 'list'
                  : 'outro'));
      if (decoded is Map) {
        debugPrint('[API.AppVersion] success=' +
            (decoded['success'] == true).toString());
        debugPrint('[API.AppVersion] latest_version_presente=' +
            (decoded['latestVersion'] is String ? 'sim' : 'nao'));
        debugPrint('[API.AppVersion] download_url_presente=' +
            (decoded['downloadUrl'] is String ? 'sim' : 'nao'));
      }
      if (response.statusCode != 200 ||
          decoded is! Map ||
          decoded['success'] != true) {
        return _unavailable(packageInfo, 'http_${response.statusCode}');
      }
      final latestVersion = decoded['latestVersion'];
      final latestVersionCode = decoded['latestVersionCode'];
      final downloadUrl = decoded['downloadUrl'];
      if (latestVersion is! String ||
          latestVersion.trim().isEmpty ||
          latestVersionCode is! int ||
          !_isValidDownloadUrl(downloadUrl)) {
        return _unavailable(packageInfo, 'parse');
      }
      final comparison = compareVersions(packageInfo.version, latestVersion);
      debugPrint('[AppUpdate] latest_version=$latestVersion');
      debugPrint('[AppUpdate] latest_version_code=$latestVersionCode');
      debugPrint(
          '[AppUpdate] comparacao_resultado=${_comparisonLabel(comparison)}');
      if (comparison == null) return _unavailable(packageInfo, 'parse');
      final status = comparison < 0
          ? AppUpdateStatus.updateAvailable
          : AppUpdateStatus.upToDate;
      final result = AppUpdateInfo(
        status: status,
        currentVersion: packageInfo.version,
        currentBuildNumber: packageInfo.buildNumber,
        latestVersion: latestVersion,
        latestVersionCode: latestVersionCode,
        downloadUrl: downloadUrl as String,
        checkedAt: DateTime.now(),
      );
      await _persist(result);
      _current = result;
      _sessionCompleted = true;
      debugPrint(
          '[AppUpdate] update_available=${status == AppUpdateStatus.updateAvailable}');
      debugPrint('[AppUpdate] status=${status.name}');
      return result;
    } on FormatException {
      return _unavailable(packageInfo, 'parse');
    } on Exception catch (error) {
      final type = error.toString().toLowerCase().contains('timeout')
          ? 'timeout'
          : 'http';
      debugPrint('[AppUpdate] erro=$type');
      return _unavailable(packageInfo, type);
    }
  }

  static AppUpdateInfo _unavailable(
      PackageInfo? packageInfo, String errorType) {
    final result = AppUpdateInfo(
      status: AppUpdateStatus.unavailable,
      currentVersion: packageInfo?.version,
      currentBuildNumber: packageInfo?.buildNumber,
      checkedAt: DateTime.now(),
      errorType: errorType,
    );
    _current = result;
    _sessionCompleted = true;
    debugPrint('[AppUpdate] erro=$errorType');
    debugPrint('[AppUpdate] status=unavailable');
    return result;
  }

  static Future<void> _persist(AppUpdateInfo result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
        _availableKey, result.status == AppUpdateStatus.updateAvailable);
    await prefs.setString(_currentVersionKey, result.currentVersion!);
    await prefs.setString(_latestVersionKey, result.latestVersion!);
    await prefs.setInt(_latestVersionCodeKey, result.latestVersionCode!);
    await prefs.setString(_downloadUrlKey, result.downloadUrl!);
    await prefs.setString(_checkedAtKey, result.checkedAt!.toIso8601String());
    debugPrint('[AppUpdate] resultado_persistido');
  }

  static Future<http.Response> _getAppVersion() async {
    final uri = Uri.parse('https://teletudo.com/api/app/versao');
    _requestCounter++;
    debugPrint('[API.AppVersion] request_id=' +
        _requestCounter.toString() +
        ' requisicao_iniciada');
    debugPrint('[API.AppVersion] endpoint=' + uri.toString());
    try {
      final response = await http.get(uri, headers: {
        'Accept': 'application/json'
      }).timeout(const Duration(seconds: 10));
      debugPrint('[API.AppVersion] status=' + response.statusCode.toString());
      debugPrint('[API.AppVersion] bytes=' + response.body.length.toString());
      return response;
    } on TimeoutException {
      debugPrint('[API.AppVersion] erro_timeout');
      rethrow;
    } catch (error) {
      debugPrint('[API.AppVersion] excecao=' + error.runtimeType.toString());
      rethrow;
    }
  }

  static Future<bool> openDownload(AppUpdateInfo info) async {
    final url = info.downloadUrl;
    if (url == null || url.isEmpty) return false;
    try {
      return await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
    } catch (error) {
      debugPrint('[AppUpdate] erro_download=' + error.runtimeType.toString());
      return false;
    }
  }

  static bool _isValidDownloadUrl(Object? value) {
    if (value is! String) return false;
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host == 'teletudo.com' &&
        uri.path == '/download/EntregaTudo.apk' &&
        !uri.hasPort &&
        uri.userInfo.isEmpty;
  }

  static String _comparisonLabel(int? value) {
    if (value == null) return 'invalido';
    if (value < 0) return 'negativo';
    if (value > 0) return 'positivo';
    return 'zero';
  }
}
