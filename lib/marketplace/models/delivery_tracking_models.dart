class DeliveryTracking {
  final int orderId;
  final int? deliveryId;
  final String? paymentStatus;
  final String? deliveryStatus;
  final bool canCancel;
  final DeliveryDriver? driver;
  final DeliveryVehicle? vehicle;
  final String? contact;
  final DeliveryLocation? location;
  final String? collectedAt;
  final String? deliveredAt;
  final String? updatedAt;
  final String? confirmationCode;

  const DeliveryTracking({
    required this.orderId,
    this.deliveryId,
    this.paymentStatus,
    this.deliveryStatus,
    required this.canCancel,
    this.driver,
    this.vehicle,
    this.contact,
    this.location,
    this.collectedAt,
    this.deliveredAt,
    this.updatedAt,
    this.confirmationCode,
  });

  factory DeliveryTracking.fromJson(Map<String, dynamic> json) {
    final delivery = _map(json['entrega']) ?? json;
    final driver = _map(delivery['entregador'] ?? delivery['driver']);
    final vehicle = _map(delivery['veiculo'] ?? delivery['vehicle']);
    final location = _map(delivery['localizacao'] ?? delivery['location']);
    return DeliveryTracking(
      orderId: _int(json['pedidoId'] ?? delivery['pedidoId']) ?? 0,
      deliveryId: _int(delivery['entregaId'] ?? delivery['idEntrega']),
      paymentStatus:
          _string(json['paymentStatus'] ?? delivery['paymentStatus']),
      deliveryStatus: _string(json['deliveryStatus'] ??
          delivery['status'] ??
          delivery['deliveryStatus']),
      canCancel: _bool(json['canCancel'] ?? delivery['canCancel']) ?? false,
      driver: driver == null ? null : DeliveryDriver.fromJson(driver),
      vehicle: vehicle == null ? null : DeliveryVehicle.fromJson(vehicle),
      contact: _string(
          delivery['contato'] ?? delivery['telefone'] ?? delivery['phone']),
      location: location == null ? null : DeliveryLocation.fromJson(location),
      collectedAt: _string(delivery['coletadoEm'] ?? delivery['collectedAt']),
      deliveredAt: _string(delivery['entregueEm'] ?? delivery['deliveredAt']),
      updatedAt: _string(json['updatedAt'] ?? delivery['updatedAt']),
      confirmationCode: _string(
        json['codigo_confirmacao_cliente'] ??
            json['codigoConfirmacaoCliente'] ??
            json['codigo_confirmacao'] ??
            json['codigoConfirmacao'] ??
            delivery['codigo_confirmacao_cliente'] ??
            delivery['codigoConfirmacaoCliente'] ??
            delivery['codigo_confirmacao'] ??
            delivery['codigoConfirmacao'],
      ),
    );
  }
}

class DeliveryDriver {
  final String? name;
  const DeliveryDriver({this.name});
  factory DeliveryDriver.fromJson(Map<String, dynamic> json) =>
      DeliveryDriver(name: _string(json['nome'] ?? json['name']));
}

class DeliveryVehicle {
  final String? description;
  final String? plate;
  const DeliveryVehicle({this.description, this.plate});
  factory DeliveryVehicle.fromJson(Map<String, dynamic> json) =>
      DeliveryVehicle(
        description: _string(
            json['descricao'] ?? json['description'] ?? json['veiculo']),
        plate: _string(json['placa'] ?? json['plate']),
      );
}

class DeliveryLocation {
  final double? latitude;
  final double? longitude;
  const DeliveryLocation({this.latitude, this.longitude, this.updatedAt});
  final String? updatedAt;

  bool get isValid =>
      latitude != null &&
      longitude != null &&
      latitude! >= -90 &&
      latitude! <= 90 &&
      longitude! >= -180 &&
      longitude! <= 180 &&
      !(latitude == 0 && longitude == 0);
  factory DeliveryLocation.fromJson(Map<String, dynamic> json) =>
      DeliveryLocation(
        latitude: _double(json['latitude'] ?? json['lat']),
        longitude: _double(json['longitude'] ?? json['lng'] ?? json['lon']),
        updatedAt: _string(json['updatedAt'] ?? json['atualizadoEm']),
      );
}

Map<String, dynamic>? _map(Object? value) =>
    value is Map<String, dynamic> ? value : null;

int? _int(Object? value) => value is int ? value : int.tryParse('$value');
double? _double(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value');
String? _string(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

bool? _bool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value == 'true' || value == '1';
  return null;
}
