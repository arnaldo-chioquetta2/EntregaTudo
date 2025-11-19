// import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'features/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:entregatudo/constants.dart';
import 'package:entregatudo/models/delivery_details.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 1.3.7 Correção do cadastro
// 1.3.6 Log na conferência do convite
// 1.3.5 Log para o servidor ao logar e ao cadastrar
// 1.3.4 Confirmação de código na entrega
// 1.3.3 Convite na fluxo certo de crítica
// 1.3.2 Fornecedor
// 1.2.7 Ajuste no Crud da configuração de valores
// 1.2.6 Copia o erro de cadastro para a memória se houver

class API {
  static final LocationService _locationService = LocationService();

  static Future<Map<String, dynamic>> saveConfigurations(
    double minValue,
    double kmRate,
    double rainSurcharge,
    double nightSurcharge,
    double dawnSurcharge,
    double weightSurcharge,
    double customDeliverySurcharge,
  ) async {
    String baseUrl = "https://teletudo.com/api/saveConfigurations";
    print("Vai acionar https://teletudo.com/api/saveConfigurations");
    try {
      final prefs = await SharedPreferences.getInstance();
      int? userid = prefs.getInt('idUser');
      if (userid == null) {
        return {'success': false, 'message': 'Usuário não autenticado'};
      }
      print("userid = ${userid}");
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'userid': userid,
          'minValue': minValue,
          'kmRate': kmRate,
          'rainSurcharge': rainSurcharge,
          'nightSurcharge': nightSurcharge,
          'dawnSurcharge': dawnSurcharge,
          'weightSurcharge': weightSurcharge,
          'customDeliverySurcharge': customDeliverySurcharge,
          'versaoApp': AppConfig.versaoApp,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final ret = json.decode(response.body);
        if (ret['success'] == true) {
          return {
            'success': true,
            'message': 'Configurações salvas com sucesso'
          };
        } else {
          return {
            'success': false,
            'message':
                ret['message'] ?? 'Erro desconhecido ao salvar configurações'
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Falha no servidor (${response.statusCode})'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão com o servidor'};
    }
  }

// curl -k -X POST https://teletudo.com/api/obtemCfgValores -H "Content-Type: application/json" -H "Accept: application/json" -d "{\"userid\": 21, \"lat\": -23.55052, \"lon\": -46.633308}"
  static Future<Map<String, dynamic>> obtemCfgValores(
      double lat, double lon) async {
    try {
      // Obter o userid das SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      int? userid = prefs.getInt('idUser');

      print('User ID: $userid'); // Log do userid
      print('Latitude: $lat, Longitude: $lon'); // Log das coordenadas

      // Preparar a URL e os dados da requisição
      final url = 'https://teletudo.com/api/obtemCfgValores';
      print('Acionando Endpoint: $url'); // Log da URL

      final requestBody = jsonEncode({
        'userid': userid,
        'lat': lat,
        'lon': lon,
      });
      print('Request Body: $requestBody'); // Log do corpo da requisição

      // Fazer a requisição POST
      final response = await http.post(
        Uri.parse(url),
        body: requestBody,
        headers: {'Content-Type': 'application/json'},
      );

      // Log do status code e do corpo da resposta
      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      // Verificar se a requisição foi bem-sucedida
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        print(
            'Response Body Decoded: $responseBody'); // Log do corpo da resposta decodificado
        return responseBody;
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e'); // Log de qualquer erro que ocorra
      throw Exception('Failed to load data: $e');
    }
  }

  static Future<Map<String, dynamic>> registerUser(
    String nome,
    String usuario,
    String email,
    String senha,
    String telefone,
    String cnh,
    String placa,
    String pix,
    int erroCodigo,
    int distanciaMaxima,
  ) async {
    String baseUrl = "https://teletudo.com/api/cadboy";

    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'nome_completo': nome,
          'usuario': usuario,
          'email': email,
          'senha': senha,
          'telefone': telefone,
          'cnh': cnh,
          'placa': placa,
          'PIX': pix,
          'erroCodigo': erroCodigo,
          'distanciaMaxima': distanciaMaxima,
          'versaoApp': AppConfig.versaoApp,
        }),
      );

      final raw = response.body;

      if (response.statusCode != 200 && response.statusCode != 201) {
        return {
          'success': false,
          'message': 'Falha no servidor (${response.statusCode})',
          'details': raw
        };
      }

      final ret = json.decode(raw);

      // 🔹 Interpretar corretamente o retorno do servidor
      final erro = ret['Erro'];
      final descErro = ret['DescErro'] ?? '';
      final id = ret['id'];

      if (erro == 0) {
        // SUCESSO
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('idUser', id);

        return {
          'success': true,
          'message': 'Cadastro bem-sucedido',
          'details': raw
        };
      } else {
        // FALHA RETORNADA PELO SERVIDOR
        return {
          'success': false,
          'message':
              descErro.isEmpty ? 'Erro desconhecido ao cadastrar' : descErro,
          'details': raw
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão com o servidor',
        'details': e.toString()
      };
    }
  }

  static Future<DeliveryDetails?> sendHeartbeat(double lat, double lon) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? userid = prefs.getInt('idUser');
    int vez = prefs.getInt('vez') ?? 0;
    await prefs.setInt('vez', vez + 1);

    if (userid == null) {
      print("User ID não encontrado");
      return null;
    }

    final String baseUrl = "https://teletudo.com/api/heartbeat";

    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: json.encode({
        'userid': userid,
        'lat': lat,
        'lon': lon,
        'vez': vez,
      }),
    );

    print(
        'Enviando heartbeat: lat: $lat, lon: $lon, userid: $userid, vez: $vez');

    if (response.statusCode != 200) {
      print('Erro ao enviar heartbeat: ${response.statusCode}');
      return null;
    }

    /// ------------------------------
    /// PROCESSAR RESPOSTA
    /// ------------------------------
    print('Response Body: ${response.body}');
    final data = json.decode(response.body);

    /// salvar 'modo'
    int modo = data['modo'] ?? 3;
    await prefs.setInt('modo', modo);

    /// salvar lojas no raio
    int lojasNoRaio = data['lojas_no_raio'] ?? 0;
    print('Lojas no Raio: $lojasNoRaio');

    /// ------------------------------
    ///  🎯 PEGAR CÓDIGO DE CONFIRMAÇÃO DA ENTREGA
    /// ------------------------------
    if (data['novaVenda'] != null) {
      var nova = data['novaVenda'];

      if (nova['codigoConfirmacao'] != null) {
        int codigo = nova['codigoConfirmacao'];

        /// SALVAR NO SHARED PREFERENCES
        await prefs.setInt('codigoConfirmacao', codigo);

        print("🔥 Código de confirmação recebido e salvo: $codigo");
      } else {
        print("⚠️ novaVenda existe, mas não contém codigoConfirmacao");
      }
    } else {
      print("Nenhuma novaVenda na resposta.");
    }

    /// retorna o modelo original
    return DeliveryDetails.fromJson(data);
  }

  static Future<FornecedorHeartbeatResponse?> sendHeartbeatF(
      double lat, double lon) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? userid = prefs.getInt('idUser');
    int? idLoja = prefs.getInt('idLoja');
    int vez = prefs.getInt('vez') ?? 0;
    await prefs.setInt('vez', vez + 1);

    if (userid != null) {
      const String baseUrl = "https://teletudo.com/api/heartbeatF";
      print('Enviando pedido para o servidor:');
      print('URL: $baseUrl');
      print(
          'Dados enviados: { "userid": $userid, "idLoja": $idLoja, "lat": $lat, "lon": $lon }');

      try {
        final response = await http.post(
          Uri.parse(baseUrl),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: json.encode({
            'userid': userid,
            'idLoja': idLoja ?? 0,
            'lat': lat,
            'lon': lon,
          }),
        );

        print('Resposta do servidor: ${response.statusCode}');
        print('Response Body: ${response.body}');

        if (response.statusCode == 200) {
          var data = json.decode(response.body);
          print('Dados recebidos do servidor: $data');

          if (data['success'] == true) {
            // Cria o objeto principal
            final responseObj = FornecedorHeartbeatResponse.fromJson(data);

            print('Nova venda: ${responseObj.novaVenda != null}');
            print('Itens da venda: ${responseObj.itensVenda.length}');
            for (var item in responseObj.itensVenda) {
              print(' - ${item.produto} x${item.quantidade}');
            }

            return responseObj;
          } else {
            print('Erro no retorno: ${data['DescErro']}');
          }
        } else {
          print('Erro ao enviar heartbeatF: ${response.statusCode}');
        }
      } catch (e) {
        print('Exceção ao enviar heartbeatF: $e');
      }
    } else {
      print('User ID não encontrado');
    }

    return null;
  }

  // curl -X POST https://teletudo.com/api/login -H "Content-Type: application/json" -H "Accept: application/json" -d "{\"user\": \"teste\", \"password\": \"teste\", \"lat\": -23.55052, \"lon\": -46.633308}" -k
  static Future<String> veLogin(
      String user, String password, double lat, double lon) async {
    const String baseUrl = "https://teletudo.com/api/login";

    print("==============================================");
    print("[API.veLogin] INICIANDO LOGIN");
    print("[API.veLogin] user=$user  password=***  lat=$lat lon=$lon");

    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'user': user,
          'password': password,
          'lat': lat,
          'lon': lon,
        }),
      );

      print("[API.veLogin] HTTP STATUS: ${response.statusCode}");
      print("[API.veLogin] RAW: ${response.body}");

      if (response.statusCode != 200) {
        print("[API.veLogin] ❌ ERRO_1: Status diferente de 200");
        return "ERRO_1";
      }

      // Tenta parsear
      Map<String, dynamic> ret;
      try {
        ret = json.decode(response.body);
      } catch (e) {
        print("[API.veLogin] ❌ ERRO_2: Falha ao decodificar JSON: $e");
        return "ERRO_2";
      }

      print("[API.veLogin] JSON decodificado: $ret");

      final int erro = ret["Erro"] ?? 1;
      print("[API.veLogin] campo Erro = $erro");

      if (erro != 0) {
        print("[API.veLogin] ❌ ERRO_3: Servidor retornou erro.");
        return "ERRO_3";
      }

      // SUCESSO
      final int idUser = ret["id"] ?? 0;
      final prefs = await SharedPreferences.getInstance();

      await prefs.setInt('idUser', idUser);

      final String nomeUser = (ret["nome"] ?? "").toString();
      await prefs.setString('nomeUser', nomeUser);

      int idLoja = 0;

      print("[API.veLogin] eh_fornecedor = ${ret['eh_fornecedor']}");
      print("[API.veLogin] id_loja = ${ret['id_loja']}");

      if (ret["eh_fornecedor"] == true) {
        idLoja = ret["id_loja"] ?? 0;
        await prefs.setBool('isFornecedor', true);
        print("[API.veLogin] Usuário é fornecedor. idLoja = $idLoja");
      }

      await prefs.setInt('idLoja', idLoja);

      print("[API.veLogin] ✅ LOGIN OK");
      print("==============================================");
      return "";
    } catch (e, st) {
      print("[API.veLogin] ❌ ERRO_4 EXCEPTION: $e");
      print("[API.veLogin] STACKTRACE: $st");
      return "ERRO_4";
    }
  }

  static Future<Position> getCurrentLocation() async {
    await _locationService.requestPermissions();
    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  static Future<bool> sacar(int userId) async {
    var url = Uri.parse('https://teletudo.com/api/sacar');
    print("Acionando API de saque");
    var headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    var body = json.encode({
      'userid': userId.toString(),
    });
    bool ret = false;
    try {
      var response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        print("Resposta da API: ${response.body}");
        ret = true;
      } else {
        print("Erro ao sacar: ${response.statusCode}");
      }
    } catch (e) {
      print("Erro ao enviar requisição: $e");
    }
    return ret;
    // return true;
  }

  static Future<bool> respondToDelivery(
      int userId, int deliveryId, bool accept) async {
    try {
      var url = Uri.parse("https://teletudo.com/api/respondToDelivery");
      var payload = json.encode({
        'userId': userId,
        'deliveryId': deliveryId,
        'accept': accept,
      });
      var response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: payload,
      );
      print("response.statusCode = ${response.statusCode}");
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        print("Envio de respondToDelivery com sucesso");
        return true;
      } else {
        print(
            "Falha ao enviar resposta: ${response.statusCode}, ${response.body.length > 300 ? response.body.substring(0, 300) : response.body}");
        return false;
      }
    } catch (e) {
      print("Erro ao enviar resposta de entrega: $e");
      return false;
    }
    // return true;
  }

  static Future<void> reportViewToServer(int? userid, int? chamado) async {
    try {
      await http.post(
        Uri.parse('https://teletudo.com/api/mtoviu'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'chamadoId': chamado,
          'motoboyId': userid,
        }),
      );
      print("Visualização reportada ao servidor com sucesso.");
    } catch (e) {
      print("Erro ao reportar visualização: $e");
    }
  }

  static Future<bool> notifyPickedUp() async {
    try {
      String baseUrl = "https://teletudo.com/api/notifyPickedUp";
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      int? currentChamado = prefs.getInt('currentChamado');
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'chamado': currentChamado}),
      );
      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
    // return true;
  }

  static Future<bool> notifyDeliveryCompleted() async {
    print("API.notifyDeliveryCompleted() chamado");

    try {
      const String baseUrl = "https://teletudo.com/api/notifyDeliveryCompleted";

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      int? currentChamado = prefs.getInt('currentChamado');

      if (currentChamado == null) {
        print("❌ ERRO: currentChamado não encontrado no SharedPreferences.");
        return false;
      }

      print("📦 Enviando encerramento do chamado $currentChamado");

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'chamado': currentChamado}),
      );

      print("Status HTTP = ${response.statusCode}");

      if (response.statusCode == 200) {
        print("✅ Sucesso ao notificar o servidor: ${response.body}");
        return true;
      } else {
        print("❌ Falha ao notificar servidor: ${response.body}");
        return false;
      }
    } catch (e) {
      print("❌ Erro na chamada API.notifyDeliveryCompleted: $e");
      return false;
    }
  }

  static Future<String> saldo(int userId) async {
    print("Ver o saldo do usuário " + userId.toString());
    var response = await http.post(
      Uri.parse('https://teletudo.com/api/saldo'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      // body: json.encode({'userid': 21}),
      body: json.encode({'userid': userId}),
    );
    if (response.statusCode == 200) {
      // print("response.body =");
      // print(response.body);
      var data = json.decode(response.body);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (data['Erro'] == 0) {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setInt('Pendente', data['Pendente'] as int);
        await prefs.setString('DtaPedResg', data['DtaPedResg']);
        return data['Saldo'].toString();
      } else {
        throw Exception('Erro ao buscar saldo: ' + data['DescErro']);
      }
    } else {
      throw Exception(
          'Falha ao carregar o saldo. Status: ${response.statusCode}');
    }
    // return "";
  }

  /// GET /api/login/status?ID=<id>  → status do processamento (polling)
  static Future<Map<String, dynamic>> googleLoginStatus({
    required int userIdForQuery,
  }) async {
    final url = Uri.parse('https://teletudo.com/api/login/status')
        .replace(queryParameters: {'ID': userIdForQuery.toString()});

    try {
      final resp = await http.get(url, headers: {'Accept': 'application/json'});
      if (resp.statusCode == 200) {
        return json.decode(resp.body) as Map<String, dynamic>;
      } else {
        return {
          'done': true,
          'success': false,
          'message': 'HTTP ${resp.statusCode}: ${resp.body}',
        };
      }
    } catch (e) {
      return {'done': true, 'success': false, 'message': 'Erro de rede: $e'};
    }
  }

  static Future<int?> nextUserId() async {
    final url = Uri.parse('https://teletudo.com/api/next-user-id');
    try {
      final response =
          await http.get(url, headers: {'Accept': 'application/json'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['nextId'] != null) {
          if (data['nextId'] is int) return data['nextId'] as int;
          return int.tryParse(data['nextId'].toString());
        }
      }
      return null;
    } catch (e) {
      // Log opcional
      return null;
    }
  }

  /// POST /login/google/callback?ID=<id>
  /// Envia idToken OU accessToken (envia o que existir)
  static Future<Map<String, dynamic>> googleLoginInit({
    String? idToken,
    String? accessToken,
    required int userIdForQuery,
  }) async {
    final url = Uri.parse('https://teletudo.com/login/google/callback')
        .replace(queryParameters: {'ID': userIdForQuery.toString()});

    final Map<String, dynamic> body = {};
    if (idToken != null && idToken.isNotEmpty) {
      body['idToken'] = idToken;
    } else if (accessToken != null && accessToken.isNotEmpty) {
      body['accessToken'] = accessToken;
    }

    if (body.isEmpty) {
      return {
        'success': false,
        'message': 'Nenhuma credencial (idToken/accessToken) para enviar.'
      };
    }

    try {
      final resp = await http.post(
        url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      if (resp.statusCode == 200) {
        return json.decode(resp.body) as Map<String, dynamic>;
      } else {
        return {
          'success': false,
          'message': 'HTTP ${resp.statusCode}: ${resp.body}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de rede ao chamar callback: $e'
      };
    }
  }

  static Future<Map<String, dynamic>> verifyInviteCode(String code) async {
    print('[API.verifyInviteCode] $code');
    String conviteDigitado = code.toUpperCase();
    await logApp("API", "conviteDigitado = $conviteDigitado");
    final response = await http.get(
      Uri.parse('https://teletudo.com/api/verify-invite-code')
          .replace(queryParameters: {'code': conviteDigitado}),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      await logApp("API",
          "Erro ao verificar convite statusCode = $response.statusCode ");
      throw Exception('Erro ao verificar convite');
    }
  }

  static Future<Map<String, dynamic>> generateInviteCode() async {
    final url =
        Uri.parse('https://teletudo.com/api/generate-random-invite-code');
    print('[API.generateInviteCode] GET $url');
    final response = await http.get(url);
    print(
        '[API.generateInviteCode] HTTP ${response.statusCode} body=${response.body}');
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> checkInviteAvailability(
      String code, int userId) async {
    final url = Uri.parse(
        'https://teletudo.com/api/check-invite-code?code=$code&user_id=$userId');
    print('[API.checkInviteAvailability] GET $url');
    final response = await http.get(url);
    print(
        '[API.checkInviteAvailability] HTTP ${response.statusCode} body=${response.body}');
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> setInvite(String code, int userId) async {
    final url = Uri.parse('https://teletudo.com/api/set-invite');
    final body = json.encode({'code': code, 'user_id': userId});
    print('[API.setInvite] POST $url body=$body');
    final response = await http.post(url,
        headers: {'Content-Type': 'application/json'}, body: body);
    print('[API.setInvite] HTTP ${response.statusCode} body=${response.body}');
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> enableInviteEdit(int userId) async {
    final url = Uri.parse('https://teletudo.com/api/enable-invite-edit');
    final body = json.encode({'user_id': userId});
    final response = await http.post(url,
        headers: {'Content-Type': 'application/json'}, body: body);
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> setInviteCode(
      int userId, String code) async {
    final response = await http.post(
      Uri.parse('https://teletudo.com/api/set-invite'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'code': code,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return {
        'success': false,
        'message': 'Erro ao definir código de convite (${response.statusCode})'
      };
    }
  }

  static Future<Map<String, dynamic>> generateRandomInviteCode() async {
    final response = await http.get(
      Uri.parse('https://teletudo.com/api/generate-random-invite-code'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return {
        'success': false,
        'message': 'Erro ao gerar novo código (${response.statusCode})'
      };
    }
  }

  static Future<String?> getUserInviteCode(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('https://teletudo.com/api/verify-invite-code')
            .replace(queryParameters: {'user_id': userId.toString()}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['inviter_name'] == null) {
          return data['code'] ?? '';
        }
      }
    } catch (e) {
      print('Erro ao buscar código de convite do usuário: $e');
    }
    return null;
  }

  static Future<void> logApp(String metodo, String mensagem,
      [Map<String, dynamic>? dados]) async {
    const String baseUrl = "https://teletudo.com/api/logapp";
    metodo = "App: $metodo";
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'metodo': metodo,
          'mensagem': mensagem,
          'dados': dados ?? {},
        }),
      );

      if (response.statusCode != 200) {
        print(
            "⚠️ Falha ao enviar log (${response.statusCode}): ${response.body}");
      }
    } catch (e) {
      print("❌ Erro ao tentar enviar log: $e");
    }
  }
}

class FornecedorHeartbeatResponse {
  final int lojasNoRaio;
  final int idLoja;
  final int modo;
  final NovaVenda? novaVenda;
  final double processingTime;
  final List<ItemVenda> itensVenda;

  FornecedorHeartbeatResponse({
    required this.lojasNoRaio,
    required this.idLoja,
    required this.modo,
    required this.processingTime,
    required this.itensVenda,
    this.novaVenda,
  });

  factory FornecedorHeartbeatResponse.fromJson(Map<String, dynamic> json) {
    return FornecedorHeartbeatResponse(
      lojasNoRaio: json['lojas_no_raio'] ?? 0,
      idLoja: json['id_loja'] ?? 0,
      modo: json['modo'] ?? 3,
      processingTime: (json['processing_time_ms'] ?? 0).toDouble(),
      novaVenda: json['nova_venda'] != null
          ? NovaVenda.fromJson(json['nova_venda'])
          : null,
      itensVenda: json['itens_venda'] != null
          ? (json['itens_venda'] as List)
              .map((item) => ItemVenda.fromJson(item))
              .toList()
          : [],
    );
  }
}

class ItemVenda {
  final String produto;
  final int quantidade;

  ItemVenda({
    required this.produto,
    required this.quantidade,
  });

  factory ItemVenda.fromJson(Map<String, dynamic> json) {
    return ItemVenda(
      produto: json['produto'] ?? '',
      quantidade: json['quantidade'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'produto': produto,
        'quantidade': quantidade,
      };
}

class NovaVenda {
  final String hora;
  final String valor;
  final String cliente;
  final int idPed;
  final int idAviso;

  NovaVenda({
    required this.hora,
    required this.valor,
    required this.cliente,
    required this.idPed,
    required this.idAviso,
  });

  factory NovaVenda.fromJson(Map<String, dynamic> json) {
    return NovaVenda(
      hora: json['hora'],
      valor: json['valor'],
      cliente: json['cliente'],
      idPed: json['idPed'],
      idAviso: json['idAviso'],
    );
  }
}
