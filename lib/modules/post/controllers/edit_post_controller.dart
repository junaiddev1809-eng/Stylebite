import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../../../core/media/media_picker_service.dart';
import '../../../core/media/media_type_resolver.dart';
import '../../../core/media/picked_media.dart';
import '../../../core/utils/api_helper.dart';
import '../../../core/utils/app_helper.dart';
import '../../home/models/home_post_model.dart';
import '../../upload/models/upload_post_model.dart';
import '../utils/hashtag_caption_limit.dart';
import '../../upload/widgets/upload_visibility_selector.dart';

class EditPostController extends GetxController {
  EditPostController({required this.initialPost});

  static const int _maxImageBytes = 12 * 1024 * 1024;
  static const int _maxVideoBytes = 80 * 1024 * 1024;

  final HomePostModel initialPost;

  final captionController = TextEditingController();
  final locationController = TextEditingController();
  final dishNameController = TextEditingController();
  final restaurantController = TextEditingController();

  final Rx<UploadPostType> selectedType = UploadPostType.outfit.obs;
  final Rxn<UploadPostVisibility> selectedVisibility =
      Rxn<UploadPostVisibility>();
  final RxBool isVisibilityLoading = false.obs;
  final RxMap<String, double> foodRatings = <String, double>{
    'food': 1,
    'service': 1,
    'staff': 1,
    'ambience': 1,
  }.obs;
  final Rxn<PickedMedia> selectedMedia = Rxn<PickedMedia>();
  final RxBool isSaving = false.obs;
  final RxString saveMessage = ''.obs;
  final RxBool saveFailed = false.obs;
  final RxString mediaError = ''.obs;

  final List<FoodRatingItem> ratingItems = const [
    FoodRatingItem(key: 'food', label: 'Food', initial: 4.8),
    FoodRatingItem(key: 'service', label: 'Service', initial: 3.8),
    FoodRatingItem(key: 'staff', label: 'Staff', initial: 4.0),
    FoodRatingItem(key: 'ambience', label: 'Ambience', initial: 4.2),
  ];

  double? _latitude;
  double? _longitude;

  bool get isOutfitPost => selectedType.value == UploadPostType.outfit;

  String get visibilityValue {
    switch (selectedVisibility.value) {
      case UploadPostVisibility.followersOnly:
        return 'followers_only';
      case UploadPostVisibility.private:
        return 'private';
      case UploadPostVisibility.public:
      case null:
        return 'public';
    }
  }

  String get postTypeValue => isOutfitPost ? 'outfit' : 'food';

  @override
  void onInit() {
    super.onInit();
    _seed();
    _resolveVisibility();
  }

  void _seed() {
    selectedType.value = initialPost.isFoodPost
        ? UploadPostType.food
        : UploadPostType.outfit;
    selectedVisibility.value = parseUploadPostVisibility(
      initialPost.visibility,
    );
    captionController.text = HashtagCaptionLimit.enforce(initialPost.caption);
    final seededLocation = initialPost.location.trim();
    locationController.text =
        seededLocation.toLowerCase() == 'unknown location' ? '' : seededLocation;
    dishNameController.text = initialPost.dishName;
    restaurantController.text = initialPost.restaurant;
    foodRatings['food'] = (initialPost.foodRating ?? 1).clamp(1.0, 5.0);
    foodRatings['service'] = (initialPost.serviceRating ?? 1).clamp(1.0, 5.0);
    foodRatings['staff'] = (initialPost.staffRating ?? 1).clamp(1.0, 5.0);
    foodRatings['ambience'] = (initialPost.ambienceRating ?? 1).clamp(1.0, 5.0);
  }

  void setPostType(UploadPostType type) {
    selectedType.value = type;
  }

  /// Slim feed cards may not carry `visibility`; pull it from the post
  /// detail so the selector reflects the real current setting. Falls back
  /// to Public only if the API gives nothing, and never overrides a choice
  /// the user already made.
  Future<void> _resolveVisibility() async {
    if (selectedVisibility.value != null) {
      isVisibilityLoading.value = false;
      return;
    }
    isVisibilityLoading.value = true;
    try {
      final response = await ApiHelper.fetchDataWithAuthorization(
        'feed/posts/${initialPost.id}?comments_page=1',
      );
      if (response != null &&
          response.statusCode >= 200 &&
          response.statusCode < 300) {
        final payload = jsonDecode(response.body);
        if (payload is Map) {
          final post = payload['post'];
          final raw = post is Map ? post['visibility'] : payload['visibility'];
          final parsed = parseUploadPostVisibility(raw?.toString());
          if (parsed != null && selectedVisibility.value == null) {
            selectedVisibility.value = parsed;
          }
        }
      }
    } catch (_) {
      // Non-fatal: the selector below still lets the user pick a value.
    } finally {
      selectedVisibility.value ??= UploadPostVisibility.public;
      isVisibilityLoading.value = false;
    }
  }

