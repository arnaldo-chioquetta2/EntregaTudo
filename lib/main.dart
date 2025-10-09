import 'HomePage.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'captador_panel.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TeleTudo App MotoBoys',
      home: const LoginPage(),
      routes: {
        '/register': (_) => const RegisterPage(),
        '/home': (_) => const HomePage(),
      },
      builder: (context, child) => child!,
    );
  }
}
