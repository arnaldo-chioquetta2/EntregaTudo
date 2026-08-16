import 'package:geolocator/geolocator.dart';

const double checkoutAddressDistanceLimitMeters = 200;

double distanceInMeters({
  required double fromLatitude,
  required double fromLongitude,
  required double toLatitude,
  required double toLongitude,
}) {
  return Geolocator.distanceBetween(
    fromLatitude,
    fromLongitude,
    toLatitude,
    toLongitude,
  );
}

bool isWithinCheckoutAddressRange({
  required double fromLatitude,
  required double fromLongitude,
  required double toLatitude,
  required double toLongitude,
}) {
  return distanceInMeters(
        fromLatitude: fromLatitude,
        fromLongitude: fromLongitude,
        toLatitude: toLatitude,
        toLongitude: toLongitude,
      ) <=
      checkoutAddressDistanceLimitMeters;
}
