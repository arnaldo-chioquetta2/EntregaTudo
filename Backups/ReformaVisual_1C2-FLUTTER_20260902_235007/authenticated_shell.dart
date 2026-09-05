import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../HomePage.dart';
import '../features/home_operational_controller.dart';
import '../marketplace/screens/comprar_page.dart';
import 'profile_navigation.dart';
import '../marketplace/services/recovery_state_service.dart';

class AuthenticatedShell extends StatefulWidget {
  const AuthenticatedShell({super.key});

  @override
  State<AuthenticatedShell> createState() => _AuthenticatedShellState();
}

class _AuthenticatedShellState extends State<AuthenticatedShell> {
  late final Future<List<AppArea>> _areasFuture = _loadAreas();
  int _selectedIndex = 0;
  late final HomeOperationalController _operationalController =
      HomeOperationalController();

  Future<List<AppArea>> _loadAreas() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('idUser');
    if (userId != null && userId > 0) {
      await RecoveryStateService.prepareForUser(userId);
    }
    return ProfileNavigation.areas(
      isFornecedor: prefs.getBool('isFornecedor') ?? false,
      isMotoboy: prefs.getBool('isMotoboy') ?? false,
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
        // Captador fica apenas no modelo ate a separacao segura da HomePage.
        final displayAreas = <AppArea>[
          AppArea.comprar,
          if (areas.contains(AppArea.fornecedor)) AppArea.fornecedor,
          if (areas.contains(AppArea.entregador)) AppArea.entregador,
        ];
        if (displayAreas.length == 1) {
          return const ComprarPage();
        }

        return Scaffold(
          body: IndexedStack(
            index: _selectedIndex == 0 ? 0 : 1,
            children: [
              const ComprarPage(),
              HomePage(operationalController: _operationalController),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.shopping_bag_outlined),
                selectedIcon: Icon(Icons.shopping_bag),
                label: 'Comprar',
              ),
              ...displayAreas.skip(1).map(_destinationForArea),
            ],
          ),
        );
      },
    );
  }

  NavigationDestination _destinationForArea(AppArea area) {
    switch (area) {
      case AppArea.fornecedor:
        return const NavigationDestination(
          icon: Icon(Icons.store_outlined),
          selectedIcon: Icon(Icons.store),
          label: 'Fornecedor',
        );
      case AppArea.entregador:
        return const NavigationDestination(
          icon: Icon(Icons.delivery_dining_outlined),
          selectedIcon: Icon(Icons.delivery_dining),
          label: 'Entregador',
        );
      case AppArea.comprar:
        return const NavigationDestination(
          icon: Icon(Icons.shopping_bag_outlined),
          label: 'Comprar',
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
