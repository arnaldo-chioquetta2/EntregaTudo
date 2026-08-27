import 'dart:async';

import 'package:flutter/material.dart';

enum ResilientImageState { notAvailable, loading, loaded, failed, retrying }

class ImageRecoveryCoordinator {
  ImageRecoveryCoordinator._();

  static final ImageRecoveryCoordinator instance = ImageRecoveryCoordinator._();

  final Map<String, _RetryRequest> _pending = <String, _RetryRequest>{};
  final Map<String, ResilientImageState> _states =
      <String, ResilientImageState>{};
  final Set<String> _cancelled = <String>{};
  String? _activeKey;
  bool _processing = false;

  void beginScreen() {
    _pending.clear();
    _states.clear();
    _cancelled.clear();
    _activeKey = null;
  }

  void register(String key, {required bool available}) {
    _states.putIfAbsent(
      key,
      () => available
          ? ResilientImageState.loading
          : ResilientImageState.notAvailable,
    );
    if (!available) {
      _log('[ImageRecovery.Skip] key=${_safeKey(key)} reason=no_url');
    }
  }

  void markLoaded(String key) {
    _states[key] = ResilientImageState.loaded;
    _log('[ImageRecovery.Success] key=${_safeKey(key)}');
    _summaryIfComplete();
  }

  void markFailed(String key) {
    _states[key] = ResilientImageState.failed;
    _log('[ImageRecovery.Failed] key=${_safeKey(key)}');
    _summaryIfComplete();
  }

  void enqueue({
    required String key,
    required int attempt,
    required Future<bool> Function(int attempt) retry,
  }) {
    if (_pending.containsKey(key) || _activeKey == key) return;
    _cancelled.remove(key);
    _pending[key] = _RetryRequest(attempt: attempt, retry: retry);
    _states[key] = ResilientImageState.retrying;
    _log('[ImageRecovery.Queue] key=${_safeKey(key)} '
        'pending=${_pending.length}');
    _process();
  }

  void remove(String key) {
    _pending.remove(key);
    _cancelled.add(key);
    if (_activeKey != key) _states.remove(key);
  }

  Future<void> _process() async {
    if (_processing) return;
    _processing = true;
    while (_pending.isNotEmpty) {
      final key = _pending.keys.first;
      final request = _pending.remove(key)!;
      _activeKey = key;
      final delay = Duration(seconds: 1 << (request.attempt - 1));
      await Future<void>.delayed(delay);
      if (_activeKey != key || _cancelled.contains(key)) {
        _activeKey = null;
        continue;
      }
      _log('[ImageRecovery.Try] key=${_safeKey(key)} '
          'attempt=${request.attempt}');
      final success = await request.retry(request.attempt);
      _activeKey = null;
      if (!success && request.attempt < 3 && !_cancelled.contains(key)) {
        _pending[key] = _RetryRequest(
          attempt: request.attempt + 1,
          retry: request.retry,
        );
        _states[key] = ResilientImageState.retrying;
      }
    }
    _activeKey = null;
    _processing = false;
    _summaryIfComplete();
  }

  void _summaryIfComplete() {
    if (_states.isEmpty) return;
    final expected = _states.values
        .where((state) => state != ResilientImageState.notAvailable)
        .length;
    final loaded = _states.values
        .where((state) => state == ResilientImageState.loaded)
        .length;
    final failed = _states.values
        .where((state) => state == ResilientImageState.failed)
        .length;
    if (loaded + failed == expected && _pending.isEmpty && !_processing) {
      final unavailable = _states.values
          .where((state) => state == ResilientImageState.notAvailable)
          .length;
      _log('[ImageRecovery.Summary] expected=$expected loaded=$loaded '
          'unavailable=$unavailable failed=$failed');
    }
  }

  String _safeKey(String key) {
    final parts = key.split(':');
    return parts.length >= 2 ? '${parts[0]}:${parts[1]}' : key;
  }

  void _log(String message) => debugPrint(message);
}

