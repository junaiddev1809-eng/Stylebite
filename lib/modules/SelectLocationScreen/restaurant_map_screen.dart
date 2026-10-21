import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/constants/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/utils/app_helper.dart';
import '../../core/utils/google_places_service.dart';
import '../../core/widgets/app_hero_icon.dart';
import '../../modules/home/models/home_post_model.dart';
import 'Widgets/bitmap_icon.dart';

class RestaurantMapScreen extends StatefulWidget {
  const RestaurantMapScreen({
    super.key,
    required this.title,
    required this.location,
    this.subtitle = '',
  });

  final String title;
  final String subtitle;
  final LatLng location;

  static bool _hasValidCoords(double? lat, double? lng) {
    if (lat == null || lng == null) {
      return false;
    }
    if (lat == 0 && lng == 0) {
      return false;
    }
    return lat.abs() <= 90 && lng.abs() <= 180;
  }

  static Future<void> openForPost(HomePostModel post) async {
    final title = post.restaurant.trim().isNotEmpty
        ? post.restaurant.trim()
        : (post.displayLocation.isNotEmpty
              ? post.displayLocation
              : 'Restaurant');
    final subtitle = post.location.trim();
    var lat = post.latitude;
    var lng = post.longitude;

    if (!_hasValidCoords(lat, lng)) {
      final queries = _mapQueriesFor(post);
      if (queries.isEmpty) {
        errorSnackBar(message: 'No restaurant location to show.');
        return;
      }
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );
      PlaceLocation? resolved;
      try {
        resolved = await GooglePlacesService.resolveQueries(queries);
      } finally {
        if (Get.isDialogOpen == true) {
          Get.back<void>();
        }
      }
      if (resolved == null) {
        errorSnackBar(message: 'Could not find this restaurant on the map.');
        return;
      }
      lat = resolved.latitude;
      lng = resolved.longitude;
    }

    await Get.to<void>(
      () => RestaurantMapScreen(
        title: title,
        subtitle: subtitle,
        location: LatLng(lat!, lng!),
      ),
    );
  }

  static List<String> _mapQueriesFor(HomePostModel post) {
    final restaurant = post.restaurant.trim();
    final location = post.location.trim();
    final city = post.displayLocation.trim().isNotEmpty
        ? post.displayLocation.trim()
        : post.authorCity.trim();
    final seen = <String>{};
    final queries = <String>[];

    void add(String value) {
      final cleaned = value.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (cleaned.isEmpty || !seen.add(cleaned.toLowerCase())) {
        return;
      }
      queries.add(cleaned);
    }

    add(restaurant);
    add([restaurant, 'Pakistan'].where((part) => part.isNotEmpty).join(', '));
    add([restaurant, city].where((part) => part.isNotEmpty).join(', '));
    add([restaurant, location].where((part) => part.isNotEmpty).join(', '));
    add(location);
    add(city);
    return queries;
  }

  @override
  State<RestaurantMapScreen> createState() => _RestaurantMapScreenState();
}

class _RestaurantMapScreenState extends State<RestaurantMapScreen> {
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _buildMarker();
  }

  Future<void> _buildMarker() async {
    BitmapDescriptor icon = BitmapDescriptor.defaultMarker;
    try {
      icon = await MapFunctions().bitmapDescriptorFromSvgAsset(
        AppAssets.locationPinSvg,
      );
    } catch (_) {}
    if (!mounted) {
      return;
    }
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('restaurant'),
          position: widget.location,
          infoWindow: InfoWindow(
            title: widget.title,
            snippet: widget.subtitle.isEmpty ? null : widget.subtitle,
          ),
          icon: icon,
        ),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              markers: _markers,
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              myLocationEnabled: false,
              initialCameraPosition: CameraPosition(
                target: widget.location,
                zoom: 16,
              ),
              onMapCreated: (controller) {
                controller.showMarkerInfoWindow(const MarkerId('restaurant'));
              },
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: [
                    Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      elevation: 4,
                      child: IconButton(
                        onPressed: () => Get.back<void>(),
                        icon: const AppHeroIconData(
                          Icons.arrow_back_rounded,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Material(
                        color: Colors.white,
                        elevation: 4,
                        borderRadius: BorderRadius.circular(18),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppFonts.beVietnam(
                                  size: 14,
                                  weight: FontWeight.w800,
                                  color: AppColors.text,
                                ),
                              ),
                              if (widget.subtitle.trim().isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  widget.subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppFonts.beVietnam(
                                    size: 12,
                                    weight: FontWeight.w500,
                                    color: AppColors.hintText,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
