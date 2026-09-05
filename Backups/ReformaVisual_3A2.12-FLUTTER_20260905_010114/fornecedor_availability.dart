import '../../marketplace/api_v1_client.dart';

enum TipoFornecedor {
  horario,
  manual,
}

class FornecedorDisponibilidade {
  const FornecedorDisponibilidade({
    required this.tipo,
    required this.disponivel,
    required this.origem,
  });

  final TipoFornecedor tipo;
  final bool disponivel;
  final String origem;

  factory FornecedorDisponibilidade.fromJson(Map<String, dynamic> json) {
    final tipoTexto = (json['tipo'] ?? '').toString().toUpperCase();
    final tipo = switch (tipoTexto) {
      'HORARIO' => TipoFornecedor.horario,
      'MANUAL' => TipoFornecedor.manual,
      _ => throw const FormatException('Tipo de fornecedor invalido.'),
    };
    final disponivel = json['disponivel'];
    if (disponivel is! bool) {
      throw const FormatException('Disponibilidade invalida.');
    }
    final origem = (json['origem'] ?? '').toString().toUpperCase();
    if (origem != tipoTexto) {
      throw const FormatException('Origem de disponibilidade invalida.');
    }
    return FornecedorDisponibilidade(
      tipo: tipo,
      disponivel: disponivel,
      origem: origem,
    );
  }
}

class FornecedorDisponibilidadeService {
  FornecedorDisponibilidadeService({ApiV1Client? client})
      : _client = client ?? ApiV1Client();

  final ApiV1Client _client;

  Future<FornecedorDisponibilidade> fetch() async {
    final response = await _client.getApi('/fornecedor/disponibilidade');
    final data = response['data'];
    if (data is! Map) {
      throw const FormatException('Dados de disponibilidade ausentes.');
    }
    return FornecedorDisponibilidade.fromJson(
      Map<String, dynamic>.from(data),
    );
  }
}
