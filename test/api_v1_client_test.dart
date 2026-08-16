import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:entregatudo/marketplace/api_v1_client.dart';
import 'package:entregatudo/marketplace/api_v1_error.dart';

class _FakeClient extends http.BaseClient {
  _FakeClient(this.responseBuilder);

  final http.Response Function(http.BaseRequest request) responseBuilder;
  http.BaseRequest? lastRequest;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRequest = request;
    final response = responseBuilder(request);
    return http.StreamedResponse(
      Stream<List<int>>.fromIterable(<List<int>>[
        utf8.encode(response.body),
      ]),
      response.statusCode,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
      request: request,
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'authToken': 'test-token',
    });
  });

  test('envia Bearer e interpreta o envelope de sucesso', () async {
    final client = _FakeClient((request) {
      expect(request.headers['authorization'], 'Bearer test-token');
      expect(request.headers.containsKey('userid'), isFalse);
      expect(request.url.path, '/api/v1/me');
      return http.Response(
        jsonEncode(<String, dynamic>{
          'success': true,
          'data': <String, dynamic>{'id': 3},
        }),
        200,
      );
    });

    final api = ApiV1Client(client: client, onUnauthorized: () async {});
    final response = await api.me();

    expect(response['success'], isTrue);
    expect((response['data'] as Map<String, dynamic>)['id'], 3);
  });

  test('preserva status, code, message e errors em falha HTTP', () async {
    final client = _FakeClient((_) => http.Response(
          jsonEncode(<String, dynamic>{
            'success': false,
            'code': 'validation_error',
            'message': 'Dados invalidos.',
            'errors': <String, dynamic>{
              'fornecedor': <String>['fornecedor_diferente'],
            },
          }),
          422,
        ));
    final api = ApiV1Client(client: client, onUnauthorized: () async {});

    try {
      await api.get('/produtos');
      fail('A requisicao deveria falhar');
    } on ApiV1Exception catch (error) {
      expect(error.statusCode, 422);
      expect(error.code, 'validation_error');
      expect(error.hasFieldError('fornecedor', 'fornecedor_diferente'), isTrue);
    }
  });

  test('dispara o tratamento centralizado quando recebe 401', () async {
    var unauthorizedCalls = 0;
    final client = _FakeClient((_) => http.Response(
          jsonEncode(<String, dynamic>{
            'success': false,
            'code': 'unauthenticated',
            'message': 'Sessao expirada.',
          }),
          401,
        ));
    final api = ApiV1Client(
      client: client,
      onUnauthorized: () async => unauthorizedCalls++,
    );

    await expectLater(api.get('/me'), throwsA(isA<ApiV1Exception>()));
    expect(unauthorizedCalls, 1);
  });
}
