import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import 'location_service.dart';
import '../models/entrega_ativa.dart';
import '../models/delivery_details.dart';
import '../utils/online_status_service.dart';
import '../services/entrega_service.dart';

typedef MotoboyHeartbeat = Future<DeliveryDetails?> Function(
    double latitude, double longitude);
typedef ReportDeliveryView = Future<void> Function(int? userId, int? chamado);
typedef FornecedorHeartbeat = Future<FornecedorHeartbeatResponse?> Function(
    double latitude, double longitude);
typedef FornecedorOffline = Future<bool> Function({int? idLoja, int? idPessoa});
typedef NewSaleListener = Future<void> Function(
    NovaVenda novaVenda, List<ItemVenda> itensVenda);
typedef RespondToDelivery = Future<bool> Function(
    int userId, int deliveryId, bool accept);
typedef LoadActiveDelivery = Future<EntregaAtiva?> Function();
typedef NotifyDelivery = Future<bool> Function(
    {int? idPedido, int? idMotoboy, String? codigo});

class DeliveryActionResult {
  const DeliveryActionResult({required this.success, this.message});
  final bool success;
  final String? message;
}

class HomeOperationalController extends ChangeNotifier {
  HomeOperationalController({
    LocationService? locationService,
    MotoboyHeartbeat? motoboyHeartbeat,
    ReportDeliveryView? reportDeliveryView,
    FornecedorHeartbeat? fornecedorHeartbeat,
    FornecedorOffline? fornecedorOffline,
    RespondToDelivery? respondToDelivery,
    LoadActiveDelivery? loadActiveDelivery,
    NotifyDelivery? notifyPickedUp,
    NotifyDelivery? notifyDeliveryCompleted,
    this.onNewSale,
    Future<SharedPreferences> Function()? preferencesProvider,
  })  : locationService = locationService ?? LocationService(),
        _motoboyHeartbeat = motoboyHeartbeat ?? API.sendHeartbeat,
        _reportDeliveryView = reportDeliveryView ?? API.reportViewToServer,
        _fornecedorHeartbeat = fornecedorHeartbeat ?? API.sendHeartbeatF,
        _fornecedorOffline = fornecedorOffline ?? API.fornecedorOff,
        _respondToDelivery = respondToDelivery ?? API.respondToDelivery,
        _loadActiveDelivery =
            loadActiveDelivery ?? EntregaService.carregarEntregaAtiva,
        _notifyPickedUp = notifyPickedUp ?? API.notifyPickedUp,
        _notifyDeliveryCompleted =
            notifyDeliveryCompleted ?? API.notifyDeliveryCompleted,
        _preferencesProvider =
            preferencesProvider ?? SharedPreferences.getInstance;

  final LocationService locationService;
  final MotoboyHeartbeat _motoboyHeartbeat;
  final ReportDeliveryView _reportDeliveryView;
  final FornecedorHeartbeat _fornecedorHeartbeat;
  final FornecedorOffline _fornecedorOffline;
  final RespondToDelivery _respondToDelivery;
  final LoadActiveDelivery _loadActiveDelivery;
  final NotifyDelivery _notifyPickedUp;
  final NotifyDelivery _notifyDeliveryCompleted;
  final Future<SharedPreferences> Function() _preferencesProvider;

  Timer? heartbeatTimer;
  bool motoboyTrackingActive = false;
  bool motoboyOnline = false;
  bool motoboyProfileActive = false;
  bool fornecedorProfileActive = false;
  bool fornecedorOnline = false;
  bool heartbeatPausedByDelivery = false;
  bool heartbeatPausedBySale = false;
  bool nextHeartbeatIsFornecedor = true;
  bool _motoboyHeartbeatInProgress = false;
  bool _fornecedorHeartbeatInProgress = false;
  bool _heartbeatCycleInProgress = false;
  bool _deliveryActionInProgress = false;
  bool hasAcceptedDelivery = false;
  bool hasPickedUp = false;
  bool deliveryCompleted = false;
  String? deliveryActionError;
  bool _sessionDisposed = false;
  EntregaAtiva? entregaAtiva;
  Map<String, dynamic>? deliveryDataMotoboy;
  Map<String, dynamic>? deliveryDataFornecedor;
  int? currentChamado;
  int lojasNoRaio = 0;
  NovaVenda? novaVenda;
  List<ItemVenda> itensVenda = const [];
  Map<String, dynamic>? currentSupplierSale;
  String? _lastSupplierSaleKey;
  NewSaleListener? onNewSale;

  bool get motoboyHeartbeatInProgress => _motoboyHeartbeatInProgress;
  bool get fornecedorHeartbeatInProgress => _fornecedorHeartbeatInProgress;
  bool get deliveryActionInProgress => _deliveryActionInProgress;

