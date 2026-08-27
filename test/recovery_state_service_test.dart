import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:entregatudo/marketplace/models/payment_models.dart';
import 'package:entregatudo/marketplace/services/recovery_state_service.dart';

void main() {
  const payment = PaymentConfirmation(
    orderId: 553,
    paymentId: 4,
    status: 'awaiting_payment',
    type: 'pix',
    amount: 24,
<<<<<<< HEAD
=======
    provider: PaymentProviders.notreve,
>>>>>>> 94e7b05 (notreve)
    pixKey: 'pix@example.com',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('persists and clears pending payment state', () async {
    await RecoveryStateService.savePayment(
      payment,
      idempotencyKey: 'same-intention',
      userId: 10,
    );

    var state = await RecoveryStateService.read();
    expect(state.paymentId, 4);
    expect(state.paymentOrderId, 553);
    expect(state.paymentStatus, 'awaiting_payment');
<<<<<<< HEAD
=======
    expect(state.paymentProvider, PaymentProviders.notreve);
>>>>>>> 94e7b05 (notreve)
    expect(state.paymentIdempotencyKey, 'same-intention');
    expect(state.ownerId, 10);

    await RecoveryStateService.updatePaymentStatus('payment_reported');
    state = await RecoveryStateService.read();
    expect(state.paymentStatus, 'payment_reported');

    await RecoveryStateService.clearPayment();
    state = await RecoveryStateService.read();
    expect(state.paymentId, isNull);
    expect(state.paymentOrderId, isNull);
    expect(state.paymentIdempotencyKey, isNull);
    expect(state.ownerId, 10);
  });

  test('clears recovery state when the authenticated user changes', () async {
    await RecoveryStateService.savePayment(
      payment,
      idempotencyKey: 'same-intention',
      userId: 10,
    );
    await RecoveryStateService.saveOrder(553, userId: 10);

    await RecoveryStateService.prepareForUser(11);
    final state = await RecoveryStateService.read();

    expect(state.paymentId, isNull);
    expect(state.orderId, isNull);
    expect(state.ownerId, 11);
  });

  test(
      'clears active order after terminal delivery state is persisted by caller',
      () async {
    await RecoveryStateService.saveOrder(553, userId: 10);
    expect((await RecoveryStateService.read()).orderId, 553);

    await RecoveryStateService.clearOrder();
    expect((await RecoveryStateService.read()).orderId, isNull);
  });
}
