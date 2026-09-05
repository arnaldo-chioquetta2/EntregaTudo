import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:entregatudo/api.dart';
import 'package:entregatudo/features/fornecedor/fornecedor_page.dart';
import 'package:entregatudo/features/home_operational_controller.dart';

void main() {
  HomeOperationalController makeController() {
    final controller = HomeOperationalController();
    controller.setProfileFlags(isMotoboy: false, isFornecedor: true);
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
    expect(find.text('Offline'), findsNWidgets(2));
    expect(find.text('Gestão da loja'), findsOneWidget);
    expect(find.text('Indicadores da loja'), findsOneWidget);
    expect(find.text('Ficar Online'), findsOneWidget);
    expect(find.byTooltip('Configurações'), findsOneWidget);
    expect(find.byTooltip('Preferências de entregadores'), findsOneWidget);
    expect(find.text('Painel do Captador'), findsNothing);
    controller.disposeSession();
  });

  testWidgets('renderiza fornecedor online', (tester) async {
    final controller = makeController()..setFornecedorOnline(true);
    await pumpPage(tester, controller);
    expect(find.text('Online'), findsNWidgets(2));
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
}
