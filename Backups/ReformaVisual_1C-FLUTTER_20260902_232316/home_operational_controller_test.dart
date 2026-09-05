import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
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
}
