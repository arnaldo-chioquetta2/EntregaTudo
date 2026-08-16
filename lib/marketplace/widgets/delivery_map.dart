import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/delivery_tracking_models.dart';

class DeliveryMap extends StatefulWidget {
  final DeliveryLocation location;
  const DeliveryMap({super.key, required this.location});

  @override
  State<DeliveryMap> createState() => _DeliveryMapState();
}

class _DeliveryMapState extends State<DeliveryMap> {
  final MapController _controller = MapController();
  bool _hasCentered = false;

  LatLng get _point =>
      LatLng(widget.location.latitude!, widget.location.longitude!);

  @override
  void didUpdateWidget(covariant DeliveryMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location.latitude != widget.location.latitude ||
        oldWidget.location.longitude != widget.location.longitude) {
      debugPrint(
          '[DeliveryMap.Location] available=true updatedAt=${widget.location.updatedAt ?? 'null'}');
      _controller.move(_point, 15);
    }
  }

  void _center() {
    _controller.move(_point, 15);
    debugPrint('[DeliveryMap.Render] action=center');
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[DeliveryMap.Render] available=true');
    return SizedBox(
      height: 280,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _controller,
              options: MapOptions(initialCenter: _point, initialZoom: 15),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.teletudo.entregatudo',
                  errorTileCallback: (_, __, ___) =>
                      debugPrint('[DeliveryMap.Error] tile_load_failed'),
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _point,
                      width: 52,
                      height: 52,
                      child: const Icon(Icons.delivery_dining,
                          size: 42, color: Colors.red),
                    ),
                  ],
                ),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
            Positioned(
              right: 12,
              top: 12,
              child: FloatingActionButton.small(
                heroTag: 'delivery-map-center',
                onPressed: _center,
                tooltip: 'Centralizar',
                child: const Icon(Icons.my_location),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
