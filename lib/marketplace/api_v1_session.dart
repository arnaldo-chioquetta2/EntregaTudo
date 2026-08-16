import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../login_page.dart';

class ApiV1Session {
  ApiV1Session._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static bool _handlingUnauthorized = false;

  static Future<void> handleUnauthorized() async {
    if (_handlingUnauthorized) return;
    _handlingUnauthorized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('authToken');
      await prefs.remove('idUser');
      await prefs.remove('isFornecedor');
      await prefs.remove('isMotoboy');
      await prefs.remove('idLoja');

      final navigator = navigatorKey.currentState;
      if (navigator != null) {
        await navigator.pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const LoginPage()),
          (_) => false,
        );
      }
    } finally {
      _handlingUnauthorized = false;
    }
  }
}
