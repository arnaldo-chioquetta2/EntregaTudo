class PaymentProviders {
  PaymentProviders._();

  static const String notreve = 'NOTREVE';
  static const String gambiarraPay = 'GAMBIARRAPAY';

  static String normalize(Object? value) {
    final provider = value?.toString().trim().toUpperCase();
    return provider == gambiarraPay ? gambiarraPay : notreve;
  }
}

class PaymentConfig {
  final String provider;

  const PaymentConfig({required this.provider});

  factory PaymentConfig.fromJson(Map<String, dynamic> json) {
    final data = _nested(json, 'config') ?? _nested(json, 'data') ?? json;
    return PaymentConfig(
      provider: PaymentProviders.normalize(
        data['provider'] ?? data['provedor'],
      ),
    );
  }
}

class PaymentConfirmation {
  final int orderId;
  final int paymentId;
  final String status;
  final String type;
  final double amount;
  final String? provider;
  final String? paymentUrl;
  final String? pixKey;
  final String? pixKeyType;
  final String? qr;
  final String? copyPaste;
  final String? instructions;
  final bool? valueEmbedded;
  final String? expiresAt;
  final String? paidAt;
  final String? reportedAt;

  const PaymentConfirmation({
    required this.orderId,
    required this.paymentId,
    required this.status,
    required this.type,
    required this.amount,
    this.provider,
    this.paymentUrl,
    this.pixKey,
    this.pixKeyType,
    this.qr,
    this.copyPaste,
    this.instructions,
    this.valueEmbedded,
    this.expiresAt,
    this.paidAt,
    this.reportedAt,
  });

  String resolveProvider(PaymentConfig config) =>
      PaymentProviders.normalize(provider ?? config.provider);

  PaymentConfirmation withProvider(String value) => PaymentConfirmation(
        orderId: orderId,
        paymentId: paymentId,
        status: status,
        type: type,
        amount: amount,
        provider: PaymentProviders.normalize(value),
        paymentUrl: paymentUrl,
        pixKey: pixKey,
        pixKeyType: pixKeyType,
        qr: qr,
        copyPaste: copyPaste,
        instructions: instructions,
        valueEmbedded: valueEmbedded,
        expiresAt: expiresAt,
        paidAt: paidAt,
        reportedAt: reportedAt,
      );

  factory PaymentConfirmation.fromJson(Map<String, dynamic> json) {
    final payment =
        _nested(json, 'pagamento') ?? _nested(json, 'payment') ?? json;
    final pix = _nested(payment, 'pix') ??
        _nested(json, 'pix') ??
        const <String, dynamic>{};
    final orderId = _asInt(payment['pedidoId'] ?? json['pedidoId']);
    final paymentId = _asInt(
        payment['paymentId'] ?? payment['pagamentoId'] ?? json['paymentId']);
    final amount =
        _asDouble(payment['valor'] ?? payment['amount'] ?? json['valor']);
    final status = _asNullableString(payment['status'] ?? json['status']);
    final key = _asNullableString(pix['chave'] ?? pix['chavePix']);
    final qr = _asNullableString(pix['qrCode'] ?? pix['qr'] ?? pix['qrUrl']);
    if (orderId == null ||
        paymentId == null ||
        amount == null ||
        status == null) {
      throw const FormatException('confirmacao_pagamento_incompleta');
    }

    return PaymentConfirmation(
      orderId: orderId,
      paymentId: paymentId,
      status: status,
      type: _asNullableString(payment['tipo'] ?? json['tipo']) ?? 'pix',
      amount: amount,
      provider: _asNullableString(
        payment['provider'] ??
            payment['provedor'] ??
            json['provider'] ??
            json['provedor'],
      ),
      paymentUrl: _asNullableString(
        payment['paymentUrl'] ??
            payment['checkoutUrl'] ??
            payment['urlPagamento'],
      ),
      pixKey: key,
      pixKeyType: _asNullableString(pix['tipoChave']),
      qr: qr,
      copyPaste: _asNullableString(pix['copiaECola'] ?? pix['copyPaste']),
      instructions: _asNullableString(pix['instrucoes']),
      valueEmbedded: _asBool(pix['valorEmbutido']),
      expiresAt: _asNullableString(payment['expiraEm'] ?? json['expiraEm']),
      paidAt: _asNullableString(payment['paidAt'] ?? json['paidAt']),
      reportedAt:
          _asNullableString(payment['reportedAt'] ?? json['reportedAt']),
    );
  }
}

class PaymentStatus {
  final int paymentId;
  final String status;
  final String? provider;
  final String? expiresAt;

  const PaymentStatus({
    required this.paymentId,
    required this.status,
    this.provider,
    this.expiresAt,
  });

  factory PaymentStatus.fromJson(Map<String, dynamic> json) {
    final data = _nested(json, 'data') ?? json;
    final id = _asInt(data['paymentId'] ?? data['pagamentoId']);
    final status = _asNullableString(data['status']);
    if (id == null || status == null) {
      throw const FormatException('status_pagamento_incompleto');
    }
    return PaymentStatus(
      paymentId: id,
      status: status,
      provider: _asNullableString(data['provider'] ?? data['provedor']),
      expiresAt: _asNullableString(data['expiraEm']),
    );
  }
}

Map<String, dynamic>? _nested(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is Map<String, dynamic> ? value : null;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll(',', '.') ?? '');
}

String? _asNullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

bool? _asBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
  }
  return null;
}
