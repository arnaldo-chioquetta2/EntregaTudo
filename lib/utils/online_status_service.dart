import 'package:shared_preferences/shared_preferences.dart';

// 1.4.4 MotoBoy e Fornecedor ao mesmo tempo
// 1.4.3 Modo offline para MotoBoy e Fornecedor

class OnlineStatusService {
  // ----------- CHAVES NOS PREFERENCES -----------
  static const String keyMoto = 'motoboyOnline';
  static const String keyFornecedor = 'fornecedorOnline';

  // ===============================================
  //               MOTOBOY
  // ===============================================
  static Future<bool> getMotoStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyMoto) ?? true; // padrão: online
  }

  static Future<void> setMotoStatus(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyMoto, value);
  }

  // ===============================================
  //               FORNECEDOR
  // ===============================================
  static Future<bool> getFornecedorStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyFornecedor) ?? true; // padrão: online
  }

  static Future<void> setFornecedorStatus(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyFornecedor, value);
  }
}
