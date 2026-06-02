class EntregaAtiva {
  final int idPedido;

  // 🔐 Código mostrado ao fornecedor
  final String codigoRetirada;

  // 🔑 Código digitado pelo cliente
  String? codigoFinalizacaoCliente;

  final String fornecedor;
  final String enderecoFornecedor;
  final String? codigoColeta;
  final int status;

  EntregaAtiva({
    required this.idPedido,
    required this.codigoRetirada,
    required this.fornecedor,
    required this.enderecoFornecedor,
    required this.status,
    this.codigoColeta,
    this.codigoFinalizacaoCliente,
  });

  static int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static String _toString(dynamic value, {String fallback = ''}) {
    final text = value?.toString();
    return text == null || text.isEmpty ? fallback : text;
  }

  static Map<String, dynamic>? _extractPedido(Map<String, dynamic> json) {
    final pedido = json['pedido'] ?? json['data'] ?? json['entrega'];

    if (pedido is Map) {
      return Map<String, dynamic>.from(pedido);
    }

    if (json.containsKey('idPed') ||
        json.containsKey('idPedido') ||
        json.containsKey('chamado')) {
      return json;
    }

    return null;
  }

  static bool canParse(Map<String, dynamic> json) {
    return _extractPedido(json) != null;
  }

  factory EntregaAtiva.fromJson(Map<String, dynamic> json) {
    final pedido = _extractPedido(json);

    if (pedido == null) {
      throw FormatException('Resposta de entrega ativa sem dados do pedido.');
    }

    return EntregaAtiva(
      idPedido: _toInt(
        pedido['idPed'] ?? pedido['idPedido'] ?? pedido['chamado'],
      ),
      codigoRetirada: _toString(
        pedido['confirmCode'] ??
            pedido['codigoRetirada'] ??
            pedido['codigoFornecedor'] ??
            pedido['codigoColeta'],
      ),
      fornecedor: _toString(pedido['fornecedor']),
      enderecoFornecedor:
          _toString(pedido['enderecoFornecedor'] ?? pedido['enderIN']),
      codigoColeta: pedido['codigoColeta']?.toString(),
      status: _toInt(pedido['status']),
    );
  }
}
