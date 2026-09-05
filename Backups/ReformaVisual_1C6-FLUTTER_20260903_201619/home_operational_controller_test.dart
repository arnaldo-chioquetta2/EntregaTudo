import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:entregatudo/models/delivery_details.dart';
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
  });}
