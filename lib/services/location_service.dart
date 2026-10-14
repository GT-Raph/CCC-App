import 'package:geolocator/geolocator.dart';

import 'places_service.dart';

enum LocationAccess { granted, denied, deniedForever, serviceOff, unavailable }

class LocationFix {
  const LocationFix(this.access, [this.position]);

  final LocationAccess access;
  final LatLng? position;
}

/// The member's current position, asking for permission when needed.
class LocationService {
  const LocationService();

  Future<LocationFix> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationFix(LocationAccess.serviceOff);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      switch (permission) {
        case LocationPermission.deniedForever:
          return const LocationFix(LocationAccess.deniedForever);
        case LocationPermission.denied:
        case LocationPermission.unableToDetermine:
          return const LocationFix(LocationAccess.denied);
        case LocationPermission.whileInUse:
        case LocationPermission.always:
          break;
      }
      final position = await _position();
      return position == null
          ? const LocationFix(LocationAccess.unavailable)
          : LocationFix(
              LocationAccess.granted,
              LatLng(position.latitude, position.longitude),
            );
    } catch (_) {
      return const LocationFix(LocationAccess.unavailable);
    }
  }

  Future<Position?> _position() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
    } catch (_) {
      return Geolocator.getLastKnownPosition();
    }
  }

  /// Opens the system screen that can fix [access].
  Future<void> openSettings(LocationAccess access) async {
    access == LocationAccess.serviceOff
        ? await Geolocator.openLocationSettings()
        : await Geolocator.openAppSettings();
  }

  double distanceMeters(LatLng from, double toLatitude, double toLongitude) =>
      Geolocator.distanceBetween(
        from.latitude,
        from.longitude,
        toLatitude,
        toLongitude,
      );
}
