import 'package:flutter/material.dart';

import '../HomePage.dart';
import '../features/home_operational_controller.dart';

class FornecedorPage extends StatelessWidget {
  const FornecedorPage({super.key, required this.controller});

  final HomeOperationalController controller;

  @override
  Widget build(BuildContext context) {
    return HomePage(operationalController: controller);
  }
}
