// import 'login_page.dart';
import 'package:flutter/material.dart';
import 'login_page.dart';
// import 'package:background_fetch/background_fetch.dart';

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
        //initPlatformState();
        return child!;
      },
    );
  }
}
