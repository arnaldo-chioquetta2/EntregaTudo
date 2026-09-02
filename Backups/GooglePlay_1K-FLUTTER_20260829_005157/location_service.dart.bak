import 'dart:async';
import 'dart:io' show Platform;
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  StreamSubscription<Position>? _positionStream;
  Position? ultimaPosicao;

  Future<void> requestPermissions() async {
    if (kIsWeb) {
      // Web não precisa de permission_handler, só verifica se GPS está ativo
      bool ativo = await Geolocator.isLocationServiceEnabled();
      if (!ativo) throw Exception('Serviço de localização está desativado.');
      return;
    }

    // Android/iOS
    var status = await Permission.locationWhenInUse.status;
    if (!status.isGranted) {
      await Permission.locationWhenInUse.request();
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Serviço de localização desativado.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Permissão de localização negada permanentemente.');
    }
  }

  /// Obtém a localização atual
  Future<Position> getCurrentLocation() async {
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  void startTracking(Function(Position) onPosition) {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((position) {
      ultimaPosicao = position;
      onPosition(position);
    });
  }

  /// Para o rastreamento
  void stopTracking() {
    _positionStream?.cancel();
  }
}
