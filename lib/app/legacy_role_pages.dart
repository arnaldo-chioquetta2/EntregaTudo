import 'package:flutter/material.dart';

import '../features/fornecedor/fornecedor_page.dart';
import '../features/home_operational_controller.dart';

export '../features/fornecedor/fornecedor_page.dart';

class LegacyFornecedorPage extends StatelessWidget {
  const LegacyFornecedorPage({super.key, required this.controller});

  final HomeOperationalController controller;

  @override
  Widget build(BuildContext context) {
    return FornecedorPage(controller: controller);
  }
}
