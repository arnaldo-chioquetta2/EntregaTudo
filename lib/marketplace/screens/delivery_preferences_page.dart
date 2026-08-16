import 'dart:async';

import 'package:flutter/material.dart';

import '../api_v1_error.dart';
import '../services/marketplace_service.dart';

class DeliveryPreferencesPage extends StatefulWidget {
  final MarketplaceService service;

  const DeliveryPreferencesPage({super.key, required this.service});

  @override
  State<DeliveryPreferencesPage> createState() =>
      _DeliveryPreferencesPageState();
}

class _DeliveryPreferencesPageState extends State<DeliveryPreferencesPage> {
  final _searchController = TextEditingController();
  Timer? _timer;
  int _generation = 0;
  bool _loading = true;
  bool _changed = false;
  String? _error;
  List<Map<String, dynamic>> _favorites = [];
  List<Map<String, dynamic>> _unwanted = [];
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.service.loadDeliveryPreferences();
      if (!mounted) return;
      setState(() {
        _favorites = _list(data['favoritos']);
        _unwanted = _list(data['indesejados']);
        _loading = false;
      });
    } on ApiV1Exception catch (error) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = error.message;
        });
    }
  }

  void _search(String value) {
    _timer?.cancel();
    final query = value.trim();
    final generation = ++_generation;
    if (query.length < 3) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }
    _timer = Timer(const Duration(seconds: 2), () async {
      try {
        final results = await widget.service.searchDeliveryPeople(query);
        if (!mounted || generation != _generation) return;
        setState(() {
          _results = results;
          _error = null;
        });
      } on ApiV1Exception catch (error) {
        if (mounted && generation == _generation)
          setState(() => _error = error.message);
      }
    });
  }

  Future<void> _set(int id, String type) async {
    try {
      await widget.service.setDeliveryPreference(id, type);
      _changed = true;
      await _load();
    } on ApiV1Exception catch (error) {
      if (mounted) _show(error.message);
    }
  }

  Future<void> _remove(int id) async {
    try {
      await widget.service.removeDeliveryPreference(id);
      _changed = true;
      await _load();
    } on ApiV1Exception catch (error) {
      if (mounted) _show(error.message);
    }
  }

  List<Map<String, dynamic>> _list(Object? value) => value is List
      ? value.whereType<Map<String, dynamic>>().toList(growable: false)
      : <Map<String, dynamic>>[];

  int _id(Map<String, dynamic> item) =>
      int.tryParse('${item['idEntregador'] ?? item['id'] ?? 0}') ?? 0;
  String _name(Map<String, dynamic> item) => '${item['nome'] ?? 'Entregador'}';

  void _show(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _changed);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Preferencias de entregadores')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  TextField(
                      controller: _searchController,
                      onChanged: _search,
                      decoration: const InputDecoration(
                          labelText: 'Buscar entregador',
                          prefixIcon: Icon(Icons.search))),
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.red))),
                  _section('Favoritos', _favorites, 'favorito'),
                  _section('Indesejados', _unwanted, 'indesejado'),
                  if (_results.isNotEmpty) _resultsSection(),
                ],
              ),
      ),
    );
  }

  Widget _section(String title, List<Map<String, dynamic>> items, String type) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 20),
      Text(title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      if (items.isEmpty)
        const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Nenhum entregador nesta lista.')),
      ...items.map((item) => ListTile(
            title: Text(_name(item)),
            leading: Icon(type == 'favorito' ? Icons.favorite : Icons.block),
            trailing: IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => _remove(_id(item))),
          )),
    ]);
  }

  Widget _resultsSection() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 20),
        const Text('Resultados',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ..._results.map((item) => ListTile(
              title: Text(_name(item)),
              leading: const Icon(Icons.person_outline),
              trailing: Wrap(children: [
                IconButton(
                    tooltip: 'Favorito',
                    icon: const Icon(Icons.favorite_border),
                    onPressed: () => _set(_id(item), 'favorito')),
                IconButton(
                    tooltip: 'Indesejado',
                    icon: const Icon(Icons.block),
                    onPressed: () => _set(_id(item), 'indesejado')),
              ]),
            )),
      ]);
}
