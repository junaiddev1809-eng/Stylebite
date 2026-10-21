import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:heroicons/heroicons.dart';
import '../../core/constants/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/utils/app_location_service.dart';
import '../../core/utils/google_places_service.dart';
import '../../core/widgets/app_hero_icon.dart';
import 'Widgets/bitmap_icon.dart';

class SelectLocationScreen extends StatefulWidget {
  final LatLng? addressLocation;
  final String? initialQuery;
  final Function(String, LatLng) onConfirmLocation;
  final Function(String?)? onZipCode;
  const SelectLocationScreen({
    super.key,
    required this.onConfirmLocation,
    this.addressLocation,
    this.initialQuery,
    this.onZipCode,
  });

  @override
  State<SelectLocationScreen> createState() => _SelectLocationScreenState();
}

class _SelectLocationScreenState extends State<SelectLocationScreen> {
  TextEditingController searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _searchDebounce;
  int _searchToken = 0;
  bool _ignoreSearch = false;
  bool _hasFix = false;
  List<PlaceSuggestion> _suggestions = [];

  // Initialized to US Center as default
  LatLng currentLocation = const LatLng(37.0902, -95.7129);
  GoogleMapController? _controller;
  Set<Marker> markers = {};
  String _selectedPlaceLabel = '';
  LatLng? _pendingCameraTarget;
  int _pinLookup = 0;
  int _cameraToken = 0;