class _RetryRequest {
  final int attempt;
  final Future<bool> Function(int attempt) retry;

  const _RetryRequest({required this.attempt, required this.retry});
}

class ResilientNetworkImage extends StatefulWidget {
  final String? url;
  final String type;
  final int itemId;
  final double size;
  final double? width;
  final IconData icon;

  const ResilientNetworkImage({
    super.key,
    required this.url,
    required this.type,
    required this.itemId,
    required this.size,
    required this.icon,
    this.width,
  });

  @override
  State<ResilientNetworkImage> createState() => _ResilientNetworkImageState();
}

class _ResilientNetworkImageState extends State<ResilientNetworkImage> {
  final ImageRecoveryCoordinator _coordinator =
      ImageRecoveryCoordinator.instance;
  Completer<bool>? _retryResult;
  late ResilientImageState _state;
  int _attempt = 0;
  bool _eventScheduled = false;

  String get _key => '${widget.type}:${widget.itemId}:${widget.url}';

  String? get _validUrl {
    final value = widget.url?.trim();
    if (value == null || value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.isAbsolute || uri.host.isEmpty) return null;
    return value;
  }

  @override
  void initState() {
    super.initState();
    final url = _validUrl;
    _state = url == null
        ? ResilientImageState.notAvailable
        : ResilientImageState.loading;
    _coordinator.register(_key, available: url != null);
  }

  @override
  void didUpdateWidget(covariant ResilientNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldKey = '${oldWidget.type}:${oldWidget.itemId}:${oldWidget.url}';
    if (oldKey == _key) return;
    _coordinator.remove(oldKey);
    _retryResult?.complete(false);
    _retryResult = null;
    final url = _validUrl;
    _attempt = 0;
    _state = url == null
        ? ResilientImageState.notAvailable
        : ResilientImageState.loading;
    _coordinator.register(_key, available: url != null);
  }

  @override
  void dispose() {
    _coordinator.remove(_key);
    _retryResult?.complete(false);
    super.dispose();
  }

  void _schedule(VoidCallback callback) {
    if (_eventScheduled) return;
    _eventScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _eventScheduled = false;
      if (mounted) callback();
    });
  }

  void _markLoaded() {
    if (_state == ResilientImageState.loaded) return;
    _schedule(() {
      _state = ResilientImageState.loaded;
      _coordinator.markLoaded(_key);
      _retryResult?.complete(true);
      _retryResult = null;
      if (mounted) setState(() {});
    });
  }

  void _markFailed() {
    if (_retryResult != null) {
      final result = _retryResult!;
      _retryResult = null;
      if (_attempt >= 3) {
        _state = ResilientImageState.failed;
        _coordinator.markFailed(_key);
      }
      result.complete(false);
      if (mounted) setState(() {});
      return;
    }
    if (_attempt == 0) {
      _state = ResilientImageState.retrying;
      _coordinator.enqueue(
        key: _key,
        attempt: 1,
        retry: _runRetry,
      );
      if (mounted) setState(() {});
    }
  }

  Future<bool> _runRetry(int attempt) async {
    if (!mounted) return false;
    final result = Completer<bool>();
    final url = _validUrl;
    if (url == null) return Future<bool>.value(false);
    NetworkImage(url).evict();
    setState(() {
      _attempt = attempt;
      _state = ResilientImageState.retrying;
      _retryResult = result;
    });
    return result.future;
  }

  Widget _placeholder() {
    return Container(
      width: widget.width ?? widget.size,
      height: widget.size,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(widget.icon, size: widget.size * 0.42),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = _validUrl;
    if (url == null) return _placeholder();
    return Image.network(
      key: ValueKey('$_key:$_attempt'),
      url,
      width: widget.width ?? widget.size,
      height: widget.size,
      fit: BoxFit.cover,
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (frame != null || wasSynchronouslyLoaded) _markLoaded();
        return child;
      },
      errorBuilder: (context, error, stackTrace) {
        _schedule(_markFailed);
        return _placeholder();
      },
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _placeholder(),
    );
  }
}
