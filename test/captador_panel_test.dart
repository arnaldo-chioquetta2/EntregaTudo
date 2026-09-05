import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:entregatudo/captador_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpPage(WidgetTester tester, CaptadorPanelPage page) async {
    await tester.pumpWidget(MaterialApp(home: page));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('renderiza estado sem codigo e acao principal', (tester) async {
    SharedPreferences.setMockInitialValues({'idUser': 1});
    await pumpPage(tester, const CaptadorPanelPage());
    expect(find.text('Captador'), findsOneWidget);
    expect(find.text('Nenhum código disponível'), findsOneWidget);
    expect(find.text('Gerar código'), findsOneWidget);
    expect(find.text('Compartilhar via WhatsApp'), findsOneWidget);
  });

  testWidgets('acoes ficam alinhadas e responsivas', (tester) async {
    SharedPreferences.setMockInitialValues({'idUser': 1});

    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpPage(tester, const CaptadorPanelPage());

    expect(find.widgetWithText(FilledButton, 'Verificar disponibilidade'),
        findsOneWidget);
    expect(
        find.widgetWithText(OutlinedButton, 'Salvar código'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(800, 800);
    await tester.pump();

    expect(find.widgetWithText(FilledButton, 'Verificar disponibilidade'),
        findsOneWidget);
    expect(
        find.widgetWithText(OutlinedButton, 'Salvar código'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gera, valida, salva e persiste codigo usando dependencias',
      (tester) async {
    SharedPreferences.setMockInitialValues({'idUser': 8});
    var generated = 0;
    var checked = 0;
    var saved = 0;
    final page = CaptadorPanelPage(
      generateInviteCode: () async {
        generated++;
        return {'code': 'ABC12345'};
      },
      checkInviteAvailability: (code, userId) async {
        checked++;
        expect(code, 'ABC12345');
        expect(userId, 8);
        return {'available': true};
      },
      saveInviteCode: (code, userId) async {
        saved++;
        expect(code, 'ABC12345');
        expect(userId, 8);
        return {'success': true};
      },
    );
    await pumpPage(tester, page);

    await tester.tap(find.text('Gerar código'));
    await tester.pumpAndSettle();
    expect(generated, 1);
    expect(find.text('Código gerado com sucesso.'), findsOneWidget);

    await tester.tap(find.text('Verificar disponibilidade'));
    await tester.pumpAndSettle();
    expect(checked, 1);
    expect(find.text('Código disponível para uso!'), findsOneWidget);

    await tester.tap(find.text('Salvar código'));
    await tester.pumpAndSettle();
    expect(saved, 1);
    expect(find.text('Código salvo com sucesso!'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getString('inviteCode'),
        'ABC12345');
  });

  testWidgets('compartilha via launcher injetado e nao usa rede real',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'idUser': 1,
      'inviteCode': 'ZXCV1234',
      'nomeUser': 'Pessoa',
    });
    Uri? launchedUri;
    await pumpPage(
      tester,
      CaptadorPanelPage(
        canLaunchInvite: (_) async => true,
        launchInvite: (uri) async {
          launchedUri = uri;
          return true;
        },
      ),
    );
    await tester.tap(find.text('Compartilhar via WhatsApp'));
    await tester.pumpAndSettle();
    expect(launchedUri?.scheme, 'https');
    expect(launchedUri?.host, 'wa.me');
    expect(launchedUri?.queryParameters['text'], contains('ZXCV1234'));
  });

  testWidgets('loading impede geracao duplicada e erro e sanitizado',
      (tester) async {
    SharedPreferences.setMockInitialValues({'idUser': 1});
    final release = Completer<Map<String, dynamic>>();
    var calls = 0;
    await pumpPage(
      tester,
      CaptadorPanelPage(
        generateInviteCode: () {
          calls++;
          return release.future;
        },
      ),
    );
    await tester.tap(find.text('Gerar código'));
    await tester.pump();
    expect(find.text('Gerar código'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(calls, 1);
    release.completeError(StateError('internal'));
    await tester.pumpAndSettle();
    expect(find.text('Erro ao gerar código.'), findsOneWidget);
    expect(find.textContaining('internal'), findsNothing);
  });
}
