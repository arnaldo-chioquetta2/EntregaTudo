import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:entregatudo/api.dart';
import 'package:entregatudo/features/fornecedor/fornecedor_availability.dart';
import 'package:entregatudo/features/fornecedor/fornecedor_page.dart';
import 'package:entregatudo/features/home_operational_controller.dart';
import 'package:entregatudo/services/coleta_service.dart';
import 'package:entregatudo/marketplace/api_v1_error.dart';

class _FakeColetaService extends ColetaService {
  _FakeColetaService({this.consulta, this.error});

  final ColetaConsulta? consulta;
  final ApiV1Exception? error;
  int consultationCalls = 0;
  int confirmationCalls = 0;
  String? lastCode;

  @override
  Future<ColetaConsulta> consultarCodigo(String codigo) async {
    consultationCalls++;
    lastCode = codigo;
    if (error != null) throw error!;
    return consulta!;
  }

  @override
  Future<void> confirmarCodigo(String codigo) async {
    confirmationCalls++;
    lastCode = codigo;
    if (error != null) throw error!;
  }
}

void main() {
  HomeOperationalController makeController() {
    final controller = HomeOperationalController();
    controller.setProfileFlags(isMotoboy: false, isFornecedor: true);
    controller.tipoFornecedor = TipoFornecedor.manual;
    controller.fornecedorDisponivelComercialmente = true;
    return controller;
  }

  Future<void> pumpPage(
      WidgetTester tester, HomeOperationalController controller) async {
    await tester.pumpWidget(
      MaterialApp(home: FornecedorPage(controller: controller)),
    );
    await tester.pump();
  }

  testWidgets('renderiza fornecedor offline e acessos', (tester) async {
    final controller = makeController();
    await pumpPage(tester, controller);
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Gestão da loja'), findsOneWidget);
    expect(find.text('Recebimento de vendas pelo aplicativo'), findsOneWidget);
    expect(find.text('Lojas no raio'), findsNothing);
    expect(find.text('Entregadores no raio'), findsNothing);
    expect(find.text('Itens na venda'), findsNothing);
    expect(find.text('Status'), findsNothing);
    expect(find.text('Ficar Online'), findsOneWidget);
    expect(find.byTooltip('Configurações'), findsOneWidget);
    expect(find.byTooltip('Preferências de entregadores'), findsOneWidget);
    expect(find.text('Painel do Captador'), findsNothing);
    controller.disposeSession();
  });

  testWidgets('renderiza fornecedor online', (tester) async {
    final controller = makeController()..setFornecedorOnline(true);
    await pumpPage(tester, controller);
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Ficar Offline'), findsOneWidget);
    controller.disposeSession();
  });

  testWidgets('CTA delega mudança de disponibilidade', (tester) async {
    final controller = makeController();
    bool? requested;
    await tester.pumpWidget(MaterialApp(
      home: FornecedorPage(
        controller: controller,
        onAvailabilityChanged: (online) async => requested = online,
      ),
    ));
    await tester.pump();
    await tester.tap(find.text('Ficar Online'));
    await tester.pump();
    expect(requested, isTrue);
    controller.disposeSession();
  });

  testWidgets('renderiza estado vazio sem venda', (tester) async {
    final controller = makeController();
    await pumpPage(tester, controller);
    expect(find.text('Nenhuma venda no momento'), findsOneWidget);
    controller.disposeSession();
  });

  testWidgets('renderiza venda e itens do controller', (tester) async {
    final controller = makeController();
    controller.novaVenda = NovaVenda(
      hora: '10:00',
      valor: '20,00',
      cliente: 'Cliente',
      idPed: 15,
      idAviso: 25,
    );
    controller.itensVenda = [ItemVenda(produto: 'Produto', quantidade: 2)];
    await pumpPage(tester, controller);
    expect(find.text('Nova venda'), findsOneWidget);
    expect(find.text('Pedido #15'), findsOneWidget);
    expect(find.text('Produto'), findsOneWidget);
    expect(find.text('Confirmar venda'), findsOneWidget);
    expect(find.text('Recusar'), findsOneWidget);
    controller.disposeSession();
  });

  testWidgets('confirmar venda delega ao controller uma vez', (tester) async {
    var calls = 0;
    final controller = HomeOperationalController(
      confirmSupplierSale: (idAviso, idPed) async {
        calls++;
        expect(idAviso, 25);
        expect(idPed, 15);
        return true;
      },
    );
    controller.setProfileFlags(isMotoboy: false, isFornecedor: true);
    controller.novaVenda = NovaVenda(
      hora: '10:00',
      valor: '20,00',
      cliente: 'Cliente',
      idPed: 15,
      idAviso: 25,
    );
    await pumpPage(tester, controller);
    final confirmButton = find.ancestor(
      of: find.text('Confirmar venda'),
      matching: find.byType(FilledButton),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
    await tester.tap(confirmButton);
    await tester.pump();
    expect(calls, 1);
    expect(controller.heartbeatPausedBySale, isTrue);
    controller.disposeSession();
  });

  testWidgets('confirma retirada em duas etapas sem expor o codigo',
      (tester) async {
    final controller = makeController();
    controller.novaVenda = NovaVenda(
      hora: '10:00',
      valor: '20,00',
      cliente: 'Cliente',
      idPed: 15,
      idAviso: 25,
    );
    final service = _FakeColetaService(
      consulta: const ColetaConsulta(idPedido: 15, valor: 20),
    );
    await tester.pumpWidget(MaterialApp(
      home: FornecedorPage(controller: controller, coletaService: service),
    ));
    await tester.pump();
    final pickupButton =
        find.widgetWithText(OutlinedButton, 'Confirmar retirada');
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
    await tester.tap(pickupButton);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('Validar codigo'));
    await tester.pumpAndSettle();
    expect(service.consultationCalls, 1);
    expect(find.text('Codigo valido para o pedido #15.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar retirada'));
    await tester.pumpAndSettle();
    expect(service.confirmationCalls, 1);
    expect(service.lastCode, '1234');
    expect(find.text('Retirada confirmada.'), findsAtLeastNWidgets(1));
    controller.disposeSession();
  });

  testWidgets('codigo de retirada aceita somente quatro digitos',
      (tester) async {
    final controller = makeController();
    controller.novaVenda = NovaVenda(
      hora: '10:00',
      valor: '20,00',
      cliente: 'Cliente',
      idPed: 15,
      idAviso: 25,
    );
    final service = _FakeColetaService(
      consulta: const ColetaConsulta(idPedido: 15),
    );
    await tester.pumpWidget(MaterialApp(
      home: FornecedorPage(controller: controller, coletaService: service),
    ));
    await tester.pump();
    final pickupButton =
        find.widgetWithText(OutlinedButton, 'Confirmar retirada');
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
    await tester.tap(pickupButton);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '12ab3456');
    expect(find.text('1234'), findsOneWidget);
    controller.disposeSession();
  });

  testWidgets('erro 404 da consulta vira mensagem amigavel', (tester) async {
    final controller = makeController();
    controller.novaVenda = NovaVenda(
      hora: '10:00',
      valor: '20,00',
      cliente: 'Cliente',
      idPed: 15,
      idAviso: 25,
    );
    final service = _FakeColetaService(
      error: const ApiV1Exception(ApiV1Error(
        statusCode: 404,
        message: 'internal response body must not be shown',
      )),
    );
    await tester.pumpWidget(MaterialApp(
      home: FornecedorPage(controller: controller, coletaService: service),
    ));
    await tester.pump();
    final pickupButton =
        find.widgetWithText(OutlinedButton, 'Confirmar retirada');
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
    await tester.tap(pickupButton);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('Validar codigo'));
    await tester.pumpAndSettle();
    expect(find.text('Codigo de coleta nao encontrado.'), findsOneWidget);
    expect(find.text('internal response body must not be shown'), findsNothing);
    controller.disposeSession();
  });
}
