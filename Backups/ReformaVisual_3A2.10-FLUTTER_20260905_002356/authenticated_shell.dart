import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/home_operational_controller.dart';
import '../features/entregador/entregador_page.dart';
import '../marketplace/screens/comprar_page.dart';
import '../captador_panel.dart';
import '../marketplace/services/recovery_state_service.dart';
import 'legacy_role_pages.dart';
import 'profile_navigation.dart';

class AuthenticatedShell extends StatefulWidget {
  const AuthenticatedShell({super.key});

  @override
  State<AuthenticatedShell> createState() => _AuthenticatedShellState();
}

class _AuthenticatedShellState extends State<AuthenticatedShell> {
  late final Future<List<AppArea>> _areasFuture = _loadAreas();
  AppArea? _selectedArea;
  late final HomeOperationalController _operationalController =
      HomeOperationalController();

  Future<List<AppArea>> _loadAreas() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('idUser');
    if (userId != null && userId > 0) {
      await RecoveryStateService.prepareForUser(userId);
    }
    final isFornecedor = prefs.getBool('isFornecedor') ?? false;
    final isMotoboy = prefs.getBool('isMotoboy') ?? false;
    _operationalController.setProfileFlags(
      isMotoboy: isMotoboy,
      isFornecedor: isFornecedor,
    );
    return ProfileNavigation.areas(
      isFornecedor: isFornecedor,
      isMotoboy: isMotoboy,
    );
  }

  @override
  void dispose() {
    _operationalController.disposeSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AppArea>>(
      future: _areasFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Scaffold(
            body: Center(child: Text('Nao foi possivel carregar os perfis.')),
          );
        }

        final areas = snapshot.data!;
        final selectedArea = ProfileNavigation.selectedOrFirst(
          areas: areas,
          selected: _selectedArea,
        );
        final selectedIndex = areas.indexOf(selectedArea);

        return Scaffold(
          body: IndexedStack(
            index: selectedIndex,
            children: [
              for (final area in areas) _buildArea(area),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) {
              if (index < 0 || index >= areas.length) return;
              setState(() {
                _selectedArea = areas[index];
              });
            },
            destinations: [
              for (final area in areas) _destinationForArea(area),
            ],
          ),
        );
      },
    );
  }

  Widget _buildArea(AppArea area) {
    switch (area) {
      case AppArea.comprar:
        return const ComprarPage();
      case AppArea.entregador:
        return EntregadorPage(controller: _operationalController);
      case AppArea.fornecedor:
        return FornecedorPage(controller: _operationalController);
      case AppArea.captador:
        return const CaptadorPanelPage();
    }
  }

  NavigationDestination _destinationForArea(AppArea area) {
    switch (area) {
      case AppArea.comprar:
        return const NavigationDestination(
          icon: Icon(Icons.shopping_bag_outlined),
          selectedIcon: Icon(Icons.shopping_bag),
          label: 'Compra',
        );
      case AppArea.entregador:
        return const NavigationDestination(
          icon: Icon(Icons.delivery_dining_outlined),
          selectedIcon: Icon(Icons.delivery_dining),
          label: 'Entregador',
        );
      case AppArea.fornecedor:
        return const NavigationDestination(
          icon: Icon(Icons.store_outlined),
          selectedIcon: Icon(Icons.store),
          label: 'Fornecedor',
        );
      case AppArea.captador:
        return const NavigationDestination(
          icon: Icon(Icons.person_add_alt_1_outlined),
          selectedIcon: Icon(Icons.person_add_alt_1),
          label: 'Captador',
        );
    }
  }
}
