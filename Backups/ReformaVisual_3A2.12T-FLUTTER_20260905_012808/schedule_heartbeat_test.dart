import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:entregatudo/features/fornecedor/fornecedor_availability.dart';
import 'package:entregatudo/features/home_operational_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  HomeOperationalController makeController({
    required Future<FornecedorDisponibilidade> Function() availability,
    FornecedorHeartbeat? fornecedorHeartbeat,
    MotoboyHeartbeat? motoboyHeartbeat,
  }) {
    final controller = HomeOperationalController(
      loadFornecedorDisponibilidade: availability,
      fornecedorHeartbeat: fornecedorHeartbeat,
      motoboyHeartbeat: motoboyHeartbeat,
    );
    controller.setProfileFlags(isMotoboy: false, isFornecedor: true);
    return controller;
  }

  test('HORARIO aberto habilita heartbeat sem alterar fornecedorOnline',
      () async {
    var heartbeatCalls = 0;
    final controller = makeController(
      availability: () async => const FornecedorDisponibilidade(
        tipo: TipoFornecedor.horario,
        disponivel: true,
        origem: 'HORARIO',
      ),
      fornecedorHeartbeat: (_, __) async {
        heartbeatCalls++;
        return null;
      },
    );

    await controller.loadFornecedorDisponibilidade();
    await controller.runHeartbeatCycle(const Duration(minutes: 1));

    expect(controller.fornecedorOnline, isFalse);
    expect(controller.fornecedorHeartbeatEnabled, isTrue);
    expect(heartbeatCalls, 1);
    controller.disposeSession();
  });

  test('HORARIO fechado nao executa heartbeat fornecedor', () async {
    var heartbeatCalls = 0;
    final controller = makeController(
      availability: () async => const FornecedorDisponibilidade(
        tipo: TipoFornecedor.horario,
        disponivel: false,
        origem: 'HORARIO',
      ),
      fornecedorHeartbeat: (_, __) async {
        heartbeatCalls++;
        return null;
      },
    );

    await controller.loadFornecedorDisponibilidade();
    await controller.runHeartbeatCycle(const Duration(minutes: 1));

    expect(controller.fornecedorHeartbeatEnabled, isFalse);
    expect(heartbeatCalls, 0);
    controller.disposeSession();
  });

  test('refresh habilita e desabilita HORARIO sem alterar fornecedorOnline',
      () async {
    var disponivel = false;
    final controller = makeController(
      availability: () async => FornecedorDisponibilidade(
        tipo: TipoFornecedor.horario,
        disponivel: disponivel,
        origem: 'HORARIO',
      ),
    );

    await controller.loadFornecedorDisponibilidade();
    expect(controller.fornecedorHeartbeatEnabled, isFalse);
    disponivel = true;
    await controller.loadFornecedorDisponibilidade(forceRefresh: true);
    expect(controller.fornecedorHeartbeatEnabled, isTrue);
    disponivel = false;
    await controller.loadFornecedorDisponibilidade(forceRefresh: true);
    expect(controller.fornecedorHeartbeatEnabled, isFalse);
    expect(controller.fornecedorOnline, isFalse);
    controller.disposeSession();
  });

  test('HORARIO fechado nao bloqueia heartbeat do Entregador no perfil duplo',
      () async {
    var motoboyCalls = 0;
    final controller = HomeOperationalController(
      loadFornecedorDisponibilidade: () async =>
          const FornecedorDisponibilidade(
        tipo: TipoFornecedor.horario,
        disponivel: false,
        origem: 'HORARIO',
      ),
      motoboyHeartbeat: (_, __) async {
        motoboyCalls++;
        return null;
      },
      fornecedorHeartbeat: (_, __) async => null,
    );
    controller.setProfileFlags(isMotoboy: true, isFornecedor: true);
    controller.setMotoboyOnline(true);

    await controller.loadFornecedorDisponibilidade();
    await controller.runHeartbeatCycle(const Duration(minutes: 1));

    expect(motoboyCalls, 1);
    expect(controller.fornecedorOnline, isFalse);
    controller.disposeSession();
  });

  test('lifecycle cancela e retoma refresh comercial', () async {
    var calls = 0;
    final controller = makeController(
      availability: () async {
        calls++;
        return const FornecedorDisponibilidade(
          tipo: TipoFornecedor.horario,
          disponivel: true,
          origem: 'HORARIO',
        );
      },
    );

    await controller.loadFornecedorDisponibilidade();
    expect(controller.fornecedorDisponibilidadeRefreshActive, isTrue);
    controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(controller.fornecedorDisponibilidadeRefreshActive, isFalse);
    controller.didChangeAppLifecycleState(AppLifecycleState.hidden);
    expect(controller.fornecedorDisponibilidadeRefreshActive, isFalse);
    controller.didChangeAppLifecycleState(AppLifecycleState.detached);
    expect(controller.fornecedorDisponibilidadeRefreshActive, isFalse);
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);

    expect(calls, 2);
    expect(controller.fornecedorDisponibilidadeRefreshActive, isTrue);
    controller.disposeSession();
    expect(controller.fornecedorDisponibilidadeRefreshActive, isFalse);
  });

  test('erro no refresh preserva ultimo estado comercial valido', () async {
    var fail = false;
    final controller = makeController(
      availability: () async {
        if (fail) throw StateError('internal response');
        return const FornecedorDisponibilidade(
          tipo: TipoFornecedor.horario,
          disponivel: true,
          origem: 'HORARIO',
        );
      },
    );

    await controller.loadFornecedorDisponibilidade();
    fail = true;
    await controller.loadFornecedorDisponibilidade(forceRefresh: true);

    expect(controller.tipoFornecedor, TipoFornecedor.horario);
    expect(controller.fornecedorDisponivelComercialmente, isTrue);
    expect(controller.fornecedorHeartbeatEnabled, isTrue);
    expect(controller.fornecedorDisponibilidadeError,
        'Nao foi possivel consultar a disponibilidade comercial.');
    controller.disposeSession();
  });

  test('dispose impede heartbeat e refresh posteriores', () async {
    var availabilityCalls = 0;
    var heartbeatCalls = 0;
    final controller = makeController(
      availability: () async {
        availabilityCalls++;
        return const FornecedorDisponibilidade(
          tipo: TipoFornecedor.horario,
          disponivel: true,
          origem: 'HORARIO',
        );
      },
      fornecedorHeartbeat: (_, __) async {
        heartbeatCalls++;
        return null;
      },
    );

    await controller.loadFornecedorDisponibilidade();
    controller.disposeSession();
    await controller.loadFornecedorDisponibilidade(forceRefresh: true);
    await controller.runHeartbeatCycle(const Duration(minutes: 1));

    expect(availabilityCalls, 1);
    expect(heartbeatCalls, 0);
  });
}
