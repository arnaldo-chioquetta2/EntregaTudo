import 'package:flutter_test/flutter_test.dart';
import 'package:entregatudo/push_message_data.dart';

void main() {
  test('interpreta evento com pedidoId', () {
    final value = PushMessageData.fromMap({
      'type': 'driver_assigned',
      'pedidoId': '553',
    });
    expect(value.type, 'driver_assigned');
    expect(value.orderId, 553);
    expect(value.canOpenTracking, isTrue);
  });

  test('aceita pedidoId em formato orderId', () {
    final value =
        PushMessageData.fromMap({'event': 'order_delivered', 'orderId': 553});
    expect(value.type, 'order_delivered');
    expect(value.orderId, 553);
  });

  test('evento desconhecido ou sem pedido nao navega', () {
    expect(
        PushMessageData.fromMap({'type': 'unknown'}).canOpenTracking, isFalse);
    expect(
        PushMessageData.fromMap({'type': 'paid', 'pedidoId': 0})
            .canOpenTracking,
        isFalse);
  });
}
