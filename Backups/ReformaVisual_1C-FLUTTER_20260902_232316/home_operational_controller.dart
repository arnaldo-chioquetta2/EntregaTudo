import 'dart:async';

import 'package:flutter/foundation.dart';

import 'location_service.dart';

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

  void setHeartbeatTimer(Timer? timer) {
    heartbeatTimer?.cancel();
    heartbeatTimer = timer;
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
    cancelHeartbeatTimer();
    motoboyTrackingActive = false;
    locationService.stopTracking();
    dispose();
  }
}