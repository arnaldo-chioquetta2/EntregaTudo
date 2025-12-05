import 'api_platform_stub.dart' if (dart.library.io) 'api_platform_io.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'features/location_service.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:entregatudo/constants.dart';
import 'package:entregatudo/models/delivery_details.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 1.4.4 MotoBoy e Fornecedor ao mesmo tempo
// 1.4.3 Modo offline para MotoBoy e Fornecedor
// 1.4.1 Recusa por versão antiga
// 1.4.0 Correção estavam sendo mostradas vendas falsas
// 1.3.9 Fornecedor recebe aviso pelo App sobre a venda
// 1.3.7 Correção do cadastro
// 1.3.6 Log na conferência do convite
// 1.3.5 Log para o servidor ao logar e ao cadastrar
// 1.3.4 Confirmação de código na entrega
// 1.3.3 Convite na fluxo certo de crítica
// 1.3.2 Fornecedor

class API {
  static final LocationService _locationService = LocationService();

  static Future<http.Response> _realizarRequisicaoLogin(
      String user, String password, double lat, double lon) {
    final sistema = PlataformaInfo.sistema;
    final versaoSO = PlataformaInfo.versao;

    return http.post(
      Uri.parse("https://teletudo.com/api/login"),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: json.encode({
        'user': user,
        'password': password,
        'lat': lat,
        'lon': lon,
        'versaoApp': AppConfig.versaoAppInt,
        'sistema': sistema,
        'versaoSO': versaoSO,
      }),
    );
  }

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
    print("=== [API.registerUser] INICIO ===");
    print("Enviando dados para /cadboy...");
    print("Payload:");
    print({
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
    });

    final url = Uri.parse("https://teletudo.com/api/cadboy");

