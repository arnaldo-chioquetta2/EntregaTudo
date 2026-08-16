import 'dart:math' as math;

class MarketplaceCategory {
  final int id;
  final String name;
  final String? imageUrl;

  const MarketplaceCategory({
    required this.id,
    required this.name,
    this.imageUrl,
  });

  factory MarketplaceCategory.fromJson(Map<String, dynamic> json) {
    return MarketplaceCategory(
      id: _asInt(json['id']) ?? 0,
      name: _asString(json['nome']),
      imageUrl: _asUrl(json['imagem']),
    );
  }
}

class MarketplaceSupplier {
  final int id;
  final String name;
  final String? imageUrl;
  final String? url;

  const MarketplaceSupplier({
    required this.id,
    required this.name,
    this.imageUrl,
    this.url,
  });

  factory MarketplaceSupplier.fromJson(Map<String, dynamic> json) {
    return MarketplaceSupplier(
      id: _asInt(json['id']) ?? 0,
      name: _asString(json['nome']),
      imageUrl: _asUrl(json['imagem']),
      url: _asUrl(json['url']),
    );
  }
}

class MarketplaceAdditional {
  final int id;
  final String name;
  final double value;

  const MarketplaceAdditional({
    required this.id,
    required this.name,
    required this.value,
  });

  factory MarketplaceAdditional.fromJson(Map<String, dynamic> json) {
    return MarketplaceAdditional(
      id: _asInt(json['id']) ?? 0,
      name: _asString(json['nome']),
      value: _asDouble(json['valor']),
    );
  }
}

class MarketplaceProduct {
  final int idProduto;
  final int idEmpresa;
  final String name;
  final String description;
  final double price;
  final String? category;
  final String supplierName;
  final String? imageUrl;
  final String? supplierUrl;
  final bool teleEntregaDisponivel;
  final List<MarketplaceAdditional> additionals;

  const MarketplaceProduct({
    required this.idProduto,
    required this.idEmpresa,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.supplierName,
    required this.imageUrl,
    required this.supplierUrl,
    required this.teleEntregaDisponivel,
    this.additionals = const <MarketplaceAdditional>[],
  });

  factory MarketplaceProduct.fromJson(Map<String, dynamic> json) {
    final rawAdditionals = json['adicionais'];
    return MarketplaceProduct(
      idProduto: _asInt(json['idProduto']) ?? 0,
      idEmpresa: _asInt(json['idEmpresa']) ?? 0,
      name: _asString(json['nome']),
      description: _asString(json['descricao']),
      price: _asDouble(json['preco']),
      category: _asNullableString(json['categoria']),
      supplierName: _asString(json['fornecedor']),
      imageUrl: _asUrl(json['imagem']),
      supplierUrl: _asUrl(json['urlFornecedor']),
      teleEntregaDisponivel: json['teleEntregaDisponivel'] == true,
      additionals: rawAdditionals is List
          ? rawAdditionals
              .whereType<Map<String, dynamic>>()
              .map(MarketplaceAdditional.fromJson)
              .toList(growable: false)
          : const <MarketplaceAdditional>[],
    );
  }
}

class MarketplacePagination {
  final int page;
  final int perPage;
  final int total;
  final int lastPage;

  const MarketplacePagination({
    required this.page,
    required this.perPage,
    required this.total,
    required this.lastPage,
  });

  bool get hasNextPage => page < lastPage;

  factory MarketplacePagination.fromJson(Map<String, dynamic> json) {
    return MarketplacePagination(
      page: _asInt(json['page']) ?? 1,
      perPage: _asInt(json['per_page']) ?? 20,
      total: _asInt(json['total']) ?? 0,
      lastPage: math.max(1, _asInt(json['last_page']) ?? 1),
    );
  }
}

class MarketplaceProductPage {
  final List<MarketplaceProduct> items;
  final MarketplacePagination pagination;

  const MarketplaceProductPage({
    required this.items,
    required this.pagination,
  });

  factory MarketplaceProductPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return MarketplaceProductPage(
      items: rawItems is List
          ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(MarketplaceProduct.fromJson)
              .toList(growable: false)
          : const <MarketplaceProduct>[],
      pagination: MarketplacePagination.fromJson(json),
    );
  }
}

class MarketplaceHome {
  final List<MarketplaceCategory> categories;
  final List<MarketplaceSupplier> suppliers;
  final MarketplaceProductPage products;

  const MarketplaceHome({
    required this.categories,
    required this.suppliers,
    required this.products,
  });

  factory MarketplaceHome.fromJson(Map<String, dynamic> json) {
    return MarketplaceHome(
      categories: _listOf(json['categorias'], MarketplaceCategory.fromJson),
      suppliers: _listOf(json['fornecedores'], MarketplaceSupplier.fromJson),
      products: MarketplaceProductPage.fromJson(
        _asMap(json['produtos']),
      ),
    );
  }
}

class CartItem {
  final int id;
  final int idProduto;
  final int idEmpresa;
  final String name;
  final int quantity;
  final double unitValue;
  final double subtotal;
  final List<MarketplaceAdditional> additionals;
  final String? observation;

  const CartItem({
    required this.id,
    required this.idProduto,
    required this.idEmpresa,
    required this.name,
    required this.quantity,
    required this.unitValue,
    required this.subtotal,
    required this.additionals,
    required this.observation,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final rawAdditionals = json['adicionais'];
    return CartItem(
      id: _asInt(json['id'] ?? json['idItem']) ?? 0,
      idProduto: _asInt(json['idProduto']) ?? 0,
      idEmpresa: _asInt(json['idEmpresa']) ?? 0,
      name: _asString(json['nome']),
      quantity: _asInt(json['quantidade']) ?? 1,
      unitValue: _asDouble(json['valorUnitario']),
      subtotal: _asDouble(json['subtotal']),
      additionals: rawAdditionals is List
          ? rawAdditionals
              .whereType<Map<String, dynamic>>()
              .map(MarketplaceAdditional.fromJson)
              .toList(growable: false)
          : const <MarketplaceAdditional>[],
      observation: _asNullableString(json['observacao']),
    );
  }
}

class ShoppingCart {
  final int id;
  final int? activeSupplierId;
  final List<CartItem> items;
  final double totalItems;

  const ShoppingCart({
    required this.id,
    required this.activeSupplierId,
    required this.items,
    required this.totalItems,
  });

  bool get isEmpty => items.isEmpty;

  factory ShoppingCart.fromJson(Map<String, dynamic> json) {
    final rawItems = json['itens'];
    return ShoppingCart(
      id: _asInt(json['id']) ?? 0,
      activeSupplierId: _asInt(json['idEmpresa']),
      items: rawItems is List
          ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(CartItem.fromJson)
              .toList(growable: false)
          : const <CartItem>[],
      totalItems: _asDouble(json['totalItens']),
    );
  }
}

Map<String, dynamic> _asMap(Object? value) {
  return value is Map<String, dynamic> ? value : const <String, dynamic>{};
}

List<T> _listOf<T>(
  Object? value,
  T Function(Map<String, dynamic>) parser,
) {
  if (value is! List) return <T>[];
  return value
      .whereType<Map<String, dynamic>>()
      .map(parser)
      .toList(growable: false);
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
}

String _asString(Object? value) => value?.toString().trim() ?? '';

String? _asNullableString(Object? value) {
  final text = _asString(value);
  return text.isEmpty ? null : text;
}

String? _asUrl(Object? value) {
  final text = _asNullableString(value);
  if (text == null) return null;
  final uri = Uri.tryParse(text);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return null;
  }
  return text;
}
