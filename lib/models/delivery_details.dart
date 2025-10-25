class DeliveryDetails {
  final String? enderIN;
  final String? enderFN;
  final double? dist;
  final double? valor;
  final double? peso;
  final int? modo;
  final int? chamado;
  final int lojasNoRaio;

  DeliveryDetails(
      {this.enderIN,
      this.enderFN,
      this.dist,
      this.valor,
      this.peso,
      this.modo,
      this.chamado,
      required this.lojasNoRaio});

  factory DeliveryDetails.fromJson(Map<String, dynamic> json) {
    return DeliveryDetails(
      enderIN: json['enderIN'],
      enderFN: json['enderFN'],
      dist: _parseDouble(json['dist']),
      valor: _parseDouble(json['valor']),
      peso: _parseDouble(json['peso']),
      modo: json['modo'],
      chamado: json['chamado'],
      lojasNoRaio: json['lojas_no_raio'] ?? 0, 
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == '') return null;
    return (value is String ? double.tryParse(value) : value)?.toDouble();
  }
}
