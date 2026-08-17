import 'dart:async';

import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';

import '../api_v1_error.dart';
import '../models/delivery_tracking_models.dart';
import '../services/marketplace_service.dart';
import '../services/recovery_state_service.dart';
import '../widgets/delivery_map.dart';

bool isTerminalDeliveryStatus(String? status) =>
    status == 'delivered' || status == 'cancelled';

class DeliveryTrackingPage extends StatefulWidget {
  final MarketplaceService service;
  final int orderId;

  const DeliveryTrackingPage(
      {super.key, required this.service, required this.orderId});

  @override
  State<DeliveryTrackingPage> createState() => _DeliveryTrackingPageState();
}

class _DeliveryTrackingPageState extends State<DeliveryTrackingPage> {
  DeliveryTracking? _tracking;
  Timer? _timer;
  bool _requestInProgress = false;
  bool _cancelling = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    if (_requestInProgress) {
      debugPrint('[DeliveryTracking.Poll] ignorado=request_in_progress');
      return;
    }
    _requestInProgress = true;
    debugPrint('[DeliveryTracking.Load] pedidoId=${widget.orderId}');
    try {
      final status = await widget.service.loadDeliveryStatus(widget.orderId);
      final details = await widget.service.loadDeliveryDetails(widget.orderId);
      if (!mounted) return;
      final merged = DeliveryTracking(
        orderId: widget.orderId,
        deliveryId: details.deliveryId ?? status.deliveryId,
        paymentStatus: details.paymentStatus ?? status.paymentStatus,
        deliveryStatus: details.deliveryStatus ?? status.deliveryStatus,
        canCancel: details.canCancel,
        driver: details.driver ?? status.driver,
        vehicle: details.vehicle ?? status.vehicle,
        contact: details.contact ?? status.contact,
        location: details.location ?? status.location,
        collectedAt: details.collectedAt ?? status.collectedAt,
        deliveredAt: details.deliveredAt ?? status.deliveredAt,
        updatedAt: details.updatedAt ?? status.updatedAt,
        confirmationCode: details.confirmationCode ?? status.confirmationCode,
      );
      setState(() {
        _tracking = merged;
        _error = null;
      });
      if (isTerminalDeliveryStatus(merged.deliveryStatus)) {
        _timer?.cancel();
        await RecoveryStateService.clearOrder();
      } else {
        await RecoveryStateService.saveOrder(widget.orderId);
      }
    } on ApiV1Exception catch (error) {
      if (!mounted) return;
      if (error.statusCode == 404) {
        await RecoveryStateService.clearOrder();
      }
      setState(() => _error =
          (error.code == 'timeout' || error.code == 'network_error')
              ? 'Aguardando conexao.'
              : 'Nao foi possivel atualizar a entrega agora.');
    } finally {
      _requestInProgress = false;
    }
  }

  Future<void> _cancel() async {
    if (_cancelling || _tracking?.canCancel != true) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar pedido'),
        content: const Text('Deseja realmente cancelar este pedido?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Nao')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cancelar pedido')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      await widget.service.cancelOrder(widget.orderId);
      await _load();
    } on ApiV1Exception catch (error) {
      if (mounted)
        setState(() => _error = error.code == 'cancelamento_nao_permitido'
            ? 'O pedido nao pode mais ser cancelado.'
            : error.message);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _call() async {
    final phone = _tracking?.contact;
    if (phone == null) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tracking = _tracking;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acompanhar entrega'),
        actions: [
          IconButton(
              onPressed: _requestInProgress ? null : _load,
              icon: const Icon(Icons.refresh),
              tooltip: 'Atualizar')
        ],
      ),
      body: tracking == null && _error == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_error != null)
                    _ErrorCard(message: _error!, onRetry: _load),
                  if (tracking != null) ..._content(tracking),
                ],
              ),
            ),
    );
  }

  List<Widget> _content(DeliveryTracking tracking) {
    final status = tracking.deliveryStatus;
    final statusText = {
          'waiting_driver': 'Procurando entregador',
          'driver_assigned': 'Entregador a caminho do fornecedor',
          'collected': 'Produto coletado',
          'delivered': 'Entrega concluida',
          'cancelled': 'Pedido cancelado',
        }[status] ??
        'Atualizando status da entrega';
    return [
      Text(statusText,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text('Pedido: #${tracking.orderId}'),
      if (tracking.confirmationCode != null) ...[
        const SizedBox(height: 12),
        const Text('Código para confirmar a entrega:'),
        Text(
          tracking.confirmationCode.toString(),
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
      ],
      if (tracking.paymentStatus != null && tracking.paymentStatus != 'paid')
        const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Pagamento ainda nao confirmado.')),
      const SizedBox(height: 20),
      if (status == 'waiting_driver')
        const Text('Aguardando um entregador assumir a entrega.'),
      if (status == 'collected')
        const Text('O entregador ja coletou seu pedido.'),
      if (status == 'driver_assigned' && tracking.location == null)
        const Text('Localizacao ainda nao disponivel.'),
      if (tracking.driver != null) ...[
        const SizedBox(height: 20),
        Card(
            child: ListTile(
                title: Text(tracking.driver!.name ?? 'Entregador'),
                subtitle: tracking.vehicle == null
                    ? null
                    : Text(_vehicleText(tracking.vehicle)!),
                trailing: tracking.contact == null
                    ? null
                    : IconButton(
                        onPressed: _call, icon: const Icon(Icons.phone))))
      ],
      if (tracking.location?.isValid == true) ...[
        const SizedBox(height: 16),
        DeliveryMap(location: tracking.location!),
        if (tracking.location!.updatedAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child:
                Text('Localizacao atualizada: ${tracking.location!.updatedAt}'),
          ),
      ] else if (status == 'driver_assigned' || status == 'collected')
        const Padding(
          padding: EdgeInsets.only(top: 16),
          child: Text('Localizacao do entregador ainda nao disponivel.'),
        ),
      if (status == 'delivered') ...[
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Entrega concluida',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                const Text('Seu pedido foi entregue com sucesso.'),
                if (tracking.deliveredAt != null)
                  Text('Entregue em: ${tracking.deliveredAt}'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _returnToBuying,
                  child: const Text('Voltar para Comprar'),
                ),
              ],
            ),
          ),
        ),
      ],
      if (status == 'cancelled') ...[
        Card(
          color: Theme.of(context).colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Pedido cancelado',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _returnToBuying,
                  child: const Text('Voltar para Comprar'),
                ),
              ],
            ),
          ),
        ),
      ],
      if (tracking.canCancel) ...[
        const SizedBox(height: 24),
        OutlinedButton(
            onPressed: _cancelling ? null : _cancel,
            child: Text(_cancelling ? 'Cancelando...' : 'Cancelar pedido')),
      ],
    ];
  }

  Future<void> _returnToBuying() async {
    await RecoveryStateService.clearPayment();
    await RecoveryStateService.clearOrder();
    if (!mounted) return;
    debugPrint(
        '[Recovery.Clear] reason=delivery_terminal navigation=marketplace');
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  String? _vehicleText(DeliveryVehicle? vehicle) {
    if (vehicle == null) return null;
    final values = [vehicle.description, vehicle.plate]
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toList();
    return values.isEmpty ? null : values.join(' - ');
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Text(message),
            TextButton(
                onPressed: onRetry, child: const Text('Tentar novamente'))
          ])));
}
