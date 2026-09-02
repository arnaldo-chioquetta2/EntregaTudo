import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'marketplace/api_v1_session.dart';
import 'marketplace/api_v1_client.dart';
import 'marketplace/screens/delivery_tracking_page.dart';
import 'marketplace/services/marketplace_service.dart';
import 'push_message_data.dart';

class PushService {
  static const _pendingOrderKey = 'pendingNotificationOrderId';
  static bool _initialized = false;
  static String? _currentToken;
  static int? _openedOrderId;

  static Future<void> initialize() async {
    if (_initialized || kIsWeb) {
      if (kIsWeb) debugPrint('[Push.Init] web_config_not_available');
      return;
    }
    _initialized = true;
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('[Sanitized] sensitive_details_suppressed=true');
      final token = await messaging.getToken();
      if (token != null) {
        _currentToken = token;
        await _registerCurrentToken();
      }
      messaging.onTokenRefresh.listen(_onTokenRefresh);
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onOpenedMessage);
      final initial = await messaging.getInitialMessage();
      if (initial != null) await _store(PushMessageData.fromMap(initial.data));
      debugPrint('[Push.Init] configured=true');
    } catch (error) {
      debugPrint('[Push.Init] unavailable type=${error.runtimeType}');
    }
  }

  static Future<void> _onTokenRefresh(String token) async {
    _currentToken = token;
    await _registerCurrentToken(force: true);
  }

  static Future<void> registerCurrentToken() => _registerCurrentToken();

  static Future<void> _registerCurrentToken({bool force = false}) async {
    final token = _currentToken;
    if (token == null || token.trim().isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('idUser');
      if (userId == null || userId <= 0) {
        debugPrint('[Push.Register] skipped=unauthenticated');
        return;
      }

      final sameToken = prefs.getString('pushRegisteredToken') == token;
      final sameUser = prefs.getInt('pushRegisteredUserId') == userId;
      if (!force && sameToken && sameUser) {
        debugPrint('[Push.Register] skipped=already_registered');
        return;
      }

      final platform =
          defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios';
      await ApiV1Client().post('/me/push-token', body: {
        'token': token,
        'platform': platform,
      });
      await prefs.setString('pushRegisteredToken', token);
      await prefs.setInt('pushRegisteredUserId', userId);
      debugPrint('[Push.Register] platform=' + platform + ' success=true');
    } catch (error) {
      debugPrint(
          '[Push.Register] success=false type=' + error.runtimeType.toString());
    }
  }

  static void _logToken(String token) {
    final masked = token.length <= 8
        ? 'present'
        : '${token.substring(0, 4)}...${token.substring(token.length - 4)}';
  }

  static void _onForegroundMessage(RemoteMessage message) {
    final data = PushMessageData.fromMap(message.data);
    debugPrint(
        '[Push.Message] type=${data.type ?? 'unknown'} orderId=${data.orderId ?? 'null'}');
    final context = ApiV1Session.navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                message.notification?.title ?? 'Atualizacao da sua compra')),
      );
    }
  }

  static Future<void> _onOpenedMessage(RemoteMessage message) async {
    final data = PushMessageData.fromMap(message.data);
    debugPrint(
        '[Push.Open] type=${data.type ?? 'unknown'} orderId=${data.orderId ?? 'null'}');
    await _store(data);
    await openPendingTracking();
  }

  static Future<void> _store(PushMessageData data) async {
    if (!data.canOpenTracking) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pendingOrderKey, data.orderId!);
  }

  static Future<void> openPendingTracking() async {
    final prefs = await SharedPreferences.getInstance();
    final orderId = prefs.getInt(_pendingOrderKey);
    final navigator = ApiV1Session.navigatorKey.currentState;
    if (orderId == null || navigator == null) return;
    if (_openedOrderId == orderId) {
      await prefs.remove(_pendingOrderKey);
      return;
    }
    await prefs.remove(_pendingOrderKey);
    _openedOrderId = orderId;
    debugPrint('[Push.Navigate] orderId=$orderId');
    navigator.push(MaterialPageRoute(
      builder: (_) => DeliveryTrackingPage(
        service: MarketplaceService(),
        orderId: orderId,
      ),
    ));
  }
}
