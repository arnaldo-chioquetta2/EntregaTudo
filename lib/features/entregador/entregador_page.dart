import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/entrega_ativa.dart';
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
  final _codeController = TextEditingController();
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
    _codeController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _toggleOnline() async {
    if (availabilityLoading) return;
    final online = !controller.motoboyOnline;
    setState(() => availabilityLoading = true);
    try {
      final action = widget.onAvailabilityChanged;
      if (action != null) {
        await action(online);
      } else {
        await controller.setMotoboyAvailability(
          online: online,
          heartbeatInterval: Duration(seconds: kIsWeb ? 5 : 1),
        );
      }
    } catch (_) {
      _showMessage('Não foi possível alterar a disponibilidade.');
    } finally {
      if (mounted) setState(() => availabilityLoading = false);
    }
  }

  Future<void> _respondToOffer(bool accept) async {
    final result = await controller.respondToCurrentOffer(accept);
    if (result.message != null) _showMessage(result.message!);
  }

  Future<void> _markPickedUp() async {
    final result = await controller.markDeliveryPickedUp();
    if (result.message != null) _showMessage(result.message!);
  }

  Future<void> _completeDelivery() async {
    final result =
        await controller.completeActiveDelivery(_codeController.text);
    if (result.success) _codeController.clear();
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
    final online = controller.motoboyOnline;
    final active = controller.entregaAtiva;
    final offer = controller.deliveryDataMotoboy;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entregador'),
        actions: [
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
          _summaryCard(context, online, active),
          const SizedBox(height: 16),
          if (active != null)
            _activeCard(context, active)
          else if (offer != null)
            _offerCard(context, offer)
          else
            const _EmptyCard(),
          if (actionMessage != null) ...[
            const SizedBox(height: 12),
            Text(actionMessage!, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }

  Widget _statusCard(BuildContext context, bool online, ColorScheme colors) {
    final theme = Theme.of(context);
    return Card(
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.delivery_dining,
                    color: online ? colors.primary : colors.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(online ? 'Online' : 'Offline',
                      style: theme.textTheme.headlineSmall),
                ),
                Chip(label: Text(online ? 'Ativo' : 'Pausado')),
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

  Widget _summaryCard(BuildContext context, bool online, EntregaAtiva? active) {
    return Card(
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
                _summary('Entrega ativa', active == null ? 'Não' : 'Sim',
                    Icons.local_shipping_outlined),
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

  Widget _offerCard(BuildContext context, Map<String, dynamic> data) {
    final busy = controller.deliveryActionInProgress;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nova oferta de entrega',
                style: Theme.of(context).textTheme.titleMedium),
            _detailTile(Icons.trip_origin,
                '${data['enderIN'] ?? 'Origem não informada'}', 'Origem'),
            _detailTile(Icons.location_on_outlined,
                '${data['enderFN'] ?? 'Destino não informado'}', 'Destino'),
            Wrap(
              spacing: 8,
              children: [
                if (data['dist'] != null)
                  Chip(label: Text('Distância: ${data['dist']} km')),
                if (data['valor'] != null)
                  Chip(label: Text('Valor: R\$ ${data['valor']}')),
                if (data['peso'] != null)
                  Chip(label: Text('Peso: ${data['peso']} kg')),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : () => _respondToOffer(false),
                    child: const Text('Recusar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : () => _respondToOffer(true),
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Aceitar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _activeCard(BuildContext context, EntregaAtiva delivery) {
    final busy = controller.deliveryActionInProgress;
    final pickedUp = controller.hasPickedUp;
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Entrega ativa',
                style: Theme.of(context).textTheme.titleMedium),
            _detailTile(
                Icons.local_shipping, 'Pedido #${delivery.idPedido}', 'Pedido'),
            _detailTile(
                Icons.storefront_outlined, delivery.fornecedor, 'Fornecedor'),
            _detailTile(Icons.location_on_outlined, delivery.enderecoFornecedor,
                'Endereço'),
            if (!pickedUp) ...[
              if (delivery.codigoRetirada.isNotEmpty)
                _detailTile(Icons.password_outlined, delivery.codigoRetirada,
                    'Código de retirada'),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: busy ? null : _markPickedUp,
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.inventory_2_outlined),
                  label: const Text('Cheguei no fornecedor'),
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              TextField(
                controller: _codeController,
                enabled: !busy,
                keyboardType: TextInputType.number,
                maxLength: 3,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  labelText: 'Código do cliente',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: busy ? null : _completeDelivery,
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: const Text('Concluir entrega'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailTile(IconData icon, String title, String subtitle) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined,
                size: 42,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('Nenhuma entrega no momento',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text('As novas ofertas aparecerão aqui.',
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
