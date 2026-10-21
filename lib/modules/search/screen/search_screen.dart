import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/app_back_navigation.dart';
import '../../../core/widgets/app_sliding_toggle.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../../../core/widgets/app_hero_icon.dart';
import '../../../core/widgets/app_verified_badge.dart';
import '../../../core/widgets/states/app_empty_state.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../home/models/home_post_model.dart';
import '../../landing/controllers/landing_controller.dart';
import '../../landing/screen/landing_screen.dart';
import '../../landing/widgets/landing_bottom_nav.dart';
import '../../post/utils/hashtag_open_helper.dart';
import '../../post/utils/post_detail_open_helper.dart';
import '../../profile/utils/profile_open_helper.dart';
import '../../profile/widgets/follow_user_button.dart';
import '../controllers/bite_restaurant_search_controller.dart';
import '../controllers/search_controller.dart';
import '../models/search_user_model.dart';
import '../widgets/explore_media_grid.dart';

enum SearchMode { people, restaurants }

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.mode = SearchMode.people});

  final SearchMode mode;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final Rx<SearchMode> _mode;
  late final LandingController _landing;
  UserSearchController? _peopleController;
  BiteRestaurantSearchController? _restaurantController;

  @override
  void initState() {
    super.initState();
    _mode = widget.mode.obs;
    _landing = Get.isRegistered<LandingController>()
        ? Get.find<LandingController>()
        : Get.put(LandingController());
    _landing.isBottomNavCompact.value = false;
    if (_mode.value == SearchMode.restaurants) {
      _ensureBiteController().openExplore();
    } else {
      final people = _ensurePeopleController();
      if (Get.arguments is Map &&
          ((Get.arguments as Map)['query']?.toString().trim().isNotEmpty ??
              false)) {
        people.configure(
          initialQuery: (Get.arguments as Map)['query']?.toString(),
          autoOpenProfile: (Get.arguments as Map)['autoOpenProfile'] == true,
        );
      } else if (people.query.value.trim().isEmpty &&
          people.exploreItems.isEmpty) {
        people.resetIdle();
      }
    }
  }

  UserSearchController _ensurePeopleController() {
    final existing = _peopleController;
    if (existing != null) {
      return existing;
    }
    final created = Get.isRegistered<UserSearchController>()
        ? Get.find<UserSearchController>()
        : Get.put(UserSearchController());
    _peopleController = created;
    return created;
  }

  BiteRestaurantSearchController _ensureBiteController() {
    final existing = _restaurantController;
    if (existing != null) {
      return existing;
    }
    final created = Get.isRegistered<BiteRestaurantSearchController>(tag: 'bite')
        ? Get.find<BiteRestaurantSearchController>(tag: 'bite')
        : Get.put(BiteRestaurantSearchController(), tag: 'bite');
    _restaurantController = created;
    return created;
  }

  void _switchMode(SearchMode mode) {
    if (_mode.value == mode) {
      return;
    }
    if (mode == SearchMode.restaurants) {
      _peopleController?.cancelInFlight();
      _ensureBiteController();
    } else {
      _restaurantController?.cancelInFlight();
      _ensurePeopleController();
    }
    _mode.value = mode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _mode.value != mode) {
        return;
      }
      if (mode == SearchMode.restaurants) {
        _restaurantController?.openExplore();
        return;
      }
      _peopleController?.ensureExplore();
    });
  }

  double get _navClearance => MediaQuery.paddingOf(context).bottom + 132;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          _landing.onPrimaryScroll(notification);
          return false;
        },
        child: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: Obx(() {
                final isBite = _mode.value == SearchMode.restaurants;
                if (isBite) {
                  _observeBite(_restaurantController!);
                } else {
                  _observeStyle(_peopleController!);
                }
                return Column(
                  children: [
                    _SearchTopBar(isBite: isBite),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Column(
                        children: [
                          Center(
                            child: _SearchModeToggle(
                              mode: _mode.value,
                              onChanged: _switchMode,
                            ),
                          ),
                          const SizedBox(height: 10),
                          isBite
                              ? _RestaurantSearchBox(
                                  key: ValueKey(
                                    'bite-search-${_restaurantController!.searchEpoch}',
                                  ),
                                  controller: _restaurantController!,
                                )
                              : _SearchBox(controller: _peopleController!),
                        ],
                      ),
                    ),
                    Expanded(
                      child: isBite
                          ? _buildRestaurantContent()
                          : _buildContent(),
                    ),
                  ],
                );
              }),
            ),
            const Align(
              alignment: Alignment.bottomCenter,
              child: _ExploreBottomNav(),
            ),
          ],
        ),
      ),
    );
  }

  void _observeStyle(UserSearchController controller) {
    controller.query.value;
    controller.exploreItems.length;
    controller.isExploreLoading.value;
    controller.isExploreLoadingMore.value;
    controller.exploreHasError.value;
    controller.users.length;
    controller.personMedia.length;
    controller.relatedMedia.length;
    controller.isInitialLoading.value;
    controller.isMediaLoading.value;
    controller.hasError.value;
    controller.isLoadingMore.value;
  }

  void _observeBite(BiteRestaurantSearchController controller) {
    controller.query.value;
    controller.exploreItems.length;
    controller.isExploreLoading.value;
    controller.isExploreLoadingMore.value;
    controller.exploreHasError.value;
    controller.posts.length;
    controller.restaurantMedia.length;
    controller.relatedMedia.length;
    controller.isInitialLoading.value;
    controller.isMediaLoading.value;
    controller.hasError.value;
    controller.isLoadingMore.value;
  }

  Widget _buildContent() {
    final controller = _peopleController!;
    if (!controller.isSearching) {
      return _buildExploreContent(controller);
    }
    return _buildSearchResults(controller);
  }

  Widget _buildExploreContent(UserSearchController controller) {
    if (controller.isExploreLoading.value && controller.exploreItems.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(top: 12, bottom: _navClearance),
        child: ExploreMediaGrid.shimmer(),
      );
    }

    if (controller.exploreHasError.value && controller.exploreItems.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => controller.loadExplore(reset: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: _navClearance),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
            AppErrorState(
              message: controller.exploreErrorMessage.value.isEmpty
                  ? 'Unable to load Explore right now.'
                  : controller.exploreErrorMessage.value,
              onRetry: () => controller.loadExplore(reset: true),
            ),
          ],
        ),
      );
    }

    if (controller.exploreItems.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => controller.loadExplore(reset: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: _navClearance),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
            const AppEmptyState(
              title: 'Explore',
              subtitle: 'Posts and reels will show up here. Pull to refresh.',
              icon: Icons.grid_view_rounded,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: controller.refreshSearch,
      child: CustomScrollView(
        controller: controller.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(
            child: ExploreMediaGrid(
              items: controller.exploreItems.toList(growable: false),
              onTap: controller.openMedia,
            ),
          ),
          SliverToBoxAdapter(child: _exploreFooter(controller.isExploreLoadingMore.value)),
        ],
      ),
    );
  }

  Widget _buildSearchResults(UserSearchController controller) {
    if (controller.isHashtagSearch) {
      return _buildHashtagResults(
        items: controller.relatedMedia.toList(growable: false),
        isLoading: controller.isMediaLoading.value,
        hasError: controller.hasError.value,
        errorMessage: controller.errorMessage.value,
        onRetry: controller.refreshSearch,
        onRefresh: controller.refreshSearch,
        onOpen: controller.openMedia,
        tag: HashtagOpenHelper.tagFromQuery(controller.query.value) ??
            controller.query.value.trim(),
        section: 'Style',
      );
    }

    final hasUsers = controller.users.isNotEmpty;
    final hasPersonMedia = controller.personMedia.isNotEmpty;
    final hasRelated = controller.relatedMedia.isNotEmpty;
    final waiting =
        (controller.isInitialLoading.value && !hasUsers) &&
        (controller.isMediaLoading.value && !hasPersonMedia && !hasRelated);

    if (waiting) {
      return _paddedCenter(const CircularProgressIndicator());
    }

    if (controller.hasError.value &&
        !hasUsers &&
        !hasPersonMedia &&
        !hasRelated &&
        !controller.isMediaLoading.value) {
      return _paddedCenter(
        AppErrorState(
          message: controller.errorMessage.value.isEmpty
              ? 'Unable to search right now.'
              : controller.errorMessage.value,
          onRetry: controller.refreshSearch,
        ),
      );
    }

    if (!hasUsers &&
        !hasPersonMedia &&
        !hasRelated &&
        !controller.isInitialLoading.value &&
        !controller.isMediaLoading.value) {
      final trimmedQuery = controller.query.value.trim();
      return _paddedCenter(
        AppEmptyState(
          title: 'No results',
          subtitle: 'No accounts or media matching "$trimmedQuery".',
          icon: Icons.person_search_rounded,
        ),
      );
    }

    final owner = controller.mediaOwnerUsername.value.trim();

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: controller.refreshSearch,
      child: CustomScrollView(
        controller: controller.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
          if (hasUsers) ...[
            const SliverToBoxAdapter(
              child: _ExploreSectionHeader(label: 'Accounts'),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _UserResultCard(user: controller.users[index]),
                    );
                  },
                  childCount: controller.users.length,
                ),
              ),
            ),
          ] else if (controller.isInitialLoading.value)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Text(
                  'No accounts found',
                  style: AppFonts.beVietnam(
                    size: 13,
                    weight: FontWeight.w600,
                    color: AppColors.hintText,
                  ),
                ),
              ),
            ),
          if (controller.isMediaLoading.value &&
              !hasPersonMedia &&
              !hasRelated)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          if (hasPersonMedia) ...[
            SliverToBoxAdapter(
              child: _ExploreSectionHeader(
                label: owner.isEmpty ? 'Posts' : 'Posts from @$owner',
              ),
            ),
            SliverToBoxAdapter(
              child: ExploreMediaGrid(
                items: controller.personMedia.toList(growable: false),
                onTap: controller.openMedia,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
          ],
          if (hasRelated) ...[
            const SliverToBoxAdapter(
              child: _ExploreSectionHeader(label: 'Related'),
            ),
            SliverToBoxAdapter(
              child: ExploreMediaGrid(
                items: controller.relatedMedia.toList(growable: false),
                onTap: controller.openMedia,
              ),
            ),
          ],
          SliverToBoxAdapter(
            child: _exploreFooter(controller.isLoadingMore.value),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantContent() {
    final controller = _restaurantController!;
    if (!controller.isSearching) {
      return _buildBiteExploreContent(controller);
    }
    if (controller.exploreItems.isNotEmpty &&
        controller.uniqueRestaurants.isEmpty &&
        controller.restaurantMedia.isEmpty &&
        controller.relatedMedia.isEmpty) {
      return _buildBiteExploreContent(controller);
    }
    return _buildBiteSearchResults(controller);
  }

  Widget _buildBiteExploreContent(BiteRestaurantSearchController controller) {
    if (controller.isExploreLoading.value && controller.exploreItems.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(top: 12, bottom: _navClearance),
        child: ExploreMediaGrid.shimmer(),
      );
    }

    if (controller.exploreHasError.value && controller.exploreItems.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => controller.loadExplore(reset: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: _navClearance),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
            AppErrorState(
              message: controller.exploreErrorMessage.value.isEmpty
                  ? 'Unable to load Explore right now.'
                  : controller.exploreErrorMessage.value,
              onRetry: () => controller.loadExplore(reset: true),
            ),
          ],
        ),
      );
    }

    if (controller.exploreItems.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => controller.loadExplore(reset: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: _navClearance),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
            const AppEmptyState(
              title: 'Explore',
              subtitle: 'Bite posts and reels will show up here. Pull to refresh.',
              icon: Icons.restaurant_rounded,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: controller.refreshSearch,
      child: CustomScrollView(
        controller: controller.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(
            child: ExploreMediaGrid(
              items: controller.exploreItems.toList(growable: false),
              onTap: controller.openMedia,
              showRestaurantName: true,
            ),
          ),
          SliverToBoxAdapter(
            child: _exploreFooter(controller.isExploreLoadingMore.value),
          ),
        ],
      ),
    );
  }

  Widget _buildBiteSearchResults(BiteRestaurantSearchController controller) {
    if (controller.isHashtagSearch) {
      return _buildHashtagResults(
        items: controller.relatedMedia.toList(growable: false),
        isLoading: controller.isMediaLoading.value,
        hasError: controller.hasError.value,
        errorMessage: controller.errorMessage.value,
        onRetry: controller.refreshSearch,
        onRefresh: controller.refreshSearch,
        onOpen: controller.openMedia,
        tag: HashtagOpenHelper.tagFromQuery(controller.query.value) ??
            controller.query.value.trim(),
        section: 'Bite',
      );
    }

    final restaurants = controller.uniqueRestaurants;
    final hasRestaurants = restaurants.isNotEmpty;
    final hasRestaurantMedia = controller.restaurantMedia.isNotEmpty;
    final hasRelated = controller.relatedMedia.isNotEmpty;
    final waiting =
        (controller.isInitialLoading.value && !hasRestaurants) &&
        (controller.isMediaLoading.value &&
            !hasRestaurantMedia &&
            !hasRelated);

    if (waiting) {
      return _paddedCenter(const CircularProgressIndicator());
    }

    if (controller.hasError.value &&
        !hasRestaurants &&
        !hasRestaurantMedia &&
        !hasRelated &&
        !controller.isMediaLoading.value) {
      return _paddedCenter(
        AppErrorState(
          message: controller.errorMessage.value.isEmpty
              ? 'Unable to search restaurants right now.'
              : controller.errorMessage.value,
          onRetry: controller.refreshSearch,
        ),
      );
    }

    if (!hasRestaurants &&
        !hasRestaurantMedia &&
        !hasRelated &&
        !controller.isInitialLoading.value &&
        !controller.isMediaLoading.value) {
      final trimmedQuery = controller.query.value.trim();
      return _paddedCenter(
        AppEmptyState(
          title: 'No results',
          subtitle: 'No restaurants or Bite posts matching "$trimmedQuery".',
          icon: Icons.search_off_rounded,
        ),
      );
    }

    final owner = controller.mediaOwnerRestaurant.value.trim();

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: controller.refreshSearch,
      child: CustomScrollView(
        controller: controller.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
          if (hasRestaurants) ...[
            const SliverToBoxAdapter(
              child: _ExploreSectionHeader(label: 'Restaurants'),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RestaurantPostCard(post: restaurants[index]),
                    );
                  },
                  childCount: restaurants.length,
                ),
              ),
            ),
          ] else if (controller.isInitialLoading.value)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Text(
                  'No restaurants found',
                  style: AppFonts.beVietnam(
                    size: 13,
                    weight: FontWeight.w600,
                    color: AppColors.hintText,
                  ),
                ),
              ),
            ),
          if (controller.isMediaLoading.value &&
              !hasRestaurantMedia &&
              !hasRelated)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          if (hasRestaurantMedia) ...[
            SliverToBoxAdapter(
              child: _ExploreSectionHeader(
                label: owner.isEmpty ? 'Posts' : 'Posts from $owner',
              ),
            ),
            SliverToBoxAdapter(
              child: ExploreMediaGrid(
                items: controller.restaurantMedia.toList(growable: false),
                onTap: controller.openMedia,
                showRestaurantName: true,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
          ],
          if (hasRelated) ...[
            const SliverToBoxAdapter(
              child: _ExploreSectionHeader(label: 'Related'),
            ),
            SliverToBoxAdapter(
              child: ExploreMediaGrid(
                items: controller.relatedMedia.toList(growable: false),
                onTap: controller.openMedia,
                showRestaurantName: true,
              ),
            ),
          ],
          SliverToBoxAdapter(
            child: _exploreFooter(controller.isLoadingMore.value),
          ),
        ],
      ),
    );
  }

  Widget _buildHashtagResults({
    required List<HomePostModel> items,
    required bool isLoading,
    required bool hasError,
    required String errorMessage,
    required VoidCallback onRetry,
    required Future<void> Function() onRefresh,
    required ValueChanged<HomePostModel> onOpen,
    required String tag,
    required String section,
  }) {
    if (isLoading && items.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(top: 12, bottom: _navClearance),
        child: ExploreMediaGrid.shimmer(),
      );
    }

    if (hasError && items.isEmpty) {
      return _paddedCenter(
        AppErrorState(
          message: errorMessage.isEmpty
              ? 'Could not load posts for $tag.'
              : errorMessage,
          onRetry: onRetry,
        ),
      );
    }

    if (items.isEmpty) {
      return _paddedCenter(
        AppEmptyState(
          title: 'No posts yet',
          subtitle: 'No $section posts with $tag.',
          icon: Icons.tag_rounded,
          actionLabel: 'Refresh',
          onAction: onRetry,
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(
            child: ExploreMediaGrid(
              items: items,
              onTap: onOpen,
              showRestaurantName: section == 'Bite',
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: _navClearance)),
        ],
      ),
    );
  }

  Widget _paddedCenter(Widget child) {
    return Padding(
      padding: EdgeInsets.only(bottom: _navClearance),
      child: Center(child: child),
    );
  }

  Widget _exploreFooter(bool isLoadingMore) {
    if (isLoadingMore) {
      return Padding(
        padding: EdgeInsets.fromLTRB(0, 16, 0, _navClearance),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    return SizedBox(height: _navClearance);
  }
}

class _ExploreBottomNav extends StatelessWidget {
  const _ExploreBottomNav();

  @override
  Widget build(BuildContext context) {
    final landing = Get.isRegistered<LandingController>()
        ? Get.find<LandingController>()
        : Get.put(LandingController());

    return Obx(
      () => LandingBottomNav(
        tabs: landing.tabs,
        currentIndex: landing.currentIndex.value,
        compact: landing.isBottomNavCompact.value,
        onTap: (index) => _goToLandingTab(landing, index),
      ),
    );
  }

  void _goToLandingTab(LandingController landing, int index) {
    landing.onTabChanged(index);

    final navigator = Get.key.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.popUntil(
        (route) =>
            route.settings.name == AppRoutes.landing || route.isFirst,
      );
    }

    if (Get.currentRoute == AppRoutes.landing) {
      return;
    }

    Get.offAll<void>(() => LandingScreen(initialIndex: index));
  }
}

