import 'package:flutter_test/flutter_test.dart';
import 'package:entregatudo/marketplace/models/payment_models.dart';

void main() {
  test('interpreta confirmacao PIX manual e dados opcionais', () {
    final payment = PaymentConfirmation.fromJson({
      'paymentId': 4,
      'pedidoId': 553,
      'status': 'awaiting_payment',
      'tipo': 'pix',
      'valor': 24,
      'pix': {
        'chave': 'pix@example.com',
        'tipoChave': null,
        'qrCode': null,
        'copiaECola': null,
        'valorEmbutido': false,
        'instrucoes': 'Informe o valor exato no seu banco.',
      },
      'expiraEm': null,
      'paidAt': null,
      'reportedAt': null,
    });
    expect(payment.orderId, 553);
    expect(payment.paymentId, 4);
    expect(payment.amount, 24);
    expect(payment.status, 'awaiting_payment');
    expect(payment.pixKey, 'pix@example.com');
    expect(payment.pixKeyType, isNull);
    expect(payment.qr, isNull);
    expect(payment.copyPaste, isNull);
    expect(payment.valueEmbedded, isFalse);
    expect(payment.instructions, 'Informe o valor exato no seu banco.');
  });

  test('interpreta status payment_reported e paid', () {
    expect(
      PaymentStatus.fromJson({'paymentId': 4, 'status': 'payment_reported'})
          .status,
      'payment_reported',
    );
    expect(
      PaymentStatus.fromJson({'paymentId': 4, 'status': 'paid'}).status,
      'paid',
    );
  });

  test('normaliza provedor do pagamento e config global', () {
    final notreve = PaymentConfirmation.fromJson({
      'paymentId': 27,
      'pedidoId': 588,
      'status': 'awaiting_payment',
      'valor': 2.0,
      'provider': 'NOTREVE',
    });
    final gambiarra = PaymentConfirmation.fromJson({
      'paymentId': 28,
      'pedidoId': 589,
      'status': 'awaiting_payment',
      'valor': 2.0,
      'provider': 'GAMBIARRAPAY',
      'pix': {'chave': 'pix@example.com'},
    });

    expect(
        notreve.resolveProvider(const PaymentConfig(provider: 'GAMBIARRAPAY')),
        PaymentProviders.notreve);
    expect(gambiarra.resolveProvider(const PaymentConfig(provider: 'NOTREVE')),
        PaymentProviders.gambiarraPay);
    expect(
        PaymentProviders.normalize('desconhecido'), PaymentProviders.notreve);
    expect(PaymentConfig.fromJson({'provider': 'NOTREVE'}).provider,
        PaymentProviders.notreve);
  });

  test('usa config quando pagamento nao informa provider', () {
    final payment = PaymentConfirmation.fromJson({
      'paymentId': 29,
      'pedidoId': 590,
      'status': 'awaiting_payment',
      'valor': 2.0,
    });

    expect(
      payment.resolveProvider(const PaymentConfig(provider: 'NOTREVE')),
      PaymentProviders.notreve,
    );
    expect(
      payment.resolveProvider(const PaymentConfig(provider: 'GAMBIARRAPAY')),
      PaymentProviders.gambiarraPay,
    );
  });

  test('rejeita confirmacao sem dados obrigatorios', () {
    expect(
      () => PaymentConfirmation.fromJson({'pedidoId': 553}),
      throwsFormatException,
    );
  });
}
