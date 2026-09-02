import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService with WidgetsBindingObserver {
  LocationService._() {
    WidgetsBinding.instance.addObserver(this);
  }

  static final LocationService _instance = LocationService._();

  factory LocationService() => _instance;

  StreamSubscription<Position>? _positionStream;
  Position? ultimaPosicao;
  Future<void> Function(Position position)? _onPosition;
  Position? _pendingPosition;
  bool _sendingPosition = false;
  bool _trackingRequested = false;

  Future<void> requestPermissions() async {
    if (kIsWeb) {
      final ativo = await Geolocator.isLocationServiceEnabled();
      if (!ativo) throw Exception('Servico de localizacao esta desativado.');
      return;
    }

    var status = await Permission.locationWhenInUse.status;
    if (!status.isGranted) {
      await Permission.locationWhenInUse.request();
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Servico de localizacao desativado.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Permissao de localizacao negada permanentemente.');
    }
  }

  Future<Position> getCurrentLocation() async {
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  void startTracking(Future<void> Function(Position) onPosition) {
    _trackingRequested = true;
    _onPosition = onPosition;
    _startPositionStreamIfForeground();
  }

  void _startPositionStreamIfForeground() {
    if (!_trackingRequested || _positionStream != null) return;
    if (!kIsWeb &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: _locationSettings(),
    ).listen((position) {
      ultimaPosicao = position;
      _pendingPosition = position;
      _drainPositionQueue();
    });
  }

  LocationSettings _locationSettings() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 30,
        intervalDuration: const Duration(seconds: 30),
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 30,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _stopPositionStreamOnly();
    } else if (state == AppLifecycleState.resumed) {
      _startPositionStreamIfForeground();
    }
  }

  Future<void> _drainPositionQueue() async {
    if (_sendingPosition) return;
    _sendingPosition = true;

    try {
      while (_pendingPosition != null && _onPosition != null) {
        final position = _pendingPosition!;
        _pendingPosition = null;
        await _onPosition!(position);
      }
    } finally {
      _sendingPosition = false;
      if (_pendingPosition != null && _onPosition != null) {
        _drainPositionQueue();
      }
    }
  }

  void _stopPositionStreamOnly() {
    _positionStream?.cancel();
    _positionStream = null;
    _pendingPosition = null;
  }

  void stopTracking() {
    _trackingRequested = false;
    _stopPositionStreamOnly();
    _onPosition = null;
  }
}