  void setProfileFlags({
    required bool isMotoboy,
    required bool isFornecedor,
  }) {
    motoboyProfileActive = isMotoboy;
    fornecedorProfileActive = isFornecedor;
  }

  void setHeartbeatTimer(Timer? timer) {
    heartbeatTimer?.cancel();
    heartbeatTimer = timer;
  }

  void scheduleHeartbeat(Duration delay, FutureOr<void> Function() action) {
    cancelHeartbeatTimer();
    heartbeatTimer = Timer(delay, action);
  }

  void cancelHeartbeatTimer() {
    heartbeatTimer?.cancel();
    heartbeatTimer = null;
  }

  void setMotoboyOnline(bool value) {
    if (motoboyOnline == value) return;
    motoboyOnline = value;
    notifyListeners();
  }

  void setFornecedorOnline(bool value) {
    if (fornecedorOnline == value) return;
    fornecedorOnline = value;
    notifyListeners();
  }

  Future<void> setMotoboyAvailability({
    required bool online,
    int? userId,
    required Duration heartbeatInterval,
  }) async {
    if (_sessionDisposed || !motoboyProfileActive) return;
    if (online) {
      await locationService.requestPermissions();
      motoboyTrackingActive = true;
      locationService.startTracking((position) async {
        if (_sessionDisposed || !motoboyOnline || !motoboyTrackingActive)
          return;
        await sendMotoboyHeartbeat(position.latitude, position.longitude);
      });
      await OnlineStatusService.setMotoStatus(true);
      setMotoboyOnline(true);
      scheduleHeartbeatCycle(heartbeatInterval);
      return;
    }
    motoboyTrackingActive = false;
    locationService.stopTracking();
    await OnlineStatusService.setMotoStatus(false);
    final effectiveUserId =
        userId ?? (await _preferencesProvider()).getInt('idUser');
    if (effectiveUserId != null) await API.motoOff(effectiveUserId);
    setMotoboyOnline(false);
  }

  Future<bool> sendMotoboyHeartbeatFromCurrentPosition() async {
    final position = locationService.ultimaPosicao;
    final latitude = position?.latitude ?? -30.1165;
    final longitude = position?.longitude ?? -51.1355;
    return sendMotoboyHeartbeat(latitude, longitude);
  }

  Future<bool> sendMotoboyHeartbeat(double latitude, double longitude) async {
    if (_sessionDisposed ||
        !motoboyProfileActive ||
        _motoboyHeartbeatInProgress) {
      return false;
    }

    _motoboyHeartbeatInProgress = true;
    try {
      final response = await _motoboyHeartbeat(latitude, longitude);
      if (response == null || _sessionDisposed) return false;
      await processMotoboyResponse(response);
      return true;
    } finally {
      _motoboyHeartbeatInProgress = false;
    }
  }

  Future<bool> processMotoboyResponse(DeliveryDetails deliveryDetails) async {
    if (_sessionDisposed) return false;

    final prefs = await _preferencesProvider();
    lojasNoRaio = deliveryDetails.lojasNoRaio;

    if (deliveryDetails.chamado == null || deliveryDetails.chamado == 0) {
      deliveryDataMotoboy = null;
      notifyListeners();
      return true;
    }

    heartbeatPausedByDelivery = true;
    final valorSeguro = (deliveryDetails.valor ?? 0).toDouble();
    final distSeguro = (deliveryDetails.dist ?? 0).toDouble();
    final pesoSeguro = (deliveryDetails.peso ?? 0).toDouble();

    deliveryDataMotoboy = {
      'enderIN': deliveryDetails.enderIN ?? 'Desconhecido',
      'enderFN': deliveryDetails.enderFN ?? 'Desconhecido',
      'dist': distSeguro,
      'valor': valorSeguro,
      'peso': pesoSeguro,
      'chamado': deliveryDetails.chamado,
      'lojasNoRaio': deliveryDetails.lojasNoRaio,
      'fornecedor': deliveryDetails.fornecedor,
      'codigoRetirada': deliveryDetails.codigoRetirada,
      'codigoColeta': deliveryDetails.codigoColeta,
      'codigoConfirmacao': deliveryDetails.codigoConfirmacao,
    };

    final previousChamado = prefs.getInt('currentChamado');
    currentChamado = previousChamado;
    if (previousChamado != deliveryDetails.chamado) {
      currentChamado = deliveryDetails.chamado;
      await prefs.setInt('currentChamado', deliveryDetails.chamado!);
      await _reportDeliveryView(
        prefs.getInt('idUser'),
        deliveryDetails.chamado,
      );
    }

    notifyListeners();
    return true;
  }

