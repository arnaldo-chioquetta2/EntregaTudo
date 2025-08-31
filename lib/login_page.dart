import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:entregatudo/HomePage.dart';
import 'package:entregatudo/constants.dart'; // Importação adicionada
import 'package:entregatudo/auth_service.dart';
import 'package:entregatudo/register_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            'EntregaTudo ' + AppConfig.versaoApp), // Uso de AppConfig.versaoApp
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
                  final AuthService _authService = AuthService();
                  String user = _userController.text;
                  String password = _passwordController.text;
                  final UserCredential userCredential = await _authService
                      .signInWithEmailAndPassword(user, password);
                  if (_isMounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => const HomePage()),
                    );
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
              onPressed: () async {
                if (!_isMounted) return;
                try {
                  final GoogleSignInAccount? googleUser =
                      await GoogleSignIn().signIn();
                  final GoogleSignInAuthentication googleAuth =
                      await googleUser!.authentication;

                  final OAuthCredential credential =
                      GoogleAuthProvider.credential(
                    accessToken: googleAuth.accessToken,
                    idToken: googleAuth.idToken,
                  );

                  final UserCredential userCredential = await FirebaseAuth
                      .instance
                      .signInWithCredential(credential);
                  if (_isMounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => const HomePage()),
                    );
                  }
                } catch (e) {
                  if (_isMounted) {
                    showErrorDialog("Erro durante o login com Google: $e");
                  }
                }
              },
              icon: const Icon(Icons.g_mobiledata),
              label: const Text("Login com Google"),
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
