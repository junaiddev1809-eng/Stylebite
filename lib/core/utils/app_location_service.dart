import 'package:geolocator/geolocator.dart';

import 'app_helper.dart';

class AppLocationService {
  AppLocationService._();

  static Future<bool> requestPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      errorSnackBar(message: 'Please enable location services to continue.');
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      errorSnackBar(message: 'Location permission was denied.');
      return false;
    }

    if (permission == LocationPermission.deniedForever) {
      errorSnackBar(
        message:
            'Location permission is permanently denied. Enable it in settings.',
      );
      return false;
    }

    return true;
  }
}
