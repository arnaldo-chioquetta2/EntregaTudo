import 'package:entregatudo/api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:entregatudo/HomePage.dart';
import 'package:entregatudo/constants.dart';
import 'package:entregatudo/auth_service.dart';
import 'package:entregatudo/register_page.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'TeleTudo App MotoBoys',
      home: LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isMounted = true;
  bool _loadingGoogle = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _userController.text = "teste";
      _passwordController.text = "teste";
    }
  }

  @override
  void dispose() {
    _isMounted = false;
    super.dispose();
  }

  Future<void> _loginComGoogle() async {
    print('[UI] _loginComGoogle START (FORCE MOCK)');
    setState(() => _loadingGoogle = true);

    try {
      final auth = AuthService();

      // 1) pega o próximo ID para manter coerência com seu fluxo (?ID=)
      final queryId = await API.nextUserId();
      print('[UI] nextUserId => $queryId');
      if (queryId == null) {
        showErrorDialog('Falha ao obter next-user-id (mock).');
        return;
      }

      // 2) roda SOMENTE o mock por 10 passos (500ms cada)
      print('[UI] chamando trazCredenciais(mock=true)');
      final cred = await auth.trazCredenciais(
        userIdForQuery: queryId,
        mock: true,
        mockEmail: 'xeviousbr@gmail.com',
        mockGoogleId: '0108000582172014674272',
        mockDisplayName: 'Arnaldo (Mock)',
        mockIsNewUser: true,
        interval: const Duration(milliseconds: 500),
      );

      print(
          '[UI] trazCredenciais => success=${cred.success} | isNewUser=${cred.isNewUser} | userId=${cred.userId}');
      if (!cred.success) {
        showErrorDialog(cred.message ?? 'Falha no login (mock).');
        return;
      }

      if (cred.isNewUser == true) {
        print('[UI] Navegando para RegisterPage (novo usuário - mock)');
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const RegisterPage()));
      } else {
        print('[UI] Navegando para HomePage (usuário existente - mock)');
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const HomePage()));
      }
    } catch (e) {
      print('[UI] EXCEPTION (mock): $e');
      showErrorDialog('Erro (mock): $e');
    } finally {
      if (mounted) setState(() => _loadingGoogle = false);
      print('[UI] _loginComGoogle END (FORCE MOCK)');
    }
  }

  @override
  Widget build(BuildContext context) {
    final googleButtonChild = _loadingGoogle
        ? const SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Text("Login com Google");

    return Scaffold(
      appBar: AppBar(
        title: Text('EntregaTudo ' + AppConfig.versaoApp),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _userController,
              decoration: const InputDecoration(labelText: 'User'),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            ElevatedButton(
              onPressed: () async {
                if (!_isMounted) return;
                try {
                  final auth = AuthService();
                  final init = await auth.signInWithGoogle();
                  if (!init.success) {}
                  final cred = await auth.trazCredenciais();

                  if (_isMounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => const HomePage()),
                    );
                  }

                  // final AuthService _authService = AuthService();
                  // String user = _userController.text;
                  // String password = _passwordController.text;

                  // // Mantido: seu fluxo de e-mail/senha (assumindo que seu AuthService expõe este método)
                  // final UserCredential userCredential = await _authService
                  //     .signInWithEmailAndPassword(user, password);

                  // if (_isMounted) {
                  //   Navigator.of(context).pushReplacement(
                  //     MaterialPageRoute(builder: (context) => const HomePage()),
                  //   );
                  // }
                } catch (e) {
                  if (_isMounted) {
                    showErrorDialog("Erro durante o login: $e");
                  }
                }
              },
              child: const Text("Login"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (_isMounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const RegisterPage()),
                  );
                }
              },
              child: const Text("Cadastrar Novo Usuário"),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadingGoogle ? null : _loginComGoogle,
              icon: const Icon(Icons.g_mobiledata),
              label: googleButtonChild,
            ),
          ],
        ),
      ),
    );
  }

  void showErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Erro"),
          content: SingleChildScrollView(
            child: SelectableText(message),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }
}
