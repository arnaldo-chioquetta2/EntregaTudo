import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:entregatudo/app/authenticated_shell.dart';

void main() {
  Future<void> verifyAreas(
    WidgetTester tester, {
    required bool isMotoboy,
    required bool isFornecedor,
    required List<String> labels,
  }) async {
    SharedPreferences.setMockInitialValues({
      'idUser': 1,
      'isMotoboy': isMotoboy,
      'isFornecedor': isFornecedor,
    });

    await tester.pumpWidget(const MaterialApp(home: AuthenticatedShell()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(NavigationBar), findsOneWidget);
    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byType(NavigationDestination), findsNWidgets(labels.length));

    await tester.pumpWidget(const SizedBox());
  }

  testWidgets('shell mostra áreas do usuário comum', (tester) async {
    await verifyAreas(
      tester,
      isMotoboy: false,
      isFornecedor: false,
      labels: ['Compra', 'Captador'],
    );
  });

  testWidgets('shell mostra áreas do Entregador', (tester) async {
    await verifyAreas(
      tester,
      isMotoboy: true,
      isFornecedor: false,
      labels: ['Compra', 'Entregador', 'Captador'],
    );
  });

  testWidgets('shell mostra áreas do Fornecedor', (tester) async {
    await verifyAreas(
      tester,
      isMotoboy: false,
      isFornecedor: true,
      labels: ['Compra', 'Fornecedor', 'Captador'],
    );
  });

  testWidgets('shell mostra as duas áreas operacionais simultaneamente',
      (tester) async {
    await verifyAreas(
      tester,
      isMotoboy: true,
      isFornecedor: true,
      labels: ['Compra', 'Entregador', 'Fornecedor', 'Captador'],
    );
  });
}
