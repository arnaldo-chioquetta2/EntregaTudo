import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:entregatudo/marketplace/api_v1_client.dart';
import 'package:entregatudo/marketplace/models/payment_models.dart';
import 'package:entregatudo/marketplace/screens/notreve_payment_page.dart';
import 'package:entregatudo/marketplace/services/marketplace_service.dart';

class _StatusClient extends http.BaseClient {
  int calls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    calls++;
    final body = jsonEncode({
      'success': true,
      'data': {
        'paymentId': 30,
        'pedidoId': 590,
        'provider': 'NOTREVE',
        'status': 'awaiting_payment',
        'expiraEm': '2026-08-24 23:26:30',
      },
    });
    return http.StreamedResponse(
      Stream<List<int>>.fromIterable([utf8.encode(body)]),
      200,
      request: request,
    );
  }
}

const _qrBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

PaymentConfirmation _payment({
  String status = 'awaiting_payment',
  String? qr = _qrBase64,
  String? copyPaste = '000201010212test-pix-payload',
  bool? valueEmbedded = true,
  String? expiresAt,
}) {
  return PaymentConfirmation.fromJson({
    'paymentId': 29,
    'pedidoId': 587,
    'provider': 'NOTREVE',
    'status': status,
    'valor': 2.0,
    'expiraEm': expiresAt,
    'pix': {
      'qrCode': qr,
      'copiaECola': copyPaste,
      'valorEmbutido': valueEmbedded,
    },
  });
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(
        <String, Object>{'authToken': 'test-token'});
  });
  test('decodifica QR puro e data URI', () {
    expect(decodeNotreveQr(_qrBase64), isNotNull);
    expect(decodeNotreveQr('data:image/png;base64,$_qrBase64'), isNotNull);
    expect(decodeNotreveQr('!!!not-base64!!!'), isNull);
    expect(decodeNotreveQr(null), isNull);
  });

  test('parser aceita QR, copia-e-cola, valor e expiracao nula', () {
    final payment = _payment();
    expect(payment.paymentId, 29);
    expect(payment.orderId, 587);
    expect(payment.amount, 2.0);
    expect(payment.qr, _qrBase64);
    expect(payment.copyPaste, '000201010212test-pix-payload');
    expect(payment.valueEmbedded, isTrue);
    expect(payment.expiresAt, isNull);
    expect(payment.valueEmbedded, isTrue);
  });

  testWidgets('mostra QR, copia-e-cola, valor e aviso de valor embutido',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NotrevePaymentPage(
          service: MarketplaceService(),
          payment: _payment(),
          pollInterval: const Duration(milliseconds: 100),
        ),
      ),
    );

    expect(find.text('Pagamento via PIX'), findsOneWidget);
    expect(find.textContaining('2,00'), findsOneWidget);
    expect(find.text('PIX Copia e Cola'), findsOneWidget);
    expect(find.text('Copiar codigo PIX'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('incluido neste PIX'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('incluido neste PIX'), findsOneWidget);
    expect(find.text('Valido ate:'), findsNothing);
  });

  testWidgets('permite somente copia-e-cola quando QR está ausente',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NotrevePaymentPage(
          service: MarketplaceService(),
          payment: _payment(qr: null),
        ),
      ),
    );

    expect(find.text('Copiar codigo PIX'), findsOneWidget);
    expect(
      find.text('Nao foi possivel carregar os dados do PIX. Tente novamente.'),
      findsNothing,
    );
  });

  testWidgets('mostra erro amigavel quando QR e copia-e-cola faltam',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NotrevePaymentPage(
          service: MarketplaceService(),
          payment: _payment(qr: null, copyPaste: null),
        ),
      ),
    );

    expect(
      find.text('Nao foi possivel carregar os dados do PIX. Tente novamente.'),
      findsOneWidget,
    );
  });

  test('interpreta expiraEm dentro do envelope data', () {
    final status = PaymentStatus.fromJson({
      'success': true,
      'data': {
        'paymentId': 30,
        'pedidoId': 590,
        'provider': 'NOTREVE',
        'status': 'awaiting_payment',
        'expiraEm': '2026-08-24 23:26:30',
      },
    });

    expect(status.paymentId, 30);
    expect(status.provider, 'NOTREVE');
    expect(status.expiresAt, '2026-08-24 23:26:30');
  });

  testWidgets('polling atualiza expiraEm sem perder dados PIX', (tester) async {
    final client = _StatusClient();
    await tester.pumpWidget(
      MaterialApp(
        home: NotrevePaymentPage(
          service: MarketplaceService(
            api: ApiV1Client(client: client, onUnauthorized: () async {}),
          ),
          payment: _payment(),
          pollInterval: const Duration(milliseconds: 100),
        ),
      ),
    );

    final state = tester.state(find.byType(NotrevePaymentPage));
    await (state as dynamic).pollForTesting();

    expect(client.calls, 1);
    expect(find.text('PIX Copia e Cola'), findsOneWidget);
    expect(find.text('Copiar codigo PIX'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Válido até: 24/08/2026 23:26'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Válido até: 24/08/2026 23:26'), findsOneWidget);
  });
  testWidgets('status paid nao inicia polling e mostra confirmacao',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NotrevePaymentPage(
          service: MarketplaceService(),
          payment: _payment(status: 'paid'),
        ),
      ),
    );

    expect(find.text('Pagamento confirmado'), findsOneWidget);
  });
}
