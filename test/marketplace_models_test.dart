import 'package:flutter_test/flutter_test.dart';

import 'package:entregatudo/marketplace/models/marketplace_models.dart';

void main() {
  test('interpreta o payload real do marketplace', () {
    final home = MarketplaceHome.fromJson(<String, dynamic>{
      'categorias': [
        <String, dynamic>{'id': 2, 'nome': 'Lanches', 'imagem': null},
      ],
      'fornecedores': [
        <String, dynamic>{
          'id': 7,
          'nome': 'Empresa Teste',
          'imagem': null,
          'url': 'https://teletudo.com/empresa/7',
        },
      ],
      'produtos': <String, dynamic>{
        'items': [
          <String, dynamic>{
            'idProduto': 10,
            'idEmpresa': 7,
            'nome': 'Xis',
            'descricao': 'Descricao',
            'preco': 12.5,
            'categoria': 'Lanches',
            'fornecedor': 'Empresa Teste',
            'imagem': null,
            'urlFornecedor': 'https://teletudo.com/empresa/7',
            'teleEntregaDisponivel': true,
          },
        ],
        'page': 1,
        'per_page': 20,
        'total': 1,
        'last_page': 1,
      },
    });

    expect(home.categories.single.name, 'Lanches');
    expect(home.suppliers.single.url, 'https://teletudo.com/empresa/7');
    expect(home.products.items.single.teleEntregaDisponivel, isTrue);
    expect(home.products.pagination.hasNextPage, isFalse);
  });

  test('preserva produto sem Teleentrega e URLs invalidas como null', () {
    final product = MarketplaceProduct.fromJson(<String, dynamic>{
      'idProduto': '10',
      'idEmpresa': '7',
      'nome': 'Produto',
      'preco': '12,50',
      'imagem': 'nao-url',
      'urlFornecedor': 'nao-url',
      'teleEntregaDisponivel': false,
    });

    expect(product.price, 12.5);
    expect(product.imageUrl, isNull);
    expect(product.supplierUrl, isNull);
    expect(product.teleEntregaDisponivel, isFalse);
  });

  test('interpreta o carrinho vazio e fornecedor ativo', () {
    final empty = ShoppingCart.fromJson(<String, dynamic>{
      'id': 1,
      'idEmpresa': null,
      'itens': <dynamic>[],
      'totalItens': 0,
    });
    final active = ShoppingCart.fromJson(<String, dynamic>{
      'id': 1,
      'idEmpresa': 7,
      'itens': [
        <String, dynamic>{
          'id': 4,
          'idProduto': 10,
          'idEmpresa': 7,
          'nome': 'Xis',
          'quantidade': 1,
          'valorUnitario': 12.5,
          'subtotal': 12.5,
          'adicionais': <dynamic>[],
          'observacao': null,
        },
      ],
      'totalItens': 12.5,
    });

    expect(empty.isEmpty, isTrue);
    expect(active.isEmpty, isFalse);
    expect(active.activeSupplierId, 7);
    expect(active.items.single.idProduto, 10);
  });
}