  Future<DeliveryActionResult> respondToCurrentOffer(bool accept) async {
    if (_sessionDisposed || _deliveryActionInProgress) {
      return const DeliveryActionResult(
          success: false, message: 'Ação já está sendo processada.');
    }
    final offer = deliveryDataMotoboy;
    final deliveryId = _toInt(offer?['chamado']);
    final prefs = await _preferencesProvider();
    final userId = prefs.getInt('idUser');
    if (offer == null || deliveryId == null || userId == null) {
      return const DeliveryActionResult(
          success: false, message: 'Não foi possível identificar a entrega.');
    }
    _deliveryActionInProgress = true;
    notifyListeners();
    try {
      final success = await _respondToDelivery(userId, deliveryId, accept);
      if (!success || _sessionDisposed) {
        return const DeliveryActionResult(
            success: false, message: 'Erro ao comunicar resposta ao servidor.');
      }
      if (!accept) {
        deliveryDataMotoboy = null;
        hasAcceptedDelivery = false;
        hasPickedUp = false;
        deliveryCompleted = false;
        heartbeatPausedByDelivery = false;
        notifyListeners();
        return const DeliveryActionResult(
            success: true, message: 'Entrega recusada.');
      }
      var activeDelivery = await _loadActiveDelivery();
      activeDelivery ??= EntregaAtiva(
        idPedido: deliveryId,
        codigoRetirada:
            (offer['codigoRetirada'] ?? offer['codigoColeta'] ?? '').toString(),
        fornecedor: (offer['fornecedor'] ?? '').toString(),
        enderecoFornecedor: (offer['enderIN'] ?? '').toString(),
        codigoColeta: offer['codigoColeta']?.toString(),
        status: 1,
      );
      entregaAtiva = activeDelivery;
      hasAcceptedDelivery = true;
      hasPickedUp = false;
      deliveryCompleted = false;
      deliveryDataMotoboy = null;
      heartbeatPausedByDelivery = true;
      notifyListeners();
      return const DeliveryActionResult(
          success: true, message: 'Entrega aceita. Dirija-se ao fornecedor.');
    } finally {
      _deliveryActionInProgress = false;
      notifyListeners();
    }
  }

  Future<DeliveryActionResult> markDeliveryPickedUp() async {
    if (_sessionDisposed || _deliveryActionInProgress) {
      return const DeliveryActionResult(
          success: false, message: 'Ação já está sendo processada.');
    }
    final activeDelivery = entregaAtiva;
    final prefs = await _preferencesProvider();
    final userId = prefs.getInt('idUser');
    if (activeDelivery == null || userId == null) {
      return const DeliveryActionResult(
          success: false, message: 'Não foi possível identificar a entrega.');
    }
    _deliveryActionInProgress = true;
    notifyListeners();
    try {
      final success = await _notifyPickedUp(
        idPedido: activeDelivery.idPedido,
        idMotoboy: userId,
        codigo: activeDelivery.codigoColeta ?? activeDelivery.codigoRetirada,
      );
      if (!success || _sessionDisposed) {
        return const DeliveryActionResult(
            success: false,
            message: 'Falha ao registrar a chegada no fornecedor.');
      }
      hasPickedUp = true;
      deliveryCompleted = false;
      notifyListeners();
      return const DeliveryActionResult(
          success: true, message: 'Peguei a encomenda com o fornecedor.');
    } finally {
      _deliveryActionInProgress = false;
      notifyListeners();
    }
  }

