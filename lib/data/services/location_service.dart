import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  static StreamSubscription<Position>? _positionStream;

  static DateTime? _lastUpdateTime;

  /// Starts tracking location with production-level optimizations (5-10s interval, 10m filter)
  static void startTracking({
    required Function(Position) onLocationChanged,
    LocationAccuracy accuracy = LocationAccuracy.balanced,
    int distanceFilter = 10,
    int timeInterval = 5, // Seconds
  }) {
    // Stop any existing stream
    stopTracking();

    final locationSettings = AndroidSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
      intervalDuration: Duration(seconds: timeInterval),
      forceLocationManager: true, // More reliable in background
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      // 🔥 PRO SCALABILITY: Throttle DB writes to once every 5 seconds
      final now = DateTime.now();
      if (_lastUpdateTime == null || now.difference(_lastUpdateTime!).inSeconds >= 5) {
        _lastUpdateTime = now;
        onLocationChanged(position);
      }
    });
  }


  static void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
  }

  /// Calculates straight-line distance (for simple checks)
  static double getDistance(LatLng start, LatLng end) {
    return Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
  }
}
