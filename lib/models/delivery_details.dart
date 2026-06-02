class DeliveryDetails {
  final String? enderIN;
  final String? enderFN;
  final double? dist;
  final double? valor;
  final double? peso;
  final int? modo;
  final int? chamado;
  final int lojasNoRaio;
  final String? fornecedor;
  final String? codigoRetirada;
  final String? codigoColeta;
  final String? codigoConfirmacao;

  DeliveryDetails(
      {this.enderIN,
      this.enderFN,
      this.dist,
      this.valor,
      this.peso,
      this.modo,
      this.chamado,
      required this.lojasNoRaio,
      this.fornecedor,
      this.codigoRetirada,
      this.codigoColeta,
      this.codigoConfirmacao});

  factory DeliveryDetails.fromJson(Map<String, dynamic> json) {
    return DeliveryDetails(
      enderIN: _parseString(json['enderIN']),
      enderFN: _parseString(json['enderFN']),
      dist: _parseDouble(json['dist']),
      valor: _parseDouble(json['valor']),
      peso: _parseDouble(json['peso']),
      modo: _parseInt(json['modo']),
      chamado: _parseInt(json['chamado']),
      lojasNoRaio: _parseInt(json['lojas_no_raio']) ?? 0,
      fornecedor: _parseString(json['fornecedor']),
      codigoRetirada: _parseString(
        json['confirmCode'] ??
            json['codigoRetirada'] ??
            json['codigoFornecedor'],
      ),
      codigoColeta: _parseString(json['codigoColeta']),
      codigoConfirmacao: _parseString(
        json['codigoConfirmacao'] ?? json['codigo_confirmacao'],
      ),
    );
  }

  static String? _parseString(dynamic value) {
    if (value == null) return null;
    return value.toString();
  }

  static int? _parseInt(dynamic value) {
    if (value == null || value == '') return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double? _parseDouble(dynamic value) {
    if (value == null || value == '') return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