  Future<DeliveryActionResult> completeActiveDelivery(String code) async {
    final normalizedCode = code.trim();
    if (normalizedCode.length != 3 || int.tryParse(normalizedCode) == null) {
      return const DeliveryActionResult(
          success: false, message: 'Digite um codigo valido de 3 digitos');
    }
    if (_sessionDisposed || _deliveryActionInProgress) {
      return const DeliveryActionResult(
          success: false, message: 'Ação já está sendo processada.');
    }
    final activeDelivery = entregaAtiva;
    final prefs = await _preferencesProvider();
    final userId = prefs.getInt('idUser');
    if (activeDelivery == null || userId == null) {
      return const DeliveryActionResult(
          success: false, message: 'Não foi possível identificar a entrega.');
    }
    _deliveryActionInProgress = true;
    notifyListeners();
    try {
      final success = await _notifyDeliveryCompleted(
        idPedido: activeDelivery.idPedido,
        idMotoboy: userId,
        codigo: normalizedCode,
      );
      if (!success || _sessionDisposed) {
        return const DeliveryActionResult(
            success: false, message: 'Codigo do cliente invalido.');
      }
      heartbeatPausedByDelivery = false;
      deliveryCompleted = true;
      hasAcceptedDelivery = false;
      hasPickedUp = false;
      entregaAtiva = null;
      deliveryDataMotoboy = null;
      notifyListeners();
      return const DeliveryActionResult(
          success: true, message: 'Entrega concluída com sucesso.');
    } finally {
      _deliveryActionInProgress = false;
      notifyListeners();
    }
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  Future<bool> sendFornecedorHeartbeatFromCurrentPosition() async {
    final position = locationService.ultimaPosicao;
    final latitude = position?.latitude ?? -30.1165;
    final longitude = position?.longitude ?? -51.1355;
    return sendFornecedorHeartbeat(latitude, longitude);
  }

  Future<bool> sendFornecedorHeartbeat(
      double latitude, double longitude) async {
    if (_sessionDisposed ||
        !fornecedorProfileActive ||
        _fornecedorHeartbeatInProgress) {
      return false;
    }

    _fornecedorHeartbeatInProgress = true;
    try {
      final response = await _fornecedorHeartbeat(latitude, longitude);
      if (response == null || _sessionDisposed) return false;
      await processFornecedorResponse(response);
      return true;
    } finally {
      _fornecedorHeartbeatInProgress = false;
    }
  }

  Future<bool> processFornecedorResponse(
      FornecedorHeartbeatResponse response) async {
    if (_sessionDisposed) return false;

    final prefs = await _preferencesProvider();
    final previousAviso = prefs.getInt('idAviso');
    final previousPedido = prefs.getInt('idPed');
    lojasNoRaio = response.lojasNoRaio;
    deliveryDataFornecedor = {
      'idLoja': response.idLoja,
      'lojasNoRaio': response.lojasNoRaio,
    };

    final sale = response.novaVenda;
    final items = response.itensVenda;
    novaVenda = sale;
    itensVenda = List<ItemVenda>.unmodifiable(items);

    if (sale != null && items.isNotEmpty) {
      final saleKey = '${sale.idAviso}:${sale.idPed}';
      final previousKey = _lastSupplierSaleKey ??
          (previousAviso == null || previousPedido == null
              ? null
              : '$previousAviso:$previousPedido');
      final isNewSale = previousKey != saleKey;
      _lastSupplierSaleKey = saleKey;
      currentSupplierSale = {
        'idPed': sale.idPed,
        'idAviso': sale.idAviso,
      };
      await prefs.setString('hora', sale.hora);
      await prefs.setString('valor', sale.valor);
      await prefs.setString('cliente', sale.cliente);
      await prefs.setInt('idPed', sale.idPed);
      await prefs.setInt('idAviso', sale.idAviso);
      notifyListeners();
      if (isNewSale) {
        final listener = onNewSale;
        if (listener != null) await listener(sale, items);
      }
    } else {
      novaVenda = null;
      itensVenda = const [];
      notifyListeners();
    }
    return true;
  }

  Future<bool> fornecedorOff({int? idLoja, int? idPessoa}) async {
    if (_sessionDisposed) return false;
    return _fornecedorOffline(idLoja: idLoja, idPessoa: idPessoa);
  }

  void scheduleHeartbeatCycle(Duration interval) {
    cancelHeartbeatTimer();
    if (_sessionDisposed) return;
    heartbeatTimer = Timer(interval, () => runHeartbeatCycle(interval));
  }

  Future<void> runHeartbeatCycle(Duration interval) async {
    if (_sessionDisposed || _heartbeatCycleInProgress) return;

    _heartbeatCycleInProgress = true;
    try {
      if (!motoboyOnline && !fornecedorOnline) return;
      if (heartbeatPausedByDelivery && heartbeatPausedBySale) return;

      if (motoboyProfileActive && !fornecedorProfileActive) {
        if (motoboyOnline && !heartbeatPausedBySale && !motoboyTrackingActive) {
          await sendMotoboyHeartbeatFromCurrentPosition();
        }
        return;
      }

      if (!motoboyProfileActive && fornecedorProfileActive) {
        if (fornecedorOnline && !heartbeatPausedByDelivery) {
          await sendFornecedorHeartbeatFromCurrentPosition();
        }
        return;
      }

      if (motoboyProfileActive && fornecedorProfileActive) {
        if (heartbeatPausedByDelivery) {
          if (!motoboyTrackingActive) {
            await sendMotoboyHeartbeatFromCurrentPosition();
          }
          return;
        }

        if (heartbeatPausedBySale) {
          await sendFornecedorHeartbeatFromCurrentPosition();
          return;
        }

        if (nextHeartbeatIsFornecedor) {
          await sendFornecedorHeartbeatFromCurrentPosition();
          nextHeartbeatIsFornecedor = false;
        } else {
          if (!motoboyTrackingActive) {
            await sendMotoboyHeartbeatFromCurrentPosition();
          }
          nextHeartbeatIsFornecedor = true;
        }
      }
    } finally {
      _heartbeatCycleInProgress = false;
      if (!_sessionDisposed) scheduleHeartbeatCycle(interval);
    }
  }

  void disposeSession() {
    if (_sessionDisposed) return;
    _sessionDisposed = true;
    cancelHeartbeatTimer();
    motoboyTrackingActive = false;
    locationService.stopTracking();
    dispose();
  }
}
