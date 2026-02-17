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

  factory EntregaAtiva.fromJson(Map<String, dynamic> json) {
    final pedido = json['pedido'];

    return EntregaAtiva(
      idPedido: pedido['idPed'],
      codigoRetirada: pedido['confirmCode'].toString(),
      fornecedor: pedido['fornecedor'] ?? '',
      enderecoFornecedor: pedido['enderecoFornecedor'] ?? '',
      codigoColeta: pedido['codigoColeta'],
      status: pedido['status'],
    );
  }
}
