import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:entregatudo/services/analytics_service.dart';

class _AnalyticsClient extends http.BaseClient {
  final List<http.BaseRequest> requests = <http.BaseRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    return http.StreamedResponse(
      Stream<List<int>>.fromIterable(<List<int>>[utf8.encode('{}')]),
      204,
      request: request,
    );
  }
}

PackageInfo _packageInfo() => PackageInfo(
      appName: 'EntregaTudo',
      packageName: 'com.teletudo.entregatudo',
      version: '1.5.2',
      buildNumber: '152',
    );

Future<void> _drainAnalytics() => Future<void>.delayed(Duration.zero);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('cria session id efemero sem dados pessoais', () {
    final first = AnalyticsService.forTesting(sessionId: 'session-a');
    final second = AnalyticsService.forTesting(sessionId: 'session-b');

    expect(first.sessionId, isNotEmpty);
    expect(first.sessionId, isNot(contains('user')));
    expect(first.sessionId, isNot(contains('@')));
    expect(first.sessionId, isNot(second.sessionId));
  });

  test('envia whitelist, versao e Bearer somente no header', () async {
    final client = _AnalyticsClient();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('authToken', 'secret-token');
    final service = AnalyticsService.forTesting(
      client: client,
      packageInfoLoader: () async => _packageInfo(),
      preferencesLoader: () async => prefs,
      sessionId: 'session-test',
      platform: 'web',
    );

    service.track(AnalyticsEvent.loginSuccess);
    await _drainAnalytics();

    expect(client.requests, hasLength(1));
    final request = client.requests.single as http.Request;
    expect(request.headers['authorization'], 'Bearer secret-token');
    final payload = jsonDecode(request.body) as Map<String, dynamic>;
    expect(payload['event_type'], AnalyticsEvent.loginSuccess);
    expect(payload['session_id'], 'session-test');
    expect(payload['app_version'], '1.5.2');
    expect(payload['build_number'], '152');
    expect(payload['platform'], 'web');
    expect(payload.containsKey('user_id'), isFalse);
    expect(payload.values, isNot(contains('secret-token')));
  });

  test('APP_OPEN nao e enviado duas vezes na mesma sessao', () async {
    final client = _AnalyticsClient();
    final service = AnalyticsService.forTesting(
      client: client,
      packageInfoLoader: () async => _packageInfo(),
      preferencesLoader: SharedPreferences.getInstance,
      sessionId: 'session-test',
      platform: 'android',
    );

    service.track(AnalyticsEvent.appOpen);
    service.track(AnalyticsEvent.appOpen);
    await _drainAnalytics();

    expect(client.requests, hasLength(1));
  });

  test('evento desconhecido nao gera request e falha nao propaga', () async {
    final client = _AnalyticsClient();
    final service = AnalyticsService.forTesting(
      client: client,
      packageInfoLoader: () async => throw StateError('metadata failure'),
      preferencesLoader: SharedPreferences.getInstance,
      sessionId: 'session-test',
      platform: 'other',
    );

    service.track('UNKNOWN_EVENT');
    service.track(AnalyticsEvent.cartAdd);
    await _drainAnalytics();

    expect(client.requests, isEmpty);
  });
}
