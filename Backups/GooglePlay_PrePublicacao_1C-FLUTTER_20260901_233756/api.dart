import 'api_platform_stub.dart' if (dart.library.io) 'api_platform_io.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'features/location_service.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:entregatudo/constants.dart';
import 'package:entregatudo/models/entrega_ativa.dart';
import 'package:entregatudo/models/delivery_details.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/web_debug_log_service.dart';

class ApiRequestException implements Exception {
  const ApiRequestException(this.message);

  final String message;

  @override
  String toString() => message;
}

// 1.4.8 Ajustes nas Apis
// 1.4.7 Fornecedor por horários
// 1.4.6 Correção do convite que estava aparecendo um errado no painel do captador

class API {
  static final LocationService _locationService = LocationService();
  static double? ultimoValorEntrega;

  static void _loginDebug(String message) {
    WebDebugLogService.instance.add(message);
    print('[API.veLogin] $message');
  }

  static Future<http.Response> _realizarRequisicaoLogin(
      String user, String password, double lat, double lon) {
    final sistema = PlataformaInfo.sistema;
    final versaoSO = PlataformaInfo.versao;
    debugPrint('[Version] package=' +
        AppConfig.versaoApp +
        ' build=' +
        AppConfig.versaoAppInt.toString() +
        ' apiVersion=' +
        AppConfig.versaoAppInt.toString());

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

  static Future<Map<String, dynamic>> forgotPassword(String user) async {
    try {
      final response = await http.post(
        Uri.parse("https://teletudo.com/api/password/forgot"),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'user': user,
          'versaoApp': AppConfig.versaoAppInt,
          'sistema': PlataformaInfo.sistema,
          'versaoSO': PlataformaInfo.versao,
        }),
      );

      debugPrint('[Sanitized] sensitive_details_suppressed=true');

      if (response.statusCode != 200) {
        return {
          'Erro': 1,
          'msg': 'Não foi possível processar a solicitação. Tente novamente.',
        };
      }

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      return {
        'Erro': 1,
        'msg': 'Não foi possível processar a solicitação. Tente novamente.',
      };
    } catch (_) {
      debugPrint('[Sanitized] sensitive_details_suppressed=true');
      return {
        'Erro': 1,
        'msg': 'Não foi possível processar a solicitação. Tente novamente.',
      };
    }
  }

  static Future<Map<String, dynamic>> resetPassword({
    required String user,
    required String code,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("https://teletudo.com/api/password/reset"),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'user': user,
          'code': code,
          'new_password': newPassword,
          'versaoApp': AppConfig.versaoAppInt,
          'sistema': PlataformaInfo.sistema,
          'versaoSO': PlataformaInfo.versao,
        }),
      );

      debugPrint('[Sanitized] sensitive_details_suppressed=true');

      if (response.statusCode != 200) {
        return {
          'Erro': 1,
          'msg': 'Não foi possível processar a solicitação. Tente novamente.',
        };
      }

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      return {
        'Erro': 1,
        'msg': 'Não foi possível processar a solicitação. Tente novamente.',
      };
    } catch (_) {
      debugPrint('[Sanitized] sensitive_details_suppressed=true');
      return {
        'Erro': 1,
        'msg': 'Não foi possível processar a solicitação. Tente novamente.',
      };
    }
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
      debugPrint('[Sanitized] sensitive_details_suppressed=true');
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
      final url = "https://teletudo.com/api/obtemCfgValores";
      final requestBody =
          jsonEncode({'userid': userid, 'lat': lat, 'lon': lon});

      debugPrint('[Sanitized] sensitive_details_suppressed=true');
      print('Request Body: $requestBody'); // Log do corpo da requisição

      // Fazer a requisição POST
      final response = await http.post(
        Uri.parse(url),
        body: requestBody,
        headers: {'Content-Type': 'application/json'},
      );

      // Log do status code e do corpo da resposta
      print('Response Status Code: ${response.statusCode}');
      debugPrint('[Sanitized] sensitive_details_suppressed=true');

      // Verificar se a requisição foi bem-sucedida
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        return responseBody is Map<String, dynamic>
            ? responseBody
            : <String, dynamic>{'success': false};
      }
      return <String, dynamic>{
        'success': false,
        'message': 'Falha no servidor'
      };
    } catch (e) {
      return <String, dynamic>{'success': false, 'message': 'Erro de conexao'};
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
    debugPrint('[Sanitized] sensitive_details_suppressed=true');
    debugPrint('[Sanitized] sensitive_details_suppressed=true');

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
      debugPrint('[Sanitized] sensitive_details_suppressed=true');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final ret = json.decode(response.body);
        print("Decodificado: $ret");

        return ret;
      }

      // Se for erro, retornar com o que vier
      try {
        final err = json.decode(response.body);
        debugPrint('[Sanitized] sensitive_details_suppressed=true');
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
      debugPrint('[Sanitized] sensitive_details_suppressed=true');
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
    final token = prefs.getString('authToken');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await http.post(
      Uri.parse(baseUrl),
      headers: headers,
      body: json.encode({
        'userid': userid,
        'lat': lat,
        'lon': lon,
        'vez': vez,
      }),
    );

    debugPrint('[Sanitized] sensitive_details_suppressed=true');

    if (response.statusCode != 200) {
      print('Erro ao enviar heartbeat: ${response.statusCode}');
      return null;
    }

    /// ------------------------------
    /// PROCESSAR RESPOSTA
    /// ------------------------------
    debugPrint('[Sanitized] sensitive_details_suppressed=true');
    final data = json.decode(response.body);

    debugPrint('[Sanitized] sensitive_details_suppressed=true');
    print("Contém lojas_no_raio? ${data.containsKey('lojas_no_raio')}");

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

    int? parseCodigoConfirmacao(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '');
    }

    // 1) novaVenda -> codigoConfirmacao
    if (data['novaVenda'] != null) {
      var nova = data['novaVenda'];

      final rawCodigo = nova['codigoConfirmacao'] ??
          nova['codigo_confirmacao'] ??
          nova['codigo_confirmacao_cliente'];
      final codigo = parseCodigoConfirmacao(rawCodigo);

      if (codigo != null) {
        if (codigo > 0) {
          await prefs.setInt('codigoConfirmacao', codigo);
          print("🔥 Código via novaVenda: $codigo");
          codigoSalvo = true;
        }
      }
    }

    // 2) codigoConfirmacao na raiz
    if (!codigoSalvo) {
      final rawCodigo = data['codigoConfirmacao'] ??
          data['codigo_confirmacao'] ??
          data['codigo_confirmacao_cliente'];
      final codigo = parseCodigoConfirmacao(rawCodigo);

      if (codigo != null && codigo > 0) {
        await prefs.setInt('codigoConfirmacao', codigo);
        print("🔥 Código via raiz: $codigo");
        codigoSalvo = true;
      }
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
      debugPrint('[Sanitized] sensitive_details_suppressed=true');

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
        debugPrint('[Sanitized] sensitive_details_suppressed=true');

        if (response.statusCode == 200) {
          var data = json.decode(response.body);
          debugPrint('[Sanitized] sensitive_details_suppressed=true');

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
        debugPrint('[Sanitized] sensitive_details_suppressed=true');
      }
    } else {
      print('User ID não encontrado');
    }

    return null;
  }

  // Login endpoint: https://teletudo.com/api/login

  static Future<String> veLogin(
      String user, String password, double lat, double lon) async {
    _loginDebug('INICIANDO LOGIN');
    if (kIsWeb) {
      _loginDebug('origin=${Uri.base.origin}');
    }
    print("==============================================");
    print("[API.veLogin] INICIANDO LOGIN");
    debugPrint('[Sanitized] sensitive_details_suppressed=true');

    try {
      _loginDebug('requisicao_iniciada');
      final response = await _realizarRequisicaoLogin(user, password, lat, lon);

      _loginDebug(
          'resposta_recebida status=${response.statusCode} bytes=${response.body.length}');
      print("[API.veLogin] HTTP STATUS: ${response.statusCode}");
      debugPrint('[Sanitized] sensitive_details_suppressed=true');

      // ------------------------------------------------------
      // 🔥 Tentar decodificar JSON SEMPRE — mesmo em erro 403
      // ------------------------------------------------------
      Map<String, dynamic>? ret;

      try {
        ret = json.decode(response.body) as Map<String, dynamic>;
        _loginDebug(
            'json_decodificado Erro=${ret['Erro'].runtimeType} id=${ret['id'].runtimeType} token=${ret['token'].runtimeType}');
      } catch (_) {
        _loginDebug('ERRO_2 resposta_nao_json');
        await _registrarErro("ERRO_2 - JSON inválido no login", {
          "statusCode": response.statusCode,
        });

        return "ERRO_2";
      }

      // 🔥 Agora ret nunca mais é nulo → podemos usar !
      final int erro = _asInt(ret!["Erro"]) ?? 1;
      debugPrint('[Sanitized] sensitive_details_suppressed=true');

      // ------------------------------------------------------
      // 🔥 1) Bloqueio de versão antiga (Erro = 5)
      // ------------------------------------------------------
      if (erro == 5) {
        final int versaoAtualInt = _asInt(ret["versaoAtual"]) ?? 0;
        final int versaoMinInt = _asInt(ret["versaoMin"]) ?? 0;

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
        _loginDebug('resposta_negada status=${response.statusCode} Erro=$erro');
        if (response.statusCode == 401 || erro == 4) {
          return "Usuário ou senha inválidos.";
        }
        await _registrarErro("ERRO_1 - Status != 200", {
          "statusCode": response.statusCode,
          "json": ret,
        });
        return "ERRO_1";
      }

      // ------------------------------------------------------
      // 🔥 3) Erros normais
      // ------------------------------------------------------
      if (erro != 0) {
        _loginDebug('backend_retornou_erro Erro=$erro');
        await _registrarErro("ERRO_3 - backend retornou erro", {
          "erro": erro,
          "json": ret,
        });
        return "ERRO_3";
      }

      // ------------------------------------------------------
      // ✔ LOGIN OK
      // ------------------------------------------------------
      await _salvarDadosLogin(ret);

      _loginDebug('retorno_sucesso');
      print("[API.veLogin] ✅ LOGIN OK");
      print("==============================================");

      return "";
    } catch (e, st) {
      _loginDebug('ERRO_4 tipo=${e.runtimeType} mensagem=$e stackTrace=$st');
      print("[API.veLogin] ERRO_4 tipo=${e.runtimeType}");
      debugPrint('[Sanitized] sensitive_details_suppressed=true');
      debugPrint('[Sanitized] sensitive_details_suppressed=true');

      await _registrarErro("ERRO_4 - Exception geral", {
        "exception": e.toString(),
        "stack": st.toString(),
      });

      return "ERRO_4";
    }
  }

  static Future<int> _preferencesUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('idUser');
    if (userId == null || userId <= 0) {
      throw const ApiRequestException('Usuario nao identificado.');
    }
    return userId;
  }

  static Map<String, String> _preferencesJsonHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  static Future<Map<String, dynamic>>
      getFornecedorEntregadorPreferencias() async {
    final userId = await _preferencesUserId();
    final response = await http
        .get(
          Uri.parse(
                  'https://teletudo.com/api/fornecedor/entregadores/preferencias')
              .replace(queryParameters: {'userid': userId.toString()}),
          headers: _preferencesJsonHeaders(),
        )
        .timeout(const Duration(seconds: 15));
    return _decodeApiMap(response);
  }

  static Future<Map<String, dynamic>> buscarFornecedorEntregadores(
      String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('idUser');
      final normalizedQuery = query.trim();
      debugPrint('[Sanitized] sensitive_details_suppressed=true');
      print('[API.buscarFornecedorEntregadores] query="$normalizedQuery"');
      if (userId == null || userId <= 0) {
        throw const ApiRequestException('Usuario nao identificado.');
      }

      final uri =
          Uri.parse('https://teletudo.com/api/fornecedor/entregadores/buscar')
              .replace(queryParameters: {
        'userid': userId.toString(),
        'q': normalizedQuery,
      });
      print('[API.buscarFornecedorEntregadores] url=$uri');
      print('[API.buscarFornecedorEntregadores] requisicao_iniciada');
      final response = await http
          .get(uri, headers: _preferencesJsonHeaders())
          .timeout(const Duration(seconds: 15));
      print('[API.buscarFornecedorEntregadores] status=${response.statusCode}');
      debugPrint('[Sanitized] sensitive_details_suppressed=true');
      if (response.statusCode >= 400) {
        print('[API.buscarFornecedorEntregadores] '
            'erro_http status=${response.statusCode}');
      }

      try {
        final decoded = jsonDecode(response.body);
        final bodyType = decoded is Map
            ? 'map'
            : decoded is List
                ? 'list'
                : 'outro';
        final quantity = decoded is Map && decoded['items'] is List
            ? (decoded['items'] as List).length
            : decoded is List
                ? decoded.length
                : 0;
        print('[API.buscarFornecedorEntregadores] body_tipo=$bodyType');
        print(
            '[API.buscarFornecedorEntregadores] quantidade_resultados=$quantity');
      } catch (error) {
        debugPrint('[Sanitized] sensitive_details_suppressed=true');
      }

      return _decodeApiMap(response);
    } catch (error) {
      print('[API.buscarFornecedorEntregadores] excecao=${error.runtimeType}');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> favoritosRecebidos(int userId) async {
    final uri = Uri.parse(
      'https://teletudo.com/api/entregador/favoritos-recebidos',
    ).replace(queryParameters: {'userid': userId.toString()});
    debugPrint('[Sanitized] sensitive_details_suppressed=true');
    print('[API.favoritosRecebidos] url=$uri');
    print('[API.favoritosRecebidos] requisicao_iniciada');
    try {
      final response = await http
          .get(uri, headers: _preferencesJsonHeaders())
          .timeout(const Duration(seconds: 15));
      print('[API.favoritosRecebidos] status=${response.statusCode}');
      debugPrint('[Sanitized] sensitive_details_suppressed=true');
      return _decodeApiMap(response);
    } catch (error) {
      print('[API.favoritosRecebidos] excecao=${error.runtimeType}');
      rethrow;
    }
  }

  static Future<bool> marcarFornecedorEntregador(
      int idEntregador, String tipo) async {
    final userId = await _preferencesUserId();
    final response = await http
        .post(
          Uri.parse(
                  'https://teletudo.com/api/fornecedor/entregadores/$idEntregador/$tipo')
              .replace(queryParameters: {'userid': userId.toString()}),
          headers: _preferencesJsonHeaders(),
          body: jsonEncode({'userid': userId}),
        )
        .timeout(const Duration(seconds: 15));
    return _decodeApiMap(response)['success'] == true;
  }

  static Future<bool> removerFornecedorEntregadorPreferencia(
      int idEntregador) async {
    final userId = await _preferencesUserId();
    final response = await http
        .delete(
          Uri.parse(
                  'https://teletudo.com/api/fornecedor/entregadores/$idEntregador/preferencia')
              .replace(queryParameters: {'userid': userId.toString()}),
          headers: _preferencesJsonHeaders(),
          body: jsonEncode({'userid': userId}),
        )
        .timeout(const Duration(seconds: 15));
    return _decodeApiMap(response)['success'] == true;
  }

  static Map<String, dynamic> _decodeApiMap(http.Response response) {
    if (response.statusCode == 401) {
      throw const ApiRequestException('Sua sessao expirou. Entre novamente.');
    }
    if (response.statusCode == 403) {
      throw const ApiRequestException(
          'Voce nao tem permissao para esta operacao.');
    }
    if (response.statusCode == 404) {
      throw const ApiRequestException('Recurso nao encontrado.');
    }
    if (response.statusCode == 422) {
      throw const ApiRequestException('Dados invalidos para esta operacao.');
    }
    if (response.statusCode >= 500) {
      throw const ApiRequestException(
          'Servidor indisponivel. Tente novamente.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const FormatException('Resposta inválida do servidor.');
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
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
      debugPrint('[Sanitized] sensitive_details_suppressed=true');

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
    _loginDebug('shared_preferences_iniciada');
    final prefs = await SharedPreferences.getInstance();

    // ------------------------------------------------------
    // 🔹 Dados básicos
    // ------------------------------------------------------
    final int idUser = _asInt(ret["id"]) ?? 0;
    await prefs.setInt('idUser', idUser);

    final String nomeUser = (ret["nome"] ?? "").toString();
    await prefs.setString('nomeUser', nomeUser);

    print("[API.veLogin] SALVANDO PERFIS recebidos do backend:");

    // ------------------------------------------------------
    // 🔹 PERFIL FORNECEDOR
    // ------------------------------------------------------
    final bool ehFornecedor = ret["eh_fornecedor"] == true;
    await prefs.setBool('isFornecedor', ehFornecedor);
    debugPrint('[Sanitized] sensitive_details_suppressed=true');

    int idLoja = 0;
    if (ehFornecedor) {
      idLoja = _asInt(ret["id_loja"]) ?? 0;
      await prefs.setInt('idLoja', idLoja);
      print("idLoja = $idLoja");
    } else {
      await prefs.remove('idLoja');
    }

    // ------------------------------------------------------
    // 🔹 PERFIL MOTOBOY
    // ------------------------------------------------------
    bool ehMotoboy = false;
    if (ret.containsKey("eh_motoboy")) {
      final v = ret["eh_motoboy"];
      if (v is bool) ehMotoboy = v;
      if (v is int) ehMotoboy = v == 1;
      if (v is String) ehMotoboy = v == "1" || v.toLowerCase() == "true";
    }

    await prefs.setBool('isMotoboy', ehMotoboy);
    debugPrint('[Sanitized] sensitive_details_suppressed=true');

    // ------------------------------------------------------
    // 🔥 CONVITE (AQUI ESTAVA O BUG)
    // ------------------------------------------------------
    final token = ret["token"];
    if (token is String && token.isNotEmpty) {
      await prefs.setString('authToken', token);
    } else if (token is Map<String, dynamic>) {
      final convite = token["convite"]?.toString().trim();
      if (convite != null && convite.isNotEmpty) {
        await prefs.setString('convite', convite);
        print("[API.veLogin] Convite salvo nas prefs: $convite");
      } else {
        debugPrint('[Sanitized] sensitive_details_suppressed=true');
      }
    } else {
      await prefs.remove('authToken');
      debugPrint('[Sanitized] sensitive_details_suppressed=true');
    }

    // ------------------------------------------------------
    // 🔹 Log final
    // ------------------------------------------------------
    debugPrint('[Sanitized] sensitive_details_suppressed=true');
    _loginDebug('shared_preferences_concluida');
  }

  static Future<void> _registrarErro(String msg, Map<String, dynamic> info) {
    return logApp("veLogin", msg, info);
  }

  static Future<Position> getCurrentLocation() async {
    await _locationService.requestPermissions();
    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
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
        debugPrint('[Sanitized] sensitive_details_suppressed=true');
        return false;
      }
    } catch (e) {
      debugPrint('[Sanitized] sensitive_details_suppressed=true');
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
      debugPrint('[Sanitized] sensitive_details_suppressed=true');
    }
  }

  static Future<bool> notifyPickedUp({
    int? idPedido,
    int? idMotoboy,
    String? codigo,
  }) async {
    try {
      String baseUrl = "https://teletudo.com/api/notifyPickedUp";
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      int? currentChamado = idPedido ?? prefs.getInt('currentChamado');
      int? userid = idMotoboy ?? prefs.getInt('idUser');

      if (currentChamado == null ||
          userid == null ||
          codigo == null ||
          codigo.isEmpty) {
        debugPrint('[Sanitized] sensitive_details_suppressed=true');
        return false;
      }

      final body = {
        'chamado': currentChamado,
        'userid': userid,
        'codigo': codigo,
      };

      debugPrint('[Sanitized] sensitive_details_suppressed=true');

      var response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(body),
      );

      debugPrint('[Sanitized] sensitive_details_suppressed=true');

      if (response.statusCode != 200) {
        return false;
      }

      if (response.body.trim().isEmpty) {
        return true;
      }

      try {
        final data = json.decode(response.body);
        if (data is Map && data.containsKey('success')) {
          return data['success'] == true;
        }
      } catch (_) {
        return true;
      }

      return true;
    } catch (e) {
      debugPrint('[Sanitized] sensitive_details_suppressed=true');
      return false;
    }
    // return true;
  }

  static Future<bool> notifyDeliveryCompleted({
    int? idPedido,
    int? idMotoboy,
    String? codigo,
  }) async {
    print("API.notifyDeliveryCompleted() chamado");

    try {
      const String baseUrl = "https://teletudo.com/api/notifyDeliveryCompleted";

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      int? currentChamado = idPedido ?? prefs.getInt('currentChamado');
      int? userid = idMotoboy ?? prefs.getInt('idUser');

      if (currentChamado == null ||
          userid == null ||
          codigo == null ||
          codigo.isEmpty) {
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
        body: json.encode({
          'chamado': currentChamado,
          'userid': userid,
          'codigo': codigo,
        }),
      );

      print("Status HTTP = ${response.statusCode}");

      if (response.statusCode == 200) {
        debugPrint('[Sanitized] sensitive_details_suppressed=true');
        if (response.body.trim().isNotEmpty) {
          final data = json.decode(response.body);
          if (data is Map && data['valorEntrega'] != null) {
            final rawValor = data['valorEntrega'];
            ultimoValorEntrega = rawValor is num
                ? rawValor.toDouble()
                : double.tryParse(rawValor.toString());
          }
        }
        return true;
      } else {
        debugPrint('[Sanitized] sensitive_details_suppressed=true');
        return false;
      }
    } catch (e) {
      debugPrint('[Sanitized] sensitive_details_suppressed=true');
      return false;
    }
  }

  static Future<String> saldo(int userId) async {
    debugPrint('[Sanitized] sensitive_details_suppressed=true');
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
    print('[API.verifyInviteCode] request_started');
    String conviteDigitado = code.toUpperCase();
    await logApp("API", "convite_verification_started");
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
    debugPrint('[Sanitized] sensitive_details_suppressed=true');
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> checkInviteAvailability(
      String code, int userId) async {
    final url = Uri.parse(
        'https://teletudo.com/api/check-invite-code?code=$code&user_id=$userId');
    print('[API.checkInviteAvailability] GET $url');
    final response = await http.get(url);
    debugPrint('[Sanitized] sensitive_details_suppressed=true');
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> setInvite(String code, int userId) async {
    final url = Uri.parse('https://teletudo.com/api/set-invite');
    final body = json.encode({'code': code, 'user_id': userId});
    print('[API.setInvite] POST $url body=$body');
    final response = await http.post(url,
        headers: {'Content-Type': 'application/json'}, body: body);
    debugPrint('[Sanitized] sensitive_details_suppressed=true');
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
      debugPrint('[Sanitized] sensitive_details_suppressed=true');
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
      debugPrint('[Sanitized] sensitive_details_suppressed=true');
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
      debugPrint('[Sanitized] sensitive_details_suppressed=true');
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

  static Future<EntregaAtiva?> getEntregaAtiva(int idMotoboy) async {
    final url = Uri.parse("https://teletudo.com/api/entrega/ativa/$idMotoboy");

    final response = await http.get(url);

    if (response.statusCode != 200) {
      print("Erro ao buscar entrega ativa");
      return null;
    }

    final data = json.decode(response.body);
    debugPrint('[Sanitized] sensitive_details_suppressed=true');

    if (data['success'] != true) {
      return null;
    }

    if (!EntregaAtiva.canParse(data)) {
      debugPrint('[Sanitized] sensitive_details_suppressed=true');
      return null;
    }

    return EntregaAtiva.fromJson(data);
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
