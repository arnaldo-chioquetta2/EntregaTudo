import '../models/entrega_ativa.dart';
import '../api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EntregaService {
  static Future<EntregaAtiva?> carregarEntregaAtiva() async {
    final prefs = await SharedPreferences.getInstance();
    final idUser = prefs.getInt('idUser');

    if (idUser == null) return null;

    return await API.getEntregaAtiva(idUser);
  }
}
