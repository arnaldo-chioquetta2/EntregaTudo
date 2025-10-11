import 'package:flutter/material.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'HomePage.dart';
import 'captador_panel.dart';

void main() {
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
        '/captador-panel': (_) => const CaptadorPanelPage(),
      },
      builder: (context, child) => child!,
    );
  }
}
