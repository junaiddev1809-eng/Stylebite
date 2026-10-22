import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/utils/api_helper.dart';
import '../../../core/utils/app_helper.dart';
import '../../contest/services/contest_enrollment_store.dart';
import '../../messages/models/chat_models.dart';
import '../../messages/screen/chat_detail_screen.dart';
import '../../messages/services/chat_api_service.dart';
import '../../messages/utils/chat_block_navigation.dart';
import '../../reports/api/reports_api.dart';
import '../../post/services/post_interaction_store.dart';
import '../models/profile_model.dart';
import '../models/style_rating_model.dart';
import '../utils/profile_overview_query.dart';
import '../utils/profile_pagination.dart';
import 'saved_post_sync.dart';

class UserProfileController extends GetxController {
  UserProfileController({
    required this.username,
    this.initialIsFollowing = false,
  }) : _chatApiService = const ChatApiService();

  static const int _pageSize = 10;

  final String username;
  final bool initialIsFollowing;
  final ChatApiService _chatApiService;

  final Rx<ProfileContentTab> activeTab = ProfileContentTab.outfits.obs;
  final ScrollController detailScrollController = ScrollController();
  Worker? _interactionWorker;

  final RxBool isInitialLoading = true.obs;
  final RxBool hasError = false.obs;
  final RxString errorMessage = ''.obs;

  final RxBool isLoadingMoreOutfits = false.obs;
  final RxBool isLoadingMoreFood = false.obs;
  final RxBool isLoadingMoreSaved = false.obs;
  final RxBool isOpeningChat = false.obs;
  final RxBool isChatStatusLoading = false.obs;
  final RxnBool isUserOnline = RxnBool();

  final Rxn<ProfileUserModel> user = Rxn<ProfileUserModel>();
  final Rxn<StyleRatingModel> styleRating = Rxn<StyleRatingModel>();
  final RxList<ProfilePostModel> outfitPosts = <ProfilePostModel>[].obs;
  final RxList<ProfilePostModel> foodPosts = <ProfilePostModel>[].obs;
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

  bool _isFetching = false;
  final Set<ProfileContentTab> _loadedTabs = <ProfileContentTab>{};

