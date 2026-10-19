import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../api/api_client.dart';
import '../api/api_constants.dart';

class LocationResult {
  final double latitude;
  final double longitude;
  final double accuracy;
  final String address;

  LocationResult({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.address,
  });
}

class LocationService {
  /// Request GPS permission and return current exact location with address
  static Future<LocationResult?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      String address = "Coordinates (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})";

      try {
        final geocoding = Geocoding();
        final placemarks = await geocoding.placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final parts = [
            p.name,
            p.subLocality,
            p.locality,
            p.administrativeArea,
          ].whereType<String>().where((s) => s.trim().isNotEmpty).toList();

          if (parts.isNotEmpty) {
            address = parts.join(", ");
          }
        }
      } catch (_) {
        // Fallback to coordinates string if reverse geocoding offline
      }

      return LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        address: address,
      );
    } catch (_) {
      return null;
    }
  }

  /// Sends agent's current live location ping to backend
  /// Workflow: Admin Application -> tracks agent's live location when app is opened
  static Future<bool> sendLiveLocationPing() async {
    final loc = await getCurrentLocation();
    if (loc == null) return false;

    final response = await ApiClient.post(
      ApiConstants.sendLocation,
      body: {
        'latitude': loc.latitude,
        'longitude': loc.longitude,
        'accuracy': loc.accuracy,
        'address': loc.address,
        'recorded_at': DateTime.now().toUtc().toIso8601String(),
      },
    );

    return response.isSuccess;
  }
}
