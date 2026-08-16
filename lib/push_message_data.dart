class PushMessageData {
  final String? type;
  final int? orderId;

  const PushMessageData({this.type, this.orderId});

  factory PushMessageData.fromMap(Map<String, dynamic> data) => PushMessageData(
        type: _string(data['type'] ?? data['event'] ?? data['eventType']),
        orderId: _int(data['pedidoId'] ?? data['orderId']),
      );

  bool get canOpenTracking => orderId != null && orderId! > 0;
}

int? _int(Object? value) => value is int ? value : int.tryParse('$value');
String? _string(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
