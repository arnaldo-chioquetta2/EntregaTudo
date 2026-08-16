import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_v1_error.dart';
import '../models/marketplace_models.dart';
import '../services/marketplace_service.dart';
import 'cart_page.dart';
import 'produto_detalhe_page.dart';
import 'delivery_tracking_page.dart';

class ComprarMarketplacePage extends StatefulWidget {
  const ComprarMarketplacePage({super.key});

  @override
  State<ComprarMarketplacePage> createState() => _ComprarMarketplacePageState();
}

class _ComprarMarketplacePageState extends State<ComprarMarketplacePage> {
  final MarketplaceService _service = MarketplaceService();
  final TextEditingController _search = TextEditingController();
  final ScrollController _resultsScroll = ScrollController();
  final NumberFormat _currency =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$ ');

  late Future<_InitialData> _initialFuture = _loadInitial();
  Timer? _debounce;
  int _generation = 0;
  String _query = '';
  int? _category;
  List<MarketplaceProduct> _results = const [];
  MarketplacePagination? _pagination;
  ShoppingCart _cart = const ShoppingCart(
    id: 0,
    activeSupplierId: null,
    items: <CartItem>[],
    totalItems: 0,
  );
  bool _loadingResults = false;
  bool _loadingNext = false;
  String? _resultsError;
  int? _activeOrderId;

  @override
  void initState() {
    super.initState();
    _search.addListener(_onQueryChanged);
    _resultsScroll.addListener(_onScroll);
    _loadActiveOrder();
  }