  void setVisibility(UploadPostVisibility visibility) {
    selectedVisibility.value = visibility;
  }

  void setFoodRating(String key, double value) {
    foodRatings[key] = value.clamp(1.0, 5.0);
  }

  Future<void> pickMedia({required bool fromCamera}) async {
    mediaError.value = '';
    final picked = fromCamera
        ? await MediaPickerService.pickFromCamera()
        : await MediaPickerService.pickFromGallery();
    if (picked == null) {
      return;
    }
    final size = await picked.file.length();
    final maxAllowed = picked.type == AppMediaType.video
        ? _maxVideoBytes
        : _maxImageBytes;
    if (size > maxAllowed) {
      mediaError.value = picked.type == AppMediaType.video
          ? 'Video is too large. Keep it under 80MB.'
          : 'Image is too large. Keep it under 12MB.';
      return;
    }
    selectedMedia.value = picked;
  }

  void clearMedia() {
    selectedMedia.value = null;
    mediaError.value = '';
  }

  Future<bool> savePost() async {
    if (isSaving.value) {
      return false;
    }

    saveMessage.value = '';
    saveFailed.value = false;

    var location = locationController.text.trim();
    if (location.toLowerCase() == 'unknown location') {
      locationController.clear();
      location = '';
    }
    if (!isOutfitPost) {
      if (dishNameController.text.trim().isEmpty ||
          restaurantController.text.trim().isEmpty) {
        errorSnackBar(message: 'Dish name and restaurant are required.');
        return false;
      }
    }

    isSaving.value = true;
    try {
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
        'location': location,
      };

      final selectedVisibilityValue = selectedVisibility.value;
      if (selectedVisibilityValue != null) {
        fields['visibility'] = visibilityValue;
      }
      if (_latitude != null && _longitude != null) {
        fields['lat'] = _latitude!.toString();
        fields['lng'] = _longitude!.toString();
      }

      if (isOutfitPost) {
        fields['rating_enabled'] = '0';
      } else {
        fields['dish_name'] = dishNameController.text.trim();
        fields['restaurant'] = restaurantController.text.trim();
        fields['food_rating'] = (foodRatings['food'] ?? 1)
            .round()
            .clamp(1, 5)
            .toString();
        fields['service_rating'] = (foodRatings['service'] ?? 1)
            .round()
            .clamp(1, 5)
            .toString();
        fields['staff_rating'] = (foodRatings['staff'] ?? 1)
            .round()
            .clamp(1, 5)
            .toString();
        fields['ambience_rating'] = (foodRatings['ambience'] ?? 1)
            .round()
            .clamp(1, 5)
            .toString();
      }

      final hasReplacementMedia = selectedMedia.value != null;
      if (hasReplacementMedia) {
        final response = await ApiHelper.multipartRequestWithAuthorization(
          'posts/${initialPost.id}',
          method: 'PATCH',
          fields: fields,
          fileFieldName: 'file',
          filePath: selectedMedia.value!.path,
        );
        if (response == null) {
          throw Exception('No response returned from update endpoint.');
        }
        final materialized = await http.Response.fromStream(response);
        final payload = jsonDecode(materialized.body) as Map<String, dynamic>;
        if (materialized.statusCode < 200 ||
            materialized.statusCode >= 300 ||
            payload['status_code'] != 1) {
          throw Exception(
            (payload['message'] ?? 'Unable to update post').toString(),
          );
        }
      } else {
        final response = await ApiHelper.patchRequestWithAuthorization(
          'posts/${initialPost.id}',
          body: fields,
        );
        if (response == null) {
          throw Exception('No response returned from update endpoint.');
        }
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        if (response.statusCode < 200 ||
            response.statusCode >= 300 ||
            payload['status_code'] != 1) {
          throw Exception(
            (payload['message'] ?? 'Unable to update post').toString(),
          );
        }
      }

      successSnackBar(message: 'Post updated successfully.');
      return true;
    } catch (error) {
      saveFailed.value = true;
      saveMessage.value = error.toString().replaceFirst('Exception: ', '');
      errorSnackBar(message: saveMessage.value);
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  @override
  void onClose() {
    captionController.dispose();
    locationController.dispose();
    dishNameController.dispose();
    restaurantController.dispose();
    super.onClose();
  }
}
