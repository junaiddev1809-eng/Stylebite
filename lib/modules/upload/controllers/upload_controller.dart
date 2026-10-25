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
import '../../../core/utils/local_storage.dart';
import '../../home/controllers/home_controller.dart';
import '../../home/models/home_post_model.dart';
import '../../landing/controllers/landing_controller.dart';
import '../../post/utils/hashtag_caption_limit.dart';
import '../../profile/controllers/profile_controller.dart';
import '../../profile/models/profile_model.dart';
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

    return isOutfitPost ? 'Location optional' : 'Location required';
  }

  bool get hasPinnedLocation =>
      locationController.text.trim().isNotEmpty &&
      _latitude != null &&
      _longitude != null;

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

    // Bite requires a real pinned place (search pick, map pin, or live GPS).
    // Style / reels can post with no location.
    if (!isOutfitPost && !hasPinnedLocation) {
      errorSnackBar(
        message:
            'Add a location for Bite — search and pick a place, pin the map, or use live GPS.',
      );
      return;
    }

    final mediaItems = selectedMediaItems.toList(growable: false);
    final location = locationController.text.trim();
    final caption = HashtagCaptionLimit.enforce(captionController.text.trim());
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

    final dishName = dishNameController.text.trim();
    final restaurant = restaurantController.text.trim();
    if (isOutfitPost) {
      fields['rating_enabled'] = '0';
    } else {
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
    fields['image_count'] = mediaItems.length.toString();

    final localId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final profileLocalId = -DateTime.now().millisecondsSinceEpoch;
    final showOnFeed = visibilityValue != 'private';
    final paths = [for (final item in mediaItems) item.path];
    if (showOnFeed) {
      HomeController.ensureController().showLocalPost(
        _localHomePost(
          id: localId,
          caption: caption,
          location: location,
          tagNames: tagNames,
          dishName: dishName,
          restaurant: restaurant,
          mediaItems: mediaItems,
        ),
      );
    }
    final profile = Get.isRegistered<ProfileController>()
        ? Get.find<ProfileController>()
        : Get.put(ProfileController());
    profile.showLocalPost(
      _localProfilePost(
        id: profileLocalId,
        caption: caption,
        location: location,
        dishName: dishName,
        mediaItems: mediaItems,
      ),
    );
    if (paths.length > 1) {
      unawaited(
        CarouselMediaStore.remember(postId: localId, sourcePaths: paths),
      );
      unawaited(
        CarouselMediaStore.remember(
          postId: profileLocalId.toString(),
          sourcePaths: paths,
        ),
      );
    }

    resetForm();
    if (Get.isRegistered<LandingController>()) {
      Get.find<LandingController>().onTabChanged(0);
    }

    unawaited(
      _uploadCreatedPost(
        localId: localId,
        profileLocalId: profileLocalId,
        fields: fields,
        mediaItems: mediaItems,
        showOnFeed: showOnFeed,
      ),
    );
  }

  Future<void> _uploadCreatedPost({
    required String localId,
    required int profileLocalId,
    required Map<String, String> fields,
    required List<PickedMedia> mediaItems,
    required bool showOnFeed,
  }) async {
    try {
      final extras = mediaItems.skip(1).toList(growable: false);
      final response = await ApiHelper.multipartRequestWithAuthorization(
        'posts',
        fields: fields,
        fileFieldName: 'file',
        filePath: mediaItems.first.path,
        files: [
          for (var i = 0; i < extras.length; i++)
            MapEntry('images[$i]', extras[i].path),
        ],
      );
      if (response == null) {
        _removeLocalPost(localId, profileLocalId, showOnFeed: showOnFeed);
        return;
      }

      final materialized = await http.Response.fromStream(response);
      final payload = jsonDecode(materialized.body) as Map<String, dynamic>;
      if (materialized.statusCode < 200 ||
          materialized.statusCode >= 300 ||
          payload['status_code'] != 1) {
        throw Exception(
          (payload['message'] ?? 'Unable to upload post').toString(),
        );
      }

      final created = payload['post'];
      if (created is! Map) {
        // Keep a single card: drop the optimistic row if the API did not
        // return a post payload we can swap in.
        _removeLocalPost(localId, profileLocalId, showOnFeed: showOnFeed);
        successSnackBar(message: 'Post uploaded');
        return;
      }
      final map = Map<String, dynamic>.from(created);
      final createdType = (map['post_type'] ?? '').toString();
      final serverHome = HomePostModel.fromJson(
        map,
        responseType: createdType == 'food' ? 'food' : 'outfit',
      );
      final serverProfile = ProfilePostModel.fromMap(map);
      if (showOnFeed) {
        HomeController.ensureController().replaceLocalPost(localId, serverHome);
      }
      if (Get.isRegistered<ProfileController>()) {
        Get.find<ProfileController>().replaceLocalPost(
          profileLocalId,
          serverProfile,
        );
      }
      final paths = [for (final item in mediaItems) item.path];
      if (paths.length > 1) {
        await CarouselMediaStore.remember(
          postId: serverHome.id,
          sourcePaths: paths,
        );
        await CarouselMediaStore.remember(
          postId: serverProfile.id.toString(),
          sourcePaths: paths,
        );
      }
      successSnackBar(message: 'Post uploaded');
    } catch (error) {
      _removeLocalPost(localId, profileLocalId, showOnFeed: showOnFeed);
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _removeLocalPost(
    String localId,
    int profileLocalId, {
    required bool showOnFeed,
  }) {
    if (showOnFeed) {
      HomeController.ensureController().removeLocalPost(localId);
    }
    if (Get.isRegistered<ProfileController>()) {
      Get.find<ProfileController>().removeLocalPost(profileLocalId);
    }
  }

  HomePostModel _localHomePost({
    required String id,
    required String caption,
    required String location,
    required List<String> tagNames,
    required String dishName,
    required String restaurant,
    required List<PickedMedia> mediaItems,
  }) {
    final first = mediaItems.first;
    final isVideo = first.type == AppMediaType.video;
    final username = LocalStorage.getUsername() ?? '';
    return HomePostModel(
      id: id,
      feedType: isOutfitPost ? HomeFeedType.style : HomeFeedType.bite,
      mediaType: isVideo ? HomeMediaType.video : HomeMediaType.image,
      contentType: isOutfitPost
          ? HomeContentType.fashion
          : HomeContentType.food,
      username: username,
      location: location,
      streakLabel: '',
      avatarUrl: LocalStorage.getAvatarUrl() ?? '',
      imageUrl: isVideo ? '' : first.path,
      displayRating: 0,
      likes: '0',
      comments: '0',
      defaultSelectedRate: 0,
      caption: caption,
      postedAt: 'Just now',
      mediaUrl: first.path,
      authorName: username,
      profileUsername: username,
      media: [
        for (final item in mediaItems)
          HomePostMedia(
            fileUrl: item.path,
            type: item.type == AppMediaType.video
                ? HomeMediaType.video
                : HomeMediaType.image,
          ),
      ],
      tags: tagNames,
      dishName: dishName,
      restaurant: restaurant,
      visibility: visibilityValue,
      publishedAt: DateTime.now(),
    );
  }

  ProfilePostModel _localProfilePost({
    required int id,
    required String caption,
    required String location,
    required String dishName,
    required List<PickedMedia> mediaItems,
  }) {
    final isVideo = mediaItems.first.type == AppMediaType.video;
    return ProfilePostModel(
      id: id,
      postType: isOutfitPost ? 'outfit' : 'food',
      caption: caption.isNotEmpty
          ? caption
          : (dishName.isNotEmpty ? dishName : 'Post'),
      mediaKind: isVideo ? 'video' : 'image',
      location: location,
      likeCount: 0,
      commentCount: 0,
      shareCount: 0,
      saveCount: 0,
      ratingAvg: null,
      createdAt: 'Just now',
      visibility: visibilityValue,
      media: [
        for (final item in mediaItems)
          ProfileMediaModel(
            id: 0,
            mediaType: item.type == AppMediaType.video ? 'video' : 'image',
            fileUrl: item.path,
            thumbnailUrl: '',
          ),
      ],
    );
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

      // Always prefer a fresh GPS fix for exact live location (not last-known).
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 0,
            timeLimit: Duration(seconds: 20),
          ),
        );
      } catch (_) {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 12),
          ),
        );
      }

      _latitude = position.latitude;
      _longitude = position.longitude;

      final resolvedLocation = await _reverseGeocode(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (resolvedLocation.isNotEmpty) {
        setLocation(resolvedLocation, position.latitude, position.longitude);
      } else {
        // Still pin exact coords even if reverse geocode is slow/empty.
        setLocation(
          '${position.latitude.toStringAsFixed(5)}, '
          '${position.longitude.toStringAsFixed(5)}',
          position.latitude,
          position.longitude,
        );
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
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }
      if (position == null) {
        return null;
      }
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
