import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../../../core/media/media_picker_service.dart';
import '../../../core/media/media_type_resolver.dart';
import '../../../core/media/picked_media.dart';
import '../../../core/utils/api_helper.dart';
import '../../../core/utils/app_helper.dart';
import '../../../core/utils/google_places_service.dart';
import '../../landing/controllers/landing_controller.dart';
import '../../post/utils/hashtag_caption_limit.dart';
import '../models/upload_post_model.dart';
import '../services/carousel_media_store.dart';

class UploadController extends GetxController {
  static const int _maxImageBytes = 12 * 1024 * 1024;
  static const int _maxVideoBytes = 80 * 1024 * 1024;

  final Rx<UploadPostType> selectedType = UploadPostType.outfit.obs;
  final Rx<UploadPostVisibility> selectedVisibility =
      UploadPostVisibility.public.obs;

  final TextEditingController captionController = TextEditingController();
  final TextEditingController locationController = TextEditingController(
    text: '',
  );
  final TextEditingController dishNameController = TextEditingController(
    text: '',
  );
  final TextEditingController restaurantController = TextEditingController(
    text: '',
  );

  final RxMap<String, double> foodRatings = <String, double>{
    'food': 1.0,
    'service': 1.0,
    'staff': 1.0,
    'ambience': 1.0,
  }.obs;
  final RxList<PickedMedia> selectedMediaItems = <PickedMedia>[].obs;
  final RxString mediaError = ''.obs;
  final RxBool isUploading = false.obs;
  final RxBool isFetchingLocation = false.obs;
  final RxDouble uploadProgress = 0.0.obs;
  final RxBool uploadFailed = false.obs;
  final RxString uploadMessage = ''.obs;
  final RxString locationQuery = ''.obs;
  final RxList<LocationSuggestion> locationSuggestions =
      <LocationSuggestion>[].obs;
  final RxBool isSearchingLocations = false.obs;
  double? _latitude;
  double? _longitude;
  double? _originLat;
  double? _originLng;
  Timer? _locationDebounce;
  int _suggestionToken = 0;
  bool _ignoreLocationTextChanges = false;

  double? get latitude => _latitude;
  double? get longitude => _longitude;

  final List<FoodRatingItem> ratingItems = const [
    FoodRatingItem(key: 'food', label: 'Food', initial: 4.8),
    FoodRatingItem(key: 'service', label: 'Service', initial: 3.8),
    FoodRatingItem(key: 'staff', label: 'Staff', initial: 4.0),
    FoodRatingItem(key: 'ambience', label: 'Ambience', initial: 4.2),
  ];

  String get captionHint => selectedType.value == UploadPostType.food
      ? 'Share your review. Add up to 5 tags with #, like #bbq #karachi'
      : 'Write a caption. Add up to 5 tags with #, like #ootd #streetwear';

  String get shareButtonLabel => selectedType.value == UploadPostType.food
      ? 'Share Food Post'
      : 'Share Outfit Post';

  bool get isOutfitPost => selectedType.value == UploadPostType.outfit;

  String get visibilityValue {
    switch (selectedVisibility.value) {
      case UploadPostVisibility.followersOnly:
        return 'followers_only';
      case UploadPostVisibility.private:
        return 'private';
      case UploadPostVisibility.public:
        return 'public';
    }
  }

  String get postTypeValue => isOutfitPost ? '1' : '2';

  String get foodPreviewTitle {
    final dish = dishNameController.text.trim();
    return dish.isEmpty ? 'BBQ Tonight' : dish;
  }

  String get foodPreviewLocation {
    final location = locationController.text.trim();
    final restaurant = restaurantController.text.trim();

    if (restaurant.isNotEmpty && location.isNotEmpty) {
      return '$restaurant | $location';
    }

    if (restaurant.isNotEmpty) {
      return restaurant;
    }

    if (location.isNotEmpty) {
      return location;
    }

    return 'Location optional';
  }

  double get overallFoodRating {
    _normalizeFoodRatings();

    final total = foodRatings.values.fold<double>(
      0,
      (sum, value) => sum + value,
    );
    return total / foodRatings.length;
  }

  @override
  void onInit() {
    super.onInit();
    _normalizeFoodRatings();
    locationQuery.value = locationController.text;
  }

  void setPostType(UploadPostType type) {
    selectedType.value = type;
    if (type == UploadPostType.food) {
      _normalizeFoodRatings();
    }
  }