  String get displayName {
    final userValue = user.value;
    if (userValue == null) {
      return username;
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
    return username;
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
    if (values.length == 1 || values.first == values.last) {
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
    _interactionWorker = ever(PostInteractionStore.ensure().revision, (_) {
      applySavedChange(savedPosts);
    });
    fetchProfileOverview();
    _fetchChatStatus();
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
    _interactionWorker?.dispose();
    detailScrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.onClose();
  }

  void setTab(ProfileContentTab tab) {
    activeTab.value = tab;
    if (tab == ProfileContentTab.more) {
      return;
    }
    if (_loadedTabs.contains(tab)) {
      // Only fill the next page when the list is already near the bottom
      // (or too short to scroll). Reselecting a tab at the top must not
      // prefetch page 2.
      Future<void>.delayed(const Duration(milliseconds: 60), () {
        if (!_isNearPaginationEdge()) {
          return;
        }
        loadMoreActiveTab();
      });
      return;
    }
    unawaited(ensureTabLoaded(tab));
  }

  Future<void> refreshProfileOverview() =>
      fetchProfileOverview(forceRefresh: true);

  Future<void> fetchProfileOverview({bool forceRefresh = false}) async {
    if (_isFetching && !forceRefresh) {
      return;
    }
    _isFetching = true;
    isInitialLoading.value = true;
    hasError.value = false;
    errorMessage.value = '';
    try {
      final tab = forceRefresh && activeTab.value != ProfileContentTab.more
          ? activeTab.value
          : ProfileContentTab.outfits;
      final observedAt = PostInteractionStore.ensure().observedClock;
      final overview = await _fetchOverviewPage(
        outfitPage: tab == ProfileContentTab.outfits ? 1 : null,
        foodPage: tab == ProfileContentTab.food ? 1 : null,
        savedPage: tab == ProfileContentTab.saved ? 1 : null,
      );
      _applyOverview(
        overview,
        appendTab: tab,
        replaceSection: true,
        savedObservedAt: observedAt,
      );
      _loadedTabs.add(tab);
    } catch (error) {
      hasError.value = true;
      errorMessage.value = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isInitialLoading.value = false;
      _isFetching = false;
    }
  }

  Future<void> openChat() async {
    final userValue = user.value;
    if (userValue == null || userValue.isSelf || isOpeningChat.value) {
      return;
    }

    isOpeningChat.value = true;
    try {
      final initialized = await _chatApiService.initializeChat(
        userValue.username,
      );
      Get.to<void>(
        () => ChatDetailScreen(
          username: userValue.username,
          conversationId: initialized.conversationId,
          initialIsMessagingStopped:
              initialized.isMessagingStopped || initialized.isBlocked,
          initialIsBlockedByMe: initialized.isBlockedByMe,
          initialIsBlockedByOther: initialized.isBlockedByOther,
        ),
      );
    } on ChatApiException catch (error) {
      final blocked = resolveBlockedChatNavigation(
        error,
        username: userValue.username,
      );
      if (blocked != null) {
        Get.to<void>(
          () => ChatDetailScreen(
            username: blocked.username,
            conversationId: blocked.conversationId,
            initialIsMessagingStopped: true,
            initialIsBlockedByMe: blocked.isBlockedByMe,
            initialIsBlockedByOther: blocked.isBlockedByOther,
          ),
        );
        return;
      }
      errorSnackBar(message: error.message);
    } catch (_) {
      errorSnackBar(message: 'Unable to open chat right now.');
    } finally {
      isOpeningChat.value = false;
    }
  }

  Future<void> reportUser(String reasonCode, String? details) async {
    final userValue = user.value;
    if (userValue == null) {
      return;
    }
    try {
      final result = await ReportsApi.submitReport(
        targetType: 'user',
        targetId: userValue.id,
        reason: reasonCode,
        description: details,
      );
      if (result.alreadyReported) {
        infoSnackBar(
          message: 'You already reported this. Our team is reviewing it.',
        );
      } else {
        successSnackBar(message: 'User reported. Thanks for letting us know.');
      }
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
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

  Future<void> _loadMoreForTab(ProfileContentTab tab) async {
    _setLoadingMore(tab, true);
    final observedAt = PostInteractionStore.ensure().observedClock;
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
      _applyOverview(overview, appendTab: tab, savedObservedAt: observedAt);
    } finally {
      _setLoadingMore(tab, false);
    }
  }

  Future<ProfileOverviewModel> _fetchOverviewPage({
    int? outfitPage,
    int? foodPage,
    int? savedPage,
  }) async {
    final params = profileOverviewQuery(
      outfitPage: outfitPage,
      foodPage: foodPage,
      savedPage: savedPage,
      perPage: _pageSize,
    );

    final uri = Uri(
      path: 'profiles/${Uri.encodeComponent(username)}/overview',
      queryParameters: params,
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

  Future<void> ensureTabLoaded(ProfileContentTab tab) async {
    if (tab == ProfileContentTab.more || _loadedTabs.contains(tab)) {
      return;
    }
    if (_isSectionLoading(tab)) {
      return;
    }
    _setLoadingMore(tab, true);
    final observedAt = PostInteractionStore.ensure().observedClock;
    try {
      final overview = await _fetchOverviewPage(
        outfitPage: tab == ProfileContentTab.outfits ? 1 : null,
        foodPage: tab == ProfileContentTab.food ? 1 : null,
        savedPage: tab == ProfileContentTab.saved ? 1 : null,
      );
      _applyOverview(
        overview,
        appendTab: tab,
        replaceSection: true,
        savedObservedAt: observedAt,
      );
      _loadedTabs.add(tab);
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    } finally {
      _setLoadingMore(tab, false);
    }
  }

  bool _isSectionLoading(ProfileContentTab tab) {
    switch (tab) {
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

  void _applyOverview(
    ProfileOverviewModel overview, {
    bool replaceAll = false,
    ProfileContentTab? appendTab,
    bool replaceSection = false,
    int savedObservedAt = 0,
  }) {
    if (replaceAll || appendTab == null || user.value == null) {
      user.value = overview.user;
    }
    final saved = savedPostsForResponse(
      overview.savedPosts,
      observedAt: savedObservedAt,
    );

    if (replaceAll || appendTab == null) {
      outfitPosts.assignAll(overview.outfitPosts);
      foodPosts.assignAll(overview.foodPosts);
      savedPosts.assignAll(saved);
      outfitPagination.value = overview.outfitPagination;
      foodPagination.value = overview.foodPagination;
      savedPagination.value = overview.savedPagination;
      _loadedTabs
        ..clear()
        ..addAll(const [
          ProfileContentTab.outfits,
          ProfileContentTab.food,
          ProfileContentTab.saved,
        ]);
      return;
    }

    user.value = overview.user;

    switch (appendTab) {
      case ProfileContentTab.outfits:
        if (replaceSection) {
          outfitPosts.assignAll(overview.outfitPosts);
        } else {
          outfitPosts.addAll(overview.outfitPosts);
        }
        outfitPagination.value = overview.outfitPagination;
        break;
      case ProfileContentTab.saved:
        if (replaceSection) {
          savedPosts.assignAll(saved);
        } else {
          final existing = savedPosts.map((item) => item.post.id).toSet();
          savedPosts.addAll(
            saved.where((item) => !existing.contains(item.post.id)),
          );
        }
        savedPagination.value = overview.savedPagination;
        break;
      case ProfileContentTab.food:
        if (replaceSection) {
          foodPosts.assignAll(overview.foodPosts);
        } else {
          foodPosts.addAll(overview.foodPosts);
        }
        foodPagination.value = overview.foodPagination;
        break;
      case ProfileContentTab.more:
        break;
    }
  }

  bool _isNearPaginationEdge() {
    if (!detailScrollController.hasClients) {
      return false;
    }
    final positions = detailScrollController.positions;
    if (positions.isEmpty) {
      return false;
    }
    final position = positions.last;
    return isNearProfilePaginationEdge(
      pixels: position.pixels,
      maxScrollExtent: position.maxScrollExtent,
    );
  }

  void _onScroll() {
    if (!_isNearPaginationEdge()) {
      return;
    }
    loadMoreActiveTab();
  }

  Future<void> _fetchChatStatus() async {
    final normalizedUsername = username.trim().replaceFirst('@', '');
    if (normalizedUsername.isEmpty) {
      return;
    }

    isChatStatusLoading.value = true;
    try {
      final response = await _chatApiService.getChats(
        search: normalizedUsername,
        page: 1,
      );

      for (final thread in response.chats) {
        if (thread.user.username.trim().toLowerCase() ==
            normalizedUsername.toLowerCase()) {
          isUserOnline.value = thread.user.isOnline;
          return;
        }
      }
    } catch (_) {
      // Keep UI quiet if the user has no existing chat thread yet.
    } finally {
      isChatStatusLoading.value = false;
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
}
