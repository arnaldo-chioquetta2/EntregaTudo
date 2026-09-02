import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:entregatudo/marketplace/screens/comprar_page.dart';

void main() {
  testWidgets('ComprarPage apresenta sua entrada visual', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ComprarPage()),
    );

    expect(find.text('Comprar'), findsOneWidget);
  });

  testWidgets('oferece exclusao de conta e permite cancelar', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ComprarPage()),
    );

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Excluir minha conta'), findsOneWidget);

    await tester.tap(find.text('Excluir minha conta'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('Tem certeza de que deseja excluir sua conta?'),
        findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tem certeza de que deseja excluir sua conta?'),
        findsNothing);
  });
}
