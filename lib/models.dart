class NovaVenda {
  final String hora;
  final String valor;
  final String cliente;
  final int idPed;
  final int idAviso;

  NovaVenda({
    required this.hora,
    required this.valor,
    required this.cliente,
    required this.idPed,
    required this.idAviso,
  });

  factory NovaVenda.fromJson(Map<String, dynamic> json) {
    return NovaVenda(
      hora: json['hora'],
      valor: json['valor'],
      cliente: json['cliente'],
      idPed: json['idPed'],
      idAviso: json['idAviso'],
    );
  }
}

class FornecedorHeartbeatResponse {
  final int modo;
  final int lojasNoRaio;
  final int idLoja;
  final NovaVenda? novaVenda;

  FornecedorHeartbeatResponse({
    required this.modo,
    required this.lojasNoRaio,
    required this.idLoja,
    this.novaVenda,
  });

  factory FornecedorHeartbeatResponse.fromJson(Map<String, dynamic> json) {
    return FornecedorHeartbeatResponse(
      modo: json['modo'] ?? 3,
      lojasNoRaio: json['lojas_no_raio'] ?? 0,
      idLoja: json['id_loja'] ?? 0,
      novaVenda: json['nova_venda'] != null
          ? NovaVenda.fromJson(json['nova_venda'])
          : null,
    );
  }
}
