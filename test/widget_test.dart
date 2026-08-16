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
}
