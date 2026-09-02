import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class AnalyticsEvent {
  static const appOpen = 'APP_OPEN';
  static const loginSuccess = 'LOGIN_SUCCESS';
  static const marketplaceOpen = 'MARKETPLACE_OPEN';
  static const categoryOpen = 'CATEGORY_OPEN';
  static const productOpen = 'PRODUCT_OPEN';
  static const cartAdd = 'CART_ADD';
  static const checkoutStart = 'CHECKOUT_START';

  static const values = <String>{
    appOpen,
    loginSuccess,
    marketplaceOpen,
    categoryOpen,
    productOpen,
    cartAdd,
    checkoutStart,
  };
}

typedef PackageInfoLoader = Future<PackageInfo> Function();
typedef PreferencesLoader = Future<SharedPreferences> Function();

class AnalyticsService {
  AnalyticsService._({
    http.Client? client,
    PackageInfoLoader? packageInfoLoader,
    PreferencesLoader? preferencesLoader,
    String? sessionId,
    String? platform,
  })  : _client = client ?? http.Client(),
        _packageInfoLoader = packageInfoLoader ?? PackageInfo.fromPlatform,
        _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance,
        _sessionId = sessionId ?? Uuid().v4(),
        _platform = platform ?? _detectPlatform();

  static final AnalyticsService instance = AnalyticsService._();

  @visibleForTesting
  AnalyticsService.forTesting({
    http.Client? client,
    PackageInfoLoader? packageInfoLoader,
    PreferencesLoader? preferencesLoader,
    String? sessionId,
    String? platform,
  }) : this._(
          client: client,
          packageInfoLoader: packageInfoLoader,
          preferencesLoader: preferencesLoader,
          sessionId: sessionId,
          platform: platform,
        );

  static const _baseUrl = 'https://teletudo.com/api/v1/analytics/event';
  static const _timeout = Duration(seconds: 3);

  final http.Client _client;
  final PackageInfoLoader _packageInfoLoader;
  final PreferencesLoader _preferencesLoader;
  final String _sessionId;
  final String _platform;
  final Set<String> _sessionEvents = <String>{};

  String get sessionId => _sessionId;
  String get platform => _platform;

  void track(String eventType, {bool success = true}) {
    if (!AnalyticsEvent.values.contains(eventType)) return;
    if (eventType == AnalyticsEvent.appOpen && !_sessionEvents.add(eventType)) {
      return;
    }
    unawaited(_track(eventType, success: success));
  }

  Future<void> _track(String eventType, {required bool success}) async {
    try {
      final packageInfo = await _packageInfoLoader();
      final prefs = await _preferencesLoader();
      final token = prefs.getString('authToken');
      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (token != null && token.trim().isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final payload = <String, dynamic>{
        'event_type': eventType,
        'session_id': _sessionId,
        'app_version': packageInfo.version,
        'build_number': packageInfo.buildNumber,
        'platform': _platform,
        'success': success,
      };
      await _client
          .post(Uri.parse(_baseUrl),
              headers: headers, body: jsonEncode(payload))
          .timeout(_timeout);
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
            '[Analytics] falha evento=$eventType tipo=${error.runtimeType}');
      }
    }
  }

  static String _detectPlatform() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.windows:
        return 'windows';
      default:
        return 'other';
    }
  }
}
