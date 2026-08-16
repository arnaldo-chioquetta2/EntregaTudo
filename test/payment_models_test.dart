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

  test('rejeita confirmacao sem dados obrigatorios', () {
    expect(
      () => PaymentConfirmation.fromJson({'pedidoId': 553}),
      throwsFormatException,
    );
  });
}
