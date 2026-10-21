import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../core/utils/api_helper.dart';
import '../../../core/utils/verified_badge_hydrator.dart';
import '../models/follower_model.dart';
import '../models/profile_model.dart';
import 'profile_controller.dart';
import 'user_profile_controller.dart';

class FollowerSheetController extends GetxController {
  FollowerSheetController({required this.username, required this.isFollowers});

  final String username;
  final bool isFollowers;
  final ScrollController scrollController = ScrollController();

  final RxList<FollowerModel> users = <FollowerModel>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasError = false.obs;
  final RxString errorMessage = ''.obs;

  final RxSet<String> loadingUsernames = <String>{}.obs;

  final Rx<ProfilePaginationModel> pagination = const ProfilePaginationModel(
    currentPage: 0,
    perPage: 20,
    total: 0,
    lastPage: 0,
    hasMorePages: true,
  ).obs;

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_onScroll);
    fetchUsers(reset: true);
  }

  @override
  void onClose() {
    scrollController.dispose();
    super.onClose();
  }

  void _onScroll() {
    if (scrollController.position.pixels >=
        scrollController.position.maxScrollExtent - 200) {
      fetchUsers();
    }
  }

  /// Fetches users from the API.
  /// If [reset] is true, it starts from the first page.
  /// If data already exists in [users], it performs a background refresh 
  /// without clearing the list immediately or showing a full-screen loader.
  Future<void> fetchUsers({bool reset = false}) async {
    if (reset) {
      // Only show main loader if we have no data yet
      if (users.isEmpty) {
        isLoading.value = true;
      }
      hasError.value = false;
      // We do NOT clear users here so that "tb tk jo old data hai wo dikha do" works.
      pagination.value =
          pagination.value.copyWith(currentPage: 0, hasMorePages: true);
    } else {
      if (isLoadingMore.value || !pagination.value.hasMorePages) return;
      isLoadingMore.value = true;
    }

    try {
      final nextPage = pagination.value.currentPage + 1;
      final endpoint = isFollowers
          ? 'profiles/$username/followers?page=$nextPage'
          : 'profiles/$username/following?page=$nextPage';

      final response = await ApiHelper.fetchDataWithAuthorization(endpoint);

      if (response != null && response.statusCode == 200) {
        final payload = jsonDecode(response.body);
        final parsed = FollowerListResponseModel.fromJson(payload);

        if (reset) {
          users.assignAll(parsed.data);
        } else {
          users.addAll(parsed.data);
        }
        pagination.value = parsed.pagination;
        VerifiedBadgeHydrator.hydrate(parsed.data.map((user) => user.username));
      } else {
        throw Exception('Failed to load users');
      }
    } catch (e) {
      if (reset && users.isEmpty) {
        hasError.value = true;
        errorMessage.value = e.toString().replaceFirst('Exception: ', '');
      }
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  Future<void> toggleFollow(FollowerModel user) async {
    final normalized = _normalize(user.username);
    if (normalized.isEmpty || loadingUsernames.contains(normalized)) {
      return;
    }

    final index = users.indexWhere((e) => e.id == user.id);
    if (index == -1) return;

    final originalUser = users[index];
    final currentlyFollowing = originalUser.isFollowing;

    loadingUsernames.add(normalized);
    // Optimistic UI update: Toggle follow state
    users[index] = originalUser.copyWith(isFollowing: !currentlyFollowing);

    try {
      final endpoint = 'profiles/${Uri.encodeComponent(normalized)}/follow';
      final response = currentlyFollowing
          ? await ApiHelper.deleteRequestWithAuthorization(endpoint)
          : await ApiHelper.postRequestWithAuthorization(endpoint);

      if (response == null) {
        throw Exception('No response returned from follow endpoint.');
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          payload['status_code'] != 1) {
        throw Exception(
          (payload['message'] ?? 'Unable to update follow').toString(),
        );
      }

      // After successful unfollow, remove user from list if we're in the "following" tab
      if (!isFollowers && currentlyFollowing) {
        users.removeWhere((e) => e.id == user.id);
      }

      // Refresh counts on the profile screen
      _refreshProfileControllers();
    } catch (e) {
      // Rollback on failure
      final rollbackIndex = users.indexWhere((e) => e.id == user.id);
      if (rollbackIndex != -1) {
        users[rollbackIndex] = originalUser;
      }
    } finally {
      loadingUsernames.remove(normalized);
    }
  }

  String _normalize(String username) => username.trim().replaceFirst('@', '');

  void _refreshProfileControllers() {
    // 1. Refresh main ProfileController (Logged-in user)
    // Their following count (Vibe Flow) always changes when they follow/unfollow someone.
    if (Get.isRegistered<ProfileController>()) {
      Get.find<ProfileController>().fetchProfileOverview(forceRefresh: true);
    }

    // 2. Refresh UserProfileController if we are viewing this specific user's profile
    // If we follow/unfollow the owner of the profile we are currently looking at,
    // or if we are looking at their followers/following list and the count needs updating.
    if (Get.isRegistered<UserProfileController>()) {
      final userProfileCtrl = Get.find<UserProfileController>();
      // Always refresh if it matches the context username
      if (userProfileCtrl.username == username) {
        userProfileCtrl.fetchProfileOverview(forceRefresh: true);
      }
    }
  }
}
