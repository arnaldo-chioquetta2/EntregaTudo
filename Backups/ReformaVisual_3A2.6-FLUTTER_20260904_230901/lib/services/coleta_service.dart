import '../marketplace/api_v1_client.dart';

class ColetaConsulta {
  const ColetaConsulta({required this.idPedido, this.valor});

  final int idPedido;
  final Object? valor;
}

class ColetaService {
  ColetaService({ApiV1Client? api}) : _api = api ?? ApiV1Client();

  final ApiV1Client _api;

  Future<ColetaConsulta> consultarCodigo(String codigo) async {
    final response = await _api.postApi(
      '/coleta/validar',
      body: <String, dynamic>{'codigo': codigo, 'modo': 'consulta'},
    );
    final pedido = response['pedido'];
    if (pedido is! Map) {
      throw const FormatException('Resposta de consulta invalida.');
    }
    final idPedido = int.tryParse(pedido['idPedido']?.toString() ?? '');
    if (idPedido == null) {
      throw const FormatException('Resposta de consulta invalida.');
    }
    return ColetaConsulta(idPedido: idPedido, valor: pedido['valor']);
  }

  Future<void> confirmarCodigo(String codigo) async {
    await _api.postApi(
      '/coleta/validar',
      body: <String, dynamic>{'codigo': codigo, 'modo': 'confirmacao'},
    );
  }
}
