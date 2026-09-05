import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../settingsPage.dart';
import '../home_operational_controller.dart';

class EntregadorPage extends StatefulWidget {
  const EntregadorPage({
    super.key,
    required this.controller,
    this.onAvailabilityChanged,
  });

  final HomeOperationalController controller;
  final Future<void> Function(bool online)? onAvailabilityChanged;

  @override
  State<EntregadorPage> createState() => _EntregadorPageState();
}

class _EntregadorPageState extends State<EntregadorPage> {
  bool loading = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _toggleOnline() async {
    if (loading) return;
    final online = !widget.controller.motoboyOnline;
    setState(() => loading = true);
    try {
      final action = widget.onAvailabilityChanged;
      if (action != null) {
        await action(online);
      } else {
        await widget.controller.setMotoboyAvailability(
          online: online,
          heartbeatInterval: Duration(seconds: kIsWeb ? 5 : 1),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('N?o foi poss?vel alterar a disponibilidade.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final online = controller.motoboyOnline;
    final active = controller.entregaAtiva;
    final offer = controller.deliveryDataMotoboy;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entregador'),
        actions: [
          IconButton(
            tooltip: 'Configura??es',
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
          Card(
            color: colors.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.delivery_dining,
                          color: online
                              ? colors.primary
                              : colors.onSurfaceVariant),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(online ? 'Online' : 'Offline',
                            style: Theme.of(context).textTheme.headlineSmall),
                      ),
                      Chip(label: Text(online ? 'Ativo' : 'Pausado')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: loading ? null : _toggleOnline,
                      icon: loading
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
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Resumo operacional',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _summary('Lojas no raio', '${controller.lojasNoRaio}',
                          Icons.storefront_outlined),
                      _summary('Entrega ativa', active == null ? 'N?o' : 'Sim',
                          Icons.local_shipping_outlined),
                      _summary(
                          'Status', online ? 'Online' : 'Offline', Icons.wifi),
                    ].map((item) => Expanded(child: item)).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (active != null)
            _activeCard(active)
          else if (offer != null)
            _offerCard(offer)
          else
            const _EmptyCard(),
        ],
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

  Widget _offerCard(Map<String, dynamic> data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nova oferta de entrega',
                style: Theme.of(context).textTheme.titleMedium),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.trip_origin),
              title: Text('${data['enderIN'] ?? 'Origem n?o informada'}'),
              subtitle: const Text('Origem'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.location_on_outlined),
              title: Text('${data['enderFN'] ?? 'Destino n?o informado'}'),
              subtitle: const Text('Destino'),
            ),
            Wrap(
              spacing: 8,
              children: [
                if (data['dist'] != null)
                  Chip(label: Text('Dist?ncia: ${data['dist']} km')),
                if (data['valor'] != null)
                  Chip(label: Text('Valor: R\$ ${data['valor']}')),
                if (data['peso'] != null)
                  Chip(label: Text('Peso: ${data['peso']} kg')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _activeCard(dynamic delivery) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: const Icon(Icons.local_shipping),
        title: Text('Entrega ativa',
            style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(
          'Pedido #${delivery.idPedido}\n${delivery.fornecedor}\n${delivery.enderecoFornecedor}',
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined,
                size: 42,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('Nenhuma entrega no momento',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text('As novas ofertas aparecer?o aqui.',
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
