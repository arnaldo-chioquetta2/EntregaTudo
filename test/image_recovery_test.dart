import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:entregatudo/marketplace/widgets/resilient_network_image.dart';

void main() {
  test('processes a failed image sequentially until a later retry succeeds',
      () async {
    final coordinator = ImageRecoveryCoordinator.instance;
    coordinator.beginScreen();
    final attempts = <int>[];

    coordinator.enqueue(
      key: 'produto:1200:https://teletudo.com/imgup/1200.png',
      attempt: 1,
      retry: (attempt) async {
        attempts.add(attempt);
        return attempt == 2;
      },
    );

    await Future<void>.delayed(const Duration(seconds: 4));
    expect(attempts, [1, 2]);
  });

  testWidgets('keeps a definitive placeholder when URL is absent',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ResilientNetworkImage(
          url: null,
          type: 'produto',
          itemId: 1200,
          size: 100,
          icon: Icons.image_outlined,
        ),
      ),
    );

    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
  });
}
