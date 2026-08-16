import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api_v1_error.dart';
import '../models/marketplace_models.dart';
import '../services/marketplace_service.dart';
import '../utils/cart_quantity.dart';
import 'checkout_address_page.dart';

class CartPage extends StatefulWidget {
  final MarketplaceService service;

  const CartPage({super.key, required this.service});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  late Future<ShoppingCart> _future = widget.service.loadCart();
  final Set<int> _updatingItemIds = <int>{};
  bool _changed = false;
  final NumberFormat _currency =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$ ');

  Future<void> _clear() async {
    try {
      final cart = await widget.service.clearCart();
      if (mounted) Navigator.pop(context, cart);
    } on ApiV1Exception catch (error) {
      _showError(error.message);
    }
  }

  Future<void> _updateItem(CartItem item, int quantity) async {
    if (quantity < 1 || _updatingItemIds.contains(item.id)) return;
    final action = quantity > item.quantity ? 'increase' : 'decrease';
    debugPrint('[Checkout.CartEdit] action=' +
        action +
        ' itemId=' +
        item.id.toString() +
        ' productId=' +
        item.idProduto.toString() +
        ' oldQuantity=' +
        item.quantity.toString() +
        ' newQuantity=' +
        quantity.toString());
    setState(() => _updatingItemIds.add(item.id));
    try {
      await widget.service.updateItem(
        itemId: item.id,
        quantity: quantity,
        additionalIds: item.additionals.map((value) => value.id).toList(),
        observation: item.observation ?? '',
      );
      final refreshedCart = await widget.service.loadCart();
      debugPrint('[Checkout.CartEdit] status=200 itemId=' + item.id.toString());
      if (mounted) {
        setState(() {
          _changed = true;
          _future = Future.value(refreshedCart);
        });
      }
    } on ApiV1Exception catch (error) {
      debugPrint('[Checkout.CartEdit] status=' +
          error.statusCode.toString() +
          ' code=' +
          (error.code ?? 'unknown'));
      _showError('Nao foi possivel atualizar a quantidade. Tente novamente.');
    } finally {
      if (mounted) setState(() => _updatingItemIds.remove(item.id));
    }
  }

  Future<void> _removeItem(CartItem item) async {
    if (_updatingItemIds.contains(item.id)) return;
    setState(() => _updatingItemIds.add(item.id));
    try {
      final cart = await widget.service.removeItem(item.id);
      if (mounted) {
        setState(() {
          _changed = true;
          _future = Future.value(cart);
        });
      }
    } on ApiV1Exception catch (error) {
      _showError(error.message);
    } finally {
      if (mounted) setState(() => _updatingItemIds.remove(item.id));
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _changed);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Carrinho')),
        body: FutureBuilder<ShoppingCart>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return const Center(
                child: Text('Nao foi possivel carregar o carrinho.'),
              );
            }
            final cart = snapshot.data!;
            if (cart.isEmpty) {
              return const Center(child: Text('Seu carrinho esta vazio.'));
            }
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                ...cart.items.map(_buildItem),
                const Divider(),
                Text(
                  'Total dos itens: ${_currency.format(cart.totalItems)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () async {
                    final reset = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            CheckoutAddressPage(service: widget.service),
                      ),
                    );
                    if (reset == true && mounted) {
                      Navigator.pop(context, true);
                    } else if (mounted) {
                      setState(() => _future = widget.service.loadCart());
                    }
                  },
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: const Text('Avancar para entrega'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _clear,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Esvaziar carrinho'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildItem(CartItem item) {
    final additionalNames =
        item.additionals.map((value) => value.name).join(', ');
    final details = <String>[
      '${item.quantity} x ${_currency.format(item.unitValue)}',
      if (additionalNames.isNotEmpty) 'Adicionais: $additionalNames',
      if (item.observation?.trim().isNotEmpty == true)
        'Observacao: ${item.observation!.trim()}',
    ];
    final updating = _updatingItemIds.contains(item.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(details.join('\n')),
                  const SizedBox(height: 4),
                  Text(_currency.format(item.subtotal)),
                ],
              ),
            ),
            Column(
              children: [
                if (updating)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Diminuir quantidade',
                        onPressed: canDecreaseQuantity(item.quantity)
                            ? () => _updateItem(
                                item, decreasedQuantity(item.quantity))
                            : null,
                        icon: const Icon(Icons.remove),
                      ),
                      Text('${item.quantity}'),
                      IconButton(
                        tooltip: 'Aumentar quantidade',
                        onPressed: () =>
                            _updateItem(item, increasedQuantity(item.quantity)),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                IconButton(
                  tooltip: 'Remover item',
                  onPressed: updating ? null : () => _removeItem(item),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
