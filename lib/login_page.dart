import 'dart:math';
import 'package:flutter/material.dart';
// import 'package:tele_tudo_app/HomePage.dart';
// import 'package:tele_tudo_app/api.dart';
import 'package:entregatudo/register_page.dart';

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
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('EntregaTudo 1.1.5'),
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
                  String user = _userController.text;
                  String password = _passwordController.text;
                  double lat = 0.0;
                  double lon = 0.0;
                  // user = "Xevious";
                  // password = "ufrs3753";

                  // String result = await API.veLogin(user, password, lat, lon);
                  // if (result == "") {
                  //   Navigator.of(context).pushReplacement(
                  //     MaterialPageRoute(builder: (context) => const HomePage()),
                  //   );
                  // } else {
                  //   showErrorDialog(result);
                  // }
                } catch (e) {
                  showErrorDialog("Erro durante o login: $e");
                }
              },
              child: const Text("Login"),
            ),
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
      barrierDismissible:
          false, // Impede que o usuário feche o diálogo tocando fora dele
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
