import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import 'location_service.dart';
import '../models/entrega_ativa.dart';
import '../models/delivery_details.dart';
import '../utils/online_status_service.dart';
import '../services/entrega_service.dart';
import 'fornecedor/fornecedor_availability.dart';

typedef MotoboyHeartbeat = Future<DeliveryDetails?> Function(
    double latitude, double longitude);
typedef ReportDeliveryView = Future<void> Function(int? userId, int? chamado);
typedef FornecedorHeartbeat = Future<FornecedorHeartbeatResponse?> Function(
    double latitude, double longitude);
typedef FornecedorOffline = Future<bool> Function({int? idLoja, int? idPessoa});
typedef ConfirmSupplierSale = Future<bool> Function(int idAviso, int idPed);
typedef NewSaleListener = Future<void> Function(
    NovaVenda novaVenda, List<ItemVenda> itensVenda);
typedef RespondToDelivery = Future<bool> Function(
    int userId, int deliveryId, bool accept);
typedef LoadActiveDelivery = Future<EntregaAtiva?> Function();
typedef LoadFornecedorDisponibilidade = Future<FornecedorDisponibilidade>
    Function();
typedef NotifyDelivery = Future<bool> Function(
    {int? idPedido, int? idMotoboy, String? codigo});

class DeliveryActionResult {
  const DeliveryActionResult({required this.success, this.message});
  final bool success;
  final String? message;
}

class HomeOperationalController extends ChangeNotifier with WidgetsBindingObserver {
  HomeOperationalController({
    LocationService? locationService,
    MotoboyHeartbeat? motoboyHeartbeat,
    ReportDeliveryView? reportDeliveryView,
    FornecedorHeartbeat? fornecedorHeartbeat,
    FornecedorOffline? fornecedorOffline,
    ConfirmSupplierSale? confirmSupplierSale,
    RespondToDelivery? respondToDelivery,
    LoadActiveDelivery? loadActiveDelivery,
    NotifyDelivery? notifyPickedUp,
    NotifyDelivery? notifyDeliveryCompleted,
    this.onNewSale,
    LoadFornecedorDisponibilidade? loadFornecedorDisponibilidade,
    Future<SharedPreferences> Function()? preferencesProvider,
  })  : locationService = locationService ?? LocationService(),
        _motoboyHeartbeat = motoboyHeartbeat ?? API.sendHeartbeat,
        _reportDeliveryView = reportDeliveryView ?? API.reportViewToServer,
        _fornecedorHeartbeat = fornecedorHeartbeat ?? API.sendHeartbeatF,
        _fornecedorOffline = fornecedorOffline ?? API.fornecedorOff,
        _confirmSupplierSale = confirmSupplierSale ?? API.fornecedorConfirmou,
        _respondToDelivery = respondToDelivery ?? API.respondToDelivery,
        _loadActiveDelivery =
            loadActiveDelivery ?? EntregaService.carregarEntregaAtiva,
        _notifyPickedUp = notifyPickedUp ?? API.notifyPickedUp,
        _notifyDeliveryCompleted =
            notifyDeliveryCompleted ?? API.notifyDeliveryCompleted,
        _loadFornecedorDisponibilidade = loadFornecedorDisponibilidade ??
            (() => FornecedorDisponibilidadeService().fetch()),
        _preferencesProvider =
            preferencesProvider ?? SharedPreferences.getInstance {
    WidgetsBinding.instance.addObserver(this);
  }

  final LocationService locationService;
  final MotoboyHeartbeat _motoboyHeartbeat;
  final ReportDeliveryView _reportDeliveryView;
  final FornecedorHeartbeat _fornecedorHeartbeat;
  final FornecedorOffline _fornecedorOffline;
  final ConfirmSupplierSale _confirmSupplierSale;
  final RespondToDelivery _respondToDelivery;
  final LoadActiveDelivery _loadActiveDelivery;
  final NotifyDelivery _notifyPickedUp;
  final NotifyDelivery _notifyDeliveryCompleted;
  final LoadFornecedorDisponibilidade _loadFornecedorDisponibilidade;
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
  bool _supplierSaleActionInProgress = false;
  TipoFornecedor? tipoFornecedor;
  bool fornecedorDisponibilidadeLoading = false;
  bool? fornecedorDisponivelComercialmente;
  String? fornecedorDisponibilidadeError;
  bool _fornecedorDisponibilidadeLoaded = false;
  bool _appForeground = true;
  Timer? _fornecedorDisponibilidadeTimer;
  static const _fornecedorDisponibilidadeInterval = Duration(minutes: 5);
  bool _fornecedorDisponibilidadeRequestInProgress = false;
  bool supplierSaleAccepted = false;
  NewSaleListener? onNewSale;

