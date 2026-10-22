import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../../../core/media/media_picker_service.dart';
import '../../../core/media/picked_media.dart';
import '../../../core/utils/api_helper.dart';
import '../../../core/utils/app_helper.dart';
import '../../../core/utils/local_storage.dart';
import '../../contest/services/contest_enrollment_store.dart';
import '../models/profile_model.dart';
import '../models/style_rating_model.dart';

class ProfileController extends GetxController {
  static const int _pageSize = 10;

  final Rx<ProfileContentTab> activeTab = ProfileContentTab.outfits.obs;

  final ScrollController detailScrollController = ScrollController();

  Future<void> scrollToTop() async {
    if (detailScrollController.hasClients &&
        detailScrollController.offset > 0) {
      await detailScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
    await refreshProfileOverview();
  }

  final RxString wallpaperImageUrl = ''.obs;
  final RxString reelsCity = 'Karachi'.obs;
  final RxString avatarImageUrl = (LocalStorage.getAvatarUrl() ?? '').obs;

  final RxBool isInitialLoading = false.obs;
  final RxBool hasError = false.obs;
  final RxString errorMessage = ''.obs;

  final RxBool isLoadingMoreOutfits = false.obs;
  final RxBool isLoadingMoreFood = false.obs;
  final RxBool isLoadingMoreSaved = false.obs;

  final RxBool isUploadingAvatar = false.obs;
  final RxBool isUploadingCover = false.obs;

  final Rxn<ProfileUserModel> user = Rxn<ProfileUserModel>();
  final Rxn<StyleRatingModel> styleRating = Rxn<StyleRatingModel>();
  final RxList<ProfilePostModel> outfitPosts = <ProfilePostModel>[].obs;
  final RxList<ProfilePostModel> foodPosts = <ProfilePostModel>[].obs;
  final Map<int, ProfilePostModel> _localPosts = <int, ProfilePostModel>{};
  final Map<int, ProfilePostModel> _confirmedPosts = <int, ProfilePostModel>{};

  void showLocalPost(ProfilePostModel post) {
    _localPosts[post.id] = post;
    _placeLocalPost(post);
  }

  void replaceLocalPost(int localId, ProfilePostModel serverPost) {
    _localPosts.remove(localId);
    outfitPosts.removeWhere((post) => post.id == localId);
    foodPosts.removeWhere((post) => post.id == localId);
    _confirmedPosts[serverPost.id] = serverPost;
    _placeLocalPost(serverPost);
  }

  void removeLocalPost(int localId) {
    _localPosts.remove(localId);
    outfitPosts.removeWhere((post) => post.id == localId);
    foodPosts.removeWhere((post) => post.id == localId);
  }

  void _placeLocalPost(ProfilePostModel post) {
    final list = post.postType == 'food' ? foodPosts : outfitPosts;
    list.removeWhere((item) => item.id == post.id);
    list.insert(0, post);
  }

  void _restoreLocalPosts() {
    for (final post in _localPosts.values) {
      _placeLocalPost(post);
    }
    final confirmed = _confirmedPosts.values.toList(growable: false);
    for (final post in confirmed) {
      final list = post.postType == 'food' ? foodPosts : outfitPosts;
      if (list.any((item) => item.id == post.id)) {
        _confirmedPosts.remove(post.id);
        continue;
      }
      _placeLocalPost(post);
    }
  }
  final RxList<SavedProfilePostModel> savedPosts =
      <SavedProfilePostModel>[].obs;

  final Rx<ProfilePaginationModel> outfitPagination =
      const ProfilePaginationModel(
        currentPage: 1,
        perPage: _pageSize,
        total: 0,
        lastPage: 1,
        hasMorePages: false,
      ).obs;
  final Rx<ProfilePaginationModel> foodPagination =
      const ProfilePaginationModel(
        currentPage: 1,
        perPage: _pageSize,
        total: 0,
        lastPage: 1,
        hasMorePages: false,
      ).obs;
  final Rx<ProfilePaginationModel> savedPagination =
      const ProfilePaginationModel(
        currentPage: 1,
        perPage: _pageSize,
        total: 0,
        lastPage: 1,
        hasMorePages: false,
      ).obs;

  String get username {
    final userValue = user.value;
    if (userValue != null && userValue.username.trim().isNotEmpty) {
      return userValue.username;
    }
    return LocalStorage.getUsername() ?? 'stylebite_user';
  }

  String get displayName {
    final userValue = user.value;
    if (userValue == null) {
      return LocalStorage.getUsername() ?? 'stylebite_user';
    }
    for (final candidate in <String>[
      userValue.displayName,
      userValue.fullName,
      userValue.username,
    ]) {
      if (candidate.trim().isNotEmpty) {
        return candidate;
      }
    }
    return 'stylebite_user';
  }

  String get profileSummary {
    final userValue = user.value;
    if (userValue == null) {
      return '';
    }
    final values = <String>[
      userValue.headline.trim(),
      userValue.bio.trim(),
    ].where((value) => value.isNotEmpty).toList(growable: false);

    if (values.isEmpty) {
      return '';
    }
    if (values.length == 1) {
      return values.first;
    }
    if (values.first == values.last) {
      return values.first;
    }
    return values.join('  ');
  }

  String get vibeCountLabel => _formatCount(user.value?.followerCount ?? 0);
  String get vibeFlowLabel => _formatCount(user.value?.followingCount ?? 0);

  // `style_points` from the profile endpoint doesn't reflect real reviews
  // (can sit at 0 while community ratings exist), so prefer the actual
  // average rating from ratings-distribution whenever it has data.
  String get stylePointsLabel {
    final rating = styleRating.value;
    if (rating != null && rating.totalRatings > 0) {
      return rating.averageRating.toStringAsFixed(1);
    }
    return _formatCount(user.value?.stylePoints ?? 0);
  }

  bool get hasMoreOutfits => outfitPagination.value.hasMorePages;
  bool get hasMoreFood => foodPagination.value.hasMorePages;
  bool get hasMoreSaved => savedPagination.value.hasMorePages;

  bool get isActiveTabLoadingMore {
    switch (activeTab.value) {
      case ProfileContentTab.outfits:
        return isLoadingMoreOutfits.value;
      case ProfileContentTab.saved:
        return isLoadingMoreSaved.value;
      case ProfileContentTab.food:
        return isLoadingMoreFood.value;
      case ProfileContentTab.more:
        return false;
    }
  }

  bool get activeTabHasMore {
    switch (activeTab.value) {
      case ProfileContentTab.outfits:
        return hasMoreOutfits;
      case ProfileContentTab.saved:
        return hasMoreSaved;
      case ProfileContentTab.food:
        return hasMoreFood;
      case ProfileContentTab.more:
        return false;
    }
  }

  int get activeTabCurrentPage {
    switch (activeTab.value) {
      case ProfileContentTab.outfits:
        return outfitPagination.value.currentPage;
      case ProfileContentTab.saved:
        return savedPagination.value.currentPage;
      case ProfileContentTab.food:
        return foodPagination.value.currentPage;
      case ProfileContentTab.more:
        return 1;
    }
  }

  @override
  void onInit() {
    super.onInit();
    detailScrollController.addListener(_onScroll);
    fetchProfileOverview();
    fetchStyleRating();
  }

  Future<void> fetchStyleRating() async {
    try {
      final response = await ApiHelper.fetchDataWithAuthorization(
        'profiles/$username/ratings-distribution',
      );
      if (response == null) {
        return;
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          payload['status_code'] == 1) {
        styleRating.value = StyleRatingModel.fromJson(
          (payload['data'] as Map<String, dynamic>?) ?? const {},
        );
      }
    } catch (_) {
      // Non-critical — the stat tile just falls back to style_points.
    }
  }

  @override
  void onClose() {
    detailScrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.onClose();
  }

  void setTab(ProfileContentTab tab) {
    activeTab.value = tab;
    Future<void>.delayed(const Duration(milliseconds: 60), loadMoreActiveTab);
  }

  void setWallpaper(String url) {
    wallpaperImageUrl.value = url;
  }

  Future<void> refreshProfileOverview() =>
      fetchProfileOverview(forceRefresh: true);

  Future<void> fetchProfileOverview({bool forceRefresh = false}) async {
    if (isInitialLoading.value && !forceRefresh) {
      return;
    }

    isInitialLoading.value = true;
    hasError.value = false;
    errorMessage.value = '';

    try {
      final overview = await _fetchOverviewPage();
      _applyOverview(overview, replaceAll: true);
    } catch (error) {
      hasError.value = true;
      errorMessage.value = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isInitialLoading.value = false;
    }
  }

  Future<void> loadMoreActiveTab() async {
    if (isInitialLoading.value || !detailScrollController.hasClients) {
      return;
    }

    switch (activeTab.value) {
      case ProfileContentTab.outfits:
        if (isLoadingMoreOutfits.value || !hasMoreOutfits) {
          return;
        }
        await _loadMoreForTab(ProfileContentTab.outfits);
        break;
      case ProfileContentTab.saved:
        if (isLoadingMoreSaved.value || !hasMoreSaved) {
          return;
        }
        await _loadMoreForTab(ProfileContentTab.saved);
        break;
      case ProfileContentTab.food:
        if (isLoadingMoreFood.value || !hasMoreFood) {
          return;
        }
        await _loadMoreForTab(ProfileContentTab.food);
        break;
      case ProfileContentTab.more:
        return;
    }
  }

  Future<void> fetchMyImages({bool silent = false}) async {
    try {
      final overview = await _fetchOverviewPage();
      _applyUser(overview.user);
    } catch (error) {
      if (!silent) {
        errorSnackBar(
          message: error.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  Future<void> pickAndUploadAvatar({required bool fromCamera}) async {
    if (isUploadingAvatar.value) {
      return;
    }

    isUploadingAvatar.value = true;
    try {
      final picked = await MediaPickerService.pickAvatarImage(
        fromCamera: fromCamera,
      );
      if (picked == null) {
        isUploadingAvatar.value = false;
        return;
      }
      await uploadAvatar(picked);
    } catch (e) {
      isUploadingAvatar.value = false;
      errorSnackBar(message: e.toString());
    }
  }

  Future<void> uploadAvatar(PickedMedia media) async {
    isUploadingAvatar.value = true;
    try {
      final extension = media.path.split('.').last.toLowerCase();
      const allowed = <String>{'jpg', 'jpeg', 'png', 'webp'};
      if (!allowed.contains(extension)) {
        throw Exception('Please select a jpg, jpeg, png, or webp image.');
      }

      final size = await media.file.length();
      const maxBytes = 5 * 1024 * 1024;
      if (size > maxBytes) {
        throw Exception('Profile image must be under 5 MB.');
      }

      final response = await ApiHelper.multipartRequestWithAuthorization(
        'profile/me/avatar',
        fields: const <String, String>{},
        fileFieldName: 'image',
        filePath: media.path,
      );
      if (response == null) {
        throw Exception('No response returned from avatar upload.');
      }

      final materialized = await http.Response.fromStream(response);
      final payload = jsonDecode(materialized.body) as Map<String, dynamic>;
      if (materialized.statusCode < 200 ||
          materialized.statusCode >= 300 ||
          (payload.containsKey('status_code') && payload['status_code'] != 1)) {
        throw Exception(
          (payload['message'] ?? 'Unable to upload profile image').toString(),
        );
      }

      final nextAvatar = _pickFirstString(
        payload['avatar_url'],
        (payload['data'] as Map?)?['avatar_url'],
      );
      if (nextAvatar != null) {
        avatarImageUrl.value = nextAvatar;
        LocalStorage.setAvatarUrl(avatarUrl: nextAvatar);
      } else {
        await fetchMyImages();
      }
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    } finally {
      isUploadingAvatar.value = false;
    }
  }

  Future<void> pickAndUploadCover({required bool fromCamera}) async {
    if (isUploadingCover.value) {
      return;
    }

    isUploadingCover.value = true;
    try {
      final picked = await MediaPickerService.pickCoverImage(
        fromCamera: fromCamera,
      );
      if (picked == null) {
        isUploadingCover.value = false;
        return;
      }
      await uploadCover(picked);
    } catch (e) {
      isUploadingCover.value = false;
      errorSnackBar(message: e.toString());
    }
  }

  Future<void> uploadCover(PickedMedia media) async {
    isUploadingCover.value = true;
    try {
      final extension = media.path.split('.').last.toLowerCase();
      const allowed = <String>{'jpg', 'jpeg', 'png', 'webp'};
      if (!allowed.contains(extension)) {
        throw Exception('Please select a jpg, jpeg, png, or webp image.');
      }

      final size = await media.file.length();
      const maxBytes = 5 * 1024 * 1024;
      if (size > maxBytes) {
        throw Exception('Wallpaper image must be under 5 MB.');
      }

      final response = await ApiHelper.multipartRequestWithAuthorization(
        'profile/me/cover',
        fields: const <String, String>{},
        fileFieldName: 'image',
        filePath: media.path,
      );
      if (response == null) {
        throw Exception('No response returned from cover upload.');
      }

      final materialized = await http.Response.fromStream(response);
      final payload = jsonDecode(materialized.body) as Map<String, dynamic>;
      if (materialized.statusCode < 200 ||
          materialized.statusCode >= 300 ||
          (payload.containsKey('status_code') && payload['status_code'] != 1)) {
        throw Exception(
          (payload['message'] ?? 'Unable to upload wallpaper image').toString(),
        );
      }

      final nextCover = _pickFirstString(
        payload['cover_url'],
        (payload['data'] as Map?)?['cover_url'],
      );
      if (nextCover != null) {
        wallpaperImageUrl.value = nextCover;
      } else {
        await fetchMyImages();
      }
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    } finally {
      isUploadingCover.value = false;
    }
  }

  Future<void> _loadMoreForTab(ProfileContentTab tab) async {
    _setLoadingMore(tab, true);
    try {
      final overview = await _fetchOverviewPage(
        outfitPage: tab == ProfileContentTab.outfits
            ? outfitPagination.value.currentPage + 1
            : null,
        foodPage: tab == ProfileContentTab.food
            ? foodPagination.value.currentPage + 1
            : null,
        savedPage: tab == ProfileContentTab.saved
            ? savedPagination.value.currentPage + 1
            : null,
      );
      _applyOverview(overview, appendTab: tab);
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    } finally {
      _setLoadingMore(tab, false);
    }
  }

  Future<ProfileOverviewModel> _fetchOverviewPage({
    int? outfitPage,
    int? foodPage,
    int? savedPage,
  }) async {
    final params = <String, String>{'per_page': '$_pageSize'};
    if (outfitPage != null) {
      params['outfit_page'] = '$outfitPage';
    }
    if (foodPage != null) {
      params['food_page'] = '$foodPage';
    }
    if (savedPage != null) {
      params['saved_page'] = '$savedPage';
    }

    final uri = Uri(
      path: 'profile/me/overview',
      queryParameters: params.isEmpty ? null : params,
    );
    await ContestEnrollmentStore.instance.ensureLoaded();
    final response = await ApiHelper.fetchDataWithAuthorization(uri.toString());
    if (response == null) {
      throw Exception('Unable to fetch profile overview.');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        (payload.containsKey('status_code') && payload['status_code'] != 1)) {
      throw Exception(
        (payload['message'] ?? 'Unable to fetch profile overview').toString(),
      );
    }

    return ProfileOverviewResponseModel.fromMap(payload).overview;
  }

  void _applyOverview(
    ProfileOverviewModel overview, {
    bool replaceAll = false,
    ProfileContentTab? appendTab,
  }) {
    _applyUser(overview.user);

    if (replaceAll || appendTab == null) {
      outfitPosts.assignAll(overview.outfitPosts);
      foodPosts.assignAll(overview.foodPosts);
      savedPosts.assignAll(overview.savedPosts);
      outfitPagination.value = overview.outfitPagination;
      foodPagination.value = overview.foodPagination;
      savedPagination.value = overview.savedPagination;
      _restoreLocalPosts();
      return;
    }

    switch (appendTab) {
      case ProfileContentTab.outfits:
        outfitPosts.addAll(overview.outfitPosts);
        outfitPagination.value = overview.outfitPagination;
        break;
      case ProfileContentTab.saved:
        savedPosts.addAll(overview.savedPosts);
        savedPagination.value = overview.savedPagination;
        break;
      case ProfileContentTab.food:
        foodPosts.addAll(overview.foodPosts);
        foodPagination.value = overview.foodPagination;
        break;
      case ProfileContentTab.more:
        break;
    }
  }

  void _applyUser(ProfileUserModel nextUser) {
    user.value = nextUser;
    LocalStorage.setUsername(username: nextUser.username);

    if (nextUser.avatarUrl.trim().isNotEmpty) {
      avatarImageUrl.value = nextUser.avatarUrl;
      LocalStorage.setAvatarUrl(avatarUrl: nextUser.avatarUrl);
    }
    if (nextUser.coverUrl.trim().isNotEmpty) {
      wallpaperImageUrl.value = nextUser.coverUrl;
    }

    final cityValue = nextUser.city.trim();
    if (cityValue.isNotEmpty) {
      reelsCity.value = cityValue;
    }
  }

  void _onScroll() {
    if (!detailScrollController.hasClients) {
      return;
    }
    final position = detailScrollController.position;
    if (position.pixels >= position.maxScrollExtent - 220) {
      loadMoreActiveTab();
    }
  }

  void _setLoadingMore(ProfileContentTab tab, bool value) {
    switch (tab) {
      case ProfileContentTab.outfits:
        isLoadingMoreOutfits.value = value;
        break;
      case ProfileContentTab.saved:
        isLoadingMoreSaved.value = value;
        break;
      case ProfileContentTab.food:
        isLoadingMoreFood.value = value;
        break;
      case ProfileContentTab.more:
        break;
    }
  }

  String _formatCount(int value) {
    if (value >= 1000000) {
      final formatted = (value / 1000000).toStringAsFixed(
        value % 1000000 == 0 ? 0 : 1,
      );
      return '${formatted.replaceAll('.0', '')}m';
    }
    if (value >= 1000) {
      final formatted = (value / 1000).toStringAsFixed(
        value % 1000 == 0 ? 0 : 1,
      );
      return '${formatted.replaceAll('.0', '')}k';
    }
    return '$value';
  }

  String? _pickFirstString(dynamic first, [dynamic second]) {
    for (final candidate in <dynamic>[first, second]) {
      final value = candidate?.toString().trim();
      if (value != null && value.isNotEmpty && value != 'null') {
        return value;
      }
    }
    return null;
  }
}