  void setVisibility(UploadPostVisibility visibility) {
    selectedVisibility.value = visibility;
  }

  void setFoodRating(String key, double value) {
    foodRatings[key] = value.clamp(1.0, 5.0);
  }

  void setLocation(String address, double lat, double lng) {
    _ignoreLocationTextChanges = true;
    locationController.text = address;
    locationQuery.value = address;
    _latitude = lat;
    _longitude = lng;
    locationSuggestions.clear();
    _ignoreLocationTextChanges = false;
    refreshFoodPreview();
  }

  void clearLocation() {
    _ignoreLocationTextChanges = true;
    locationController.clear();
    locationQuery.value = '';
    _latitude = null;
    _longitude = null;
    locationSuggestions.clear();
    _ignoreLocationTextChanges = false;
    refreshFoodPreview();
  }

  void onLocationQueryChanged(String value) {
    if (_ignoreLocationTextChanges) {
      return;
    }
    locationQuery.value = value;
    _latitude = null;
    _longitude = null;
    refreshFoodPreview();
    _locationDebounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      _locationDebounce = Timer(const Duration(milliseconds: 200), () {
        unawaited(_fetchLocationSuggestions(''));
      });
      return;
    }
    _locationDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_fetchLocationSuggestions(trimmed));
    });
  }

  Future<void> selectLocationSuggestion(LocationSuggestion suggestion) async {
    _suggestionToken++;
    locationSuggestions.clear();
    isSearchingLocations.value = false;
    final label = suggestion.label;
    if (suggestion.latitude != null && suggestion.longitude != null) {
      setLocation(label, suggestion.latitude!, suggestion.longitude!);
      _fillRestaurantName(suggestion.title);
      return;
    }
    _ignoreLocationTextChanges = true;
    locationController.text = label;
    locationQuery.value = label;
    _ignoreLocationTextChanges = false;
    refreshFoodPreview();
    await _applyPlaceDetails(suggestion.placeId, label);
    _fillRestaurantName(suggestion.title);
  }

  void refreshFoodPreview() {
    selectedType.refresh();
  }

  Future<void> pickMedia({required bool fromCamera}) async {
    mediaError.value = '';
    uploadFailed.value = false;

    if (fromCamera) {
      final picked = await MediaPickerService.pickFromCamera();
      if (picked == null) {
        return;
      }
      await _acceptMedia([picked]);
      return;
    }

    final result = await MediaPickerService.pickPostGallery();
    if (result.notice.isNotEmpty) {
      mediaError.value = result.notice;
    }
    if (result.media.isEmpty) {
      return;
    }
    await _acceptMedia(result.media);
  }

  Future<void> _acceptMedia(List<PickedMedia> picked) async {
    final accepted = <PickedMedia>[];
    for (final item in picked.take(MediaPickerService.carouselPhotoLimit)) {
      final size = await item.file.length();
      final maxAllowed = item.type == AppMediaType.video
          ? _maxVideoBytes
          : _maxImageBytes;
      if (size > maxAllowed) {
        mediaError.value = item.type == AppMediaType.video
            ? 'Video is too large. Keep it under 80MB.'
            : 'Each photo must be under 12MB.';
        continue;
      }
      accepted.add(item);
    }
    if (accepted.isEmpty) {
      return;
    }
    selectedMediaItems.assignAll(accepted);
  }

  void clearMedia() {
    selectedMediaItems.clear();
    mediaError.value = '';
  }

  Future<void> submitPost() async {
    uploadMessage.value = '';
    mediaError.value = '';

    if (selectedMediaItems.isEmpty) {
      mediaError.value = 'Add photo or video before posting.';
      return;
    }

    isUploading.value = true;
    uploadFailed.value = false;
    uploadProgress.value = 0;
    try {
      uploadProgress.value = 0.25;
      final mediaItems = selectedMediaItems.toList(growable: false);
      final media = mediaItems.first;
      final location = locationController.text.trim();
      if (location.isNotEmpty && (_latitude == null || _longitude == null)) {
        await _geocodeTypedLocation(location);
      }

      final caption = HashtagCaptionLimit.enforce(
        captionController.text.trim(),
      );
      final tagNames = HashtagCaptionLimit.tagsIn(caption)
          .map((tag) => tag.replaceFirst('#', '').trim())
          .where((tag) => tag.isNotEmpty)
          .toList(growable: false);
      final fields = <String, String>{
        'post_type': postTypeValue,
        'caption': caption,
        'tags': tagNames.join(','),
        'visibility': visibilityValue,
      };
      if (location.isNotEmpty) {
        fields['location'] = location;
        if (_latitude != null && _longitude != null) {
          fields['lat'] = _latitude.toString();
          fields['lng'] = _longitude.toString();
        }
      }

      if (isOutfitPost) {
        fields['rating_enabled'] = '0';
      } else {
        final dishName = dishNameController.text.trim();
        final restaurant = restaurantController.text.trim();
        if (dishName.isNotEmpty) {
          fields['dish_name'] = dishName;
        }
        if (restaurant.isNotEmpty) {
          fields['restaurant'] = restaurant;
        }
        fields['food_rating'] = (foodRatings['food'] ?? 0)
            .round()
            .clamp(1, 5)
            .toString();
        fields['service_rating'] = (foodRatings['service'] ?? 0)
            .round()
            .clamp(1, 5)
            .toString();
        fields['staff_rating'] = (foodRatings['staff'] ?? 0)
            .round()
            .clamp(1, 5)
            .toString();
        fields['ambience_rating'] = (foodRatings['ambience'] ?? 0)
            .round()
            .clamp(1, 5)
            .toString();
      }

      uploadProgress.value = 0.55;
      fields['image_count'] = mediaItems.length.toString();
      final extras = mediaItems.skip(1).toList(growable: false);
      final response = await ApiHelper.multipartRequestWithAuthorization(
        'posts',
        fields: fields,
        fileFieldName: 'file',
        filePath: media.path,
        files: [
          for (var i = 0; i < extras.length; i++)
            MapEntry('images[$i]', extras[i].path),
        ],
      );

      if (response == null) {
        throw Exception('No response returned from server.');
      }

      uploadProgress.value = 0.85;
      final materialized = await http.Response.fromStream(response);
      final payload = jsonDecode(materialized.body) as Map<String, dynamic>;
      if (materialized.statusCode < 200 ||
          materialized.statusCode >= 300 ||
          payload['status_code'] != 1) {
        throw Exception(
          (payload['message'] ?? 'Unable to upload post').toString(),
        );
      }

      uploadProgress.value = 1;
      uploadFailed.value = false;
      if (mediaItems.length > 1) {
        await CarouselMediaStore.remember(
          postId: _createdPostId(payload),
          sourcePaths: [for (final item in mediaItems) item.path],
        );
      }

      resetForm();

      successSnackBar(message: (payload['message'] ?? 'Post uploaded successfully.').toString());
      if (Get.isRegistered<LandingController>()) {
        Get.find<LandingController>().onTabChanged(0);
      }
    } catch (error) {
      uploadFailed.value = true;
      uploadMessage.value = error.toString().replaceFirst('Exception: ', '');
      errorSnackBar(message: uploadMessage.value);
    } finally {
      isUploading.value = false;
    }
  }

  Future<void> fetchCurrentLocation({bool silent = false}) async {
    if (isFetchingLocation.value) {
      return;
    }

    isFetchingLocation.value = true;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Enable location services to use current location.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is needed to use current location.',
        );
      }

      final lastKnown = await Geolocator.getLastKnownPosition();
      final position =
          lastKnown ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 12),
            ),
          );

      _latitude = position.latitude;
      _longitude = position.longitude;

      final resolvedLocation = await _reverseGeocode(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (resolvedLocation.isNotEmpty) {
        setLocation(resolvedLocation, position.latitude, position.longitude);
      } else if (!silent) {
        throw Exception('Unable to fetch current address. Please try again.');
      }
    } catch (error) {
      if (!silent) {
        errorSnackBar(
          message: error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      isFetchingLocation.value = false;
    }
  }

  Future<String> _reverseGeocode({
    required double latitude,
    required double longitude,
  }) {
    return GooglePlacesService.reverseLabel(latitude, longitude);
  }

  Future<void> _fetchLocationSuggestions(String input) async {
    final token = ++_suggestionToken;
    isSearchingLocations.value = true;
    try {
      final origin = await _searchOrigin();
      if (token != _suggestionToken) {
        return;
      }
      final results = await GooglePlacesService.suggest(
        input,
        latitude: origin?.lat,
        longitude: origin?.lng,
      );
      if (token != _suggestionToken) {
        return;
      }
      locationSuggestions.assignAll(
        results.map(
          (item) => LocationSuggestion(
            placeId: item.placeId,
            description: item.label,
            title: item.title,
            subtitle: item.subtitle,
            latitude: item.latitude,
            longitude: item.longitude,
            isRestaurant: item.isRestaurant,
          ),
        ),
      );
    } catch (_) {
      if (token == _suggestionToken) {
        locationSuggestions.clear();
      }
    } finally {
      if (token == _suggestionToken) {
        isSearchingLocations.value = false;
      }
    }
  }

  Future<({double lat, double lng})?> _searchOrigin() async {
    if (_latitude != null && _longitude != null) {
      return (lat: _latitude!, lng: _longitude!);
    }
    if (_originLat != null && _originLng != null) {
      return (lat: _originLat!, lng: _originLng!);
    }
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final lastKnown = await Geolocator.getLastKnownPosition();
      final position =
          lastKnown ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 5),
            ),
          );
      _originLat = position.latitude;
      _originLng = position.longitude;
      return (lat: position.latitude, lng: position.longitude);
    } catch (_) {
      return null;
    }
  }

  void _fillRestaurantName(String name) {
    final trimmed = name.trim();
    if (isOutfitPost || trimmed.isEmpty) {
      return;
    }
    if (restaurantController.text.trim().isNotEmpty) {
      return;
    }
    restaurantController.text = trimmed;
    refreshFoodPreview();
  }

  Future<void> _applyPlaceDetails(String placeId, String fallback) async {
    final details = await GooglePlacesService.fetchPlaceDetails(placeId);
    if (details == null) {
      return;
    }
    final label = details.label.isNotEmpty ? details.label : fallback;
    setLocation(label, details.latitude, details.longitude);
    _fillRestaurantName(details.name);
  }

  String _createdPostId(Map<String, dynamic> payload) {
    for (final key in <String>['post', 'data', 'item']) {
      final nested = payload[key];
      if (nested is! Map) {
        continue;
      }
      final id = (nested['id'] ?? nested['post_id'] ?? '').toString().trim();
      if (id.isNotEmpty && id != 'null') {
        return id;
      }
    }
    return '';
  }

  Future<void> _geocodeTypedLocation(String query) async {
    final details = await GooglePlacesService.geocode(query);
    if (details == null) {
      return;
    }
    _latitude = details.latitude;
    _longitude = details.longitude;
  }

  void resetForm() {
    captionController.clear();
    dishNameController.clear();
    restaurantController.clear();
    locationController.clear();
    locationQuery.value = '';
    locationSuggestions.clear();
    selectedMediaItems.clear();
    mediaError.value = '';
    _latitude = null;
    _longitude = null;
    uploadProgress.value = 0.0;
    uploadMessage.value = '';
    uploadFailed.value = false;
    _normalizeFoodRatings(forceDefaults: true);
    refreshFoodPreview();
  }

  void clearStatusMessages() {
    uploadMessage.value = '';
    uploadFailed.value = false;
  }

  void _normalizeFoodRatings({bool forceDefaults = false}) {
    for (final item in ratingItems) {
      final rawValue = forceDefaults ? item.initial : foodRatings[item.key];
      final normalized = (rawValue ?? item.initial).clamp(1.0, 5.0).toDouble();
      if (foodRatings[item.key] != normalized) {
        foodRatings[item.key] = normalized;
      }
    }
  }

  @override
  void onClose() {
    _locationDebounce?.cancel();
    captionController.dispose();
    locationController.dispose();
    dishNameController.dispose();
    restaurantController.dispose();
    super.onClose();
  }
}

class LocationSuggestion {
  const LocationSuggestion({
    required this.placeId,
    required this.description,
    this.title = '',
    this.subtitle = '',
    this.latitude,
    this.longitude,
    this.isRestaurant = false,
  });

  final String placeId;
  final String description;
  final String title;
  final String subtitle;
  final double? latitude;
  final double? longitude;
  final bool isRestaurant;

  String get label {
    final name = title.trim();
    final address = subtitle.trim();
    if (description.trim().isNotEmpty && name.isEmpty) {
      return description.trim();
    }
    if (name.isEmpty) {
      return address;
    }
    if (address.isEmpty || address.toLowerCase().contains(name.toLowerCase())) {
      return address.isEmpty ? name : address;
    }
    return '$name, $address';
  }
}