    try {
      final response = await http.post(
        url,
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
        }),
      );

      print("=== [API.registerUser] RESPOSTA ===");
      print("Status code: ${response.statusCode}");
      print("Body cru: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final ret = json.decode(response.body);
        print("Decodificado: $ret");

        return ret;
      }

      // Se for erro, retornar com o que vier
      try {
        final err = json.decode(response.body);
        print("Erro decodificado: $err");
        return err;
      } catch (_) {
        print("Erro não é JSON. Retornando padrão.");
        return {
          'success': false,
          'message': "Falha no servidor (${response.statusCode})",
          'raw': response.body
        };
      }
    } catch (e) {
      print("EXCEPTION em registerUser: $e");
      return {
        'success': false,
        'message': 'Erro de conexão',
        'erro': e.toString()
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

    // ==========================================================
    //  🎯 AJUSTE CRÍTICO: SALVAR CÓDIGO DE CONFIRMAÇÃO
    //  Origens possíveis:
    //   1) novaVenda.codigoConfirmacao
    //   2) codigoConfirmacao na RAIZ do JSON
    //
    //  → Somente limpar se ambos forem inexistentes ou 0
    // ==========================================================

    bool codigoSalvo = false;

    // 1) novaVenda -> codigoConfirmacao
    if (data['novaVenda'] != null) {
      var nova = data['novaVenda'];

      if (nova['codigoConfirmacao'] != null) {
        int codigo = nova['codigoConfirmacao'];

        if (codigo > 0) {
          await prefs.setInt('codigoConfirmacao', codigo);
          print("🔥 Código via novaVenda: $codigo");
          codigoSalvo = true;
        }
      }
    }

    // 2) codigoConfirmacao na raiz
    if (!codigoSalvo &&
        data['codigoConfirmacao'] != null &&
        data['codigoConfirmacao'] > 0) {
      int codigo = data['codigoConfirmacao'];
      await prefs.setInt('codigoConfirmacao', codigo);
      print("🔥 Código via raiz: $codigo");
      codigoSalvo = true;
    }

    // 3) Nenhum código válido → NÃO apagar código anterior
    if (!codigoSalvo) {
      print("ℹ Nenhum código novo recebido. Mantendo código existente.");
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
    print("==============================================");
    print("[API.veLogin] INICIANDO LOGIN");
    print("[API.veLogin] user=$user  password=***  lat=$lat lon=$lon");

    try {
      final response = await _realizarRequisicaoLogin(user, password, lat, lon);

      print("[API.veLogin] HTTP STATUS: ${response.statusCode}");
      print("[API.veLogin] RAW: ${response.body}");

      // ------------------------------------------------------
      // 🔥 Tentar decodificar JSON SEMPRE — mesmo em erro 403
      // ------------------------------------------------------
      Map<String, dynamic>? ret;

      try {
        ret = json.decode(response.body) as Map<String, dynamic>;
      } catch (_) {
        await _registrarErro("ERRO_2 - JSON inválido no login", {
          "statusCode": response.statusCode,
          "body": response.body,
          "user": user,
        });

        return "ERRO_2";
      }

      // 🔥 Agora ret nunca mais é nulo → podemos usar !
      final int erro = ret!["Erro"] ?? 1;
      print("[API.veLogin] campo Erro = $erro");

      // ------------------------------------------------------
      // 🔥 1) Bloqueio de versão antiga (Erro = 5)
      // ------------------------------------------------------
      if (erro == 5) {
        final int versaoAtualInt = ret["versaoAtual"] ?? 0;
        final int versaoMinInt = ret["versaoMin"] ?? 0;

        final versaoAtual = formatarVersaoInt(versaoAtualInt);
        final versaoMin = formatarVersaoInt(versaoMinInt);

        final msg =
            "Esta versão ($versaoAtual) não é mais suportada. Mínima: $versaoMin";

        print("[API.veLogin] ❌ BLOQUEADO POR VERSÃO ANTIGA: $msg");

        return "VERSAO_ANTIGA|$msg";
      }

      // ------------------------------------------------------
      // 🔥 2) Qualquer outro erro HTTP ≠ 200
      // ------------------------------------------------------
      if (response.statusCode != 200) {
        await _registrarErro("ERRO_1 - Status != 200", {
          "statusCode": response.statusCode,
          "body": response.body,
          "json": ret,
          "user": user,
        });
        return "ERRO_1";
      }

      // ------------------------------------------------------
      // 🔥 3) Erros normais
      // ------------------------------------------------------
      if (erro != 0) {
        await _registrarErro("ERRO_3 - backend retornou erro", {
          "erro": erro,
          "json": ret,
          "user": user,
        });
        return "ERRO_3";
      }

      // ------------------------------------------------------
      // ✔ LOGIN OK
      // ------------------------------------------------------
      await _salvarDadosLogin(ret);

      print("[API.veLogin] ✅ LOGIN OK");
      print("==============================================");

      return "";
    } catch (e, st) {
      print("[API.veLogin] ❌ ERRO_4 EXCEPTION: $e");
      print("[API.veLogin] STACKTRACE: $st");

      await _registrarErro("ERRO_4 - Exception geral", {
        "exception": e.toString(),
        "stack": st.toString(),
        "user": user,
      });

      return "ERRO_4";
    }
  }

  static String formatarVersaoInt(int v) {
    final major = v ~/ 100; // 140 → 1
    final minor = (v % 100) ~/ 10; // 140 % 100 = 40 → 4
    final patch = v % 10; // 0
    return "$major.$minor.$patch";
  }

  static Future<Map<String, dynamic>?> _parseJson(
      String responseBody, String user) async {
    try {
      final ret = json.decode(responseBody);
      print("[API.veLogin] JSON decodificado: $ret");
      return ret;
    } catch (e) {
      print("[API.veLogin] ❌ ERRO_2: Falha ao decodificar JSON: $e");

      await _registrarErro(
        "ERRO_2 - Falha ao parsear JSON",
        {
          "exception": e.toString(),
          "rawResponse": responseBody,
          "user": user,
        },
      );
      return null;
    }
  }

  static Future<void> _salvarDadosLogin(Map<String, dynamic> ret) async {
    final prefs = await SharedPreferences.getInstance();

    // ------------------------------------------------------
    // 🔹 Dados básicos do usuário
    // ------------------------------------------------------
    final int idUser = ret["id"] ?? 0;
    await prefs.setInt('idUser', idUser);

    final String nomeUser = (ret["nome"] ?? "").toString();
    await prefs.setString('nomeUser', nomeUser);

    print("[API.veLogin] SALVANDO PERFIS recebidos do backend:");

    // ------------------------------------------------------
    // 🔹 PERFIL FORNECEDOR
    // ------------------------------------------------------
    final bool ehFornecedor = ret["eh_fornecedor"] == true;
    await prefs.setBool('isFornecedor', ehFornecedor);
    print("eh_fornecedor = $ehFornecedor");

    int idLoja = 0;
    if (ehFornecedor) {
      idLoja = ret["id_loja"] ?? 0;
      await prefs.setInt('idLoja', idLoja);
      print("idLoja = $idLoja");
    } else {
      await prefs.remove('idLoja');
    }

    // ------------------------------------------------------
    // 🔹 PERFIL MOTOBOY (valor agora vem do servidor)
    // ------------------------------------------------------
    bool ehMotoboy = false;

    if (ret.containsKey("eh_motoboy")) {
      final v = ret["eh_motoboy"];

      if (v is bool) {
        ehMotoboy = v;
      } else if (v is int) {
        ehMotoboy = (v == 1);
      } else if (v is String) {
        ehMotoboy = (v == "1" || v.toLowerCase() == "true");
      }
    }

    await prefs.setBool('isMotoboy', ehMotoboy);
    print("eh_motoboy = $ehMotoboy");

    // ------------------------------------------------------
    // 🔹 Log final
    // ------------------------------------------------------
    print("[API.veLogin] OK → "
        "isMotoboy=$ehMotoboy | "
        "isFornecedor=$ehFornecedor | "
        "idLoja=$idLoja");
  }

  static Future<void> _registrarErro(String msg, Map<String, dynamic> info) {
    return logApp("veLogin", msg, info);
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
      // ignore: unused_local_variable
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
    } catch (e) {
      print("❌ Erro na função logApp: $e");
    }
  }

  static Future<bool> fornecedorConfirmou(int idAviso, int idPed) async {
    final String url = "https://teletudo.com/api/fornecedor/confirmou";
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'id': idAviso,
          'idPed': idPed,
        }),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['Erro'] == 0;
      } else {
        print("⚠️ Erro HTTP: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("❌ Erro fornecedorConfirmou(): $e");
      return false;
    }
  }

  static Future<bool> motoOff(int userId) async {
    try {
      final url = Uri.parse("https://teletudo.com/moto/off");

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({"userid": userId}),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> fornecedorOff({int? idLoja, int? idPessoa}) async {
    try {
      final url = Uri.parse("https://teletudo.com/fornecedor/off");

      final body = <String, dynamic>{};

      if (idLoja != null) body["idLoja"] = idLoja;
      if (idPessoa != null) body["idPessoa"] = idPessoa;

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(body),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
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
