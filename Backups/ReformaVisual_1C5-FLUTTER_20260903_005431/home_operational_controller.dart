import 'dart:async';

import 'package:flutter/foundation.dart';

import 'location_service.dart';
import '../models/entrega_ativa.dart';

class HomeOperationalController extends ChangeNotifier {
  HomeOperationalController({LocationService? locationService})
      : locationService = locationService ?? LocationService();

  final LocationService locationService;

  Timer? heartbeatTimer;
  bool motoboyTrackingActive = false;
  bool motoboyOnline = false;
  bool fornecedorOnline = false;
  bool heartbeatPausedByDelivery = false;
  bool heartbeatPausedBySale = false;
  bool nextHeartbeatIsFornecedor = true;
  bool _sessionDisposed = false;
  EntregaAtiva? entregaAtiva;
  Map<String, dynamic>? deliveryDataMotoboy;
  Map<String, dynamic>? deliveryDataFornecedor;

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

  void disposeSession() {
    if (_sessionDisposed) return;
    _sessionDisposed = true;
    cancelHeartbeatTimer();
    motoboyTrackingActive = false;
    locationService.stopTracking();
    dispose();
  }
}
