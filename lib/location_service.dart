import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton service that detects the user's city and caches it.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  static const String _prefKey = 'userCity';

  // The 6 supported cities — used for fuzzy matching
  static const List<String> supportedCities = [
    'Buea',
    'Douala',
    'Yaoundé',
    'Bamenda',
    'Bafoussam',
    'Limbe',
  ];

  String? _userCity;
  String? get userCity => _userCity;

  /// Load city from SharedPreferences (cached).
  Future<String?> loadCachedCity() async {
    final prefs = await SharedPreferences.getInstance();
    _userCity = prefs.getString(_prefKey);
    return _userCity;
  }

  /// Persist a city choice to SharedPreferences.
  Future<void> saveCity(String city) async {
    _userCity = city;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, city);
  }

  /// Request permissions and detect city via GPS + reverse geocoding.
  /// Returns the matched supported city name, or null on failure/denial.
  Future<String?> detectCity() async {
    try {
      // Check & request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      // Get position
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 10),
      );

      // Reverse geocode
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isEmpty) return null;

      final placemark = placemarks.first;
      final rawCity = placemark.locality ??
          placemark.subAdministrativeArea ??
          placemark.administrativeArea ??
          '';

      return _matchCity(rawCity);
    } catch (_) {
      return null;
    }
  }

  /// Fuzzy-match a raw city string to one of the supported cities.
  String? _matchCity(String raw) {
    if (raw.isEmpty) return null;
    
    // Normalize string by stripping accents (e.g. Yaoundé -> Yaounde)
    String _stripAccents(String input) {
      final Map<String, String> replacements = {
        'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
        'à': 'a', 'â': 'a', 'ä': 'a',
        'î': 'i', 'ï': 'i',
        'ô': 'o', 'ö': 'o',
        'û': 'u', 'ü': 'u',
        'ç': 'c',
      };
      String result = input.toLowerCase();
      replacements.forEach((key, value) {
        result = result.replaceAll(key, value);
      });
      return result;
    }

    final lowerRaw = _stripAccents(raw);
    
    for (final city in supportedCities) {
      final cityLower = _stripAccents(city);
      if (lowerRaw.contains(cityLower) || cityLower.contains(lowerRaw)) {
        return city;
      }
    }
    return null; // no match
  }
}
