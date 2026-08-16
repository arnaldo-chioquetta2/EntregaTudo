class PaymentConfirmation {
  final int orderId;
  final int paymentId;
  final String status;
  final String type;
  final double amount;
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

  factory PaymentConfirmation.fromJson(Map<String, dynamic> json) {
    final pix = _nested(json, 'pix') ?? const <String, dynamic>{};
    final orderId = _asInt(json['pedidoId']);
    final paymentId = _asInt(json['paymentId'] ?? json['pagamentoId']);
    final amount = _asDouble(json['valor']);
    final status = _asNullableString(json['status']);
    final key = _asNullableString(pix['chave'] ?? pix['chavePix']);
    final qr = _asNullableString(pix['qrCode'] ?? pix['qr'] ?? pix['qrUrl']);
    if (orderId == null ||
        paymentId == null ||
        amount == null ||
        status == null) {
      throw const FormatException('confirmacao_pagamento_incompleta');
    }
    if (key == null && qr == null) {
      throw const FormatException('confirmacao_pagamento_sem_meio_pix');
    }
    return PaymentConfirmation(
      orderId: orderId,
      paymentId: paymentId,
      status: status,
      type: _asNullableString(json['tipo']) ?? 'pix',
      amount: amount,
      pixKey: key,
      pixKeyType: _asNullableString(pix['tipoChave']),
      qr: qr,
      copyPaste: _asNullableString(pix['copiaECola'] ?? pix['copyPaste']),
      instructions: _asNullableString(pix['instrucoes']),
      valueEmbedded: _asBool(pix['valorEmbutido']),
      expiresAt: _asNullableString(json['expiraEm']),
      paidAt: _asNullableString(json['paidAt']),
      reportedAt: _asNullableString(json['reportedAt']),
    );
  }
}

class PaymentStatus {
  final int paymentId;
  final String status;

  const PaymentStatus({required this.paymentId, required this.status});

  factory PaymentStatus.fromJson(Map<String, dynamic> json) {
    final id = _asInt(json['paymentId'] ?? json['pagamentoId']);
    final status = _asNullableString(json['status']);
    if (id == null || status == null) {
      throw const FormatException('status_pagamento_incompleto');
    }
    return PaymentStatus(paymentId: id, status: status);
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
