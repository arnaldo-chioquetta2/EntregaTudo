import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../api_v1_error.dart';
import '../models/checkout_models.dart';
import '../services/marketplace_service.dart';
import 'cart_page.dart';
import 'delivery_preferences_page.dart';
import 'pix_payment_page.dart';

class CheckoutReviewPage extends StatefulWidget {
  final MarketplaceService service;
  final CheckoutQuote quote;
  final DeliveryAddress? temporaryAddress;
  final String idempotencyKey;

  const CheckoutReviewPage({
    super.key,
    required this.service,
    required this.quote,
    required this.idempotencyKey,
    this.temporaryAddress,
  });

  @override
  State<CheckoutReviewPage> createState() => _CheckoutReviewPageState();
}

class _CheckoutReviewPageState extends State<CheckoutReviewPage> {
  final NumberFormat _currency =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$ ');
  late CheckoutQuote _quote = widget.quote;
  bool _loading = false;
  String _idempotencyKey = '';
  late final String _confirmationKey = const Uuid().v4();

  @override
  void initState() {
    super.initState();
    debugPrint('[Payment.Build] F3.3 active');
    _idempotencyKey = widget.idempotencyKey;
    debugPrint('[Checkout.Review] pedidoId=' +
        (widget.quote.orderId?.toString() ?? 'null') +
        ' totalItens=' +
        widget.quote.itemsTotal.toString() +
        ' valorEntrega=' +
        widget.quote.deliveryValue.toString() +
        ' total=' +
        widget.quote.total.toString());
  }

  Future<void> _editCart() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CartPage(service: widget.service)),
    );
    if (!mounted || changed != true) return;
    await _reQuote();
  }

  Future<void> _reQuote() async {
    debugPrint(
        '[Checkout.Requote] iniciada reason=cart_or_preferences_changed');
    if (_loading) return;
    setState(() => _loading = true);
    final previousTotal = _quote.total;
    _idempotencyKey = const Uuid().v4();
    try {
      final quote = await widget.service.requestQuote(
        temporaryAddress: widget.temporaryAddress,
        idempotencyKey: _idempotencyKey,
      );
      if (mounted)
        setState(() {
          _quote = quote;
          debugPrint('[Checkout.Requote] status=200 pedidoId=' +
              quote.orderId.toString() +
              ' totalAnterior=' +
              previousTotal.toString() +
              ' totalNovo=' +
              quote.total.toString());
          _loading = false;
        });
    } on ApiV1Exception catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error.code == 'sem_candidatos'
              ? 'Nao ha entregadores disponiveis para esse destino.'
              : error.message)));
    }
  }

  Future<void> _chooseDeliveryPeople() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DeliveryPreferencesPage(service: widget.service),
      ),
    );
    if (changed == true && mounted) await _reQuote();
  }

  Future<void> _confirmPayment() async {
    debugPrint(
        '[Payment.UI.ConfirmTap] pedidoId=${_quote.orderId ?? 'null'} quote=true loading=$_loading mounted=$mounted');
    if (_loading) return;
    if (_quote.orderId == null || _quote.orderId == 0) {
      debugPrint(
          '[Payment.UI.ConfirmError] type=missing_order_id code=missing_order_id message=pedido_id_invalido');
      _showMessage(
          'Nao foi possivel identificar o pedido. Refaça o orcamento.');
      return;
    }
    debugPrint('[Payment.UI.ConfirmCall] pedidoId=${_quote.orderId}');
    setState(() => _loading = true);
    try {
      final payment = await widget.service.confirmCheckout(
        orderId: _quote.orderId!,
        idempotencyKey: _confirmationKey,
      );
      debugPrint(
          '[Payment.UI.ConfirmResult] success=true pagamentoId=${payment.paymentId}');
      if (!mounted) return;
      setState(() => _loading = false);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PixPaymentPage(service: widget.service, payment: payment),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint(
          '[Payment.UI.ConfirmError] type=${error.runtimeType} code=${error is ApiV1Exception ? error.code : 'unknown'} message=${error is ApiV1Exception ? error.message : error}');
      debugPrint(
          '[Payment.UI.ConfirmStack] ${stackTrace.toString().split('\n').take(4).join(' | ')}');
      if (!mounted) return;
      setState(() => _loading = false);
      final message =
          error is ApiV1Exception && error.code == 'payment_gateway_unavailable'
              ? 'O pagamento PIX esta temporariamente indisponivel.'
              : error is ApiV1Exception
                  ? error.message
                  : 'Nao foi possivel iniciar o pagamento.';
      _showMessage(message);
    }
  }

  Future<void> _differentPurchase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fazer compra diferente?'),
        content:
            const Text('O carrinho atual sera esvaziado. Deseja continuar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Esvaziar carrinho')),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      if (mounted) debugPrint('[Checkout.NewPurchase] action=cancel');
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.service.clearCart();
      debugPrint(
          '[Checkout.NewPurchase] action=confirm cartCleared=true navigation=marketplace');
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on ApiV1Exception catch (error) {
      debugPrint('[Checkout.NewPurchase] status=error code=' +
          (error.code ?? 'unknown'));
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final address = _quote.deliveryAddress ?? widget.temporaryAddress;
    return Scaffold(
      appBar: AppBar(title: const Text('Revisao da compra')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Confira sua compra',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          if (address != null)
            Card(
                child: ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(address.isTemporary
                        ? 'Endereco temporario'
                        : 'Endereco cadastrado'),
                    subtitle: Text(address.displayText))),
          _valueRow('Total dos itens', _quote.itemsTotal),
          _valueRow('Teleentrega', _quote.deliveryValue),
          const Divider(),
          _valueRow('Total geral', _quote.total, emphasized: true),
          if (_quote.orderId != null)
            Text('Pedido: ${_quote.orderId}',
                style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _loading ? null : _confirmPayment,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lock_outline),
            label: const Text('Confirmar'),
          ),
          OutlinedButton(
              onPressed: _loading ? null : () => Navigator.pop(context),
              child: const Text('Retornar as compras')),
          OutlinedButton.icon(
              onPressed: _loading ? null : _editCart,
              icon: const Icon(Icons.edit),
              label: const Text('Editar quantidade de itens')),
          OutlinedButton.icon(
              onPressed: _loading ? null : _differentPurchase,
              icon: const Icon(Icons.refresh),
              label: const Text('Fazer compra diferente')),
          OutlinedButton.icon(
              onPressed: _loading ? null : _chooseDeliveryPeople,
              icon: const Icon(Icons.people_outline),
              label: const Text('Escolher entregador')),
          if (_loading)
            const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }

  Widget _valueRow(String label, double value, {bool emphasized = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontWeight:
                        emphasized ? FontWeight.w700 : FontWeight.normal)),
            Text(_currency.format(value),
                style: TextStyle(
                    fontWeight:
                        emphasized ? FontWeight.w700 : FontWeight.normal,
                    fontSize: emphasized ? 18 : null)),
          ],
        ),
      );

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