class _ExploreSectionHeader extends StatelessWidget {
  const _ExploreSectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Text(
        label,
        style: AppFonts.plusJakarta(
          size: 16,
          weight: FontWeight.w800,
          color: AppColors.text,
        ),
      ),
    );
  }
}

class _SearchTopBar extends StatelessWidget {
  const _SearchTopBar({required this.isBite});

  final bool isBite;

  @override
  Widget build(BuildContext context) {
    final brand = isBite ? 'Bite' : 'Style';
    return ColoredBox(
      color: AppColors.background,
      child: SizedBox(
        height: 62,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
          child: Row(
            children: [
              IconButton(
                onPressed: AppBackNavigation.handleBack,
                icon: const AppHeroIconData(
                  Icons.arrow_back_rounded,
                  color: AppColors.text,
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: ShaderMask(
                        key: ValueKey(brand),
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [AppColors.primary, AppColors.secondary],
                        ).createShader(bounds),
                        child: Text(
                          brand,
                          style: AppFonts.plusJakarta(
                            size: 24,
                            weight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Search',
                      style: AppFonts.plusJakarta(
                        size: 24,
                        weight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchModeToggle extends StatelessWidget {
  const _SearchModeToggle({
    required this.mode,
    required this.onChanged,
  });

  final SearchMode mode;
  final ValueChanged<SearchMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppSlidingToggle(
      labels: const ['Style', 'Bite'],
      selectedIndex: mode == SearchMode.restaurants ? 1 : 0,
      minSegmentWidth: 84,
      fontSize: 12,
      segmentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      onChanged: (index) => onChanged(
        index == 1 ? SearchMode.restaurants : SearchMode.people,
      ),
    );
  }
}

class _StyleShirtIcon extends StatelessWidget {
  const _StyleShirtIcon();

  static const double _size = 20;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.primary, AppColors.secondary],
      ).createShader(bounds),
      child: Image.asset(
        AppAssets.styleShirt,
        width: _size,
        height: _size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.controller});

  final UserSearchController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: TextField(
        controller: controller.searchTextController,
        onChanged: controller.onQueryChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search',
          hintStyle: AppFonts.beVietnam(
            size: 14,
            weight: FontWeight.w500,
            color: AppColors.hintText,
          ),
          prefixIcon: const SizedBox(
            width: 48,
            height: 48,
            child: Center(child: _StyleShirtIcon()),
          ),
          prefixIconConstraints: const BoxConstraints.tightFor(
            width: 48,
            height: 48,
          ),
          suffixIcon: Obx(
            () => controller.query.value.trim().isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    onPressed: () {
                      controller.searchTextController.clear();
                      controller.onQueryChanged('');
                    },
                    icon: const AppHeroIconData(Icons.close_rounded,
                      color: AppColors.hintText,
                    ),
                  ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
        ),
        style: AppFonts.beVietnam(
          size: 14,
          weight: FontWeight.w600,
          color: AppColors.text,
        ),
      ),
    );
  }
}

class _RestaurantSearchBox extends StatelessWidget {
  const _RestaurantSearchBox({super.key, required this.controller});

  final BiteRestaurantSearchController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: TextField(
        controller: controller.searchTextController,
        onChanged: controller.onQueryChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search',
          hintStyle: AppFonts.beVietnam(
            size: 14,
            weight: FontWeight.w500,
            color: AppColors.hintText,
          ),
          prefixIcon: ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.secondary],
            ).createShader(bounds),
            child: const AppHeroIconData(
              Icons.restaurant_rounded,
              color: Colors.white,
            ),
          ),
          suffixIcon: Obx(
            () => controller.query.value.trim().isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    onPressed: () {
                      controller.searchTextController.clear();
                      controller.onQueryChanged('');
                    },
                    icon: const AppHeroIconData(
                      Icons.close_rounded,
                      color: AppColors.hintText,
                    ),
                  ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
        ),
        style: AppFonts.beVietnam(
          size: 14,
          weight: FontWeight.w600,
          color: AppColors.text,
        ),
      ),
    );
  }
}