  Future<void> _loadActiveOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final orderId = prefs.getInt('currentMarketplaceOrderId');
    if (mounted && orderId != null) setState(() => _activeOrderId = orderId);
  }

  Future<void> _openActiveOrder() async {
    final orderId = _activeOrderId;
    if (orderId == null) return;
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                DeliveryTrackingPage(service: _service, orderId: orderId)));
  }

  Future<_InitialData> _loadInitial() async {
    final home = await _service.loadMarketplace();
    final cart = await _service.loadCart();
    if (cart.activeSupplierId == null) {
      return _InitialData(home: home, cart: cart);
    }
    final products = await _service.loadProducts(
      supplierId: cart.activeSupplierId,
    );
    return _InitialData(
      home: MarketplaceHome(
        categories: home.categories,
        suppliers: home.suppliers,
        products: products,
      ),
      cart: cart,
    );
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    final value = _search.text.trim();
    _query = value;
    if (value.isEmpty) {
      _generation++;
      setState(() {
        _results = const [];
        _pagination = null;
        _resultsError = null;
        _loadingResults = false;
        _category = null;
      });
      return;
    }
    _debounce = Timer(const Duration(seconds: 2), () {
      _loadResults(query: value);
    });
  }

  Future<void> _loadResults({String query = '', int? category}) async {
    final generation = ++_generation;
    setState(() {
      _category = category;
      _results = const [];
      _pagination = null;
      _resultsError = null;
      _loadingResults = true;
    });
    try {
      final page = await _service.loadProducts(
        query: query,
        categoryId: category,
        supplierId: _cart.activeSupplierId,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _results = page.items;
        _pagination = page.pagination;
        _loadingResults = false;
      });
    } on ApiV1Exception catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _resultsError = _friendlyError(error);
        _loadingResults = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _resultsError = 'Nao foi possivel carregar os produtos.';
        _loadingResults = false;
      });
    }
  }

  Future<void> _loadNextPage() async {
    final pagination = _pagination;
    if (_loadingNext || pagination == null || !pagination.hasNextPage) return;
    _loadingNext = true;
    final generation = _generation;
    try {
      final page = await _service.loadProducts(
        query: _query,
        categoryId: _category,
        supplierId: _cart.activeSupplierId,
        page: pagination.page + 1,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _results = [..._results, ...page.items];
        _pagination = page.pagination;
      });
    } finally {
      _loadingNext = false;
    }
  }

  void _onScroll() {
    if (_resultsScroll.position.extentAfter < 500) _loadNextPage();
  }

  Future<void> _refresh() async {
    final future = _loadInitial();
    setState(() => _initialFuture = future);
    try {
      final data = await future;
      if (mounted) setState(() => _cart = data.cart);
    } catch (_) {}
  }

  Future<void> _selectCategory(int id) async {
    _debounce?.cancel();
    _search.clear();
    await _loadResults(category: id);
  }

  Future<void> _openUrl(String? value) async {
    if (value == null) return;
    final uri = Uri.tryParse(value);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openProduct(MarketplaceProduct product) async {
    if (!product.teleEntregaDisponivel) {
      final access = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Teleentrega indisponivel'),
          content: const Text(
            'Esta empresa nao esta disponivel para Teleentrega no momento. Deseja acessar a pagina da empresa?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Acessar'),
            ),
          ],
        ),
      );
      if (access == true) await _openUrl(product.supplierUrl);
      return;
    }
    final cart = await Navigator.push<ShoppingCart>(
      context,
      MaterialPageRoute(
        builder: (_) => ProdutoDetalhePage(
          productId: product.idProduto,
          service: _service,
        ),
      ),
    );
    if (cart != null && mounted) setState(() => _cart = cart);
  }

  Future<void> _addProduct(MarketplaceProduct product) async {
    if (!product.teleEntregaDisponivel ||
        _cart.items.any((item) => item.idProduto == product.idProduto)) {
      return;
    }
    try {
      final cart = await _service.addItem(productId: product.idProduto);
      if (mounted) setState(() => _cart = cart);
    } on ApiV1Exception catch (error) {
      if (!mounted) return;
      if (error.hasFieldError('fornecedor', 'fornecedor_diferente')) {
        await _offerSupplierChange();
      } else {
        _message(error.message);
      }
    }
  }

  Future<void> _offerSupplierChange() async {
    final change = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fornecedor diferente'),
        content: const Text(
          'O carrinho atual pertence a outro fornecedor. Deseja esvaziar o carrinho e continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Trocar fornecedor'),
          ),
        ],
      ),
    );
    if (change == true) await _changeSupplier();
  }

  Future<void> _changeSupplier() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Trocar fornecedor?'),
        content: const Text(
          'Para escolher produtos de outro fornecedor, o carrinho atual precisa ser esvaziado. Deseja continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Esvaziar carrinho'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final cart = await _service.clearCart();
      if (!mounted) return;
      _search.clear();
      setState(() {
        _cart = cart;
        _category = null;
        _results = const [];
        _pagination = null;
        _initialFuture = _loadInitial();
      });
    } on ApiV1Exception catch (error) {
      if (mounted) _message(error.message);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _resultsScroll.dispose();
    _service.close();
    super.dispose();
  }

  String _friendlyError(Object? error) {
    if (error is ApiV1Exception) {
      if (error.code == 'timeout') {
        return 'O marketplace demorou para responder. Tente novamente.';
      }
      if (error.statusCode == 401) {
        return 'Sua sessao expirou. Entre novamente.';
      }
      if (error.statusCode >= 500) {
        return 'O servidor esta indisponivel no momento.';
      }
      if (error.code == 'invalid_json') {
        return 'O servidor retornou uma resposta invalida.';
      }
      return error.message;
    }
    return 'Nao foi possivel carregar o marketplace.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comprar')),
      body: FutureBuilder<_InitialData>(
        future: _initialFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _LoadingView();
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _ErrorView(
              message: _friendlyError(snapshot.error),
              onRetry: _refresh,
            );
          }
          final data = snapshot.data!;
          if (_cart.id == 0) _cart = data.cart;
          final browsing = _query.isNotEmpty || _category != null;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: Stack(
              children: [
                browsing ? _buildResults() : _buildHome(data.home),
                if (!_cart.isEmpty) _buildCartSummary(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHome(MarketplaceHome home) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 112),
      children: [
        if (_activeOrderId != null) _activeOrderBanner(),
        _buildSearchField(),
        if (_cart.activeSupplierId != null) ...[
          const SizedBox(height: 12),
          _supplierFilter(),
        ],
        const SizedBox(height: 24),
        _title('Categorias'),
        const SizedBox(height: 12),
        _categories(home.categories),
        const SizedBox(height: 28),
        _title('Produtos em destaque'),
        const SizedBox(height: 12),
        _products(home.products.items),
        const SizedBox(height: 28),
        _title('Fornecedores'),
        const SizedBox(height: 12),
        _suppliers(home.suppliers),
      ],
    );
  }

  Widget _buildResults() {
    if (_loadingResults && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_resultsError != null && _results.isEmpty) {
      return _ErrorView(
        message: _resultsError!,
        onRetry: () => _loadResults(query: _query, category: _category),
      );
    }
    return ListView.builder(
      controller: _resultsScroll,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 112),
      itemCount: _results.isEmpty ? 2 : _results.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) return _buildSearchField();
        if (index == 1) {
          if (_results.isEmpty && !_loadingResults) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: Text('Nenhum produto encontrado.')),
            );
          }
          return const SizedBox(height: 16);
        }
        final product = _results[index - 2];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _ProductCard(
            product: product,
            currency: _currency,
            inCart: _inCart(product),
            onTap: () => _openProduct(product),
            onAdd: () => _addProduct(product),
          ),
        );
      },
    );
  }

  bool _inCart(MarketplaceProduct product) =>
      _cart.items.any((item) => item.idProduto == product.idProduto);

  Widget _activeOrderBanner() => Card(
        child: ListTile(
          leading: const Icon(Icons.local_shipping),
          title: const Text('Voce possui uma entrega em andamento'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _openActiveOrder,
        ),
      );
  Widget _buildSearchField() {
    return TextField(
      controller: _search,
      decoration: InputDecoration(
        hintText: 'Buscar produtos',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                onPressed: _search.clear,
                icon: const Icon(Icons.clear),
                tooltip: 'Limpar busca',
              ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _categories(List<MarketplaceCategory> categories) {
    if (categories.isEmpty) return const Text('Nenhuma categoria disponivel.');
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final category = categories[index];
          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _selectCategory(category.id),
            child: SizedBox(
              width: 90,
              child: Column(
                children: [
                  _NetworkImage(
                    url: category.imageUrl,
                    type: 'categoria',
                    itemId: category.id,
                    size: 64,
                    icon: Icons.category_outlined,
                  ),
                  const SizedBox(height: 6),
                  Text(category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _products(List<MarketplaceProduct> products) {
    if (products.isEmpty) return const Text('Nenhum produto disponivel.');
    return SizedBox(
      height: 292,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final product = products[index];
          return SizedBox(
            width: 220,
            child: _ProductCard(
              product: product,
              currency: _currency,
              inCart: _inCart(product),
              onTap: () => _openProduct(product),
              onAdd: () => _addProduct(product),
            ),
          );
        },
      ),
    );
  }

  Widget _suppliers(List<MarketplaceSupplier> suppliers) {
    if (suppliers.isEmpty) return const Text('Nenhum fornecedor disponivel.');
    return SizedBox(
      height: 128,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: suppliers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final supplier = suppliers[index];
          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _openUrl(supplier.url),
            child: SizedBox(
              width: 132,
              child: Column(
                children: [
                  _NetworkImage(
                    url: supplier.imageUrl,
                    type: 'fornecedor',
                    itemId: supplier.id,
                    size: 82,
                    icon: Icons.storefront_outlined,
                  ),
                  const SizedBox(height: 8),
                  Text(supplier.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _supplierFilter() {
    return Row(
      children: [
        const Icon(Icons.store_outlined, size: 18),
        const SizedBox(width: 8),
        const Expanded(child: Text('Fornecedor ativo no carrinho.')),
        TextButton(
          onPressed: _changeSupplier,
          child: const Text('Outros fornecedores'),
        ),
      ],
    );
  }

  Widget _title(String value) => Text(
        value,
        style: Theme.of(context)
            .textTheme
            .titleLarge
            ?.copyWith(fontWeight: FontWeight.w700),
      );

  Widget _buildCartSummary() {
    final count = _cart.items.fold<int>(0, (sum, item) => sum + item.quantity);
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Material(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        elevation: 8,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            final result = await Navigator.push<Object?>(
              context,
              MaterialPageRoute(builder: (_) => CartPage(service: _service)),
            );
            if (!mounted) return;
            if (result == true) {
              _search.clear();
              final future = _loadInitial();
              setState(() {
                _query = '';
                _category = null;
                _results = const [];
                _pagination = null;
                _cart = const ShoppingCart(
                  id: 0,
                  activeSupplierId: null,
                  items: [],
                  totalItems: 0,
                );
                _initialFuture = future;
              });
            } else if (result is ShoppingCart) {
              setState(() => _cart = result);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.shopping_cart, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$count ${count == 1 ? 'item' : 'itens'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(_currency.format(_cart.totalItems),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InitialData {
  final MarketplaceHome home;
  final ShoppingCart cart;

  const _InitialData({required this.home, required this.cart});
}

class _ProductCard extends StatelessWidget {
  final MarketplaceProduct product;
  final NumberFormat currency;
  final bool inCart;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  const _ProductCard({
    required this.product,
    required this.currency,
    required this.inCart,
    required this.onTap,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _NetworkImage(
                  url: product.imageUrl,
                  type: 'produto',
                  itemId: product.idProduto,
                  size: 132,
                  width: double.infinity,
                  icon: Icons.fastfood_outlined,
                ),
                if (product.teleEntregaDisponivel)
                  Positioned(
                    top: 12,
                    left: -32,
                    child: Transform.rotate(
                      angle: -0.785,
                      child: Container(
                        width: 126,
                        color: Colors.green.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: const Text(
                          'Teleentrega',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(currency.format(product.price),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          )),
                  const SizedBox(height: 4),
                  Text(product.supplierName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: inCart
                          ? null
                          : (product.teleEntregaDisponivel ? onAdd : onTap),
                      icon: Icon(inCart ? Icons.check : Icons.add_shopping_cart,
                          size: 17),
                      label: Text(inCart ? 'No carrinho' : 'Adicionar'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkImage extends StatelessWidget {
  static final Set<String> _loggedItems = <String>{};
  final String? url;
  final String type;
  final int itemId;
  final double size;
  final double? width;
  final IconData icon;

  const _NetworkImage({
    required this.url,
    required this.type,
    required this.itemId,
    required this.size,
    required this.icon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: width ?? size,
      height: size,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(icon, size: size * 0.42),
    );
    final logKey = '$type:$itemId';
    if (_loggedItems.add(logKey)) {
      debugPrint('[Marketplace.Image] $type id=$itemId url=${url ?? '(nula)'}');
    }
    if (url == null) {
      debugPrint('[Marketplace.Image] sem_imagem tipo=$type id=$itemId');
      return fallback;
    }
    final uri = Uri.tryParse(url!);
    if (uri == null || !uri.isAbsolute || uri.host.isEmpty) {
      debugPrint(
          '[Marketplace.Image.Web] tipo=$type id=$itemId url=$url exception=UriInvalida statusCode=n/a message=uri_invalida');
      return fallback;
    }
    if (_loggedItems.add('uri:$logKey')) {
      debugPrint(
          '[Marketplace.Image.Uri] scheme=${uri.scheme} host=${uri.host} path=${uri.path} absolute=${uri.isAbsolute}');
    }
    return Image.network(
      url!,
      width: width ?? size,
      height: size,
      fit: BoxFit.cover,
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
      errorBuilder: (_, error, __) {
        final statusCode =
            error is NetworkImageLoadException ? error.statusCode : null;
        debugPrint(
            '[Marketplace.Image.Web] tipo=$type id=$itemId url=$url exception=${error.runtimeType} statusCode=${statusCode ?? 'n/a'} message=$error');
        return fallback;
      },
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : fallback,
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        _LoadingBlock(height: 56),
        SizedBox(height: 24),
        _LoadingBlock(height: 110),
        SizedBox(height: 24),
        _LoadingBlock(height: 260),
      ],
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  final double height;

  const _LoadingBlock({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final Future<void> Function() onRetry;
  final String message;

  const _ErrorView({
    required this.onRetry,
    this.message = 'Nao foi possivel carregar o marketplace.',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
