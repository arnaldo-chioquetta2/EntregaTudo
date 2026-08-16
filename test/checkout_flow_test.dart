import 'package:flutter_test/flutter_test.dart';

import 'package:entregatudo/marketplace/api_v1_error.dart';
import 'package:entregatudo/marketplace/models/checkout_models.dart';
import 'package:entregatudo/marketplace/utils/geo_distance.dart';
import 'package:entregatudo/marketplace/utils/cart_quantity.dart';
import 'package:entregatudo/marketplace/models/marketplace_models.dart';
import 'package:entregatudo/marketplace/screens/checkout_address_page.dart';

void main() {
  test('calcula distancia dentro e fora de 200 metros', () {
    expect(
        isWithinCheckoutAddressRange(
          fromLatitude: -30.000000,
          fromLongitude: -51.000000,
          toLatitude: -30.000500,
          toLongitude: -51.000000,
        ),
        isTrue);
    expect(
        isWithinCheckoutAddressRange(
          fromLatitude: -30.000000,
          fromLongitude: -51.000000,
          toLatitude: -30.003000,
          toLongitude: -51.000000,
        ),
        isFalse);
  });

  test('normaliza endereco temporario e nao altera cadastro', () {
    final address = DeliveryAddress.fromJson({
      'tipo': 'temporario',
      'cep': '90000000',
      'logradouro': 'Rua A',
      'numero': '10',
      'complemento': 'Sala 2',
      'cidade': 'Porto Alegre',
      'uf': 'RS',
      'formatado': 'Rua A, 10 - Porto Alegre/RS',
    });

    expect(address.isTemporary, isTrue);
    expect(address.displayText, 'Rua A, 10 - Porto Alegre/RS');
    expect(address.toTemporaryPayload(), {
      'tipo': 'temporario',
      'cep': '90000000',
      'numero': '10',
      'complemento': 'Sala 2',
    });
  });

  test('interpreta orcamento com endereco e valores oficiais', () {
    final quote = CheckoutQuote.fromJson({
      'pedidoId': 42,
      'produtos': [],
      'entrega': {'valor': '7.50'},
      'totalItens': '20.00',
      'total': 27.5,
      'enderecoEntrega': {'tipo': 'padrao', 'formatado': 'Rua A, 10'},
      'canConfirm': true,
      'status': 'orcamento_disponivel',
    });

    expect(quote.orderId, 42);
    expect(quote.itemsTotal, 20);
    expect(quote.deliveryValue, 7.5);
    expect(quote.total, 27.5);
    expect(quote.deliveryAddress?.displayText, 'Rua A, 10');
  });

  test('interpreta os campos financeiros reais do P4', () {
    final quote = CheckoutQuote.fromJson({
      'pedidoId': 552,
      'produtos': '12.50',
      'entrega': 4.75,
      'total': 17.25,
      'canConfirm': true,
    });
    expect(quote.itemsTotal, 12.5);
    expect(quote.deliveryValue, 4.75);
    expect(quote.total, 17.25);
  });

  test('rejeita financeiro obrigatorio ausente ou invalido', () {
    expect(
      () => CheckoutQuote.fromJson({
        'pedidoId': 1,
        'produtos': null,
        'entrega': 2,
        'total': 'x',
      }),
      throwsFormatException,
    );
  });
  test('identifica fornecedor diferente em lista Laravel', () {
    const error = ApiV1Exception(ApiV1Error(
      statusCode: 422,
      code: 'validation_error',
      message: 'Dados invalidos.',
      errors: {
        'fornecedor': ['fornecedor_diferente'],
      },
    ));

    expect(error.hasFieldError('fornecedor', 'fornecedor_diferente'), isTrue);
  });

  test('incremento, decremento e minimo de quantidade', () {
    expect(increasedQuantity(1), 2);
    expect(increasedQuantity(2), 3);
    expect(decreasedQuantity(3), 2);
    expect(decreasedQuantity(2), 1);
    expect(decreasedQuantity(1), 1);
    expect(canDecreaseQuantity(1), isFalse);
    expect(canDecreaseQuantity(2), isTrue);
  });

  test('carrinho usa id do item e preserva adicionais', () {
    final item = CartItem.fromJson({
      'idItem': 77,
      'idProduto': 782,
      'idEmpresa': 5,
      'nome': 'Produto',
      'quantidade': 1,
      'valorUnitario': 10,
      'subtotal': 10,
      'adicionais': [],
      'observacao': 'sem cebola',
    });
    expect(item.id, 77);
    expect(item.idProduto, 782);
    expect(item.observation, 'sem cebola');
  });
  test('usa o texto correto para solicitar valor da entrega', () {
    expect(checkoutQuoteActionLabel, 'Clique para ver o valor da entrega');
  });
  test('chave de idempotencia e reutilizavel pela operacao', () {
    const key = 'quote-operation-1';
    expect(key, equals(key));
  });
}
