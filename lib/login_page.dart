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
    _tentarSilent();
  }

  Future<void> _tentarSilent() async {
    setState(() => _loadingGoogle = true);
    try {
      final auth = AuthService();
      final res = await auth.trySilentGoogleLogin();

      print(
          '[UI] silent => success=${res.success} isNew=${res.isNewUser} userId=${res.userId}');

      if (!res.success) {
        // não navega; só deixa o botão visível pra login “normal”
        return;
      }

      // sucesso: roteia como de costume
      if (res.isNewUser == true) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const RegisterPage()));
      } else {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const HomePage()));
      }
    } catch (e) {
      print('[UI] silent EXCEPTION: $e');
      // segue a vida, mostra botão
    } finally {
      if (mounted) setState(() => _loadingGoogle = false);
    }
  }

  // void initState() {
  //   super.initState();
  //   if (kIsWeb) {
  //     _userController.text = "teste";
  //     _passwordController.text = "teste";
  //   }
  // }

  @override
  void dispose() {
    _isMounted = false;
    super.dispose();
  }

  Future<void> _loginComGoogle() async {
    print('[UI] _loginComGoogle START (REAL)');
    if (!mounted) return;
    setState(() => _loadingGoogle = true);

    try {
      final auth = AuthService();

      // 1) Inicia o fluxo: nextId -> Google Sign-In -> callback ?ID=<nextId>
      print('[UI] chamando signInWithGoogle() (real)');
      final init = await auth.signInWithGoogle();
      print(
          '[UI] init => success=${init.success} | msg=${init.message} | queryId=${init.queryId} | userId=${init.userId} | isNew=${init.isNewUser}');

      if (!init.success) {
        showErrorDialog(init.message ?? 'Falha ao iniciar o login Google.');
        return;
      }

      // 2) Se o backend já devolveu user_id/tokens, navegamos imediatamente
      if (init.userId != null) {
        if (init.isNewUser == true) {
          print('[UI] login finalizado (novo usuário) → RegisterPage');
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const RegisterPage()),
          );
        } else {
          print('[UI] login finalizado (usuário existente) → HomePage');
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomePage()),
          );
        }
        return;
      }

      // 3) Caso contrário, seguimos com o POLLING usando o MESMO queryId
      final qid = init.queryId ?? auth.lastQueryId;
      if (qid == null) {
        print('[UI] ERRO: queryId ausente para polling');
        showErrorDialog('Falha interna: ID de consulta ausente para polling.');
        return;
      }

      print('[UI] iniciando polling com queryId=$qid');
      final cred = await auth.trazCredenciais(userIdForQuery: qid);
      print(
          '[UI] polling result => success=${cred.success} | msg=${cred.message} | userId=${cred.userId} | isNew=${cred.isNewUser}');

      if (!cred.success) {
        showErrorDialog(cred.message ?? 'Falha no login.');
        return;
      }

      // 4) Navegação após polling concluído
      if (cred.isNewUser == true) {
        print('[UI] novo usuário (via polling) → RegisterPage');
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const RegisterPage()),
        );
      } else {
        print('[UI] usuário existente (via polling) → HomePage');
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } catch (e) {
      print('[UI] EXCEPTION (real): $e');
      if (mounted) showErrorDialog('Erro: $e');
    } finally {
      if (mounted) setState(() => _loadingGoogle = false);
      print('[UI] _loginComGoogle END (REAL)');
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
                  final user = _userController.text.trim();
                  final password = _passwordController.text.trim();

                  if (user.isEmpty || password.isEmpty) {
                    showErrorDialog("Preencha usuário e senha.");
                    return;
                  }
                  double lat = 0.0;
                  double lon = 0.0;
                  String result = await API.veLogin(user, password, lat, lon);
                  if (result == "") {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => const HomePage()),
                    );
                  } else {
                    showErrorDialog(result);
                  }
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
