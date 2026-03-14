import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Location service for prayer alarm — GPS + city search.
/// Uses Geolocator for GPS and Nominatim (free) for city search/reverse geocoding.
class LocationService {
  static const Duration _timeout = Duration(seconds: 10);

  // ── GPS Location ───────────────────────────────────

  /// Get current device GPS coordinates.
  /// Returns { 'lat': double, 'lng': double } or throws.
  static Future<Map<String, double>> getCurrentLocation() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationException('Location services are disabled. Please enable GPS.');
    }

    // Check permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationException('Location permission denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationException(
        'Location permission permanently denied. Please enable in Settings.',
      );
    }

    // Get position
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 15),
      ),
    );

    return {
      'lat': position.latitude,
      'lng': position.longitude,
    };
  }

  // ── Reverse Geocoding (coordinates → city name) ────

  /// Get city/area name from coordinates using Nominatim.
  static Future<String> getCityName(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json&lat=$lat&lon=$lng&zoom=10&addressdetails=1',
      );

      final response = await http.get(uri, headers: {
        'User-Agent': 'SukoonLauncher/1.0',
        'Accept-Language': 'en',
      }).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'] as Map<String, dynamic>?;

        if (address != null) {
          // Try city → town → village → county
          final city = address['city'] ??
              address['town'] ??
              address['village'] ??
              address['county'] ??
              address['state'] ??
              '';
          final country = address['country'] ?? '';

          if (city.toString().isNotEmpty) {
            return country.toString().isNotEmpty
                ? '$city, $country'
                : city.toString();
          }
        }

        // Fallback to display_name
        final displayName = data['display_name'] as String?;
        if (displayName != null && displayName.isNotEmpty) {
          // Take first 2 parts of the comma-separated display name
          final parts = displayName.split(',').map((s) => s.trim()).toList();
          if (parts.length >= 2) return '${parts[0]}, ${parts[1]}';
          return parts.first;
        }
      }
    } catch (_) {}

    return 'Lat: ${lat.toStringAsFixed(2)}, Lng: ${lng.toStringAsFixed(2)}';
  }

  // ── City Search (name → coordinates) ───────────────

  /// Search for cities by name using Nominatim.
  /// Returns list of { 'name': String, 'lat': double, 'lng': double }
  static Future<List<Map<String, dynamic>>> searchCity(String query) async {
    if (query.trim().length < 2) return [];

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?format=json&q=${Uri.encodeComponent(query)}&limit=5&addressdetails=1',
      );

      final response = await http.get(uri, headers: {
        'User-Agent': 'SukoonLauncher/1.0',
        'Accept-Language': 'en',
      }).timeout(_timeout);

      if (response.statusCode == 200) {
        final List results = json.decode(response.body);
        return results.map((item) {
          final address = item['address'] as Map<String, dynamic>?;
          final city = address?['city'] ??
              address?['town'] ??
              address?['village'] ??
              item['display_name'] ??
              '';
          final country = address?['country'] ?? '';
          final displayName = country.toString().isNotEmpty
              ? '$city, $country'
              : city.toString();

          return {
            'name': displayName,
            'lat': double.tryParse(item['lat']?.toString() ?? '0') ?? 0.0,
            'lng': double.tryParse(item['lon']?.toString() ?? '0') ?? 0.0,
          };
        }).toList();
      }
    } catch (_) {}

    return [];
  }
}

/// Custom exception for location errors.
class LocationException implements Exception {
  final String message;
  LocationException(this.message);

  @override
  String toString() => message;
}
