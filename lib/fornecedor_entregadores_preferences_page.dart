import 'dart:async';

import 'package:flutter/material.dart';

import 'api.dart';

class FornecedorEntregadoresPreferencesPage extends StatefulWidget {
  const FornecedorEntregadoresPreferencesPage({super.key});

  @override
  State<FornecedorEntregadoresPreferencesPage> createState() =>
      _FornecedorEntregadoresPreferencesPageState();
}

class _FornecedorEntregadoresPreferencesPageState
    extends State<FornecedorEntregadoresPreferencesPage> {
  final _searchController = TextEditingController();
  Timer? _searchTimer;
  int _searchGeneration = 0;
  final Set<int> _busyIds = <int>{};
  List<Map<String, dynamic>> _favoritos = [];
  List<Map<String, dynamic>> _resultadosDaBusca = [];
  List<Map<String, dynamic>> _indesejados = [];
  bool _loading = true;
  bool _searchLoading = false;
  bool _searchCompleted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await API.getFornecedorEntregadorPreferencias();
      if (!mounted) return;
      setState(() {
        _favoritos = _maps(data['favoritos']);
        _resultadosDaBusca = [];
        _indesejados = _maps(data['indesejados']);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyError(error, 'Nao foi possivel carregar as preferencias.');
      });
    }
  }

  void _search(String value) {
    _searchTimer?.cancel();
    final query = value.trim();
    final generation = ++_searchGeneration;
    print('[EntregadoresPreferencias] busca_digitada="$query"');
    print('[EntregadoresPreferencias] tamanho_query=${query.length}');
    print('[EntregadoresPreferencias] generation=$generation');
    if (query.isEmpty) {
      _searchLoading = false;
      _searchCompleted = false;
      _loadPreferences();
      return;
    }
    if (query.length < 3) {
      setState(() {
        _resultadosDaBusca = [];
        _searchLoading = false;
        _searchCompleted = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _resultadosDaBusca = [];
      _searchLoading = true;
      _searchCompleted = false;
      _error = null;
    });
    print('[EntregadoresPreferencias] debounce_agendado');
    _searchTimer = Timer(const Duration(milliseconds: 300), () async {
      print('[EntregadoresPreferencias] busca_iniciada');
      try {
        final data = await API.buscarFornecedorEntregadores(query);
        if (!mounted || generation != _searchGeneration) {
          print('[EntregadoresPreferencias] resposta_ignorada_por_generation');
          print('[EntregadoresPreferencias] busca_finalizada');
          return;
        }
        final resultados = _maps(data['items'])
            .where((item) => item['tipo'] == null)
            .toList();
        print('[EntregadoresPreferencias] resultados_recebidos=${resultados.length}');
        setState(() {
          _error = null;
          _searchLoading = false;
          _searchCompleted = true;
          _resultadosDaBusca = resultados;
        });
        print('[EntregadoresPreferencias] busca_finalizada');
      } catch (error) {
        if (!mounted || generation != _searchGeneration) {
          print('[EntregadoresPreferencias] resposta_ignorada_por_generation');
          print('[EntregadoresPreferencias] busca_finalizada');
          return;
        }
        print('[EntregadoresPreferencias] erro=${error.runtimeType}: '
            '${_friendlyError(error, 'Falha ao buscar entregadores.')}');
        setState(() {
          _searchLoading = false;
          _searchCompleted = true;
          _error = _friendlyError(error, 'Falha ao buscar entregadores.');
        });
        print('[EntregadoresPreferencias] busca_finalizada');
      }
    });
  }

  Future<void> _setPreference(int id, String tipo) async {
    if (_busyIds.contains(id)) return;
    setState(() => _busyIds.add(id));
    try {
      final ok = await API.marcarFornecedorEntregador(id, tipo);
      if (!ok) throw const ApiRequestException('Nao foi possivel atualizar a preferencia.');
      _moveLocally(id, tipo);
      _showMessage(tipo == 'favorito'
          ? 'Entregador adicionado aos favoritos.'
          : 'Entregador marcado como indesejado.');
    } catch (error) {
      _showMessage(_friendlyError(error, 'Nao foi possivel atualizar a preferencia.'),
          isError: true);
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  Future<void> _removePreference(int id) async {
    if (_busyIds.contains(id)) return;
    setState(() => _busyIds.add(id));
    try {
      final ok = await API.removerFornecedorEntregadorPreferencia(id);
      if (!ok) throw const ApiRequestException('Nao foi possivel remover a preferencia.');
      final item = _takeById(_favoritos, id) ?? _takeById(_indesejados, id);
      if (item != null) _resultadosDaBusca = [..._resultadosDaBusca, item];
      setState(() {});
      _showMessage('Preferencia removida.');
    } catch (error) {
      _showMessage(_friendlyError(error, 'Nao foi possivel remover a preferencia.'),
          isError: true);
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  void _moveLocally(int id, String tipo) {
    final item = _takeById(_favoritos, id) ??
        _takeById(_resultadosDaBusca, id) ??
        _takeById(_indesejados, id);
    if (item == null) return;
    final updated = {...item, 'tipo': tipo};
    if (tipo == 'favorito') {
      _favoritos = [..._favoritos, updated];
    } else {
      _indesejados = [..._indesejados, updated];
    }
    setState(() {});
  }

  Map<String, dynamic>? _takeById(List<Map<String, dynamic>> list, int id) {
    final index = list.indexWhere((item) => _id(item) == id);
    if (index < 0) return null;
    final item = list[index];
    list.removeAt(index);
    return item;
  }

  String _friendlyError(Object error, String fallback) {
    if (error is ApiRequestException && error.message.isNotEmpty) {
      return error.message;
    }
    return fallback;
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ));
  }

  List<Map<String, dynamic>> _maps(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  int _id(Map<String, dynamic> item) =>
      int.tryParse('${item['idEntregador']}') ?? 0;

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();
    final queryValida = query.length >= 3;

    return Scaffold(
      appBar: AppBar(title: const Text('Preferencias de entregadores')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPreferences,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: _search,
                    decoration: const InputDecoration(
                      labelText: 'Buscar entregador',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (!queryValida)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Digite pelo menos 3 caracteres para buscar.'),
                    ),
                  if (_searchLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: LinearProgressIndicator(),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
                  _section('Favoritos', _favoritos, (item) => [
                        _actionButton('Remover dos favoritos', _id(item),
                            () => _removePreference(_id(item))),
                        _actionButton('Marcar como indesejado', _id(item),
                            () => _setPreference(_id(item), 'indesejado')),
                      ],
                      empty: 'Voce ainda nao possui entregadores favoritos.'),
                  if (queryValida)
                    _section('Outros entregadores', _resultadosDaBusca, (item) => [
                          _actionButton('Adicionar aos favoritos', _id(item),
                              () => _setPreference(_id(item), 'favorito'),
                              primary: true),
                          _actionButton('Marcar como indesejado', _id(item),
                              () => _setPreference(_id(item), 'indesejado')),
                        ],
                        empty: _searchCompleted
                            ? 'Nenhum entregador encontrado.'
                            : 'Nenhum outro entregador encontrado.'),
                  _section('Indesejados', _indesejados, (item) => [
                        _actionButton('Remover dos indesejados', _id(item),
                            () => _removePreference(_id(item))),
                        _actionButton('Adicionar aos favoritos', _id(item),
                            () => _setPreference(_id(item), 'favorito'),
                            primary: true),
                      ],
                      empty: 'Voce ainda nao possui entregadores indesejados.'),
                ],
              ),
            ),
    );
  }

  Widget _actionButton(String label, int id, VoidCallback action,
      {bool primary = false}) {
    final busy = _busyIds.contains(id);
    final child = busy
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label);
    if (primary) {
      return ElevatedButton(
        onPressed: busy ? null : action,
        child: child,
      );
    }
    return OutlinedButton(
      onPressed: busy ? null : action,
      child: child,
    );
  }

  Widget _section(
    String title,
    List<Map<String, dynamic>> items,
    List<Widget> Function(Map<String, dynamic>) actions, {
    required String empty,
  }) {
    return Card(
      margin: const EdgeInsets.only(top: 20),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(empty),
              )
            else
              ...items.map((item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${item['nome'] ?? ''}'),
                    subtitle: Wrap(
                        spacing: 8, runSpacing: 4, children: actions(item)),
                  )),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}