  bool get motoboyHeartbeatInProgress => _motoboyHeartbeatInProgress;
  bool get fornecedorHeartbeatInProgress => _fornecedorHeartbeatInProgress;
  bool get deliveryActionInProgress => _deliveryActionInProgress;
  bool get supplierSaleActionInProgress => _supplierSaleActionInProgress;

  bool get fornecedorHeartbeatEnabled {
    if (_sessionDisposed || !fornecedorProfileActive || !_appForeground) {
      return false;
    }
    if (tipoFornecedor == TipoFornecedor.horario) {
      return fornecedorDisponivelComercialmente == true;
    }
    return fornecedorOnline;
  }

  Future<void> loadFornecedorDisponibilidade({bool forceRefresh = false}) async {
    if (_sessionDisposed ||
        (!forceRefresh && _fornecedorDisponibilidadeLoaded) ||
        _fornecedorDisponibilidadeRequestInProgress) {
      return;
    }
    _fornecedorDisponibilidadeRequestInProgress = true;
    fornecedorDisponibilidadeLoading = true;
    fornecedorDisponibilidadeError = null;
    notifyListeners();
    try {
      final disponibilidade = await _loadFornecedorDisponibilidade();
      if (_sessionDisposed) return;
      tipoFornecedor = disponibilidade.tipo;
      fornecedorDisponivelComercialmente = disponibilidade.disponivel;
      if (tipoFornecedor == TipoFornecedor.horario && _appForeground) {
        _scheduleFornecedorDisponibilidadeRefresh();
      } else {
        _cancelFornecedorDisponibilidadeRefresh();
      }
    } catch (_) {
      if (_sessionDisposed) return;
      fornecedorDisponibilidadeError =
          'Nao foi possivel consultar a disponibilidade comercial.';
    } finally {
      _fornecedorDisponibilidadeLoaded = true;
      _fornecedorDisponibilidadeRequestInProgress = false;
      fornecedorDisponibilidadeLoading = false;
      if (!_sessionDisposed) notifyListeners();
    }
  }

  void _scheduleFornecedorDisponibilidadeRefresh() {
    _cancelFornecedorDisponibilidadeRefresh();
    if (_sessionDisposed ||
        !_appForeground ||
        tipoFornecedor != TipoFornecedor.horario) {
      return;
    }
    _fornecedorDisponibilidadeTimer = Timer.periodic(
      _fornecedorDisponibilidadeInterval,
      (_) => unawaited(
        loadFornecedorDisponibilidade(forceRefresh: true),
      ),
    );
  }

  void _cancelFornecedorDisponibilidadeRefresh() {
    _fornecedorDisponibilidadeTimer?.cancel();
    _fornecedorDisponibilidadeTimer = null;
  }

