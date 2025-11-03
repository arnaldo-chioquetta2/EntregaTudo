class NovaVenda {
  final String? hora;
  final String? valor;
  final String? cliente;
  final int? idPed;
  final int? idAviso;

  NovaVenda({this.hora, this.valor, this.cliente, this.idPed, this.idAviso});

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
