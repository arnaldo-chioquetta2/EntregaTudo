import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:entregatudo/models/delivery_details.dart';
import 'package:entregatudo/api.dart';
import 'package:entregatudo/features/home_operational_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('mantem flags independentes para entregador e fornecedor', () {
    final controller = HomeOperationalController();

    expect(controller.motoboyOnline, isFalse);
    expect(controller.fornecedorOnline, isFalse);

    controller.setMotoboyOnline(true);
    controller.setFornecedorOnline(true);

    expect(controller.motoboyOnline, isTrue);
    expect(controller.fornecedorOnline, isTrue);

    controller.disposeSession();
  });

  test('mantem um unico timer e cancela o anterior', () {
    final controller = HomeOperationalController();
    var firstTicked = false;
    var secondTicked = false;
    final first = Timer(const Duration(milliseconds: 10), () {
      firstTicked = true;
    });
    final second = Timer(const Duration(milliseconds: 10), () {
      secondTicked = true;
    });

    controller.setHeartbeatTimer(first);
    controller.setHeartbeatTimer(second);

    expect(controller.heartbeatTimer, same(second));
    expect(first.isActive, isFalse);

    controller.disposeSession();
    expect(controller.heartbeatTimer, isNull);
    expect(firstTicked, isFalse);
    expect(secondTicked, isFalse);
  });

  test('disposeSession e idempotente', () {
    final controller = HomeOperationalController();

    controller.disposeSession();
    controller.disposeSession();

    expect(controller.motoboyTrackingActive, isFalse);
  });

  test('controller uses fallback and injected heartbeat', () async {
    SharedPreferences.setMockInitialValues({'idUser': 7});
    final calls = <List<double>>[];
    final controller = HomeOperationalController(
      motoboyHeartbeat: (lat, lon) async {
        calls.add([lat, lon]);
        return null;
      },
    );
    controller.setProfileFlags(isMotoboy: true, isFornecedor: false);
    controller.locationService.ultimaPosicao = null;

    await controller.sendMotoboyHeartbeatFromCurrentPosition();

    expect(calls, [
      [-30.1165, -51.1355],
    ]);
    controller.disposeSession();
  });

  test('controller stores delivery and reports a new call once', () async {
    SharedPreferences.setMockInitialValues({'idUser': 12});
    var reports = 0;
    final details = DeliveryDetails(
      chamado: 77,
      lojasNoRaio: 3,
      valor: 10,
      dist: 2,
      peso: 1,
      enderIN: 'origin',
      enderFN: 'destination',
    );
    final controller = HomeOperationalController(
      motoboyHeartbeat: (_, __) async => details,
      reportDeliveryView: (_, chamado) async {
        expect(chamado, 77);
        reports++;
      },
    );
    controller.setProfileFlags(isMotoboy: true, isFornecedor: false);

    await controller.sendMotoboyHeartbeat(1, 2);
    await controller.sendMotoboyHeartbeat(3, 4);

    expect(controller.currentChamado, 77);
    expect(controller.deliveryDataMotoboy?['chamado'], 77);
    expect(controller.heartbeatPausedByDelivery, isTrue);
    expect(reports, 1);
    controller.disposeSession();
  });

  test('controller clears invalid delivery offer', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = HomeOperationalController(
      motoboyHeartbeat: (_, __) async => DeliveryDetails(
        chamado: null,
        lojasNoRaio: 0,
      ),
    );
    controller.setProfileFlags(isMotoboy: true, isFornecedor: false);
    controller.deliveryDataMotoboy = {'chamado': 10};

    await controller.sendMotoboyHeartbeat(1, 2);

    expect(controller.deliveryDataMotoboy, isNull);
    controller.disposeSession();
  });

  test('controller prevents concurrent motoboy heartbeats', () async {
    SharedPreferences.setMockInitialValues({});
    final release = Completer<DeliveryDetails?>();
    var calls = 0;
    final controller = HomeOperationalController(
      motoboyHeartbeat: (_, __) {
        calls++;
        return release.future;
      },
    );
    controller.setProfileFlags(isMotoboy: true, isFornecedor: false);

    final first = controller.sendMotoboyHeartbeat(1, 2);
    await Future<void>.delayed(Duration.zero);
    final second = await controller.sendMotoboyHeartbeat(3, 4);

    expect(second, isFalse);
    expect(calls, 1);
    release.complete(null);
    await first;
    controller.disposeSession();
  });

  test('controller rejects heartbeat after session disposal', () async {
    var calls = 0;
    final controller = HomeOperationalController(
      motoboyHeartbeat: (_, __) async {
        calls++;
        return null;
      },
    );
    controller.setProfileFlags(isMotoboy: true, isFornecedor: false);
    controller.disposeSession();

    final result = await controller.sendMotoboyHeartbeat(1, 2);

    expect(result, isFalse);
    expect(calls, 0);
  });
  test('heartbeat Fornecedor usa a dependência injetada e atualiza o estado',
      () async {
    SharedPreferences.setMockInitialValues({'idUser': 1, 'idLoja': 8});
    var calls = 0;
    final controller = HomeOperationalController(
      fornecedorHeartbeat: (_, __) async {
        calls++;
        return FornecedorHeartbeatResponse(
          lojasNoRaio: 2,
          idLoja: 8,
          modo: 1,
          processingTime: 1,
          novaVenda: NovaVenda(
            hora: '10:00',
            valor: '20,00',
            cliente: 'cliente',
            idPed: 15,
            idAviso: 25,
          ),
          itensVenda: [ItemVenda(produto: 'item', quantidade: 1)],
        );
      },
    );
    controller.setProfileFlags(isMotoboy: false, isFornecedor: true);

    final result = await controller.sendFornecedorHeartbeat(1, 2);

    expect(result, isTrue);
    expect(calls, 1);
    expect(controller.fornecedorOnline, isFalse);
    expect(controller.currentSupplierSale?['idPed'], 15);
    expect(controller.deliveryDataFornecedor?['idLoja'], 8);
    controller.disposeSession();
  });

  test('nova venda do Fornecedor notifica uma vez e preserva estado', () async {
    SharedPreferences.setMockInitialValues({});
    var events = 0;
    final sale = NovaVenda(
      hora: '10:00',
      valor: '20,00',
      cliente: 'cliente',
      idPed: 15,
      idAviso: 25,
    );
    final response = FornecedorHeartbeatResponse(
      lojasNoRaio: 1,
      idLoja: 8,
      modo: 1,
      processingTime: 1,
      novaVenda: sale,
      itensVenda: [ItemVenda(produto: 'item', quantidade: 1)],
    );
    final controller = HomeOperationalController(
      fornecedorHeartbeat: (_, __) async => response,
      onNewSale: (_, __) async => events++,
    );
    controller.setProfileFlags(isMotoboy: false, isFornecedor: true);

    await controller.sendFornecedorHeartbeat(1, 2);
    await controller.sendFornecedorHeartbeat(1, 2);

    expect(events, 1);
    expect(controller.novaVenda, same(sale));
    expect(controller.itensVenda, hasLength(1));
    controller.disposeSession();
  });

  test('resposta sem venda limpa o estado transitório', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = HomeOperationalController(
      fornecedorHeartbeat: (_, __) async => FornecedorHeartbeatResponse(
        lojasNoRaio: 0,
        idLoja: 8,
        modo: 1,
        processingTime: 1,
        itensVenda: const [],
      ),
    );
    controller.setProfileFlags(isMotoboy: false, isFornecedor: true);
    controller.novaVenda = NovaVenda(
      hora: '10:00',
      valor: '20,00',
      cliente: 'cliente',
      idPed: 15,
      idAviso: 25,
    );

    await controller.sendFornecedorHeartbeat(1, 2);

    expect(controller.novaVenda, isNull);
    expect(controller.itensVenda, isEmpty);
    controller.disposeSession();
  });

  test('fornecedorOff é delegado sem alterar o contrato', () async {
    int? receivedStore;
    final controller = HomeOperationalController(
      fornecedorOffline: ({idLoja, idPessoa}) async {
        receivedStore = idLoja;
        return true;
      },
    );

    final result = await controller.fornecedorOff(idLoja: 8);

    expect(result, isTrue);
    expect(receivedStore, 8);
    controller.disposeSession();
  });

  test('heartbeat Fornecedor concorrente é ignorado', () async {
    SharedPreferences.setMockInitialValues({});
    final release = Completer<FornecedorHeartbeatResponse?>();
    var calls = 0;
    final controller = HomeOperationalController(
      fornecedorHeartbeat: (_, __) {
        calls++;
        return release.future;
      },
    );
    controller.setProfileFlags(isMotoboy: false, isFornecedor: true);

    final first = controller.sendFornecedorHeartbeat(1, 2);
    await Future<void>.delayed(Duration.zero);
    final second = await controller.sendFornecedorHeartbeat(3, 4);

    expect(second, isFalse);
    expect(calls, 1);
    release.complete(null);
    await first;
    controller.disposeSession();
  });

  test('ciclo comum não executa heartbeat', () async {
    var motoboyCalls = 0;
    var fornecedorCalls = 0;
    final controller = HomeOperationalController(
      motoboyHeartbeat: (_, __) async {
        motoboyCalls++;
        return null;
      },
      fornecedorHeartbeat: (_, __) async {
        fornecedorCalls++;
        return null;
      },
    );
    controller.setProfileFlags(isMotoboy: false, isFornecedor: false);

    await controller.runHeartbeatCycle(const Duration(seconds: 60));

    expect(motoboyCalls, 0);
    expect(fornecedorCalls, 0);
    controller.disposeSession();
  });

  test('ciclo somente Entregador executa apenas Entregador', () async {
    var motoboyCalls = 0;
    var fornecedorCalls = 0;
    final controller = HomeOperationalController(
      motoboyHeartbeat: (_, __) async {
        motoboyCalls++;
        return null;
      },
      fornecedorHeartbeat: (_, __) async {
        fornecedorCalls++;
        return null;
      },
    );
    controller.setProfileFlags(isMotoboy: true, isFornecedor: false);
    controller.setMotoboyOnline(true);

    await controller.runHeartbeatCycle(const Duration(seconds: 60));

    expect(motoboyCalls, 1);
    expect(fornecedorCalls, 0);
    controller.disposeSession();
  });

  test('ciclo somente Fornecedor executa apenas Fornecedor', () async {
    var motoboyCalls = 0;
    var fornecedorCalls = 0;
    final controller = HomeOperationalController(
      motoboyHeartbeat: (_, __) async {
        motoboyCalls++;
        return null;
      },
      fornecedorHeartbeat: (_, __) async {
        fornecedorCalls++;
        return null;
      },
    );
    controller.setProfileFlags(isMotoboy: false, isFornecedor: true);
    controller.setFornecedorOnline(true);

    await controller.runHeartbeatCycle(const Duration(seconds: 60));

    expect(motoboyCalls, 0);
    expect(fornecedorCalls, 1);
    controller.disposeSession();
  });

  test('ciclo de ambos preserva alternância Fornecedor e Entregador', () async {
    final calls = <String>[];
    final controller = HomeOperationalController(
      motoboyHeartbeat: (_, __) async {
        calls.add('motoboy');
        return null;
      },
      fornecedorHeartbeat: (_, __) async {
        calls.add('fornecedor');
        return null;
      },
    );
    controller.setProfileFlags(isMotoboy: true, isFornecedor: true);
    controller.setMotoboyOnline(true);
    controller.setFornecedorOnline(true);

    await controller.runHeartbeatCycle(const Duration(seconds: 60));
    await controller.runHeartbeatCycle(const Duration(seconds: 60));

    expect(calls, ['fornecedor', 'motoboy']);
    expect(controller.nextHeartbeatIsFornecedor, isTrue);
    controller.disposeSession();
  });

  test('pausas preservam a prioridade operacional atual', () async {
    final calls = <String>[];
    final controller = HomeOperationalController(
      motoboyHeartbeat: (_, __) async {
        calls.add('motoboy');
        return null;
      },
      fornecedorHeartbeat: (_, __) async {
        calls.add('fornecedor');
        return null;
      },
    );
    controller.setProfileFlags(isMotoboy: true, isFornecedor: true);
    controller.setMotoboyOnline(true);
    controller.setFornecedorOnline(true);

    controller.heartbeatPausedByDelivery = true;
    await controller.runHeartbeatCycle(const Duration(seconds: 60));
    expect(calls, ['motoboy']);

    calls.clear();
    controller.heartbeatPausedByDelivery = false;
    controller.heartbeatPausedBySale = true;
    await controller.runHeartbeatCycle(const Duration(seconds: 60));
    expect(calls, ['fornecedor']);
    controller.disposeSession();
  });

  test('timer do controller dispara o ciclo sem HomePage', () async {
    var fornecedorCalls = 0;
    final controller = HomeOperationalController(
      fornecedorHeartbeat: (_, __) async {
        fornecedorCalls++;
        return null;
      },
    );
    controller.setProfileFlags(isMotoboy: false, isFornecedor: true);
    controller.setFornecedorOnline(true);

    controller.scheduleHeartbeatCycle(const Duration(milliseconds: 1));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(fornecedorCalls, greaterThanOrEqualTo(1));
    controller.disposeSession();
  });

  test('ciclos concorrentes não iniciam dois perfis', () async {
    SharedPreferences.setMockInitialValues({});
    final release = Completer<FornecedorHeartbeatResponse?>();
    var fornecedorCalls = 0;
    final controller = HomeOperationalController(
      fornecedorHeartbeat: (_, __) {
        fornecedorCalls++;
        return release.future;
      },
    );
    controller.setProfileFlags(isMotoboy: false, isFornecedor: true);
    controller.setFornecedorOnline(true);

    final first = controller.runHeartbeatCycle(const Duration(seconds: 60));
    await Future<void>.delayed(Duration.zero);
    final second = controller.runHeartbeatCycle(const Duration(seconds: 60));

    expect(fornecedorCalls, 1);
    release.complete(null);
    await first;
    await second;
    controller.disposeSession();
  });
}