  @override
  void initState() {
    super.initState();
    final initialQuery = widget.initialQuery?.trim() ?? '';
    if (initialQuery.isNotEmpty) {
      searchController.text = initialQuery;
      _selectedPlaceLabel = initialQuery;
    }
    _searchFocus.addListener(() {
      if (_searchFocus.hasFocus && searchController.text.trim().isEmpty) {
        _scheduleSearch('');
      }
    });
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchFocus.dispose();
    searchController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _scheduleSearch(String value) {
    if (_ignoreSearch) {
      return;
    }
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_runSearch(value));
    });
  }

  Future<void> _runSearch(String value) async {
    final token = ++_searchToken;
    final trimmed = value.trim();
    if (trimmed.isEmpty && !_hasFix) {
      if (mounted) {
        setState(() => _suggestions = []);
      }
      return;
    }
    final results = await GooglePlacesService.suggest(
      trimmed,
      latitude: _hasFix ? currentLocation.latitude : null,
      longitude: _hasFix ? currentLocation.longitude : null,
    );
    if (!mounted || token != _searchToken) {
      return;
    }
    setState(() => _suggestions = results);
  }

  Future<void> _pickSuggestion(PlaceSuggestion item) async {
    _searchToken++;
    _searchDebounce?.cancel();
    _ignoreSearch = true;
    setState(() => _suggestions = []);
    _searchFocus.unfocus();
    final lat = item.latitude;
    final lng = item.longitude;
    if (lat != null && lng != null) {
      await _focusOnPlace(LatLng(lat, lng), label: item.label);
    } else {
      await _selectSearchedPlace(
        description: item.label,
        placeId: item.placeId.startsWith('nominatim:') ||
                item.placeId.startsWith('photon:') ||
                item.placeId.startsWith('osm:')
            ? null
            : item.placeId,
      );
    }
    _ignoreSearch = false;
  }

  void _keepUserPin() {
    _cameraToken++;
  }

  Future<void> _getCurrentLocation() async {
    final token = _cameraToken;
    final hasPermission = await AppLocationService.requestPermission();
    Position? position;

    if (hasPermission) {
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
      } catch (e) {
        debugPrint('Error getting current position: $e');
      }
    }

    // A tap or search that happened while GPS was loading owns the map.
    if (!mounted || token != _cameraToken) return;

    if (widget.addressLocation != null) {
      _hasFix = true;
      setState(() {
        currentLocation = widget.addressLocation!;
      });
      if (!await _addCurrentLocationMarker(currentLocation, token: token)) {
        return;
      }
      _moveCameraToLocation(currentLocation);
    } else {
      setState(() {
        if (position != null) {
          _hasFix = true;
          currentLocation = LatLng(position.latitude, position.longitude);
        }
      });
      if (!mounted || token != _cameraToken) return;
      if (!await _addCurrentLocationMarker(currentLocation, token: token)) {
        return;
      }
      _moveCameraToLocation(currentLocation, zoom: position != null ? 15 : 4);
    }
    if (_searchFocus.hasFocus && searchController.text.trim().isEmpty) {
      _scheduleSearch('');
    }
  }

  Future<void> _goToMyLocation() async {
    final token = ++_cameraToken;
    final hasPermission = await AppLocationService.requestPermission();
    if (!hasPermission || !mounted || token != _cameraToken) {
      return;
    }
    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      debugPrint('Error getting current position: $e');
    }
    if (position == null || !mounted || token != _cameraToken) {
      return;
    }
    final pinned = LatLng(position.latitude, position.longitude);
    _hasFix = true;
    currentLocation = pinned;
    _selectedPlaceLabel = '';
    if (!await _addCurrentLocationMarker(pinned, token: token)) {
      return;
    }
    _moveCameraToLocation(pinned);
    final address = await GooglePlacesService.reverseLabel(
      pinned.latitude,
      pinned.longitude,
    );
    if (!mounted || token != _cameraToken) return;
    _showPinAddress(address);
  }

  Future<bool> _addCurrentLocationMarker(
    LatLng position, {
    required int token,
  }) async {
    BitmapDescriptor icon = BitmapDescriptor.defaultMarker;
    try {
      icon = await MapFunctions().bitmapDescriptorFromSvgAsset(
        AppAssets.locationPinSvg,
      );
    } catch (e) {
      debugPrint('Error loading marker icon: $e');
    }

    if (!mounted || token != _cameraToken) return false;
    setState(() {
      markers.clear();
      markers.add(
        Marker(
          markerId: const MarkerId("currentLocation"),
          position: position,
          infoWindow: InfoWindow(
            title: _selectedPlaceLabel.isNotEmpty
                ? _selectedPlaceLabel
                : 'Location',
          ),
          icon: icon,
        ),
      );
    });
    return true;
  }

  void _moveCameraToLocation(LatLng position, {double zoom = 15}) {
    currentLocation = position;
    _pendingCameraTarget = position;
    _controller?.animateCamera(CameraUpdate.newLatLngZoom(position, zoom));
  }

  Future<void> _focusOnPlace(LatLng position, {String? label}) async {
    _keepUserPin();
    final resolvedLabel = (label ?? '').trim();
    if (resolvedLabel.isNotEmpty) {
      _selectedPlaceLabel = resolvedLabel;
      _ignoreSearch = true;
      searchController.text = resolvedLabel;
      _ignoreSearch = false;
      _suggestions = [];
    }
    currentLocation = position;
    final token = _cameraToken;
    if (!await _addCurrentLocationMarker(position, token: token)) {
      return;
    }
    _moveCameraToLocation(position, zoom: 16);
  }

  Future<void> _selectSearchedPlace({
    required String description,
    String? placeId,
    String? lat,
    String? lng,
  }) async {
    final token = _cameraToken;
    final parsedLat = double.tryParse(lat ?? '');
    final parsedLng = double.tryParse(lng ?? '');
    if (parsedLat != null && parsedLng != null) {
      await _focusOnPlace(
        LatLng(parsedLat, parsedLng),
        label: description,
      );
      return;
    }

    if (placeId != null && placeId.trim().isNotEmpty) {
      final details = await GooglePlacesService.fetchPlaceDetails(placeId);
      if (!mounted || token != _cameraToken || details == null) {
        return;
      }
      await _focusOnPlace(
        LatLng(details.latitude, details.longitude),
        label: details.name.isNotEmpty ? details.name : description,
      );
      return;
    }

    final geocoded = await GooglePlacesService.geocode(description);
    if (!mounted || token != _cameraToken || geocoded == null) {
      return;
    }
    await _focusOnPlace(
      LatLng(geocoded.latitude, geocoded.longitude),
      label: description,
    );
  }

  void _showPinAddress(String address) {
    final label = address.trim();
    if (label.isEmpty || !mounted) {
      return;
    }
    setState(() {
      _selectedPlaceLabel = label;
      searchController.text = label;
      searchController.selection = TextSelection.collapsed(
        offset: label.length,
      );
    });
  }

  Future<void> _addMarkerOnTap(LatLng position) async {
    _keepUserPin();
    final token = _cameraToken;
    final lookup = ++_pinLookup;
    currentLocation = position;
    _selectedPlaceLabel = '';
    BitmapDescriptor icon = BitmapDescriptor.defaultMarker;
    try {
      icon = await MapFunctions().bitmapDescriptorFromSvgAsset(
        AppAssets.locationPinSvg,
      );
    } catch (_) {}

    if (!mounted || token != _cameraToken || lookup != _pinLookup) return;
    setState(() {
      markers.clear();
      markers.add(
        Marker(
          markerId: const MarkerId("selectedLocation"),
          position: position,
          infoWindow: const InfoWindow(title: "Selected Location"),
          icon: icon,
        ),
      );
    });
    _moveCameraToLocation(position);

    final address = await GooglePlacesService.reverseLabel(
      position.latitude,
      position.longitude,
    );
    if (!mounted || lookup != _pinLookup) return;
    _showPinAddress(address);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Map Layer
          Positioned.fill(
            child: GoogleMap(
              key: const ValueKey("google_map"),
              zoomControlsEnabled: false,
              markers: markers,
              myLocationButtonEnabled: false,
              myLocationEnabled: false,
              onTap: (location) {
                _addMarkerOnTap(location);
              },
              initialCameraPosition: CameraPosition(
                target: currentLocation,
                zoom: 15.0,
              ),
              onMapCreated: (GoogleMapController controller) {
                _controller = controller;
                final target = _pendingCameraTarget ?? widget.addressLocation;
                if (target != null) {
                  Future.delayed(const Duration(milliseconds: 300), () {
                    _moveCameraToLocation(target);
                  });
                }
              },
            ),
          ),

          // Header Overlay: Back Button & Search Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 10,
                bottom: 24,
                left: 16,
                right: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                children: [
                  Row(
                children: [
                  // Back Button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: AppHeroIconData(
                          HeroIcons.xMark,
                          color: AppColors.text,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Search Bar
                  Expanded(
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: searchController,
                        focusNode: _searchFocus,
                        maxLines: 1,
                        onChanged: (value) {
                          setState(() {});
                          _scheduleSearch(value);
                        },
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: "Search locations...",
                          hintStyle: AppFonts.beVietnam(
                            size: 14,
                            weight: FontWeight.w500,
                            color: const Color(0xFF9A8F8A),
                          ),
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(left: 16, right: 10),
                            child: AppHeroIconData(
                              HeroIcons.magnifyingGlass,
                              size: 20,
                              color: Color(0xFF9A8F8A),
                            ),
                          ),
                          prefixIconConstraints: const BoxConstraints(minWidth: 46),
                          suffixIcon: searchController.text.isNotEmpty
                              ? IconButton(
                                  onPressed: () {
                                    _searchToken++;
                                    setState(() {
                                      searchController.clear();
                                      _suggestions = [];
                                    });
                                    _scheduleSearch('');
                                  },
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: Color(0xFF9A8F8A),
                                    size: 20,
                                  ),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        style: AppFonts.beVietnam(
                          size: 14,
                          weight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_suggestions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 8, left: 60),
                  constraints: const BoxConstraints(maxHeight: 320),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                    ),
                    itemBuilder: (context, index) {
                      final item = _suggestions[index];
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          item.isRestaurant
                              ? Icons.storefront_rounded
                              : Icons.place_outlined,
                          size: 18,
                          color: AppColors.hintText,
                        ),
                        title: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.beVietnam(
                            size: 13,
                            weight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        subtitle: item.subtitle.trim().isEmpty
                            ? null
                            : Text(
                                item.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppFonts.beVietnam(
                                  size: 11,
                                  weight: FontWeight.w500,
                                  color: AppColors.hintText,
                                ),
                              ),
                        onTap: () => _pickSuggestion(item),
                      );
                    },
                  ),
                ),
                ],
              ),
            ),
          ),

          // My Location Button
          Positioned(
            bottom: 150,
            right: 16,
            child: GestureDetector(
              onTap: _goToMyLocation,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: AppHeroIconData(
                    HeroIcons.mapPin,
                    color: AppColors.primary,
                    size: 28,
                    style: HeroIconStyle.solid,
                  ),
                ),
              ),
            ),
          ),

          // Confirm Button
          Positioned(
            bottom: 34,
            left: 16,
            right: 16,
            child: SafeArea(
              child: Container(
                width: double.infinity,
                height: 58,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [AppColors.primary, AppColors.secondary],
                  ),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    // Always describe the pin coordinates, not an older search
                    // or the phone's GPS point.
                    final pinned = currentLocation;
                    var address = (await GooglePlacesService.reverseLabel(
                      pinned.latitude,
                      pinned.longitude,
                    )).trim();
                    if (address.isEmpty) {
                      address = _selectedPlaceLabel.trim();
                    }
                    if (address.isEmpty) {
                      address = searchController.text.trim();
                    }
                    if (address.isEmpty ||
                        address.toLowerCase() == 'unknown location') {
                      address =
                          '${pinned.latitude.toStringAsFixed(5)}, '
                          '${pinned.longitude.toStringAsFixed(5)}';
                    }

                    widget.onConfirmLocation(address, pinned);
                    if (!context.mounted) {
                      return;
                    }
                    Navigator.pop(context);
                    if (widget.onZipCode != null) {
                      final zipCode = await MapFunctions()
                          .getPostalCodeFromLatLng(pinned);
                      widget.onZipCode!(zipCode);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  icon: const AppHeroIconData(
                    HeroIcons.check,
                    color: Colors.white,
                    size: 22,
                    style: HeroIconStyle.solid,
                  ),
                  label: Text(
                    "Confirm Location",
                    style: AppFonts.beVietnam(
                      size: 16,
                      weight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
