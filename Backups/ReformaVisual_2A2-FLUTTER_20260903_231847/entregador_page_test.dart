import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:entregatudo/features/entregador/entregador_page.dart';
import 'package:entregatudo/features/home_operational_controller.dart';
import 'package:entregatudo/models/entrega_ativa.dart';

void main() {
  HomeOperationalController makeController() {
    final value = HomeOperationalController();
    value.setProfileFlags(isMotoboy: true, isFornecedor: false);
    return value;
  }

  Future<void> pumpPage(
      WidgetTester tester, HomeOperationalController controller) async {
    await tester.pumpWidget(
      MaterialApp(home: EntregadorPage(controller: controller)),
    );
    await tester.pump();
  }

  testWidgets('renderiza offline, configuracoes e sem Captador duplicado',
      (tester) async {
    final controller = makeController();
    await pumpPage(tester, controller);
    expect(find.text('Offline'), findsNWidgets(2));
    expect(find.text('Ficar Online'), findsOneWidget);
    expect(find.byTooltip('Configura??es'), findsOneWidget);
    expect(find.text('Painel do Captador'), findsNothing);
    controller.disposeSession();
  });

  testWidgets('renderiza online', (tester) async {
    final controller = makeController()..setMotoboyOnline(true);
    await pumpPage(tester, controller);
    expect(find.text('Online'), findsNWidgets(2));
    expect(find.text('Ficar Offline'), findsOneWidget);
    controller.disposeSession();
  });

  testWidgets('CTA delega a mudan?a de disponibilidade', (tester) async {
    final controller = makeController();
    bool? requested;
    await tester.pumpWidget(MaterialApp(
      home: EntregadorPage(
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

  testWidgets('renderiza oferta e entrega ativa do controller', (tester) async {
    final controller = makeController();
    controller.deliveryDataMotoboy = {
      'enderIN': 'Origem',
      'enderFN': 'Destino',
      'dist': 2.5,
      'valor': 12.0,
      'peso': 1.0,
    };
    await pumpPage(tester, controller);
    expect(find.text('Nova oferta de entrega'), findsOneWidget);
    expect(find.text('Origem'), findsNWidgets(2));
    expect(find.text('Destino'), findsNWidgets(2));

    controller.deliveryDataMotoboy = null;
    controller.entregaAtiva = EntregaAtiva(
      idPedido: 10,
      codigoRetirada: 'retirada',
      fornecedor: 'Fornecedor',
      enderecoFornecedor: 'Endereco',
      status: 1,
    );
    controller.notifyListeners();
    await tester.pump();
    expect(find.text('Entrega ativa'), findsNWidgets(2));
    expect(find.textContaining('Pedido #10'), findsOneWidget);
    controller.disposeSession();
  });

  testWidgets('renderiza estado vazio sem oferta ou entrega', (tester) async {
    final controller = makeController();
    await pumpPage(tester, controller);
    expect(find.text('Nenhuma entrega no momento'), findsOneWidget);
    controller.disposeSession();
  });
}
