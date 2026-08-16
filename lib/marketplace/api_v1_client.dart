import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_v1_error.dart';
import 'api_v1_session.dart';

class ApiV1Client {
  static const String baseUrl = 'https://teletudo.com/api/v1';
  static const Duration requestTimeout = Duration(seconds: 15);

  final http.Client _client;
  final Future<void> Function() _onUnauthorized;

  ApiV1Client({
    http.Client? client,
    Future<void> Function()? onUnauthorized,
  })  : _client = client ?? http.Client(),
        _onUnauthorized = onUnauthorized ?? ApiV1Session.handleUnauthorized;

  Future<Map<String, dynamic>> me() => get('/me');

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParameters,
  }) {
    return _request(
      method: 'GET',
      path: path,
      queryParameters: queryParameters,
    );
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParameters,
    String? idempotencyKey,
  }) {
    return _request(
      method: 'POST',
      path: path,
      body: body,
      queryParameters: queryParameters,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParameters,
  }) {
    return _request(
      method: 'PATCH',
      path: path,
      body: body,
      queryParameters: queryParameters,
    );
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParameters,
  }) {
    return _request(
      method: 'DELETE',
      path: path,
      body: body,
      queryParameters: queryParameters,
    );
  }

  Future<Map<String, dynamic>> _request({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    Map<String, String>? queryParameters,
    String? idempotencyKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    if (token == null || token.trim().isEmpty) {
      await _onUnauthorized();
      throw const ApiV1Exception(ApiV1Error(
        statusCode: 401,
        code: 'unauthenticated',
        message: 'Sessao expirada. Entre novamente.',
      ));
    }

    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters:
          queryParameters?.isEmpty == true ? null : queryParameters,
    );
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    if (idempotencyKey != null && idempotencyKey.trim().isNotEmpty) {
      headers['Idempotency-Key'] = idempotencyKey;
    }

    debugPrint('[API.v1] requisicao_iniciada method=$method path=$path');
    if (path == '/checkout/confirmar') {
      debugPrint(
          '[Payment.Confirm.Request] pedidoId=${body?['pedidoId'] ?? 'null'} idempotency=${idempotencyKey != null && idempotencyKey.trim().isNotEmpty} authenticated=true path=$path');
    }

    final stopwatch = Stopwatch()..start();
    try {
      final response = await _send(
        method,
        uri,
        headers,
        body == null ? null : jsonEncode(body),
      ).timeout(requestTimeout);

      debugPrint(
        '[API.v1] resposta method=$method path=$path status=${response.statusCode} duration_ms=${stopwatch.elapsedMilliseconds}',
      );

      if (path == '/checkout/confirmar') {
        final contentType = response.headers['content-type'] ?? 'ausente';
        final bodyPresent = response.body.trim().isNotEmpty;
        debugPrint(
            '[Payment.Confirm.Http] status=${response.statusCode} contentType=$contentType bytes=${response.body.length} duration_ms=${stopwatch.elapsedMilliseconds} body_presente=${bodyPresent ? 'sim' : 'nao'}');
        debugPrint(
            '[Payment.Confirm.Raw] ${_sanitizePaymentBody(response.body)}');
      }

      if (response.statusCode == 401) {
        await _onUnauthorized();
      }

      return _decodeEnvelope(response);
    } on TimeoutException {
      debugPrint(
          '[API.v1] request_timeout method=$method path=$path duration_ms=${stopwatch.elapsedMilliseconds}');
      throw const ApiV1Exception(ApiV1Error(
        statusCode: 0,
        code: 'timeout',
        message: 'A requisicao demorou demais. Tente novamente.',
      ));
    } on ApiV1Exception {
      rethrow;
    } catch (error) {
      debugPrint('[API.v1] erro_rede method=$method tipo=${error.runtimeType}');
      throw const ApiV1Exception(ApiV1Error(
        statusCode: 0,
        code: 'network_error',
        message: 'Nao foi possivel conectar ao servidor.',
      ));
    }
  }

  Future<http.Response> _send(
    String method,
    Uri uri,
    Map<String, String> headers,
    String? body,
  ) {
    switch (method) {
      case 'GET':
        return _client.get(uri, headers: headers);
      case 'POST':
        return _client.post(uri, headers: headers, body: body);
      case 'PATCH':
        return _client.patch(uri, headers: headers, body: body);
      case 'DELETE':
        return _client.delete(uri, headers: headers, body: body);
      default:
        throw ArgumentError('Metodo HTTP nao suportado: $method');
    }
  }

  String _sanitizePaymentBody(String body) {
    if (body.trim().isEmpty) return '(vazio)';
    try {
      final decoded = jsonDecode(body);
      return jsonEncode(_sanitizeValue(decoded));
    } on FormatException {
      return '(nao_json bytes=${body.length})';
    }
  }

  Object? _sanitizeValue(Object? value) {
    if (value is Map) {
      return value.map((key, item) {
        final name = key.toString().toLowerCase();
        if (name.contains('token') ||
            name.contains('authorization') ||
            name.contains('chavepix') ||
            name == 'chave') {
          return MapEntry(key, '[REDACTED]');
        }
        return MapEntry(key, _sanitizeValue(item));
      });
    }
    if (value is List) return value.map(_sanitizeValue).toList();
    return value;
  }

  Map<String, dynamic> _decodeEnvelope(http.Response response) {
    Map<String, dynamic> payload = <String, dynamic>{};
    if (response.body.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          payload = decoded;
        }
      } on FormatException {
        throw ApiV1Exception(ApiV1Error(
          statusCode: response.statusCode,
          code: 'invalid_json',
          message: 'Resposta invalida do servidor.',
        ));
      }
    }

    final success = payload['success'] == true;
    if (response.statusCode >= 200 && response.statusCode < 300 && success) {
      return payload;
    }

    final rawErrors = payload['errors'];
    final errors = rawErrors is Map<String, dynamic>
        ? rawErrors
        : const <String, dynamic>{};
    throw ApiV1Exception(ApiV1Error(
      statusCode: response.statusCode,
      code: payload['code']?.toString(),
      message: payload['message']?.toString() ??
          'Nao foi possivel concluir a requisicao.',
      errors: errors,
    ));
  }

  void close() => _client.close();
}
