import 'package:flutter/material.dart';

import '../../api.dart';
import '../../fornecedor_entregadores_preferences_page.dart';
import '../../settingsPage.dart';
import '../home_operational_controller.dart';

class FornecedorPage extends StatefulWidget {
  const FornecedorPage({
    super.key,
    required this.controller,
    this.onAvailabilityChanged,
  });

  final HomeOperationalController controller;
  final Future<void> Function(bool online)? onAvailabilityChanged;

  @override
  State<FornecedorPage> createState() => _FornecedorPageState();
}

class _FornecedorPageState extends State<FornecedorPage> {
  bool availabilityLoading = false;
  String? actionMessage;

  HomeOperationalController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.addListener(_refresh);
  }

  @override
  void dispose() {
    controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _toggleOnline() async {
    if (availabilityLoading) return;
    setState(() => availabilityLoading = true);
    final online = !controller.fornecedorOnline;
    try {
      final callback = widget.onAvailabilityChanged;
      if (callback != null) {
        await callback(online);
      } else {
        await controller.setFornecedorAvailability(online: online);
      }
    } catch (_) {
      _showMessage('Não foi possível alterar a disponibilidade.');
    } finally {
      if (mounted) setState(() => availabilityLoading = false);
    }
  }

  Future<void> _respondToSale(bool accept) async {
    final result = await controller.respondToCurrentSupplierSale(accept);
    if (result.message != null) _showMessage(result.message!);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    setState(() => actionMessage = message);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final online = controller.fornecedorOnline;
    final sale = controller.novaVenda;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fornecedor'),
        actions: [
          IconButton(
            tooltip: 'Preferências de entregadores',
            icon: const Icon(Icons.delivery_dining_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const FornecedorEntregadoresPreferencesPage(),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Configurações',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => SettingsPage()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _statusCard(context, online, colors),
          const SizedBox(height: 16),
          _summaryCard(context, online, sale),
          const SizedBox(height: 16),
          if (sale != null)
            _saleCard(context, sale)
          else
            const _EmptySaleCard(),
          if (actionMessage != null) ...[
            const SizedBox(height: 12),
            Text(actionMessage!, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }

  Widget _statusCard(BuildContext context, bool online, ColorScheme colors) {
    return Card(
      color: colors.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gestão da loja',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Disponibilidade para receber vendas',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.storefront_outlined,
                    color: online ? colors.primary : colors.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(online ? 'Online' : 'Offline',
                      style: Theme.of(context).textTheme.headlineSmall),
                ),
                Chip(label: Text(online ? 'Disponível' : 'Pausado')),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: availabilityLoading ? null : _toggleOnline,
                icon: availabilityLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(online ? Icons.pause : Icons.play_arrow),
                label: Text(online ? 'Ficar Offline' : 'Ficar Online'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(BuildContext context, bool online, NovaVenda? sale) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Indicadores da loja',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Visão rápida da operação e das vendas',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                _summary(
                    'Lojas no raio', '${controller.lojasNoRaio}', Icons.store),
                _summary(
                    'Itens na venda',
                    sale == null ? '0' : '${controller.itensVenda.length}',
                    Icons.shopping_basket_outlined),
                _summary('Status', online ? 'Online' : 'Offline', Icons.wifi),
              ].map((item) => Expanded(child: item)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summary(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 6),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        Text(label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _saleCard(BuildContext context, NovaVenda sale) {
    final busy = controller.supplierSaleActionInProgress;
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long_outlined,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('Vendas recebidas',
                    style: Theme.of(context).textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 8),
            Text('Nova venda', style: Theme.of(context).textTheme.titleMedium),
            _detail(
                Icons.receipt_long_outlined, 'Pedido #${sale.idPed}', 'Pedido'),
            _detail(Icons.person_outline, sale.cliente, 'Cliente'),
            _detail(Icons.payments_outlined, sale.valor, 'Valor'),
            _detail(Icons.schedule_outlined, sale.hora, 'Horário'),
            const SizedBox(height: 8),
            Text('Itens do pedido',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            ...controller.itensVenda.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.shopping_basket_outlined),
                title: Text(item.produto),
                trailing: Text('x${item.quantidade}'),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : () => _respondToSale(false),
                    child: const Text('Recusar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : () => _respondToSale(true),
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Confirmar venda'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detail(IconData icon, String title, String subtitle) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }
}

class _EmptySaleCard extends StatelessWidget {
  const _EmptySaleCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 42,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('Nenhuma venda no momento',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text('Novas vendas aparecerão aqui.',
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