  bool get fornecedorDisponibilidadeRefreshActive =>
      _fornecedorDisponibilidadeTimer?.isActive == true;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasForeground = _appForeground;
    _appForeground = state == AppLifecycleState.resumed;
    if (!_appForeground) {
      _cancelFornecedorDisponibilidadeRefresh();
    } else if (!wasForeground && fornecedorProfileActive) {
      unawaited(loadFornecedorDisponibilidade(forceRefresh: true));
    } else if (tipoFornecedor == TipoFornecedor.horario) {
      _scheduleFornecedorDisponibilidadeRefresh();
    }
    notifyListeners();
  }

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

  Future<DeliveryActionResult> respondToCurrentSupplierSale(bool accept) async {
    if (_sessionDisposed || _supplierSaleActionInProgress) {
      return const DeliveryActionResult(
          success: false, message: 'Ação já está sendo processada.');
    }
    final sale = novaVenda;
    if (sale == null) {
      return const DeliveryActionResult(
          success: false, message: 'Nenhuma venda disponível.');
    }
    _supplierSaleActionInProgress = true;
    notifyListeners();
    try {
      if (!accept) {
        supplierSaleAccepted = false;
        heartbeatPausedBySale = false;
        notifyListeners();
        return const DeliveryActionResult(
            success: true, message: 'Venda recusada.');
      }
      final success = await _confirmSupplierSale(sale.idAviso, sale.idPed);
      if (!success || _sessionDisposed) {
        return const DeliveryActionResult(
            success: false, message: 'Não foi possível confirmar a venda.');
      }
      supplierSaleAccepted = true;
      heartbeatPausedBySale = true;
      notifyListeners();
      return const DeliveryActionResult(
          success: true, message: 'Venda confirmada.');
    } finally {
      _supplierSaleActionInProgress = false;
      notifyListeners();
    }
  }

  Future<void> setFornecedorAvailability(
      {required bool online, int? idLoja}) async {
    if (_sessionDisposed || !fornecedorProfileActive) return;
    if (online) {
      await OnlineStatusService.setFornecedorStatus(true);
      setFornecedorOnline(true);
      return;
    }
    await OnlineStatusService.setFornecedorStatus(false);
    final prefs = await _preferencesProvider();
    final effectiveStoreId = idLoja ?? prefs.getInt('idLoja');
    await fornecedorOff(idLoja: effectiveStoreId);
    setFornecedorOnline(false);
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
    if (_sessionDisposed || _heartbeatCycleInProgress || !_appForeground) return;

    _heartbeatCycleInProgress = true;
    try {
      if (!motoboyOnline && !fornecedorHeartbeatEnabled) return;
      if (heartbeatPausedByDelivery && heartbeatPausedBySale) return;

      if (motoboyProfileActive && !fornecedorProfileActive) {
        if (motoboyOnline && !heartbeatPausedBySale && !motoboyTrackingActive) {
          await sendMotoboyHeartbeatFromCurrentPosition();
        }
        return;
      }

      if (!motoboyProfileActive && fornecedorProfileActive) {
        if (fornecedorHeartbeatEnabled && !heartbeatPausedByDelivery) {
          await sendFornecedorHeartbeatFromCurrentPosition();
        }
        return;
      }

      if (motoboyProfileActive && fornecedorProfileActive) {
        if (heartbeatPausedByDelivery) {
          if (!motoboyTrackingActive && motoboyOnline) {
            await sendMotoboyHeartbeatFromCurrentPosition();
          }
          return;
        }

        if (heartbeatPausedBySale) {
          if (fornecedorHeartbeatEnabled) {
            await sendFornecedorHeartbeatFromCurrentPosition();
          }
          return;
        }

        if (nextHeartbeatIsFornecedor && fornecedorHeartbeatEnabled) {
          await sendFornecedorHeartbeatFromCurrentPosition();
          nextHeartbeatIsFornecedor = false;
        } else if (motoboyOnline && !motoboyTrackingActive) {
          await sendMotoboyHeartbeatFromCurrentPosition();
          nextHeartbeatIsFornecedor = true;
        } else if (fornecedorHeartbeatEnabled) {
          await sendFornecedorHeartbeatFromCurrentPosition();
          nextHeartbeatIsFornecedor = false;
        }
      }
    } finally {
      _heartbeatCycleInProgress = false;
      if (!_sessionDisposed && _appForeground) scheduleHeartbeatCycle(interval);
    }
  }

  void disposeSession() {
    if (_sessionDisposed) return;
    _sessionDisposed = true;
    cancelHeartbeatTimer();
    _cancelFornecedorDisponibilidadeRefresh();
    WidgetsBinding.instance.removeObserver(this);
    motoboyTrackingActive = false;
    locationService.stopTracking();
    dispose();
  }
}
