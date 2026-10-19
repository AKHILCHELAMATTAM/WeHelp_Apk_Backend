import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../api/api_client.dart';
import '../api/api_constants.dart';

class LocationResult {
  final double latitude;
  final double longitude;
  final double accuracy;
  final String address;
  final DateTime timestamp;

  LocationResult({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.address,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  String get googleMapsUrl => 'https://www.google.com/maps?q=$latitude,$longitude';
}

class LocationService {
  static LocationResult? lastLocation;
  static final ValueNotifier<LocationResult?> currentLocationNotifier = ValueNotifier<LocationResult?>(null);

  /// Request GPS permission and return current exact location with real street address
  static Future<LocationResult?> getCurrentLocation({bool forceRefresh = false}) async {
    try {
      // 1. Verify if location services (GPS hardware) are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location toggle is turned off on device
        return null;
      }

      // 2. Check and request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      Position? position;

      // 3. Tiered Position Acquisition
      // Step A: Attempt high-accuracy GPS fix (12 second limit)
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 12),
          ),
        );
      } catch (_) {
        // Step B: Fallback to medium/balanced accuracy (network/WiFi triangulation)
        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 8),
            ),
          );
        } catch (_) {
          // Step C: Fallback to last known position from OS cache
          position = await Geolocator.getLastKnownPosition();
        }
      }

      if (position == null) {
        return null;
      }

      // 4. Reverse Geocode Coordinates to Exact Physical Address
      final address = await reverseGeocode(position.latitude, position.longitude);

      final result = LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        address: address,
      );

      lastLocation = result;
      currentLocationNotifier.value = result;
      return result;
    } catch (_) {
      return null;
    }
  }

  /// Dual-stage reverse geocoding:
  /// Stage 1: Native Android Geocoder
  /// Stage 2: OpenStreetMap Nominatim HTTP API (guaranteed street address lookup)
  static Future<String> reverseGeocode(double latitude, double longitude) async {
    // Stage 1: Try native Android geocoder
    try {
      final geocoding = Geocoding();
      final placemarks = await geocoding.placemarkFromCoordinates(
        latitude,
        longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = [
          p.street,
          p.subLocality,
          p.locality,
          p.subAdministrativeArea,
          p.administrativeArea,
          p.postalCode,
        ]
            .whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty && s.toLowerCase() != 'unnamed road')
            .toSet()
            .toList();

        if (parts.isNotEmpty) {
          return parts.join(', ');
        }
      }
    } catch (_) {
      // Native geocoder failed (common without Google Play Services or network delay)
    }

    // Stage 2: Nominatim OpenStreetMap HTTP API fallback
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$latitude&lon=$longitude&zoom=18&addressdetails=1',
      );
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(url);
      request.headers.set('User-Agent', 'WeHelpAgentApp/1.0 (contact@wehelp.org)');
      final response = await request.close().timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final respBody = await response.transform(utf8.decoder).join();
        final data = jsonDecode(respBody);
        if (data is Map<String, dynamic>) {
          final addr = data['address'] as Map<String, dynamic>?;
          if (addr != null) {
            final road = addr['road'] ?? addr['suburb'] ?? addr['neighbourhood'];
            final city = addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['county'];
            final state = addr['state'];
            final postcode = addr['postcode'];
            final segments = [road, city, state, postcode]
                .whereType<String>()
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
            if (segments.isNotEmpty) {
              return segments.join(', ');
            }
          }
          if (data['display_name'] != null) {
            return data['display_name'].toString().split(',').take(4).join(',').trim();
          }
        }
      }
    } catch (_) {
      // HTTP reverse geocode failed or offline
    }

    // Stage 3: Fallback formatted coordinates
    return 'Location (${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)})';
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
