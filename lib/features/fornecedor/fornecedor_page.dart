import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api.dart';
import '../../fornecedor_entregadores_preferences_page.dart';
import '../../marketplace/api_v1_error.dart';
import '../../services/coleta_service.dart';
import '../../settingsPage.dart';
import '../home_operational_controller.dart';
import 'fornecedor_availability.dart';

class FornecedorPage extends StatefulWidget {
  const FornecedorPage({
    super.key,
    required this.controller,
    this.onAvailabilityChanged,
    this.coletaService,
  });

  final HomeOperationalController controller;
  final Future<void> Function(bool online)? onAvailabilityChanged;
  final ColetaService? coletaService;

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

  Future<void> _confirmarRetirada() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ColetaDialog(
        service: widget.coletaService ?? ColetaService(),
      ),
    );
    if (confirmed == true) _showMessage('Retirada confirmada.');
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
    final tipo = controller.tipoFornecedor;
    if (tipo == TipoFornecedor.horario) {
      return _scheduleStatusCard(context, colors);
    }
    if (tipo == TipoFornecedor.manual) {
      return _manualStatusCard(context, online, colors);
    }
    return _unknownStatusCard(context, online, colors);
  }

  Widget _scheduleStatusCard(BuildContext context, ColorScheme colors) {
    final commercialText = controller.fornecedorDisponivelComercialmente == true
        ? 'Loja disponível agora'
        : 'Loja fora do horário agora';
    return Card(
      color: colors.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Funcionamento por horário',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.storefront_outlined, color: colors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    commercialText,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            if (controller.fornecedorDisponibilidadeLoading) ...[
              const SizedBox(height: 8),
              const Text('Atualizando disponibilidade comercial...'),
            ] else if (controller.fornecedorDisponibilidadeError != null) ...[
              const SizedBox(height: 8),
              const Text('Disponibilidade comercial indisponível no momento.'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _manualStatusCard(
    BuildContext context,
    bool online,
    ColorScheme colors,
  ) {
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
            const Text('Recebimento de vendas pelo aplicativo'),
            const SizedBox(height: 16),
            _operationalStatusRow(context, online, colors),
            const SizedBox(height: 16),
            _availabilityButton(online),
          ],
        ),
      ),
    );
  }

  Widget _unknownStatusCard(
    BuildContext context,
    bool online,
    ColorScheme colors,
  ) {
    final loading = controller.fornecedorDisponibilidadeLoading;
    return Card(
      color: colors.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Disponibilidade do fornecedor',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              loading
                  ? 'Consultando disponibilidade comercial...'
                  : 'Não foi possível identificar o tipo do fornecedor.',
            ),
            if (!loading &&
                controller.fornecedorDisponibilidadeError != null) ...[
              const SizedBox(height: 8),
              const Text('O controle operacional permanece disponível.'),
              const SizedBox(height: 16),
              _operationalStatusRow(context, online, colors),
              const SizedBox(height: 16),
              _availabilityButton(online),
            ],
          ],
        ),
      ),
    );
  }

  Widget _operationalStatusRow(
    BuildContext context,
    bool online,
    ColorScheme colors,
  ) {
    return Row(
      children: [
        Icon(
          Icons.storefront_outlined,
          color: online ? colors.primary : colors.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                online ? 'Online' : 'Offline',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Text('Estado operacional do aplicativo'),
            ],
          ),
        ),
        Chip(label: Text(online ? 'Disponível' : 'Pausado')),
      ],
    );
  }

  Widget _availabilityButton(bool online) {
    return SizedBox(
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
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: busy ? null : _confirmarRetirada,
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Confirmar retirada'),
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

class _ColetaDialog extends StatefulWidget {
  const _ColetaDialog({required this.service});

  final ColetaService service;

  @override
  State<_ColetaDialog> createState() => _ColetaDialogState();
}

class _ColetaDialogState extends State<_ColetaDialog> {
  final _codeController = TextEditingController();
  bool _loading = false;
  ColetaConsulta? _consulta;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    final code = _codeController.text.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(code)) {
      setState(() => _error = 'Digite um codigo numerico de 4 digitos.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_consulta == null) {
        _consulta = await widget.service.consultarCodigo(code);
        if (mounted) setState(() {});
      } else {
        await widget.service.confirmarCodigo(code);
        if (mounted) Navigator.of(context).pop(true);
      }
    } on ApiV1Exception catch (error) {
      if (mounted) setState(() => _error = _messageForStatus(error.statusCode));
    } on FormatException {
      if (mounted) setState(() => _error = 'Resposta invalida do servidor.');
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Nao foi possivel validar a retirada.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _messageForStatus(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Codigo ou entrada invalida.';
      case 401:
        return 'Sessao expirada. Entre novamente.';
      case 403:
        return 'Codigo nao autorizado ou fornecedor indisponivel.';
      case 404:
        return 'Codigo de coleta nao encontrado.';
      case 409:
        return 'Esta coleta ja foi confirmada.';
      case 429:
        return 'Muitas tentativas. Aguarde e tente novamente.';
      default:
        return 'Não foi possível validar a retirada.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final consulta = _consulta;
    return AlertDialog(
      title: const Text('Confirmar retirada'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(consulta == null
              ? 'Digite o codigo apresentado pelo entregador.'
              : 'Codigo valido para o pedido #${consulta.idPedido}.'),
          if (consulta?.valor != null) ...[
            const SizedBox(height: 4),
            Text('Valor: ${consulta!.valor}'),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _codeController,
            enabled: !_loading,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            decoration: InputDecoration(
              labelText: 'Codigo de coleta',
              errorText: _error,
              counterText: '',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  consulta == null ? 'Validar codigo' : 'Confirmar retirada'),
        ),
      ],
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
