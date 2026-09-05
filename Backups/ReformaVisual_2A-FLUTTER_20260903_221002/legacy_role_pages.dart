import 'package:flutter/material.dart';

import '../HomePage.dart';
import '../features/home_operational_controller.dart';

/// Temporary role pages that reuse the legacy visual until the redesign.
class EntregadorPage extends StatelessWidget {
  const EntregadorPage({super.key, required this.controller});

  final HomeOperationalController controller;

  @override
  Widget build(BuildContext context) {
    return HomePage(operationalController: controller);
  }
}

class FornecedorPage extends StatelessWidget {
  const FornecedorPage({super.key, required this.controller});

  final HomeOperationalController controller;

  @override
  Widget build(BuildContext context) {
    return HomePage(operationalController: controller);
  }
}
