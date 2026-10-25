import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;

import 'package:geocoding/geocoding.dart' as geo;
import 'package:http/http.dart' as http;

import 'config.dart';

class _ReverseHit {
  const _ReverseHit({
    required this.address,
    required this.meters,
    required this.score,
  });

  final String address;
  final double meters;
  final double score;
}

class PlaceSuggestion {
  const PlaceSuggestion({
    required this.placeId,
    required this.title,
    this.subtitle = '',
    this.latitude,
    this.longitude,
    this.isRestaurant = false,
  });

  final String placeId;
  final String title;
  final String subtitle;
  final double? latitude;
  final double? longitude;
  final bool isRestaurant;

  String get label {
    final name = title.trim();
    final address = subtitle.trim();
    if (name.isEmpty) {
      return address;
    }
    if (address.isEmpty) {
      return name;
    }
    if (address.toLowerCase().contains(name.toLowerCase())) {
      return address;
    }
    return '$name, $address';
  }
}

class PlaceLocation {
  const PlaceLocation({
    required this.latitude,
    required this.longitude,
    this.name = '',
    this.address = '',
  });

  final double latitude;
  final double longitude;
  final String name;
  final String address;

  String get label {
    if (address.trim().isNotEmpty) {
      return address.trim();
    }
    if (name.trim().isNotEmpty) {
      return name.trim();
    }
    return '';
  }
}

class GooglePlacesService {
  GooglePlacesService._();

  static const _timeout = Duration(seconds: 8);
  static const _englishLocale = 'en_US';
  static const _osmEnglishHeaders = {
    'User-Agent': 'StyleBite/1.0 (location-field)',
    'Accept': 'application/json',
    'Accept-Language': 'en',
  };
  static bool _googleRestDenied = false;
  static bool _englishLocaleReady = false;

  /// Device placemarks follow the phone language (e.g. Urdu). Force English
  /// so locations always show as English in the app.
  static Future<void> _ensureEnglishGeocodingLocale() async {
    if (_englishLocaleReady) {
      return;
    }
    try {
      await geo.setLocaleIdentifier(_englishLocale);
      _englishLocaleReady = true;
    } catch (error) {
      log('setLocaleIdentifier failed: $error', name: 'Places');
    }
  }

  /// Nearby places when [query] is empty, otherwise every related match.
  /// A search like "kfc multan" keeps the Multan branches first, then the
  /// other branches of that name.
  static Future<List<PlaceSuggestion>> suggest(
    String query, {
    double? latitude,
    double? longitude,
  }) async {
    final trimmed = query.trim();
    final hasOrigin = latitude != null &&
        longitude != null &&
        _isValidCoord(latitude, longitude);

    if (trimmed.isEmpty) {
      if (!hasOrigin) {
        return const [];
      }
      return _nominatimSuggestions(
        'restaurant',
        latitude,
        longitude,
        limit: 15,
        bounded: true,
        span: 0.06,
      );
    }
    if (trimmed.length < 2) {
      return const [];
    }

    final brand = _brandToken(trimmed);
    final tail = _placeTail(trimmed);
    final batches = await Future.wait<List<PlaceSuggestion>>([
      _photonSuggestions(
        trimmed,
        hasOrigin ? latitude : null,
        hasOrigin ? longitude : null,
      ),
      _nominatimSuggestions(
        trimmed,
        hasOrigin ? latitude : null,
        hasOrigin ? longitude : null,
        limit: tail.isEmpty ? 20 : 8,
        countryCodes: tail.isEmpty ? 'pk' : null,
      ),
      if (!_googleRestDenied)
        _textSearch(
          trimmed,
          hasOrigin ? latitude : null,
          hasOrigin ? longitude : null,
        ),
    ]);
    var merged = _mergeSuggestions(batches);
    if (tail.isNotEmpty && brand.length >= 2) {
      final related = await _nominatimSuggestions(
        brand,
        null,
        null,
        limit: 20,
        countryCodes: 'pk',
      );
      merged = _mergeSuggestions([merged, related]);
    }

    final originLat = hasOrigin ? latitude : null;
    final originLng = hasOrigin ? longitude : null;
    merged.sort((a, b) {
      final rank = _suggestionRank(a, brand, tail).compareTo(
        _suggestionRank(b, brand, tail),
      );
      if (rank != 0 || originLat == null || originLng == null) {
        return rank;
      }
      final aDistance = _metersBetween(
        originLat,
        originLng,
        a.latitude ?? originLat,
        a.longitude ?? originLng,
      );
      final bDistance = _metersBetween(
        originLat,
        originLng,
        b.latitude ?? originLat,
        b.longitude ?? originLng,
      );
      return aDistance.compareTo(bDistance);
    });
    if (merged.length <= 25) {
      return merged;
    }
    return merged.sublist(0, 25);
  }

