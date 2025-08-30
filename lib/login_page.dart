import 'package:entregatudo/api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:entregatudo/HomePage.dart';
import 'package:entregatudo/constants.dart';
import 'package:entregatudo/auth_service.dart';
import 'package:entregatudo/register_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() => runApp(const MyApp());

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

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _userController.text = "teste";
      _passwordController.text = "teste";
    }
  }

  Widget build(BuildContext context) {
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
                try {
                  final AuthService _authService = AuthService();
                  String user = _userController.text;
                  String password = _passwordController.text;
                  final UserCredential userCredential = await _authService
                      .signInWithEmailAndPassword(user, password);
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const HomePage()),
                  );
                } catch (e) {
                  showErrorDialog("Erro durante o login: $e");
                }
              },
              child: const Text("Login"),
            ),

            // ElevatedButton(
            //   onPressed: () async {
            //     try {
            //       String user = _userController.text;
            //       String password = _passwordController.text;
            //       double lat = 0.0;
            //       double lon = 0.0;
            //       String result = await API.veLogin(user, password, lat, lon);
            //       if (result == "") {
            //         Navigator.of(context).pushReplacement(
            //           MaterialPageRoute(builder: (context) => const HomePage()),
            //         );
            //       } else {
            //         showErrorDialog(result);
            //       }
            //     } catch (e) {
            //       showErrorDialog("Erro durante o login: $e");
            //     }
            //   },
            //   child: const Text("Login"),
            // ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RegisterPage()),
                );
              },
              child: const Text("Cadastrar Novo Usuário"),
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
