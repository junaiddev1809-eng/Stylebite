import 'dart:math' as math;
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/ranking/trending_ranker.dart';
import '../../../core/media/reel_ready_service.dart';
import '../../../core/media/shared_video_mute.dart';
import '../../../core/utils/api_helper.dart';
import '../../../core/utils/app_helper.dart';
import '../../../core/utils/config.dart';
import '../../../core/utils/ad_service.dart';
import '../../../core/utils/verified_badge_hydrator.dart';
import '../../contest/services/contest_enrollment_store.dart';
import '../../earnings/controllers/earnings_controller.dart';
import '../../home/controllers/home_controller.dart';
import '../../home/models/home_post_model.dart';
import '../../post/models/post_comment_model.dart';
import '../../post/services/post_interaction_store.dart';
import '../../post/utils/rating_math.dart';
import '../../post/utils/post_detail_open_helper.dart';
import '../../profile/models/profile_model.dart';
import '../../story/story_marker.dart';
import '../models/reel_item_model.dart';
import '../utils/reel_open_helper.dart';

class ReelController extends GetxController {
  ReelController({
    this.viewerSeed,
    ReelFeedType? viewerType,
    this.authorScope,
  }) : viewerType = viewerType ?? viewerSeed?.feedType;

  final ReelItemModel? viewerSeed;
  final ReelFeedType? viewerType;
  final ReelAuthorScope? authorScope;

  bool get isAuthorViewer => authorScope != null;
  bool get isViewerMode => viewerSeed != null || isAuthorViewer;

  final Rx<ReelFeedType> selectedFeedType = ReelFeedType.style.obs;
  final RxString selectedCity = ''.obs;
  final RxInt currentIndex = 0.obs;

  final RxInt pagerItemCount = 0.obs;
  final RxBool isInitialLoading = true.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasError = false.obs;
  final RxBool hasMore = true.obs;
  final RxInt biteDetailsTick = 0.obs;
  final RxBool isMuted = false.obs;
  final RxnString pausedReelId = RxnString();
  final RxBool isLikeLoading = false.obs;
  Worker? _interactionWorker;
  final RxBool isSaveLoading = false.obs;
  final RxBool isShareLoading = false.obs;
  final RxBool isVoteLoading = false.obs;
  final RxBool isSubmittingComment = false.obs;
  final RxList<ReelItemModel> visibleReels = <ReelItemModel>[].obs;
  final RxMap<String, List<PostCommentModel>> commentsByReel =
      <String, List<PostCommentModel>>{}.obs;
  final RxMap<String, bool> commentsLoadingByReel = <String, bool>{}.obs;
  final RxMap<String, bool> commentsLoadingMoreByReel = <String, bool>{}.obs;
  final RxMap<String, bool> commentsHasMoreByReel = <String, bool>{}.obs;
  final Map<String, int> _commentsPageByReel = <String, int>{};
  final Queue<String> _recentPlayedVideoUrls = Queue<String>();
  final Completer<void> _firstPageReady = Completer<void>();

  Future<void> get firstPageReady => _firstPageReady.future;

  Future<void> prepareOpeningVideos() async {
    await firstPageReady;
    _warmVisibleVideoAt(0);
  }

  static ReelController ensureTabController() {
    if (Get.isRegistered<ReelController>()) {
      return Get.find<ReelController>();
    }
    return Get.put(ReelController(), permanent: true);
  }

  /// Ad pages currently placed in the feed, ordered by page index.
  final RxList<ReelAdSlot> _adSlots = <ReelAdSlot>[].obs;

  /// Loaded ads waiting to be dropped into a slot.
  final List<NativeAd> _adPool = <NativeAd>[];
  int _adsInFlight = 0;
  int _adFailureStreak = 0;
  Timer? _adRetryTimer;

  /// Interstitial ads loaded for specific reels.
  final Map<String, InterstitialAd> _loadedInterstitials = {};

  /// Reels with an interstitial request currently in progress.
  final Set<String> _interstitialLoadsInFlight = {};

  /// Reels for which an ad has already been shown in this session.
  final Set<String> _shownAdReelIds = {};

  /// Invalidates callbacks from interstitial requests started before a refresh.
  int _interstitialLoadGeneration = 0;

  /// Number of reel pages to show before the next scheduled native ad. This
  /// advances on content boundaries, even if a late ad has to be skipped to
  /// avoid changing pages the user can already reach.
  int _nextNativeAdAfterReelCount = reelsBeforeFirstAd;

  /// Frequency control for interstitial ads.
  /// Minimum number of reels to watch before another interstitial is allowed.
  static const int _interstitialCooldownThreshold = 5;

  /// Number of reels watched since the last shown interstitial.
  int _reelsWatchedSinceLastInterstitial = _interstitialCooldownThreshold;

  /// Tracks the last reel index processed to avoid double counting.
  int _lastProcessedReelIndex = -1;

  /// Watch time tracking buffer. Maps reelId -> watch seconds.
  final Map<String, int> _watchTimeBuffer = {};
  Timer? _watchTimeTicker;
  Timer? _watchBatchTimer;
  final RxBool isFeedVisible = false.obs;
  static const int _viewCreditSeconds = 3;
  final RxMap<String, int> sessionViewCredits = <String, int>{}.obs;

  final TextEditingController citySearchController = TextEditingController();
  final PageController pageController = PageController();

  final Map<ReelFeedType, _ReelSessionState> _sessions =
      <ReelFeedType, _ReelSessionState>{};

  final List<String> allCities = const [
    'Karachi',
    'Lahore',
    'Islamabad',
    'Rawalpindi',
    'Peshawar',
    'Quetta',
    'New York',
    'Tokyo',
    'Dubai',
    'London',
    'Istanbul',
    'Bangkok',
    'Doha',
    'Riyadh',
    'Toronto',
    'Sydney',
  ];

  final Map<ReelFeedType, List<String>> suggestedByFeed = const {
    ReelFeedType.style: ['Karachi', 'Tokyo', 'New York', 'London', 'Dubai'],
    ReelFeedType.bite: ['Karachi', 'Lahore', 'Istanbul', 'Bangkok', 'Dubai'],
  };

