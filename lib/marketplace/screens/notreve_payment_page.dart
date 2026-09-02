import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../api_v1_error.dart';
import '../models/payment_models.dart';
import '../services/marketplace_service.dart';
import '../services/recovery_state_service.dart';
import 'delivery_tracking_page.dart';

class NotrevePaymentPage extends StatefulWidget {
  final MarketplaceService service;
  final PaymentConfirmation payment;
  final Duration pollInterval;

  const NotrevePaymentPage({
    super.key,
    required this.service,
    required this.payment,
    this.pollInterval = const Duration(seconds: 5),
  });

  @override
  State<NotrevePaymentPage> createState() => _NotrevePaymentPageState();
}

class _NotrevePaymentPageState extends State<NotrevePaymentPage> {
  final NumberFormat _currency =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$ ');
  Timer? _pollTimer;
  late String _status = widget.payment.status;
  String? _expiresAt;
  bool _pollInProgress = false;
  String? _error;
  Uint8List? _qrBytes;

  bool get _hasCopyPaste => widget.payment.copyPaste?.isNotEmpty == true;

  bool get _hasPaymentData => _qrBytes != null || _hasCopyPaste;

  @override
  void initState() {
    super.initState();
    _qrBytes = decodeNotreveQr(widget.payment.qr);
    _expiresAt = widget.payment.expiresAt;
    debugPrint('[Notreve:10.Page] opened=true');
    if (_isPollable(_status)) {
      _pollTimer = Timer.periodic(widget.pollInterval, (_) => _poll());
    }
  }

  static bool _isPollable(String status) =>
      status == 'awaiting_payment' || status == 'payment_reported';

  @visibleForTesting
  Future<void> pollForTesting() => _poll();

  Future<void> _poll() async {
    if (!mounted || _pollInProgress || !_isPollable(_status)) return;
    _pollInProgress = true;
    try {
      final status =
          await widget.service.loadPaymentStatus(widget.payment.paymentId);
      debugPrint('[Notreve:16.Status] status_received=true');
      await RecoveryStateService.updatePaymentStatus(status.status);
      if (!mounted) return;
      setState(() {
        _status = status.status;
        _expiresAt = status.expiresAt ?? _expiresAt;
        _error = null;
      });
      if (status.status == 'paid') {
        _pollTimer?.cancel();
        await _openPaid();
      } else if (!_isPollable(status.status)) {
        _pollTimer?.cancel();
      }
    } on ApiV1Exception catch (error) {
      if (mounted) {
        setState(() => _error =
            error.code == 'timeout' || error.code == 'network_error'
                ? 'Aguardando conexao.'
                : 'Nao foi possivel atualizar o pagamento agora.');
      }
    } finally {
      _pollInProgress = false;
    }
  }

  Future<void> _copyCode() async {
    final code = widget.payment.copyPaste;
    if (code == null || code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Codigo PIX copiado.')),
    );
  }

  Future<void> _openPaid() async {
    if (!mounted) return;
    await RecoveryStateService.clearPayment();
    final recovery = await RecoveryStateService.read();
    await RecoveryStateService.saveOrder(
      widget.payment.orderId,
      userId: recovery.ownerId,
    );
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

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAwaiting = _status == 'awaiting_payment';
    final isReported = _status == 'payment_reported';
    final isPaid = _status == 'paid';
    final isTerminal = isPaid ||
        _status == 'expired' ||
        _status == 'cancelled' ||
        _status == 'failed';

    return Scaffold(
      appBar: AppBar(title: const Text('Pagamento via PIX')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            _statusLabel(_status),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          const Text('Valor a pagar:'),
          Text(
            _currency.format(widget.payment.amount),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
          ),
          if (_qrBytes != null) ...[
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Image.memory(
                  _qrBytes!,
                  width: 260,
                  height: 260,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ],
          if (_hasCopyPaste) ...[
            const SizedBox(height: 20),
            const Text(
              'PIX Copia e Cola',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 96),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: SelectableText(widget.payment.copyPaste!),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _copyCode,
              icon: const Icon(Icons.copy),
              label: const Text('Copiar codigo PIX'),
            ),
          ],
          if (widget.payment.valueEmbedded == true)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text('O valor ja esta incluido neste PIX.'),
            ),
          if (_expiresAt != null) _expirationView(),
          if (widget.payment.instructions != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(widget.payment.instructions!),
            ),
          if (!_hasPaymentData && !isTerminal)
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: Text(
                'Nao foi possivel carregar os dados do PIX. Tente novamente.',
              ),
            ),
          if (isReported)
            const Card(
              margin: EdgeInsets.only(top: 20),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('Pagamento informado. Aguardando confirmacao.'),
              ),
            ),
          if (_error != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            if (!isTerminal)
              TextButton(
                onPressed: _pollInProgress ? null : _poll,
                child: const Text('Tentar novamente'),
              ),
          ],
          if (isAwaiting && !_hasPaymentData)
            TextButton(
              onPressed: _pollInProgress ? null : _poll,
              child: const Text('Tentar novamente'),
            ),
        ],
      ),
    );
  }

  Widget _expirationView() {
    final parsed = DateTime.tryParse(_expiresAt!);
    if (parsed == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        'Válido até: ${DateFormat('dd/MM/yyyy HH:mm').format(parsed.toLocal())}',
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'awaiting_payment':
        return 'Aguardando pagamento';
      case 'payment_reported':
        return 'Pagamento informado';
      case 'paid':
        return 'Pagamento confirmado';
      case 'expired':
        return 'PIX expirado';
      case 'cancelled':
        return 'Pagamento cancelado';
      case 'failed':
        return 'Nao foi possivel concluir o pagamento';
      default:
        return 'Pagamento via PIX';
    }
  }
}

Uint8List? decodeNotreveQr(String? rawQr) {
  if (rawQr == null || rawQr.trim().isEmpty) return null;
  try {
    var encoded = rawQr.trim();
    final separator = encoded.indexOf(',');
    if (encoded.startsWith('data:image/') && separator >= 0) {
      encoded = encoded.substring(separator + 1);
    }
    return base64Decode(encoded.replaceAll(RegExp(r'\s+'), ''));
  } on FormatException {
    return null;
  }
}
