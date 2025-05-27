import 'login_page.dart';
import 'package:flutter/material.dart';

// 1.2 Campos de usuário e máximo de distância de entrega

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TeleTudo App MotoBoys',
      home: LoginPage(),
      builder: (context, child) {
        return child!;
      },
    );
  }
}
