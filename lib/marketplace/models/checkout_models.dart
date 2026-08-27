class DeliveryAddress {
  final String type;
  final int? id;
  final String cep;
  final String logradouro;
  final String numero;
  final String complemento;
  final String bairro;
  final String cidade;
  final String uf;
  final double? latitude;
  final double? longitude;
  final String formatado;

  const DeliveryAddress({
    required this.type,
    required this.id,
    required this.cep,
    required this.logradouro,
    required this.numero,
    required this.complemento,
    required this.bairro,
    required this.cidade,
    required this.uf,
    required this.latitude,
    required this.longitude,
    required this.formatado,
  });

  bool get isTemporary => type == 'temporario';

  factory DeliveryAddress.fromJson(Map<String, dynamic> json) {
    return DeliveryAddress(
      type: _string(json['tipo']),
      id: _int(json['id']),
      cep: _string(json['cep']),
      logradouro: _string(json['logradouro']),
      numero: _string(json['numero']),
      complemento: _string(json['complemento']),
      bairro: _string(json['bairro']),
      cidade: _string(json['cidade']),
      uf: _string(json['uf']),
      latitude: _doubleOrNull(json['latitude']),
      longitude: _doubleOrNull(json['longitude']),
      formatado: _string(json['formatado']),
    );
  }

  Map<String, dynamic> toTemporaryPayload() => <String, dynamic>{
        'tipo': 'temporario',
        'cep': cep,
        'numero': numero,
        'complemento': complemento,
      };

  String get displayText {
    if (formatado.isNotEmpty) return formatado;
    final line = [
      if (logradouro.isNotEmpty) logradouro,
      if (numero.isNotEmpty) numero,
      if (complemento.isNotEmpty) complemento,
    ].join(', ');
    final place = [
      if (bairro.isNotEmpty) bairro,
      if (cidade.isNotEmpty) cidade,
      if (uf.isNotEmpty) uf,
    ].join(' - ');
    return [line, place].where((value) => value.isNotEmpty).join(' | ');
  }
}

class CheckoutQuote {
  final int? orderId;
  final List<Map<String, dynamic>> products;
  final double deliveryValue;
  final double taxaSistema;
  final double itemsTotal;
  final double total;
  final DeliveryAddress? deliveryAddress;
  final bool canConfirm;
  final String status;

  const CheckoutQuote({
    required this.orderId,
    required this.products,
    required this.deliveryValue,
    required this.taxaSistema,
    required this.itemsTotal,
    required this.total,
    required this.deliveryAddress,
    required this.canConfirm,
    required this.status,
  });

  factory CheckoutQuote.fromJson(Map<String, dynamic> json) {
    final rawProducts = json['produtos'];
    final rawDelivery = json['entrega'];
    final products = rawProducts is List
        ? rawProducts.whereType<Map<String, dynamic>>().toList(growable: false)
        : const <Map<String, dynamic>>[];
    return CheckoutQuote(
      orderId: _int(json['pedidoId']),
      products: products,
      taxaSistema: _moneyOrZero(json['taxaSistema'] ?? json['taxa_sistema']),
      itemsTotal: _requiredMoney(
        rawProducts is num || rawProducts is String
            ? rawProducts
            : json['totalItens'] ?? json['subtotal'],
        'produtos',
      ),
      deliveryValue: _requiredMoney(
        rawDelivery is num || rawDelivery is String
            ? rawDelivery
            : _map(rawDelivery)['valor'] ??
                _map(rawDelivery)['valorEntrega'] ??
                json['valorEntrega'] ??
                json['frete'],
        'entrega',
      ),
      total: _requiredMoney(json['total'] ?? json['totalGeral'], 'total'),
      deliveryAddress: _mapOrNull(json['enderecoEntrega']) == null
          ? null
          : DeliveryAddress.fromJson(_map(json['enderecoEntrega'])),
      canConfirm: json['canConfirm'] == true,
      status: _string(json['status']),
    );
  }
}

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const <String, dynamic>{};
Map<String, dynamic>? _mapOrNull(Object? value) =>
    value is Map<String, dynamic> ? value : null;
String _string(Object? value) => value?.toString().trim() ?? '';
int? _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(_string(value));
}

double _double(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(_string(value).replaceAll(',', '.')) ?? 0;
}

double _requiredMoney(Object? value, String field) {
  if (value is num) return value.toDouble();
  final text = _string(value).replaceAll(',', '.');
  final parsed = double.tryParse(text);
  if (parsed == null) {
    throw FormatException('Campo financeiro invalido: ');
  }
  return parsed;
}

double _moneyOrZero(Object? value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(_string(value).replaceAll(',', '.')) ?? 0;
}

double? _doubleOrNull(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(_string(value).replaceAll(',', '.'));
}
