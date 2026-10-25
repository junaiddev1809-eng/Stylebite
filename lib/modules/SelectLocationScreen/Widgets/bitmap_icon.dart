import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:ui' as ui;
import 'package:google_maps_flutter/google_maps_flutter.dart';


class MapFunctions{
  Future<BitmapDescriptor> bitmapDescriptorFromSvgAsset(String assetName, [
    Size size = const Size(40, 40),
  ]) async {
    final pictureInfo = await vg.loadPicture(SvgAssetLoader(assetName), null);

    double devicePixelRatio =
        ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
    int width = (size.width * devicePixelRatio).toInt();
    int height = (size.height * devicePixelRatio).toInt();

    final scaleFactor = min(
      width / pictureInfo.size.width,
      height / pictureInfo.size.height,
    );

    final recorder = ui.PictureRecorder();

    ui.Canvas(recorder)
      ..scale(scaleFactor)
      ..drawPicture(pictureInfo.picture);

    final rasterPicture = recorder.endRecording();

    final image = await rasterPicture.toImage(width, height);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;

    return BitmapDescriptor.fromBytes(bytes.buffer.asUint8List());
  }


  Future<String> getAddressFromLatLng(LatLng position) async {
    try {
      // Phone locale can be Urdu; keep map labels in English.
      await setLocaleIdentifier('en_US');
      List<Placemark> placeMarks =
      await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placeMarks.isNotEmpty) {
        Placemark place = placeMarks.first;
        final address = [
          place.locality,
          place.administrativeArea,
          place.country,
        ]
            .where((part) => part != null && part.trim().isNotEmpty)
            .map((part) => part!.trim())
            .join(', ');
        return address;
      } else {
        debugPrint("No address found for the given coordinates.");
      }
    } catch (e) {
      debugPrint("Error getting address: $e");
    }
    return "";
  }

  Future<String?> getPostalCodeFromLatLng(LatLng position) async {
    try {
      await setLocaleIdentifier('en_US');
      List<Placemark> placeMarks =
      await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placeMarks.isNotEmpty) {
        return placeMarks.first.postalCode;
      }
    } catch (e) {
      debugPrint("Error getting postal code: $e");
    }
    return null;
  }
}