class _RestaurantPostCard extends StatelessWidget {
  const _RestaurantPostCard({required this.post});

  final HomePostModel post;

  @override
  Widget build(BuildContext context) {
    final restaurant = post.restaurant.trim().isNotEmpty
        ? post.restaurant.trim()
        : (post.displayLocation.isNotEmpty
              ? post.displayLocation
              : 'Restaurant post');
    final subtitleParts = <String>[
      if (post.dishName.trim().isNotEmpty) post.dishName.trim(),
      if (post.displayLocation.isNotEmpty) post.displayLocation,
    ];
    final imageUrl = post.imageUrl.trim().isNotEmpty
        ? post.imageUrl
        : (post.thumbnailUrl ?? post.primaryMediaUrl);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => PostDetailOpenHelper.openIfAccessible(post),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(47, 47, 46, 0.08),
              blurRadius: 24,
              offset: Offset(0, 10),
              spreadRadius: -14,
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 72,
                height: 72,
                child: imageUrl.trim().isEmpty
                    ? const ColoredBox(
                        color: Color(0xFFF1EEEE),
                        child: AppHeroIconData(Icons.restaurant_rounded),
                      )
                    : AppCachedImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.beVietnam(
                      size: 15,
                      weight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  if (subtitleParts.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitleParts.join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.beVietnam(
                        size: 12,
                        weight: FontWeight.w500,
                        color: AppColors.hintText,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    'Posted by ${post.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.beVietnam(
                      size: 11,
                      weight: FontWeight.w600,
                      color: AppColors.hintText,
                    ),
                  ),
                ],
              ),
            ),
            const AppHeroIconData(
              Icons.chevron_right_rounded,
              color: AppColors.hintText,
            ),
          ],
        ),
      ),
    );
  }
}