  static String _brandToken(String query) {
    final parts = query
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().length >= 2)
        .toList(growable: false);
    if (parts.isEmpty) {
      return '';
    }
    return parts.first.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
  }

  static String _placeTail(String query) {
    final parts = query
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.length < 2) {
      return '';
    }
    return parts.skip(1).join(' ');
  }

  static List<PlaceSuggestion> _mergeSuggestions(
    Iterable<List<PlaceSuggestion>> batches,
  ) {
    final merged = <PlaceSuggestion>[];
    final seen = <String>{};
    for (final batch in batches) {
      for (final item in batch) {
        if (item.label.trim().isEmpty) {
          continue;
        }
        final title = item.title.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
        final lat = item.latitude;
        final lng = item.longitude;
        final key = lat != null && lng != null
            ? '$title@${lat.toStringAsFixed(3)},${lng.toStringAsFixed(3)}'
            : '$title|${item.subtitle.toLowerCase()}';
        if (seen.add(key)) {
          merged.add(item);
        }
      }
    }
    return merged;
  }

  static int _suggestionRank(PlaceSuggestion item, String brand, String tail) {
    final title = item.title.toLowerCase();
    final blob = '${item.title} ${item.subtitle}'.toLowerCase();
    final brandHit = brand.isNotEmpty && title.contains(brand.toLowerCase());
    final tailHit = tail.isNotEmpty && blob.contains(tail.toLowerCase());
    if (brandHit && tailHit) {
      return 0;
    }
    if (brandHit) {
      return 1;
    }
    if (tailHit) {
      return 2;
    }
    return 3;
  }

  static Future<List<PlaceSuggestion>> _nominatimSuggestions(
    String query,
    double? latitude,
    double? longitude, {
    int limit = 15,
    bool bounded = false,
    String? countryCodes,
    double span = 0.12,
  }) async {
    try {
      final params = <String, String>{
        'q': query,
        'format': 'json',
        'limit': '$limit',
        'addressdetails': '1',
        'accept-language': 'en',
      };
      if (countryCodes != null && countryCodes.trim().isNotEmpty) {
        params['countrycodes'] = countryCodes.trim();
      }
      if (latitude != null && longitude != null) {
        params['viewbox'] =
            '${longitude - span},${latitude + span},${longitude + span},${latitude - span}';
        params['bounded'] = bounded ? '1' : '0';
      }
      final response = await http
          .get(
            Uri.https('nominatim.openstreetmap.org', '/search', params),
            headers: _osmEnglishHeaders,
          )
          .timeout(_timeout);
      if (response.statusCode != 200) {
        return const [];
      }
      final payload = jsonDecode(response.body);
      if (payload is! List) {
        return const [];
      }
      final items = <PlaceSuggestion>[];
      for (final item in payload) {
        if (item is! Map) {
          continue;
        }
        final lat = _toDouble(item['lat']);
        final lng = _toDouble(item['lon']);
        if (lat == null || lng == null) {
          continue;
        }
        final name = (item['name'] ?? '').toString().trim();
        final display = (item['display_name'] ?? '').toString().trim();
        final kind = (item['type'] ?? item['class'] ?? '').toString();
        items.add(
          PlaceSuggestion(
            placeId: 'nominatim:${item['place_id'] ?? display}',
            title: name.isNotEmpty ? name : display,
            subtitle: name.isNotEmpty ? display : '',
            latitude: lat,
            longitude: lng,
            isRestaurant: kind == 'restaurant' ||
                kind == 'cafe' ||
                kind == 'fast_food',
          ),
        );
      }
      return items;
    } catch (error) {
      log('nominatim suggest failed: $error', name: 'Places');
      return const [];
    }
  }

  static Future<List<PlaceSuggestion>> _photonSuggestions(
    String query,
    double? latitude,
    double? longitude,
  ) async {
    try {
      final params = <String, String>{
        'q': query,
        'limit': '15',
        'lang': 'en',
      };
      if (latitude != null && longitude != null) {
        params['lat'] = '$latitude';
        params['lon'] = '$longitude';
      }
      final response = await http
          .get(
            Uri.https('photon.komoot.io', '/api/', params),
            headers: const {
              'User-Agent': 'StyleBite/1.0 (location-field)',
              'Accept': 'application/json',
            },
          )
          .timeout(_timeout);
      if (response.statusCode != 200) {
        return const [];
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map) {
        return const [];
      }
      final features = payload['features'];
      if (features is! List) {
        return const [];
      }
      final items = <PlaceSuggestion>[];
      for (final feature in features) {
        if (feature is! Map) {
          continue;
        }
        final properties = feature['properties'];
        final geometry = feature['geometry'];
        if (properties is! Map || geometry is! Map) {
          continue;
        }
        final coordinates = geometry['coordinates'];
        if (coordinates is! List || coordinates.length < 2) {
          continue;
        }
        final lng = _toDouble(coordinates[0]);
        final lat = _toDouble(coordinates[1]);
        final name = (properties['name'] ?? '').toString().trim();
        if (lat == null || lng == null || name.isEmpty) {
          continue;
        }
        final address = _joinAddressParts([
          (properties['street'] ?? '').toString(),
          (properties['district'] ?? '').toString(),
          (properties['city'] ?? '').toString(),
          (properties['state'] ?? '').toString(),
          (properties['country'] ?? '').toString(),
        ]);
        final kind = (properties['osm_value'] ?? '').toString();
        items.add(
          PlaceSuggestion(
            placeId: 'photon:${properties['osm_id'] ?? name}',
            title: name,
            subtitle: address,
            latitude: lat,
            longitude: lng,
            isRestaurant: kind == 'restaurant' ||
                kind == 'cafe' ||
                kind == 'fast_food' ||
                kind == 'food_court',
          ),
        );
      }
      return items;
    } catch (error) {
      log('photon suggest failed: $error', name: 'Places');
      return const [];
    }
  }

  static Future<List<PlaceSuggestion>> _textSearch(
    String query,
    double? latitude,
    double? longitude,
  ) async {
    try {
      final params = <String, String>{
        'query': query,
        'key': googleMapsApiKey,
        'language': 'en',
      };
      if (latitude != null && longitude != null) {
        params['location'] = '$latitude,$longitude';
        params['radius'] = '40000';
      }
      final response = await http
          .get(
            Uri.https(
              'maps.googleapis.com',
              '/maps/api/place/textsearch/json',
              params,
            ),
          )
          .timeout(_timeout);
      if (response.statusCode != 200) {
        return const [];
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map) {
        return const [];
      }
      final status = (payload['status'] ?? '').toString();
      if (status != 'OK') {
        _markDeniedIfNeeded(payload, 'textsearch-suggest');
        return const [];
      }
      final results = payload['results'];
      if (results is! List) {
        return const [];
      }
      final items = <PlaceSuggestion>[];
      for (final result in results.take(15)) {
        final place = _fromGoogleResult(result);
        if (place == null || result is! Map) {
          continue;
        }
        items.add(
          PlaceSuggestion(
            placeId: (result['place_id'] ?? '').toString(),
            title: place.name.isNotEmpty ? place.name : place.address,
            subtitle: place.address,
            latitude: place.latitude,
            longitude: place.longitude,
            isRestaurant: _looksLikeRestaurant(result['types']),
          ),
        );
      }
      return items;
    } catch (error) {
      log('text search suggest failed: $error', name: 'Places');
      return const [];
    }
  }

  static bool _looksLikeRestaurant(dynamic types) {
    if (types is! List) {
      return false;
    }
    const restaurantTypes = {
      'restaurant',
      'cafe',
      'food',
      'meal_takeaway',
      'meal_delivery',
      'bakery',
      'bar',
    };
    return types.any((type) => restaurantTypes.contains(type.toString()));
  }

  static Future<PlaceLocation?> fetchPlaceDetails(String placeId) async {
    if (placeId.trim().isEmpty) {
      return null;
    }
    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/details/json',
        {
          'place_id': placeId,
          'fields': 'geometry,name,formatted_address',
          'key': googleMapsApiKey,
          'language': 'en',
        },
      );
      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode != 200) {
        return null;
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map || (payload['status'] ?? '').toString() != 'OK') {
        _markDeniedIfNeeded(payload, 'place-details');
        return null;
      }
      return _fromGoogleResult(payload['result']);
    } catch (error, stack) {
      log('place-details failed: $error', name: 'Places', stackTrace: stack);
      return null;
    }
  }

  /// Turns a map pin into the address of that exact point.
  static Future<String> reverseLabel(double latitude, double longitude) async {
    if (!_isValidCoord(latitude, longitude)) {
      return '';
    }
    _ReverseHit? google;
    if (!_googleRestDenied) {
      google = await _reverseGoogle(latitude, longitude);
      if (google != null &&
          google.address.isNotEmpty &&
          google.meters <= 80) {
        return google.address;
      }
    }
    final osm = await _reverseNominatim(latitude, longitude);
    if (osm != null && osm.isNotEmpty) {
      return osm;
    }
    if (google != null && google.address.isNotEmpty) {
      return google.address;
    }
    return _reverseDevice(latitude, longitude);
  }

  static Future<_ReverseHit?> _reverseGoogle(
    double latitude,
    double longitude,
  ) async {
    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/geocode/json',
        {
          'latlng': '$latitude,$longitude',
          'key': googleMapsApiKey,
          'language': 'en',
        },
      );
      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode != 200) {
        return null;
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map) {
        return null;
      }
      final status = (payload['status'] ?? '').toString();
      if (status != 'OK') {
        _markDeniedIfNeeded(payload, 'reverse-geocode');
        return null;
      }
      final results = payload['results'];
      if (results is! List || results.isEmpty) {
        return null;
      }
      return _closestReverseHit(results, latitude, longitude);
    } catch (error) {
      log('reverse-geocode failed: $error', name: 'Places');
      return null;
    }
  }

  static _ReverseHit? _closestReverseHit(
    List<dynamic> results,
    double latitude,
    double longitude,
  ) {
    _ReverseHit? best;
    for (final item in results) {
      if (item is! Map) {
        continue;
      }
      final geometry = item['geometry'];
      if (geometry is! Map) {
        continue;
      }
      final location = geometry['location'];
      if (location is! Map) {
        continue;
      }
      final lat = _toDouble(location['lat']);
      final lng = _toDouble(location['lng']);
      final address = (item['formatted_address'] ?? '').toString().trim();
      if (lat == null || lng == null || address.isEmpty) {
        continue;
      }
      final types = item['types'];
      final typeNames = types is List
          ? types.map((type) => type.toString()).toSet()
          : <String>{};
      if (typeNames.contains('country') ||
          typeNames.contains('administrative_area_level_1')) {
        continue;
      }
      final meters = _metersBetween(latitude, longitude, lat, lng);
      final locationType = (geometry['location_type'] ?? '').toString();
      final penalty = switch (locationType) {
        'ROOFTOP' => 0.0,
        'RANGE_INTERPOLATED' => 25.0,
        'GEOMETRIC_CENTER' => 70.0,
        _ => 140.0,
      };
      final plusCode = RegExp(r'^[A-Z0-9]{4,}\+').hasMatch(address) ? 300.0 : 0.0;
      final score = meters + penalty + plusCode;
      if (best == null || score < best.score) {
        best = _ReverseHit(address: address, meters: meters, score: score);
      }
    }
    return best;
  }

  static Future<String> _reverseDevice(double latitude, double longitude) async {
    try {
      await _ensureEnglishGeocodingLocale();
      final placemarks = await geo.placemarkFromCoordinates(
        latitude,
        longitude,
      );
      if (placemarks.isEmpty) {
        return '';
      }
      final place = placemarks.first;
      final parts = <String>[
        place.street ?? '',
        place.thoroughfare ?? '',
        place.subLocality ?? '',
        place.locality ?? '',
        place.subAdministrativeArea ?? '',
        place.administrativeArea ?? '',
        place.country ?? '',
      ];
      return _joinAddressParts(parts);
    } catch (error) {
      log('device reverse failed: $error', name: 'Places');
      return '';
    }
  }

  static Future<String?> _reverseNominatim(
    double latitude,
    double longitude,
  ) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': '$latitude',
        'lon': '$longitude',
        'format': 'json',
        'zoom': '18',
        'addressdetails': '1',
        'accept-language': 'en',
      });
      final response = await http
          .get(uri, headers: _osmEnglishHeaders)
          .timeout(_timeout);
      if (response.statusCode != 200) {
        return null;
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map) {
        return null;
      }
      final details = payload['address'];
      if (details is Map) {
        final composed = _joinAddressParts([
          '${details['house_number'] ?? ''} ${details['road'] ?? details['pedestrian'] ?? ''}',
          (details['suburb'] ?? details['neighbourhood'] ?? details['quarter'] ?? '')
              .toString(),
          (details['city'] ?? details['town'] ?? details['village'] ?? '')
              .toString(),
          (details['state'] ?? '').toString(),
          (details['country'] ?? '').toString(),
        ]);
        if (composed.isNotEmpty) {
          return composed;
        }
      }
      final address = (payload['display_name'] ?? '').toString().trim();
      return address.isEmpty ? null : address;
    } catch (error) {
      log('nominatim reverse failed: $error', name: 'Places');
      return null;
    }
  }

  static String _joinAddressParts(List<String> parts) {
    final unique = <String>[];
    for (final part in parts) {
      final cleaned = part.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (cleaned.isEmpty || cleaned.contains('+')) {
        continue;
      }
      final exists = unique.any(
        (item) => item.toLowerCase() == cleaned.toLowerCase(),
      );
      if (!exists) {
        unique.add(cleaned);
      }
    }
    return unique.join(', ');
  }

  static double _metersBetween(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earth = 6371000.0;
    final dLat = _radians(lat2 - lat1);
    final dLng = _radians(lng2 - lng1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radians(lat1)) *
            math.cos(_radians(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earth * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _radians(double degrees) => degrees * math.pi / 180;

  static Future<PlaceLocation?> geocode(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || _googleRestDenied) {
      return null;
    }
    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/geocode/json',
        {
          'address': trimmed,
          'key': googleMapsApiKey,
          'region': 'pk',
          'language': 'en',
        },
      );
      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode != 200) {
        return null;
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map) {
        return null;
      }
      final status = (payload['status'] ?? '').toString();
      log('geocode status=$status query=$trimmed', name: 'Places');
      if (status != 'OK') {
        _markDeniedIfNeeded(payload, 'geocode');
        return null;
      }
      final results = payload['results'];
      if (results is! List || results.isEmpty) {
        return null;
      }
      return _fromGoogleResult(results.first);
    } catch (error) {
      log('geocode failed: $error', name: 'Places');
      return null;
    }
  }

  static Future<PlaceLocation?> searchPlace(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || _googleRestDenied) {
      return null;
    }
    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/textsearch/json',
        {
          'query': trimmed,
          'key': googleMapsApiKey,
          'region': 'pk',
          'language': 'en',
        },
      );
      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode != 200) {
        return null;
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map) {
        return null;
      }
      final status = (payload['status'] ?? '').toString();
      log('textsearch status=$status query=$trimmed', name: 'Places');
      if (status != 'OK' && status != 'ZERO_RESULTS') {
        _markDeniedIfNeeded(payload, 'textsearch');
        return null;
      }
      final results = payload['results'];
      if (results is! List || results.isEmpty) {
        return null;
      }
      return _fromGoogleResult(results.first);
    } catch (error) {
      log('textsearch failed: $error', name: 'Places');
      return null;
    }
  }

  static Future<PlaceLocation?> findPlace(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || _googleRestDenied) {
      return null;
    }
    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/findplacefromtext/json',
        {
          'input': trimmed,
          'inputtype': 'textquery',
          'fields': 'geometry,name,formatted_address',
          'key': googleMapsApiKey,
          'region': 'pk',
          'language': 'en',
        },
      );
      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode != 200) {
        return null;
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map) {
        return null;
      }
      final status = (payload['status'] ?? '').toString();
      log('findplace status=$status query=$trimmed', name: 'Places');
      if (status != 'OK') {
        _markDeniedIfNeeded(payload, 'findplace');
        return null;
      }
      final candidates = payload['candidates'];
      if (candidates is! List || candidates.isEmpty) {
        return null;
      }
      return _fromGoogleResult(candidates.first);
    } catch (error) {
      log('findplace failed: $error', name: 'Places');
      return null;
    }
  }

  static Future<PlaceLocation?> resolve(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return await searchPlace(trimmed) ??
        await findPlace(trimmed) ??
        await geocode(trimmed) ??
        await geocodeDevice(trimmed) ??
        await searchNominatim(trimmed);
  }

  static Future<PlaceLocation?> resolveQueries(List<String> queries) async {
    final unique = <String>[];
    final seen = <String>{};
    for (final query in queries) {
      final cleaned = query.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (cleaned.isEmpty || !seen.add(cleaned.toLowerCase())) {
        continue;
      }
      unique.add(cleaned);
    }
    if (unique.isEmpty) {
      return null;
    }

    if (!_googleRestDenied) {
      for (final query in unique) {
        final google = await searchPlace(query) ??
            await findPlace(query) ??
            await geocode(query);
        if (google != null) {
          return google;
        }
        if (_googleRestDenied) {
          break;
        }
      }
    }

    for (var i = 0; i < unique.length; i++) {
      if (i > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 1100));
      }
      final osm = await searchNominatim(unique[i]);
      if (osm != null) {
        return osm;
      }
    }

    for (final query in unique) {
      final device = await geocodeDevice(query);
      if (device != null) {
        return device;
      }
    }
    return null;
  }

  static Future<PlaceLocation?> geocodeDevice(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    try {
      await _ensureEnglishGeocodingLocale();
      final results = await geo.locationFromAddress(trimmed);
      if (results.isEmpty) {
        return null;
      }
      final loc = results.first;
      if (!_isValidCoord(loc.latitude, loc.longitude)) {
        return null;
      }
      log('device geocode hit query=$trimmed', name: 'Places');
      return PlaceLocation(
        latitude: loc.latitude,
        longitude: loc.longitude,
        name: trimmed,
        address: trimmed,
      );
    } catch (error) {
      log('device geocode failed: $error', name: 'Places');
      return null;
    }
  }

  static Future<PlaceLocation?> searchNominatim(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': trimmed,
        'format': 'json',
        'limit': '1',
        'addressdetails': '0',
        'accept-language': 'en',
      });
      final response = await http.get(
        uri,
        headers: const {
          'User-Agent': 'StyleBite/1.0 (restaurant-map)',
          'Accept': 'application/json',
          'Accept-Language': 'en',
        },
      ).timeout(_timeout);
      if (response.statusCode != 200) {
        log('nominatim http=${response.statusCode}', name: 'Places');
        return null;
      }
      final payload = jsonDecode(response.body);
      if (payload is! List || payload.isEmpty) {
        log('nominatim empty query=$trimmed', name: 'Places');
        return null;
      }
      final first = payload.first;
      if (first is! Map) {
        return null;
      }
      final lat = _toDouble(first['lat']);
      final lon = _toDouble(first['lon']);
      if (lat == null || lon == null || !_isValidCoord(lat, lon)) {
        return null;
      }
      log('nominatim hit query=$trimmed', name: 'Places');
      return PlaceLocation(
        latitude: lat,
        longitude: lon,
        name: (first['name'] ?? trimmed).toString().trim(),
        address: (first['display_name'] ?? '').toString().trim(),
      );
    } catch (error) {
      log('nominatim failed: $error', name: 'Places');
      return null;
    }
  }

  static void _markDeniedIfNeeded(dynamic payload, String source) {
    if (payload is! Map) {
      return;
    }
    final status = (payload['status'] ?? '').toString();
    if (status == 'REQUEST_DENIED' || status == 'OVER_QUERY_LIMIT') {
      _googleRestDenied = true;
      log(
        '$source denied status=$status error=${payload['error_message']}',
        name: 'Places',
      );
    }
  }

  static PlaceLocation? _fromGoogleResult(dynamic result) {
    if (result is! Map) {
      return null;
    }
    final geometry = result['geometry'];
    final location = geometry is Map ? geometry['location'] : null;
    if (location is! Map) {
      return null;
    }
    final lat = _toDouble(location['lat']);
    final lng = _toDouble(location['lng']);
    if (lat == null || lng == null || !_isValidCoord(lat, lng)) {
      return null;
    }
    return PlaceLocation(
      latitude: lat,
      longitude: lng,
      name: (result['name'] ?? '').toString().trim(),
      address: (result['formatted_address'] ?? '').toString().trim(),
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString().trim());
  }

  static bool _isValidCoord(double lat, double lng) {
    if (lat == 0 && lng == 0) {
      return false;
    }
    return lat.abs() <= 90 && lng.abs() <= 180;
  }
}