  @override
  void onInit() {
    super.onInit();
    if (isMuted.value != SharedVideoMute.muted.value) {
      isMuted.value = SharedVideoMute.muted.value;
    }
    _ensureEligibilityFetched();
    _interactionWorker = ever(PostInteractionStore.ensure().revision, (_) {
      final id = PostInteractionStore.ensure().lastChangedId;
      if (id != null) {
        _applySharedInteraction(id);
      }
    });
    if (viewerSeed != null) {
      selectedFeedType.value = viewerType ?? viewerSeed!.feedType;
      unawaited(_startFromSeed(viewerSeed!));
    } else {
      unawaited(refreshReels());
    }
  }

  @override
  void onClose() {
    _interactionWorker?.dispose();
    _stopWatchTimeTracking();
    _adRetryTimer?.cancel();
    _clearInterstitialState();
    for (final slot in _adSlots) {
      slot.ad.dispose();
    }
    _adSlots.clear();
    for (final ad in _adPool) {
      ad.dispose();
    }
    _adPool.clear();
    citySearchController.dispose();
    pageController.dispose();
    super.onClose();
  }

  // ---------------------------------------------------------------------------
  // Watch Time Reporting
  // ---------------------------------------------------------------------------

  void _startWatchTimeTracking() {
    if (!isFeedVisible.value) {
      return;
    }
    _watchTimeTicker?.cancel();
    _watchTimeTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      final reelIndex = mapToReelIndex(currentIndex.value);
      if (reelIndex != -1 && reelIndex < visibleReels.length) {
        final reel = visibleReels[reelIndex];
        // Only increment if the reel is not paused
        if (pausedReelId.value != reel.id) {
          final seconds = (_watchTimeBuffer[reel.id] ?? 0) + 1;
          _watchTimeBuffer[reel.id] = seconds;
          if (seconds >= _viewCreditSeconds) {
            _creditReelView(reel.id);
          }
        }
      }
    });

    _watchBatchTimer?.cancel();
    _watchBatchTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _reportWatchTimeBatch();
    });
  }

  void _stopWatchTimeTracking() {
    _watchTimeTicker?.cancel();
    _watchBatchTimer?.cancel();
    // Flush remaining watch time before closing
    _reportWatchTimeBatch();
  }

  /// Starts watch-time accounting only while the reels screen is visible.
  /// Leaving the screen stops its timers and flushes the time already earned.
  void setFeedVisible(bool visible) {
    if (isFeedVisible.value == visible) {
      return;
    }

    isFeedVisible.value = visible;
    if (visible) {
      _startWatchTimeTracking();
      if (!isViewerMode) {
        _loadNativeAds();
      }
    } else {
      _stopWatchTimeTracking();
    }
  }

  Future<void> _reportWatchTimeBatch() async {
    if (_watchTimeBuffer.isEmpty) return;

    final List<Map<String, dynamic>> views = [];
    _watchTimeBuffer.forEach((reelId, seconds) {
      if (seconds > 0) {
        if (seconds >= _viewCreditSeconds) {
          _creditReelView(reelId);
        }
        views.add({
          // Ensure post_id is an integer for backend validation
          'post_id': int.tryParse(reelId) ?? 0,
          'watch_seconds': seconds,
          'view_source': 'reel',
        });
      }
    });

    if (views.isEmpty) return;

    // Clear buffer immediately before making the request
    _watchTimeBuffer.clear();

    try {
      await ApiHelper.postRequestWithAuthorization(
        'views/batch',
        body: {'views': views},
      );
    } catch (e) {
      debugPrint('Failed to report watch time batch: $e');
    }
  }

  void _creditReelView(String reelId) {
    if (reelId.isEmpty || sessionViewCredits.containsKey(reelId)) {
      return;
    }
    sessionViewCredits[reelId] = 1;
  }

  String viewLabelFor(String reelId) {
    final reel = _findReel(reelId);
    final count = (reel?.viewCount ?? 0) + (sessionViewCredits[reelId] ?? 0);
    return _formatCount(count);
  }

  List<String> get suggestedCities =>
      suggestedByFeed[selectedFeedType.value] ?? const [];

  ReelItemModel? get currentReelOrNull {
    final list = visibleReels;
    if (list.isEmpty) {
      return null;
    }

    // On an ad page there is no "current reel", so fall back to the reel the
    // user is about to land on — otherwise the city chip blanks out mid-ad.
    final pageIndex = currentIndex.value;
    var reelIndex = mapToReelIndex(pageIndex);
    if (reelIndex == -1) {
      reelIndex = mapToReelIndex(pageIndex + 1);
    }
    if (reelIndex == -1) return null;

    final safeIndex = reelIndex.clamp(0, list.length - 1);
    return list[safeIndex];
  }

  // ---------------------------------------------------------------------------
  // In-feed native ads
  // ---------------------------------------------------------------------------

  int get totalItemsCount =>
      isViewerMode ? visibleReels.length : visibleReels.length + _adSlots.length;

  void _publishPagerCount() {
    final count = totalItemsCount;
    if (pagerItemCount.value != count) {
      pagerItemCount.value = count;
    }
  }

  /// The ad occupying [pageIndex], or null when that page holds a reel.
  NativeAd? nativeAdAt(int pageIndex) {
    if (isViewerMode) {
      return null;
    }
    for (final slot in _adSlots) {
      if (slot.pageIndex == pageIndex) {
        return slot.ad;
      }
    }
    return null;
  }

  /// Maps a PageView index to an index in [visibleReels], or -1 for an ad page.
  int mapToReelIndex(int pageIndex) {
    if (isViewerMode) {
      return pageIndex;
    }
    var adsBefore = 0;
    for (final slot in _adSlots) {
      if (slot.pageIndex == pageIndex) {
        return -1;
      }
      if (slot.pageIndex < pageIndex) {
        adsBefore++;
      }
    }
    return pageIndex - adsBefore;
  }

  void _syncAdSlots() {
    if (isClosed || isViewerMode) {
      return;
    }

    while (true) {
      // Keep ad frequency anchored to reel counts rather than moving an
      // overdue slot to an arbitrary page. Existing slots before the boundary
      // still occupy a PageView page, so they are included in the target.
      var targetPage = _nextNativeAdAfterReelCount + _adSlots.length;
      final earliestPage = currentIndex.value + 2;
      if (targetPage < earliestPage) {
        // This slot is too close to insert safely. Skip this scheduled
        // boundary and preserve the configured cadence for the next one.
        _nextNativeAdAfterReelCount += reelsBetweenAds;
        continue;
      }

      final reelsRequired = targetPage - _adSlots.length;
      if (visibleReels.length <= reelsRequired) {
        return;
      }

      if (_adPool.isEmpty) {
        _loadNativeAds();
        return;
      }

      final ad = _adPool.removeAt(0);

      // Attribution: Tie this native ad to the previous reel's post ID for creator earnings split.
      final reelIndexBefore = mapToReelIndex(targetPage - 1);
      String attributedPostId = "0";
      if (reelIndexBefore != -1 && reelIndexBefore < visibleReels.length) {
        attributedPostId = visibleReels[reelIndexBefore].id;
      }

      _adSlots.add(
        ReelAdSlot(
          pageIndex: targetPage,
          ad: ad,
          attributedPostId: attributedPostId,
        ),
      );
      _nextNativeAdAfterReelCount += reelsBetweenAds;
      _publishPagerCount();
      _loadNativeAds();
    }
  }

  void _resetAdSlots() {
    _nextNativeAdAfterReelCount = reelsBeforeFirstAd;
    if (_adSlots.isEmpty) {
      return;
    }

    final retired = _adSlots.map((slot) => slot.ad).toList();
    _adSlots.clear();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final ad in retired) {
        ad.dispose();
      }
    });
  }

  void _loadNativeAds() {
    if (adsPaused || isClosed || (_adRetryTimer?.isActive ?? false)) {
      return;
    }

    final missing = reelNativeAdPoolSize - _adPool.length - _adsInFlight;
    for (var i = 0; i < missing; i++) {
      _loadNativeAd();
    }
  }

  void _loadNativeAd() {
    _adsInFlight++;
    NativeAd(
      adUnitId: Platform.isIOS
          ? iosReelNativeAdUnitId
          : androidReelNativeAdUnitId,
      factoryId: reelNativeAdFactoryId,
      request: const AdRequest(),
      nativeAdOptions: NativeAdOptions(
        mediaAspectRatio: MediaAspectRatio.portrait,
        adChoicesPlacement: AdChoicesPlacement.topRightCorner,
        videoOptions: VideoOptions(
          startMuted: true,
          clickToExpandRequested: true,
        ),
      ),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          _adsInFlight--;
          if (isClosed) {
            ad.dispose();
            return;
          }
          _adFailureStreak = 0;
          _adPool.add(ad as NativeAd);
          _syncAdSlots();
        },
        onAdFailedToLoad: (ad, error) {
          _adsInFlight--;
          ad.dispose();
          debugPrint('Reel native ad failed to load: $error');
          if (isClosed) {
            return;
          }
          _adFailureStreak++;
          _adRetryTimer?.cancel();
          _adRetryTimer = Timer(
            Duration(seconds: math.min(60, 5 * _adFailureStreak)),
            () {
              if (!isClosed) {
                _loadNativeAds();
              }
            },
          );
        },
        onPaidEvent: (ad, valueMicros, precision, currencyCode) {
          _handleNativeAdPaidEvent(
            ad as NativeAd,
            valueMicros,
            precision,
            currencyCode,
          );
        },
      ),
    ).load();
  }

  void _handleNativeAdPaidEvent(
    NativeAd ad,
    double valueMicros,
    PrecisionType precision,
    String currencyCode,
  ) {
    // Find the slot this ad belongs to to get its attributed post ID
    String attributedPostId = "0";
    for (final slot in _adSlots) {
      if (slot.ad == ad) {
        attributedPostId = slot.attributedPostId;
        break;
      }
    }

    AppAdService().reportImpression(
      postId: attributedPostId,
      adType: 'scroll',
      revenue: valueMicros / 1000000.0,
      currency: currencyCode,
      adUnitId: ad.adUnitId,
    );
  }

  // ---------------------------------------------------------------------------
  // Interstitial Ads (Backend-driven with Cooldown)
  // ---------------------------------------------------------------------------

  void _preLoadInterstitialForReel(ReelItemModel reel) {
    if (adsPaused) {
      return;
    }

    // Only preload if the backend flags it and cooldown is met
    if (_reelsWatchedSinceLastInterstitial <
        (_interstitialCooldownThreshold - 1)) {
      return;
    }

    if (!reel.showAd ||
        _loadedInterstitials.containsKey(reel.id) ||
        _interstitialLoadsInFlight.contains(reel.id) ||
        _shownAdReelIds.contains(reel.id)) {
      return;
    }

    final loadGeneration = _interstitialLoadGeneration;
    _interstitialLoadsInFlight.add(reel.id);
    AppAdService().loadInterstitialAd(
      postId: reel.id,
      adType: 'mid_reel',
      onAdLoaded: (ad) {
        _interstitialLoadsInFlight.remove(reel.id);
        if (isClosed ||
            loadGeneration != _interstitialLoadGeneration ||
            _shownAdReelIds.contains(reel.id)) {
          ad.dispose();
          return;
        }
        _loadedInterstitials[reel.id] = ad;
      },
      onAdFailedToLoad: (_) {
        if (loadGeneration == _interstitialLoadGeneration) {
          _interstitialLoadsInFlight.remove(reel.id);
        }
      },
    );
  }

  void handleVideoProgress(String reelId, double progress) {
    if (progress >= 0.8) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _creditReelView(reelId);
      });
    }

    final reel = _findReel(reelId);

    // Check backend flag, cooldown, and ensure not shown already
    if (reel == null ||
        !reel.showAd ||
        _shownAdReelIds.contains(reelId) ||
        _reelsWatchedSinceLastInterstitial < _interstitialCooldownThreshold) {
      return;
    }

    // Determine trigger ratio: API global config > reel specific > default 0.4
    double triggerRatio = reel.adTriggerRatio > 0 ? reel.adTriggerRatio : 0.4;
    
    try {
      if (Get.isRegistered<EarningsController>()) {
        final config = Get.find<EarningsController>().eligibility.value?.config;
        if (config != null && config.midReelTriggerPercent > 0) {
          triggerRatio = config.midReelTriggerPercent / 100.0;
        }
      }
    } catch (_) {}

    if (progress >= triggerRatio) {
      final ad = _loadedInterstitials.remove(reelId);
      if (ad != null) {
        _shownAdReelIds.add(reelId);
        _reelsWatchedSinceLastInterstitial = 0; // Reset frequency counter
        // Deferred: this fires from the video player's progress-update
        // listener, which can land mid-frame. Setting an .obs read by the
        // Obx wrapping the video widget synchronously here would trigger a
        // rebuild while Flutter is still building that widget, throwing
        // "setState() or markNeedsBuild() called during build".
        WidgetsBinding.instance.addPostFrameCallback((_) {
          pausedReelId.value = reelId; // Pause background playback
        });

        ad.fullScreenContentCallback = FullScreenContentCallback(
          onAdDismissedFullScreenContent: (ad) {
            ad.dispose();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              pausedReelId.value = null; // Auto-resume
            });
          },
          onAdFailedToShowFullScreenContent: (ad, error) {
            ad.dispose();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              pausedReelId.value = null; // Resume on error
            });
          },
        );
        ad.show();
      }
    }
  }

  List<String> filteredCities(String query) {
    final key = query.trim().toLowerCase();
    if (key.isEmpty) {
      return allCities;
    }

    return allCities.where((city) => city.toLowerCase().contains(key)).toList();
  }

  /// Jumps to the first reel and reloads that Style/Bite reel feed.
  /// Used when the user taps the Reels tab they are already on.
  Future<void> scrollToTop() async {
    if (isInitialLoading.value) {
      return;
    }
    currentIndex.value = 0;
    pausedReelId.value = null;
    if (pageController.hasClients) {
      pageController.jumpToPage(0);
    }
    await refreshReels();
  }

  Future<void> refreshReels() async {
    hasError.value = false;
    isInitialLoading.value = true;

    final session = _session;
    session.reels.clear();
    session.currentPage = 0;
    session.hasMore = true;
    pausedReelId.value = null;
    _resetAdSlots();
    _clearInterstitialState();

    try {
      await _fetchPage(page: 1, replaceExisting: true);
      _jumpToFirstPage();
      _warmVisibleVideoAt(0);
      _preLoadNextInterstitials(0);
    } catch (error) {
      hasError.value = true;
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    } finally {
      isInitialLoading.value = false;
      _markFirstPageReady();
    }
  }

  void _clearInterstitialState() {
    _interstitialLoadGeneration++;
    for (final ad in _loadedInterstitials.values) {
      ad.dispose();
    }
    _loadedInterstitials.clear();
    _interstitialLoadsInFlight.clear();
    _shownAdReelIds.clear();
    _reelsWatchedSinceLastInterstitial = _interstitialCooldownThreshold;
    _lastProcessedReelIndex = -1;
  }

  Future<void> loadMore() async {
    if (isLoadingMore.value || !hasMore.value || hasError.value) {
      return;
    }

    isLoadingMore.value = true;
    try {
      await _fetchPage(page: _session.currentPage + 1);
    } catch (error) {
      hasError.value = true;
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    } finally {
      isLoadingMore.value = false;
    }
  }

  void setFeedType(ReelFeedType type) {
    if (selectedFeedType.value == type) {
      return;
    }

    selectedFeedType.value = type;
    currentIndex.value = 0;
    pausedReelId.value = null;
    hasError.value = false;
    _resetAdSlots();
    _clearInterstitialState();

    final session = _session;
    if (session.reels.isNotEmpty) {
      _applyVisibleReels();
      _jumpToFirstPage();
      _warmVisibleVideoAt(0);
      _preLoadNextInterstitials(0);
      return;
    }

    refreshReels();
  }

  void onReelChanged(int index) {
    _reportWatchTimeBatch();
    currentIndex.value = index;
    pausedReelId.value = null;

    final mapped = mapToReelIndex(index);
    final reelIndex = mapped == -1 ? mapToReelIndex(index + 1) : mapped;

    if (reelIndex != -1) {
      // Frequency control: Increment counter when user switches to a new unique reel.
      if (reelIndex != _lastProcessedReelIndex) {
        _reelsWatchedSinceLastInterstitial++;
        _lastProcessedReelIndex = reelIndex;
      }

      _warmVisibleVideoAt(reelIndex);
      _preLoadNextInterstitials(reelIndex);
      _hydrateBiteDetails();

      if (reelIndex >= visibleReels.length - 2) {
        loadMore();
      }
    }

    _syncAdSlots();
  }

  void _preLoadNextInterstitials(int currentIndex) {
    _ensureEligibilityFetched();
    // Preload current and next reel's interstitials if needed
    for (var i = currentIndex; i < currentIndex + 2; i++) {
      if (i >= 0 && i < visibleReels.length) {
        _preLoadInterstitialForReel(visibleReels[i]);
      }
    }
  }

  void _ensureEligibilityFetched() {
    try {
      if (Get.isRegistered<EarningsController>()) {
        final ec = Get.find<EarningsController>();
        if (ec.eligibility.value == null && !ec.isEligibilityLoading.value) {
          ec.fetchEligibility();
        }
      }
    } catch (_) {}
  }

  void setCity(String city) {
    selectedCity.value = city;
    currentIndex.value = 0;
    pausedReelId.value = null;
    _resetAdSlots();
    _clearInterstitialState();
    _applyVisibleReels();
    _jumpToFirstPage();
    _warmVisibleVideoAt(0);
    _preLoadNextInterstitials(0);
  }

  void setMuted(bool value) {
    isMuted.value = value;
    SharedVideoMute.setMuted(value);
  }

  void setCurrentVideoPaused(String reelId, bool value) {
    pausedReelId.value = value ? reelId : null;
  }

  bool isReelPaused(String reelId) => pausedReelId.value == reelId;

  List<PostCommentModel> commentsForReel(String reelId) =>
      commentsByReel[reelId] ?? const <PostCommentModel>[];

  bool isCommentsLoading(String reelId) =>
      commentsLoadingByReel[reelId] ?? false;

  bool isCommentsLoadingMore(String reelId) =>
      commentsLoadingMoreByReel[reelId] ?? false;

  bool hasMoreComments(String reelId) => commentsHasMoreByReel[reelId] ?? false;

  Future<void> toggleLike(String reelId) async {
    final currentReel = _findReel(reelId);
    if (currentReel == null) {
      return;
    }
    final shared = PostInteractionStore.ensure().stateFor(reelId);
    PostInteractionStore.ensure().toggleLike(
      postId: reelId,
      isLiked: shared?.isLiked ?? currentReel.isLiked,
      likeCount: shared?.likeCount ?? currentReel.likeCount,
      isSaved: currentReel.isSaved,
      saveCount: currentReel.saveCount,
    );
  }

  void toggleSave(String reelId) {
    final currentReel = _findReel(reelId);
    if (currentReel == null) {
      return;
    }
    final shared = PostInteractionStore.ensure().stateFor(reelId);
    PostInteractionStore.ensure().toggleSave(
      postId: reelId,
      isSaved: shared?.isSaved ?? currentReel.isSaved,
      saveCount: shared?.saveCount ?? currentReel.saveCount,
      isLiked: currentReel.isLiked,
      likeCount: currentReel.likeCount,
      draft: SavedPostDraft.fromReel(currentReel),
    );
  }

  void _applySharedInteraction(String postId) {
    final current = _findReel(postId);
    if (current == null) {
      return;
    }
    _updateReel(PostInteractionStore.ensure().presentReel(current));
  }

  Future<void> registerShare(
    String reelId, {
    required String shareChannel,
    int? targetUserId,
  }) async {
    await _runReelAction(
      loadingFlag: isShareLoading,
      endpoint: 'reels/$reelId/share',
      body: <String, dynamic>{
        'share_channel': shareChannel,
        'target_user_id': targetUserId,
      },
      onSuccess: () {
        final reel = _findReel(reelId);
        if (reel == null) {
          return;
        }
        _updateReel(reel.copyWith(shareCount: reel.shareCount + 1));
      },
    );
  }

  Future<void> voteReel(String reelId, int rating) async {
    if (isVoteLoading.value) {
      return;
    }

    final currentReel = _findReel(reelId);
    if (currentReel == null) {
      return;
    }

    final previousReel = currentReel;
    final previousScore = double.tryParse(currentReel.rating) ?? 0;
    final nextAverage = nextRatingAverage(
      average: previousScore,
      count: currentReel.ratingCount,
      previous: currentReel.viewerRating ?? 0,
      next: rating,
    );
    final hadPrevious =
        (currentReel.viewerRating ?? 0) >= 1 &&
        (currentReel.viewerRating ?? 0) <= 5;
    _updateReel(
      currentReel.copyWith(
        viewerRating: rating,
        rating: nextAverage.toStringAsFixed(1),
        ratingCount: hadPrevious
            ? currentReel.ratingCount
            : currentReel.ratingCount + 1,
      ),
    );

    isVoteLoading.value = true;
    try {
      final response = await ApiHelper.postRequestWithAuthorization(
        'reels/$reelId/vote',
        body: <String, dynamic>{'rating_value': rating},
      );
      await _ensureSuccess(response, fallback: 'Unable to update reel');
      final payload = jsonDecode(response!.body) as Map<String, dynamic>;
      final serverAverage = payload['rating_avg'];
      final serverCount = payload['rating_count'];
      final latest = _findReel(reelId) ?? currentReel;
      _updateReel(
        latest.copyWith(
          viewerRating: rating,
          rating: serverAverage == null
              ? latest.rating
              : (serverAverage is num
                    ? serverAverage.toDouble()
                    : double.tryParse(serverAverage.toString()) ?? nextAverage)
                  .toStringAsFixed(1),
          ratingCount: serverCount is num
              ? serverCount.round()
              : int.tryParse('${serverCount ?? ''}') ?? latest.ratingCount,
        ),
      );
    } catch (error) {
      _updateReel(previousReel);
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    } finally {
      isVoteLoading.value = false;
    }
  }

  Future<void> submitComment(String reelId, String text) async {
    if (isSubmittingComment.value) {
      return;
    }

    isSubmittingComment.value = true;
    try {
      final response = await ApiHelper.postRequestWithAuthorization(
        'reels/$reelId/comments',
        body: <String, dynamic>{'body': text},
      );
      await _ensureSuccess(response, fallback: 'Unable to add comment');
      final localComment = PostCommentModel.localFromViewer(text: text);
      commentsByReel[reelId] = <PostCommentModel>[
        localComment,
        ...commentsForReel(reelId),
      ];
      commentsByReel.refresh();

      final reel = _findReel(reelId);
      if (reel != null) {
        final nextCount = reel.commentCount + 1;
        _updateReel(
          reel.copyWith(
            commentCount: nextCount,
            comments: _formatCount(nextCount),
          ),
        );
      }
      await refreshCommentsSilently(reelId);
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    } finally {
      isSubmittingComment.value = false;
    }
  }

  Future<void> deleteComment(String reelId, String commentId) async {
    final previousComments = List<PostCommentModel>.from(
      commentsForReel(reelId),
    );
    final previousReel = _findReel(reelId);

    var removedCount = 0;
    final remaining = <PostCommentModel>[];
    for (final comment in previousComments) {
      if (comment.id == commentId) {
        removedCount += 1 + comment.replies.length;
        continue;
      }
      remaining.add(comment);
    }
    if (removedCount <= 0) {
      return;
    }

    commentsByReel[reelId] = remaining;
    commentsByReel.refresh();
    if (previousReel != null) {
      final nextCount = (previousReel.commentCount - removedCount)
          .clamp(0, previousReel.commentCount)
          .toInt();
      _updateReel(
        previousReel.copyWith(
          commentCount: nextCount,
          comments: _formatCount(nextCount),
        ),
      );
    }

    try {
      if (!commentId.startsWith('local-')) {
        Exception? lastError;
        for (final endpoint in <String>[
          'reels/$reelId/comments/$commentId',
          'feed/comments/$commentId',
        ]) {
          final response = await ApiHelper.deleteRequestWithAuthorization(
            endpoint,
          );
          if (response == null) {
            lastError = Exception('No response returned from server.');
            continue;
          }
          try {
            await _ensureSuccess(response, fallback: 'Unable to delete comment');
            lastError = null;
            break;
          } catch (error) {
            lastError = error is Exception
                ? error
                : Exception(error.toString());
            if (response.statusCode != 404) {
              throw lastError;
            }
          }
        }
        if (lastError != null) {
          throw lastError;
        }
      }
      successSnackBar(message: 'Comment deleted.');
    } catch (error) {
      commentsByReel[reelId] = previousComments;
      commentsByReel.refresh();
      if (previousReel != null) {
        _updateReel(previousReel);
      }
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> fetchCommentsForReel(String reelId, {bool reset = false}) async {
    if (reset) {
      commentsLoadingByReel[reelId] = true;
      commentsHasMoreByReel[reelId] = true;
      _commentsPageByReel[reelId] = 0;
    } else {
      if (isCommentsLoadingMore(reelId) || !hasMoreComments(reelId)) {
        return;
      }
      commentsLoadingMoreByReel[reelId] = true;
    }
    commentsLoadingByReel.refresh();
    commentsLoadingMoreByReel.refresh();
    commentsHasMoreByReel.refresh();

    try {
      final page = reset ? 1 : (_commentsPageByReel[reelId] ?? 0) + 1;
      final response = await ApiHelper.fetchDataWithAuthorization(
        'reels/$reelId/comments?page=$page',
      );
      if (response == null) {
        throw Exception('No response returned from reel comments endpoint.');
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || payload['status_code'] != 1) {
        throw Exception(
          (payload['message'] ?? 'Failed to load reel comments').toString(),
        );
      }

      final fetchedComments =
          (payload['comments'] as List<dynamic>? ?? const [])
              .map(
                (item) =>
                    PostCommentModel.fromJson(item as Map<String, dynamic>),
              )
              .toList();
      final pagination = PostCommentsPagination.fromJson(
        payload['pagination'] as Map<String, dynamic>? ?? const {},
      );

      commentsByReel[reelId] = reset
          ? fetchedComments
          : <PostCommentModel>[
              ...commentsForReel(reelId),
              ...fetchedComments.where(
                (incoming) => commentsForReel(
                  reelId,
                ).every((existing) => existing.id != incoming.id),
              ),
            ];
      commentsByReel.refresh();
      _commentsPageByReel[reelId] = pagination.currentPage;
      commentsHasMoreByReel[reelId] = pagination.hasMorePages;
      commentsHasMoreByReel.refresh();
      VerifiedBadgeHydrator.hydrate(_reelCommentUsernames(fetchedComments));
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    } finally {
      commentsLoadingByReel[reelId] = false;
      commentsLoadingMoreByReel[reelId] = false;
      commentsLoadingByReel.refresh();
      commentsLoadingMoreByReel.refresh();
    }
  }

  Future<void> refreshCommentsSilently(String reelId) async {
    try {
      final response = await ApiHelper.fetchDataWithAuthorization(
        'reels/$reelId/comments?page=1',
      );
      if (response == null) {
        return;
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || payload['status_code'] != 1) {
        return;
      }
      final fetchedComments =
          (payload['comments'] as List<dynamic>? ?? const [])
              .map(
                (item) =>
                    PostCommentModel.fromJson(item as Map<String, dynamic>),
              )
              .toList();
      final pagination = PostCommentsPagination.fromJson(
        payload['pagination'] as Map<String, dynamic>? ?? const {},
      );
      commentsByReel[reelId] = fetchedComments;
      commentsByReel.refresh();
      _commentsPageByReel[reelId] = pagination.currentPage;
      commentsHasMoreByReel[reelId] = pagination.hasMorePages;
      commentsHasMoreByReel.refresh();
      VerifiedBadgeHydrator.hydrate(_reelCommentUsernames(fetchedComments));
    } catch (_) {}
  }

  Future<void> _fetchPage({
    required int page,
    bool replaceExisting = false,
  }) async {
    if (isAuthorViewer) {
      await _fetchAuthorPage(page: page, replaceExisting: replaceExisting);
      return;
    }

    unawaited(ContestEnrollmentStore.instance.ensureLoaded());
    final observedAt = PostInteractionStore.ensure().observedClock;
    final response = await ApiHelper.fetchDataWithAuthorization(
      _buildEndpoint(page),
    );

    if (response == null) {
      throw Exception('No response returned from reels endpoint.');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || payload['status_code'] != 1) {
      throw Exception(
        (payload['message'] ?? 'Failed to load reels').toString(),
      );
    }

    final parsed = ReelResponse.fromJson(payload);
    final tabType = selectedFeedType.value;
    final incomingRaw = replaceExisting
        ? TrendingRanker.shuffleTrendingStart(parsed.reels)
        : parsed.reels;
    final incoming = incomingRaw
        .map(
          (reel) => reel.feedType == tabType
              ? reel
              : reel.copyWith(feedType: tabType),
        )
        .map((reel) => PostInteractionStore.ensure().ingestReel(
              reel,
              observedAt: observedAt,
            ))
        .toList();

    final session = _session;
    final merged = replaceExisting
        ? incoming
        : _mergeReels(session.reels, incoming);

    session.reels
      ..clear()
      ..addAll(merged);
    session.currentPage = parsed.pagination.currentPage;
    session.hasMore = parsed.pagination.hasMorePages;

    _applyVisibleReels();
  }

  void _applyVisibleReels() {
    final store = PostInteractionStore.ensure();
    final filtered = _session.reels
        .where((item) => item.matchesCity(selectedCity.value))
        .where(
          (item) => !StoryMarker.isStory(tags: item.tags, caption: item.caption),
        )
        .map(store.presentReel)
        .toList();
    visibleReels.assignAll(filtered);
    hasMore.value = _session.hasMore;

    if (visibleReels.isEmpty) {
      currentIndex.value = 0;
      _resetAdSlots();
      _clearInterstitialState();
      pagerItemCount.value = 0;
      return;
    }

    currentIndex.value = currentIndex.value.clamp(0, totalItemsCount - 1);
    _syncAdSlots();
    _publishPagerCount();

    final reelIndex = mapToReelIndex(currentIndex.value);
    if (reelIndex != -1) {
      _warmVisibleVideoAt(reelIndex);
      _preLoadNextInterstitials(reelIndex);
    }
    _hydrateBiteDetails();
  }

  List<ReelItemModel> cachedReelsFor(ReelFeedType type) {
    final seen = <String>{};
    final reels = <ReelItemModel>[];
    void take(ReelItemModel reel) {
      final id = reel.id.trim();
      if (id.isEmpty || !seen.add(id)) {
        return;
      }
      if (type == ReelFeedType.bite) {
        if (reel.feedType != ReelFeedType.bite) {
          return;
        }
      } else if (reel.feedType == ReelFeedType.bite) {
        return;
      }
      reels.add(reel);
    }

    if (selectedFeedType.value == type) {
      for (final reel in visibleReels) {
        take(reel);
      }
    }
    final session = _sessions[type];
    if (session != null) {
      for (final reel in session.reels) {
        take(reel);
      }
    }
    return reels;
  }

  Future<void> _startFromSeed(ReelItemModel seed) async {
    isInitialLoading.value = true;
    hasError.value = false;
    pausedReelId.value = null;
    currentIndex.value = 0;
    _resetAdSlots();
    _clearInterstitialState();

    final session = _session;
    session.reels
      ..clear()
      ..add(seed);
    session.currentPage = authorScope?.currentPage ?? 0;
    session.hasMore = authorScope?.hasMore ?? true;

    if (isAuthorViewer) {
      for (final reel in authorScope!.seeds) {
        if (reel.id != seed.id) {
          session.reels.add(reel);
        }
      }
    } else if (Get.isRegistered<ReelController>()) {
      final tab = Get.find<ReelController>();
      if (!identical(tab, this)) {
        for (final reel in tab.cachedReelsFor(selectedFeedType.value)) {
          if (reel.id != seed.id) {
            session.reels.add(reel);
          }
        }
      }
    }

    _applyVisibleReels();
    isInitialLoading.value = false;
    _markFirstPageReady();
    _jumpToFirstPage();
    _warmVisibleVideoAt(0);

    try {
      if (isAuthorViewer) {
        if (session.hasMore && session.reels.length < 4) {
          await _fetchPage(page: session.currentPage + 1);
        }
      } else {
        await _fetchPage(page: 1, replaceExisting: false);
      }
    } catch (_) {
      if (visibleReels.isEmpty) {
        hasError.value = true;
      }
    }
  }

  Future<void> _fetchAuthorPage({
    required int page,
    bool replaceExisting = false,
  }) async {
    final scope = authorScope;
    if (scope == null) {
      return;
    }

    unawaited(ContestEnrollmentStore.instance.ensureLoaded());
    final params = <String, String>{'per_page': '10'};
    switch (scope.tab) {
      case ProfileContentTab.outfits:
        params['outfit_page'] = '$page';
        break;
      case ProfileContentTab.food:
        params['food_page'] = '$page';
        break;
      case ProfileContentTab.saved:
        params['saved_page'] = '$page';
        break;
      case ProfileContentTab.more:
        break;
    }

    final path = scope.isOwnProfile
        ? 'profile/me/overview'
        : 'profiles/${Uri.encodeComponent(scope.username)}/overview';
    final observedAt = PostInteractionStore.ensure().observedClock;
    final response = await ApiHelper.fetchDataWithAuthorization(
      Uri(path: path, queryParameters: params).toString(),
    );
    if (response == null) {
      throw Exception('No response returned from profile reels.');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        (payload.containsKey('status_code') && payload['status_code'] != 1)) {
      throw Exception(
        (payload['message'] ?? 'Failed to load profile reels').toString(),
      );
    }

    final overview = ProfileOverviewResponseModel.fromMap(payload).overview;
    final source = switch (scope.tab) {
      ProfileContentTab.outfits => overview.outfitPosts,
      ProfileContentTab.food => overview.foodPosts,
      ProfileContentTab.saved =>
        overview.savedPosts.map((item) => item.post).toList(growable: false),
      ProfileContentTab.more => const <ProfilePostModel>[],
    };
    final incoming = source
        .map(
          (post) => post.toHomePostModel(
            username: scope.username,
            avatarUrl: scope.avatarUrl,
            profileUsername: scope.username,
            authorName: scope.authorName,
          ),
        )
        .where(ReelOpenHelper.isReel)
        .map(ReelOpenHelper.fromPost)
        .map((reel) => PostInteractionStore.ensure().ingestReel(
              reel,
              observedAt: observedAt,
            ))
        .toList();

    final pagination = switch (scope.tab) {
      ProfileContentTab.outfits => overview.outfitPagination,
      ProfileContentTab.food => overview.foodPagination,
      ProfileContentTab.saved => overview.savedPagination,
      ProfileContentTab.more => overview.outfitPagination,
    };

    final session = _session;
    final merged = replaceExisting
        ? incoming
        : _mergeReels(session.reels, incoming);
    session.reels
      ..clear()
      ..addAll(merged);
    session.currentPage = pagination.currentPage;
    session.hasMore = pagination.hasMorePages;
    _applyVisibleReels();
  }

  String _buildEndpoint(int page) {
    final type = selectedFeedType.value == ReelFeedType.style
        ? 'outfit'
        : 'food';
    return 'reels?type=$type&page=$page&sort=trending';
  }

  _ReelSessionState get _session =>
      _sessions.putIfAbsent(selectedFeedType.value, _ReelSessionState.new);

  List<ReelItemModel> _mergeReels(
    List<ReelItemModel> existing,
    List<ReelItemModel> incoming,
  ) {
    final byId = <String, ReelItemModel>{
      for (final item in existing) item.id: item,
    };
    for (final item in incoming) {
      final previous = byId[item.id];
      byId[item.id] = previous != null &&
              previous.hasFoodDetails &&
              !item.hasFoodDetails
          ? item.copyWith(
              restaurant: previous.restaurant,
              dishName: previous.dishName,
              foodRating: previous.foodRating,
              serviceRating: previous.serviceRating,
              staffRating: previous.staffRating,
              ambienceRating: previous.ambienceRating,
              rating: previous.rating,
              locationName: previous.locationName,
              latitude: previous.latitude,
              longitude: previous.longitude,
            )
          : item;
    }
    return byId.values.toList();
  }

  void _jumpToFirstPage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!pageController.hasClients) {
        return;
      }
      pageController.jumpToPage(0);
    });
  }

  void prefetchAround(int index) => _warmVisibleVideoAt(index);

  void _warmVisibleVideoAt(int index) {
    if (visibleReels.isEmpty) {
      return;
    }

    final safeIndex = index.clamp(0, visibleReels.length - 1);
    final fileUrls = <String>[];

    void collect(int reelIndex) {
      if (reelIndex < 0 || reelIndex >= visibleReels.length) {
        return;
      }
      final reel = visibleReels[reelIndex];
      if (reel.mediaType != ReelMediaType.video ||
          reel.mediaUrl.trim().isEmpty) {
        return;
      }
      _rememberPlayedVideo(reel.mediaUrl);
      fileUrls.add(reel.mediaUrl);
    }

    collect(safeIndex);
    collect(safeIndex + 1);
    collect(safeIndex + 2);
    collect(safeIndex + 3);
    collect(safeIndex - 1);
    ReelReadyService.prefetch(fileUrls, limit: 5);
  }

  void _markFirstPageReady() {
    if (!_firstPageReady.isCompleted) {
      _firstPageReady.complete();
    }
  }

  void _rememberPlayedVideo(String url) {
    if (url.trim().isEmpty) {
      return;
    }

    _recentPlayedVideoUrls.remove(url);
    _recentPlayedVideoUrls.addLast(url);

    while (_recentPlayedVideoUrls.length > 5) {
      _recentPlayedVideoUrls.removeFirst();
    }
  }

  Future<void> _runReelAction({
    required RxBool loadingFlag,
    required String endpoint,
    Map<String, dynamic>? body,
    required VoidCallback onSuccess,
  }) async {
    if (loadingFlag.value) {
      return;
    }

    loadingFlag.value = true;
    try {
      final response = await ApiHelper.postRequestWithAuthorization(
        endpoint,
        body: body,
      );
      await _ensureSuccess(response, fallback: 'Unable to update reel');
      onSuccess();
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    } finally {
      loadingFlag.value = false;
    }
  }

  Future<void> _ensureSuccess(
    dynamic response, {
    required String fallback,
  }) async {
    if (response == null) {
      throw Exception('No response returned from server.');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        payload['status_code'] != 1) {
      throw Exception((payload['message'] ?? fallback).toString());
    }
  }

  final Set<String> _biteHydrateInFlight = <String>{};

  void _hydrateBiteDetails() {
    _mergeBiteDetailsFromHome();
    unawaited(_fetchMissingBiteDetails());
  }

  void _mergeBiteDetailsFromHome() {
    if (!Get.isRegistered<HomeController>()) {
      return;
    }
    final home = Get.find<HomeController>();
    final posts = <String, HomePostModel>{};
    for (final post in [
      ...home.cachedPostsFor(HomeFeedType.bite),
      ...home.visiblePosts,
    ]) {
      posts[post.id] = post;
    }
    final updates = <ReelItemModel>[];
    for (final reel in visibleReels) {
      if ((!reel.isBite && selectedFeedType.value != ReelFeedType.bite) ||
          !reel.needsBiteHydration) {
        continue;
      }
      final post = posts[reel.id];
      if (post == null) {
        continue;
      }
      if (post.restaurant.trim().isEmpty &&
          post.dishName.trim().isEmpty &&
          !post.hasFoodRatings) {
        continue;
      }
      updates.add(reel.withFoodFrom(post));
    }
    _patchReels(updates);
  }

  Future<void> _fetchMissingBiteDetails() async {
    final start = mapToReelIndex(currentIndex.value);
    if (start < 0) {
      return;
    }
    final missing = <ReelItemModel>[];
    for (var i = start; i < visibleReels.length && missing.length < 3; i++) {
      final reel = visibleReels[i];
      if ((!reel.isBite && selectedFeedType.value != ReelFeedType.bite) ||
          !reel.needsBiteHydration ||
          _biteHydrateInFlight.contains(reel.id)) {
        continue;
      }
      missing.add(reel);
    }
    if (missing.isEmpty) {
      return;
    }

    for (final reel in missing) {
      _biteHydrateInFlight.add(reel.id);
    }
    try {
      final fetched = await Future.wait(
        missing.map((reel) => PostDetailOpenHelper.fetchPost(reel.id)),
      );
      final updates = <ReelItemModel>[];
      for (var i = 0; i < missing.length; i++) {
        final post = fetched[i];
        if (post == null) {
          continue;
        }
        final current = _findReel(missing[i].id) ?? missing[i];
        updates.add(current.withFoodFrom(post));
      }
      _patchReels(updates);
    } finally {
      for (final reel in missing) {
        _biteHydrateInFlight.remove(reel.id);
      }
    }
  }

  void _patchReels(List<ReelItemModel> updates) {
    if (updates.isEmpty) {
      return;
    }
    final byId = {for (final reel in updates) reel.id: reel};
    for (var i = 0; i < _session.reels.length; i++) {
      final next = byId[_session.reels[i].id];
      if (next != null) {
        _session.reels[i] = next;
      }
    }
    for (var i = 0; i < visibleReels.length; i++) {
      final next = byId[visibleReels[i].id];
      if (next != null) {
        visibleReels[i] = next;
      }
    }
    visibleReels.refresh();
    biteDetailsTick.value++;
  }

  ReelItemModel? _findReel(String reelId) {
    for (final reel in _session.reels) {
      if (reel.id == reelId) {
        return reel;
      }
    }
    return null;
  }

  void _updateReel(ReelItemModel updatedReel) {
    final session = _session;
    final sessionIndex = session.reels.indexWhere(
      (item) => item.id == updatedReel.id,
    );
    if (sessionIndex != -1) {
      session.reels[sessionIndex] = updatedReel;
    }
    final visibleIndex = visibleReels.indexWhere(
      (item) => item.id == updatedReel.id,
    );
    if (visibleIndex != -1) {
      visibleReels[visibleIndex] = updatedReel;
    }
  }

  List<String> _reelCommentUsernames(Iterable<PostCommentModel> comments) {
    final usernames = <String>[];
    for (final comment in comments) {
      usernames.add(comment.user);
      for (final reply in comment.replies) {
        usernames.add(reply.user);
      }
    }
    return usernames;
  }
}

/// A loaded native ad pinned to a page index in the reels PageView.
class ReelAdSlot {
  const ReelAdSlot({
    required this.pageIndex,
    required this.ad,
    required this.attributedPostId,
  });

  final int pageIndex;
  final NativeAd ad;
  final String attributedPostId;
}

class _ReelSessionState {
  final List<ReelItemModel> reels = <ReelItemModel>[];
  int currentPage = 0;
  bool hasMore = true;
}

String _formatCount(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}m';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}k';
  }
  return value.toString();
}