class _UserResultCard extends StatelessWidget {
  const _UserResultCard({required this.user});

  final SearchUserModel user;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => ProfileOpenHelper.open(
        username: user.username,
        initialIsFollowing: user.isFollowing,
        avatarUrl: user.avatarUrl,
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(47, 47, 46, 0.08),
              blurRadius: 24,
              offset: Offset(0, 10),
              spreadRadius: -14,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipOval(
              child: user.avatarUrl.trim().isEmpty
                  ? Container(
                      width: 54,
                      height: 54,
                      color: const Color(0xFFF1EEEE),
                      alignment: Alignment.center,
                      child: const AppHeroIconData(Icons.person_rounded),
                    )
                  : AppCachedImage(
                      imageUrl: user.avatarUrl,
                      width: 54,
                      height: 54,
                      fit: BoxFit.cover,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    user.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppFonts.beVietnam(
                                      size: 15,
                                      weight: FontWeight.w700,
                                      color: AppColors.text,
                                    ),
                                  ),
                                ),
                                VerifiedBadgeSlot(
                                  username: user.username,
                                  fallback: user.isVerifiedBadge,
                                  size: 14,
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    '@${user.username}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppFonts.beVietnam(
                                      size: 12,
                                      weight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FollowUserButton(
                        username: user.username,
                        initialIsFollowing: user.isFollowing,
                        compact: true,
                      ),
                    ],
                  ),
                  if (user.bio.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      user.bio,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.beVietnam(
                        size: 13,
                        weight: FontWeight.w500,
                        color: AppColors.hintText,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (user.locationLabel.isNotEmpty)
                        _MetaChip(
                          icon: Icons.location_on_outlined,
                          label: user.locationLabel,
                        ),
                      if (user.followsYou)
                        const _MetaChip(
                          icon: Icons.reply_all_rounded,
                          label: 'Follows you',
                        ),
                      if (user.isMutualFollow)
                        const _MetaChip(
                          icon: Icons.people_alt_outlined,
                          label: 'Mutual',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F0EF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppHeroIconData(icon, size: 14, color: AppColors.hintText),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppFonts.beVietnam(
              size: 11,
              weight: FontWeight.w700,
              color: AppColors.hintText,
            ),
          ),
        ],
      ),
    );
  }
}
