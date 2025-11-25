import 'package:shared_preferences/shared_preferences.dart';

// 1.4.3 Modo offline para MotoBoy e Fornecedor

class OnlineStatusService {
  static const String key = 'isOnline';

  static Future<bool> getStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? true; // padrão: online
  }

  static Future<void> setStatus(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }
}
