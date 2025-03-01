import 'package:permission_handler/permission_handler.dart';

class LocationService {
  Future<void> requestPermissions() async {
    var status = await Permission.locationWhenInUse.status;
    if (!status.isGranted) {
      await Permission.locationWhenInUse.request();
    }
  }
}
