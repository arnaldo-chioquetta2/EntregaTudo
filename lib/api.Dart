import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'features/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:entregatudo/constants.dart';
import 'package:entregatudo/models/delivery_details.dart';
// import 'package:seu_projeto/models/nova_venda.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      String PIX,
      int erroCodigo,
      int distanciaMaxima) async {
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
          'PIX': PIX,
          'erroCodigo': erroCodigo,
          'distanciaMaxima': distanciaMaxima,
          'versaoApp': AppConfig.versaoApp,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final ret = json.decode(response.body);
        if (ret['success'] == true) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('idUser', ret["id"]);
          return {'success': true, 'message': 'Cadastro bem-sucedido'};
        } else {
          return {
            'success': false,
            'message': ret['message'] ?? 'Erro desconhecido ao cadastrar',
            'details': 'Resposta do servidor: ${response.body}',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Falha no servidor (${response.statusCode})',
          'details':
              'Código HTTP: ${response.statusCode}\nResposta do servidor: ${response.body}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão com o servidor',
        'details': 'Exceção capturada: $e',
      };
    }
  }

  static Future<DeliveryDetails?> sendHeartbeat(double lat, double lon) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? userid = prefs.getInt('idUser');
    int vez = prefs.getInt('vez') ?? 0;
    await prefs.setInt('vez', vez + 1);

    if (userid != null) {
      String baseUrl = "https://teletudo.com/api/heartbeat";
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

      if (response.statusCode == 200) {
        print('Response Body: ${response.body}');
        var data = json.decode(response.body);
        int modo = data['modo'] ?? 3;
        await prefs.setInt('modo', modo);
        int lojasNoRaio = data['lojas_no_raio'] ?? 0;
        print('Lojas no Raio: $lojasNoRaio');
        return DeliveryDetails.fromJson(data);
      } else {
        print('Erro ao enviar heartbeat: ${response.statusCode}');
      }
    } else {
      print('User ID não encontrado');
    }
    return null;
  }

  static Future<FornecedorHeartbeatResponse?> sendHeartbeatF(
      double lat, double lon) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? userid = prefs.getInt('idUser');
    int? idLoja = prefs.getInt('idLoja');
    int vez = prefs.getInt('vez') ?? 0;
    await prefs.setInt('vez', vez + 1);

    if (userid != null) {
      String baseUrl = "https://teletudo.com/api/heartbeatF";
      print('Enviando pedido para o servidor:');
      print('URL: $baseUrl');
      print(
          'Dados enviados: { "userid": $userid, "idLoja": $idLoja, "lat": $lat, "lon": $lon }');

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
          NovaVenda? novaVenda = data['nova_venda'] != null
              ? NovaVenda.fromJson(data['nova_venda'])
              : null;
          return FornecedorHeartbeatResponse(
            modo: data['modo'] ?? 3,
            lojasNoRaio: data['lojas_no_raio'] ?? 0,
            idLoja: idLoja ?? 0,
            novaVenda: novaVenda,
            processingTime: (data['processing_time_ms'] as num).toDouble(),
          );
        } else {
          print('Erro no retorno: ${data['DescErro']}');
        }
      } else {
        print(
            'Erro ao enviar heartbeat para fornecedor: ${response.statusCode}');
      }
    } else {
      print('User ID não encontrado');
    }
    return null;
  }

// curl -X POST https://teletudo.com/api/login -H "Content-Type: application/json" -H "Accept: application/json" -d "{\"user\": \"teste\", \"password\": \"teste\", \"lat\": -23.55052, \"lon\": -46.633308}" -k
  static Future<String> veLogin(
      String user, String password, double lat, double lon) async {
    String baseUrl = "https://teletudo.com/api/login";
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
    if (response.statusCode == 200) {
      var ret = json.decode(response.body);
      final int erro = ret["Erro"] ?? 1;
      if (erro == 0) {
        final int idUser = ret["id"] ?? 0;
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setInt('idUser', idUser);
        final String nomeUser = (ret["nome"] ?? "").toString();
        await prefs.setString('nomeUser', nomeUser);
        int idLoja = 0;
        print("[API.veLogin] eh_fornecedor = $ret['eh_fornecedor']");
        print("[API.veLogin] id_loja = $ret['id_loja']");
        if (ret["eh_fornecedor"] == true) {
          idLoja = ret["id_loja"];
          print("[API.veLogin] Usuário é fornecedor. idLoja = $idLoja");
          await prefs.setBool('isFornecedor', true);
        }
        await prefs.setInt('idLoja', idLoja);
        return "";
      } else {
        return "ERRO";
      }
    } else {
      return "ERRO";
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
    print("Entrou na API notifyDeliveryCompleted");
    try {
      String baseUrl = "https://teletudo.com/api/notifyDeliveryCompleted";
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      int? currentChamado = prefs.getInt('currentChamado');
      print("chamado = " + currentChamado.toString());
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'chamado': currentChamado}),
      );
      print(response.statusCode);
      if (response.statusCode == 200) {
        print("Sucesso ao notificar o servidor: ${response.body}");
        return true;
      } else {
        print("Falha ao notificar o servidor: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Erro na chamada API: $e");
      return false;
    }
    // return true;
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
    final response = await http.get(
      Uri.parse('https://teletudo.com/api/verify-invite-code')
          .replace(queryParameters: {'code': code}),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
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
}

class FornecedorHeartbeatResponse {
  final int modo;
  final int lojasNoRaio;
  final int idLoja;
  final NovaVenda? novaVenda;
  final double processingTime;

  FornecedorHeartbeatResponse({
    required this.modo,
    required this.lojasNoRaio,
    required this.idLoja,
    this.novaVenda,
    required this.processingTime,
  });

  factory FornecedorHeartbeatResponse.fromJson(Map<String, dynamic> json) {
    return FornecedorHeartbeatResponse(
      modo: json['modo'] ?? 3,
      lojasNoRaio: json['lojas_no_raio'] ?? 0,
      idLoja: json['id_loja'] ?? 0,
      novaVenda: json['nova_venda'] != null
          ? NovaVenda.fromJson(json['nova_venda'])
          : null,
      processingTime: json['processing_time_ms'], // Adicione esta linha
    );
  }
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
