import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../api_v1_error.dart';
import '../models/payment_models.dart';
import '../services/marketplace_service.dart';
import '../services/recovery_state_service.dart';
import 'delivery_tracking_page.dart';

class PixPaymentPage extends StatefulWidget {
  final MarketplaceService service;
  final PaymentConfirmation payment;

  const PixPaymentPage({
    super.key,
    required this.service,
    required this.payment,
  });

  @override
  State<PixPaymentPage> createState() => _PixPaymentPageState();
}

class _PixPaymentPageState extends State<PixPaymentPage> {
  final NumberFormat _currency =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$ ');
  Timer? _pollTimer;
  late String _status = widget.payment.status;
  bool _reporting = false;
  bool _pollInProgress = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_status != 'paid') {
      _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
    }
  }

  Future<void> _poll() async {
    if (!mounted || _reporting || _pollInProgress || _status == 'paid') return;
    _pollInProgress = true;
    try {
      final status =
          await widget.service.loadPaymentStatus(widget.payment.paymentId);
      if (!mounted) return;
      await RecoveryStateService.updatePaymentStatus(status.status);
      setState(() {
        _status = status.status;
        _error = null;
      });
      if (_status == 'paid') {
        _pollTimer?.cancel();
        await _openPaid();
      }
    } on ApiV1Exception catch (error) {
      debugPrint('[Sanitized] sensitive_details_suppressed=true');
      if (mounted)
        setState(() => _error =
            (error.code == 'timeout' || error.code == 'network_error')
                ? 'Aguardando conexao.'
                : 'Nao foi possivel atualizar o status agora.');
    } finally {
      _pollInProgress = false;
    }
  }

  Future<void> _reportPayment() async {
    if (_reporting || _status == 'payment_reported' || _status == 'paid')
      return;
    setState(() {
      _reporting = true;
      _error = null;
    });
    try {
      final status =
          await widget.service.reportPayment(widget.payment.paymentId);
      await RecoveryStateService.updatePaymentStatus(status.status);
      if (!mounted) return;
      setState(() {
        _status = status.status;
        _reporting = false;
      });
    } on ApiV1Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _reporting = false;
        _error = error.message;
      });
    }
  }

  Future<void> _openPaid() async {
    if (!mounted) return;
    await RecoveryStateService.clearPayment();
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('idUser');
    await RecoveryStateService.saveOrder(widget.payment.orderId,
        userId: userId);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DeliveryTrackingPage(
          service: widget.service,
          orderId: widget.payment.orderId,
        ),
      ),
    );
  }

  Future<void> _copyKey() async {
    final key = widget.payment.pixKey;
    if (key == null) return;
    await Clipboard.setData(ClipboardData(text: key));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Chave PIX copiada.')));
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final awaiting = _status == 'awaiting_payment';
    final reported = _status == 'payment_reported';
    return Scaffold(
      appBar: AppBar(title: const Text('Pagamento via PIX')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(awaiting
              ? 'Aguardando pagamento'
              : reported
                  ? 'Pagamento informado'
                  : 'Pagamento via PIX'),
          const SizedBox(height: 8),
          Text('Valor a pagar: ${_currency.format(widget.payment.amount)}',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text(
            'Erro no valor - correÃ§Ã£o pendente',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          if (widget.payment.qr != null) _QrView(value: widget.payment.qr!),
          if (widget.payment.valueEmbedded == false)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                    'O QR Code nao inclui automaticamente o valor. Confira e informe no seu banco o valor exibido acima.'),
              ),
            ),
          if (widget.payment.pixKey != null) ...[
            const SizedBox(height: 16),
            const Text('Chave PIX',
                style: TextStyle(fontWeight: FontWeight.w700)),
            SelectableText(widget.payment.pixKey!),
            TextButton.icon(
              onPressed: _copyKey,
              icon: const Icon(Icons.copy),
              label: const Text('Copiar chave PIX'),
            ),
          ],
          if (widget.payment.instructions != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(widget.payment.instructions!),
            ),
          if (_error != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
            TextButton(
              onPressed: _pollInProgress || _reporting ? null : _poll,
              child: const Text('Tentar novamente'),
            ),
          ] else
            const SizedBox.shrink(),
          const SizedBox(height: 20),
          if (awaiting)
            FilledButton(
              onPressed: _reporting ? null : _reportPayment,
              child: Text(_reporting ? 'Enviando...' : 'Ja paguei'),
            )
          else if (reported)
            const Card(
                child: Padding(
                    padding: EdgeInsets.all(12),
                    child:
                        Text('Pagamento informado. Aguardando confirmacao.'))),
        ],
      ),
    );
  }
}

class _QrView extends StatelessWidget {
  final String value;
  const _QrView({required this.value});

  @override
  Widget build(BuildContext context) {
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return Image.network(
        value,
        height: 220,
        fit: BoxFit.contain,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        errorBuilder: (_, __, ___) => const Icon(Icons.qr_code_2, size: 180),
      );
    }
    if (value.startsWith('data:image/')) {
      final comma = value.indexOf(',');
      if (comma > 0) {
        try {
          return Image.memory(base64Decode(value.substring(comma + 1)),
              height: 220);
        } on FormatException {
          return const Icon(Icons.qr_code_2, size: 180);
        }
      }
    }
    return SelectableText(value);
  }
}

class PaymentConfirmedPage extends StatelessWidget {
  final int orderId;
  final String status;
  const PaymentConfirmedPage(
      {super.key, required this.orderId, required this.status});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Compra confirmada')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
                'Pagamento confirmado.\nSeu pedido foi confirmado.\nPedido: $orderId\nStatus: $status'),
          ),
        ),
      );
}
