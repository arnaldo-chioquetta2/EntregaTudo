import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:entregatudo/features/fornecedor/fornecedor_availability.dart';
import 'package:entregatudo/features/fornecedor/fornecedor_page.dart';
import 'package:entregatudo/features/home_operational_controller.dart';
import 'package:entregatudo/marketplace/api_v1_client.dart';

class _AvailabilityClient extends http.BaseClient {
  _AvailabilityClient(this.response);

  final Map<String, dynamic> response;
  Uri? requestedUri;
  Map<String, String>? requestedHeaders;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestedUri = request.url;
    requestedHeaders = request.headers;
    final body = jsonEncode(response);
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'authToken': 'test-token'});
  });

  test('service consulta disponibilidade usando GET autenticado', () async {
    final client = _AvailabilityClient({
      'success': true,
      'data': {
        'tipo': 'HORARIO',
        'disponivel': true,
        'origem': 'HORARIO',
      },
    });
    final service = FornecedorDisponibilidadeService(
      client: ApiV1Client(client: client, onUnauthorized: () async {}),
    );

    final result = await service.fetch();

    expect(result.tipo, TipoFornecedor.horario);
    expect(result.disponivel, isTrue);
    expect(client.requestedUri.toString(),
        'https://teletudo.com/api/fornecedor/disponibilidade');
    expect(client.requestedHeaders?['authorization'], 'Bearer test-token');
  });

  test('controller carrega disponibilidade uma vez por sessao', () async {
    var calls = 0;
    final controller = HomeOperationalController(
      loadFornecedorDisponibilidade: () async {
        calls++;
        return const FornecedorDisponibilidade(
          tipo: TipoFornecedor.manual,
          disponivel: false,
          origem: 'MANUAL',
        );
      },
    );

    await Future.wait([
      controller.loadFornecedorDisponibilidade(),
      controller.loadFornecedorDisponibilidade(),
    ]);
    await controller.loadFornecedorDisponibilidade();

    expect(calls, 1);
    expect(controller.tipoFornecedor, TipoFornecedor.manual);
    expect(controller.fornecedorDisponivelComercialmente, isFalse);
    expect(controller.fornecedorDisponibilidadeLoading, isFalse);
    controller.disposeSession();
  });

  test('erro de disponibilidade e sanitizado e nao repete consulta', () async {
    var calls = 0;
    final controller = HomeOperationalController(
      loadFornecedorDisponibilidade: () async {
        calls++;
        throw StateError('internal response body');
      },
    );

    await controller.loadFornecedorDisponibilidade();
    await controller.loadFornecedorDisponibilidade();

    expect(calls, 1);
    expect(controller.fornecedorDisponibilidadeError,
        'Nao foi possivel consultar a disponibilidade comercial.');
    controller.disposeSession();
  });

  Future<void> pumpPage(
    WidgetTester tester,
    HomeOperationalController controller,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: FornecedorPage(controller: controller)),
    );
    await tester.pump();
  }

  testWidgets('HORARIO mostra disponibilidade comercial separada do app',
      (tester) async {
    final controller = HomeOperationalController();
    controller.setProfileFlags(isMotoboy: false, isFornecedor: true);
    controller.tipoFornecedor = TipoFornecedor.horario;
    controller.fornecedorDisponivelComercialmente = true;
    controller.fornecedorOnline = false;

    await pumpPage(tester, controller);

    expect(find.text('Funcionamento por horário'), findsOneWidget);
    expect(find.text('Loja disponível agora'), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Ficar Online'), findsOneWidget);
    controller.disposeSession();
  });

  testWidgets('HORARIO indisponivel nao transforma estado do app em horario',
      (tester) async {
    final controller = HomeOperationalController();
    controller.setProfileFlags(isMotoboy: false, isFornecedor: true);
    controller.tipoFornecedor = TipoFornecedor.horario;
    controller.fornecedorDisponivelComercialmente = false;
    controller.fornecedorOnline = true;

    await pumpPage(tester, controller);

    expect(find.text('Loja fora do horário agora'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Ficar Offline'), findsOneWidget);
    controller.disposeSession();
  });

  testWidgets('MANUAL mantém contexto operacional do recebimento',
      (tester) async {
    final controller = HomeOperationalController();
    controller.setProfileFlags(isMotoboy: false, isFornecedor: true);
    controller.tipoFornecedor = TipoFornecedor.manual;
    controller.fornecedorDisponivelComercialmente = true;
    controller.fornecedorOnline = true;

    await pumpPage(tester, controller);

    expect(find.text('Gestão da loja'), findsOneWidget);
    expect(find.text('Recebimento de vendas pelo aplicativo'), findsOneWidget);
    expect(find.text('Estado operacional do aplicativo'), findsOneWidget);
    expect(find.text('Ficar Offline'), findsOneWidget);
    controller.disposeSession();
  });

  testWidgets('erro comercial nao bloqueia CTA operacional', (tester) async {
    final controller = HomeOperationalController();
    controller.setProfileFlags(isMotoboy: false, isFornecedor: true);
    controller.fornecedorDisponibilidadeError = 'erro sanitizado';

    await pumpPage(tester, controller);

    expect(find.text('Disponibilidade comercial indisponível no momento.'),
        findsOneWidget);
    expect(find.text('Ficar Online'), findsOneWidget);
    controller.disposeSession();
  });
}
