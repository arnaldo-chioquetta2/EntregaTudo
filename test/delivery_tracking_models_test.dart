import 'package:flutter_test/flutter_test.dart';
import 'package:entregatudo/marketplace/models/delivery_tracking_models.dart';

void main() {
  test('interpreta entrega aguardando entregador sem dados opcionais', () {
    final value = DeliveryTracking.fromJson({
      'pedidoId': 553,
      'paymentStatus': 'paid',
      'deliveryStatus': 'waiting_driver',
      'canCancel': true,
    });
    expect(value.deliveryStatus, 'waiting_driver');
    expect(value.driver, isNull);
    expect(value.location, isNull);
    expect(value.canCancel, isTrue);
  });

  test('interpreta entregador, veiculo e localizacao', () {
    final value = DeliveryTracking.fromJson({
      'pedidoId': 553,
      'deliveryStatus': 'driver_assigned',
      'canCancel': true,
      'entregador': {'nome': 'Joao'},
      'veiculo': {'descricao': 'Moto', 'placa': 'ABC1D23'},
      'localizacao': {'latitude': '-30.1', 'longitude': -51.2},
      'telefone': '51999999999',
    });
    expect(value.driver!.name, 'Joao');
    expect(value.vehicle!.plate, 'ABC1D23');
    expect(value.location!.latitude, -30.1);
    expect(value.contact, '51999999999');
  });

  test('aceita estados finais e canCancel false', () {
    for (final status in ['collected', 'delivered', 'cancelled']) {
      final value = DeliveryTracking.fromJson({
        'pedidoId': 553,
        'status': status,
        'canCancel': false,
      });
      expect(value.deliveryStatus, status);
      expect(value.canCancel, isFalse);
    }
  });

  test('separa codigo de confirmacao do id do pedido', () {
    final value = DeliveryTracking.fromJson({
      'pedidoId': 581,
      'codigo_confirmacao_cliente': '8123',
      'deliveryStatus': 'collected',
    });
    expect(value.orderId, 581);
    expect(value.confirmationCode, '8123');
  });

  test('preserva zero a esquerda e nao usa pedidoId como codigo', () {
    final value = DeliveryTracking.fromJson({
      'pedidoId': 581,
      'codigo_confirmacao_cliente': '0812',
    });
    expect(value.orderId, 581);
    expect(value.confirmationCode, '0812');

    final absent = DeliveryTracking.fromJson({'pedidoId': 581});
    expect(absent.confirmationCode, isNull);
  });

  test('rejeita coordenadas invalidas e zero zero', () {
    final invalid = DeliveryTracking.fromJson({
      'pedidoId': 1,
      'deliveryStatus': 'driver_assigned',
      'localizacao': {'latitude': 91, 'longitude': 0},
    });
    final zero = DeliveryTracking.fromJson({
      'pedidoId': 1,
      'deliveryStatus': 'driver_assigned',
      'localizacao': {'latitude': 0, 'longitude': 0},
    });
    expect(invalid.location!.isValid, isFalse);
    expect(zero.location!.isValid, isFalse);
  });
}
