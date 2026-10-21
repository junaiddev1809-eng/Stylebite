import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/app_back_navigation.dart';
import '../../../core/utils/app_helper.dart';
import '../../../core/widgets/app_hero_icon.dart';
import '../../landing/models/landing_tab_model.dart';
import '../../landing/screen/landing_screen.dart';
import '../../landing/widgets/landing_bottom_nav.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();

  final List<String> _tabs = const ['outfits', 'food', 'battles', 'brands'];
  final List<String> _cities = const [
    'Multan',
    'Lahore',
    'Karachi',
    'Islamabad',
  ];

  final List<_ExploreCardData> _trendingCards = const [
    _ExploreCardData(
      title: '#Y2KRevival',
      meta: 'Outfit Trend',
      imageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDa0h4-Hea4nBBWmPTl9KlsIojR7YdO_lz1_ddGrtoTPH1JiDvTC5FW9ZSZ26-K7L6d_N9VnuQ53ZXxoa8kG7m22KCUXv-O3bxHyN02fogPCi57d5ludWZoVPFkMy-HUL32fHB2Imv_FdqpVL9xns9pdDcZf4WuUXysXprl4k5_O0K4dsjGcJ-hUZOrKF9DPMridFrL5KI-YfHwUOTk2KKe3irtppCWlk70I2yaNUZtAbip8dBo4UP00-2ReJ-URlPFSswPQsLyQkmi',
      categories: ['outfits', 'brands'],
      cities: ['all'],
      searchable: '#y2krevival neon street style fashion trend',
      isTall: true,
    ),
    _ExploreCardData(
      title: 'Fusion Plate Live',
      meta: 'Food Spotlight',
      imageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuBTDqrtFFOTPbsJ0Ri61hmqkEFMUOK-r-do2CJiExSK2CJGNbDsJHHvFNbedRar6sOY9extDN599xGzd4RtON62bQubbh__e1G-PwWnIjWrceTrTvy1AaOK5Z0A34FZ9ut0Qo-bzWqt2o43X-mGa3LtgiqcqFlid_yutI9Z-NrLWVJwgVjSuLUcUIo5bLR32RTRSPHUacECqcXh3SKWB3N-IN-BgIRLWHKXHo7j6yKPh6t5J5faAaPcy3zmVyklVGQ3RnNGrMlKmpXx',
      categories: ['food'],
      cities: ['multan', 'lahore'],
      searchable: 'fusion plate gourmet food live trend',
      showLiveBadge: true,
    ),
    _ExploreCardData(
      title: 'Sneaker Battle',
      meta: 'Battle Arena',
      imageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuAxInCJci7sgOmmLDjey34TutNNBO4-vGfrjQT-_VAd6dMBner3XRzpk1f4H84zBBlTE7x1VfrXL4pj3ksGnsidjhYlWDZqubWItIUv4ZPMxDxTO09z2KEulWeOGrIeT-DKdzDkKbB3dMb29cEzrU0Bes-GghaYjNmszqZGD1lUIOpAT4yAzaa6176n4fERhIIMcxvnC-r3ykuUPk-D01ltbbwy8XvrL5lrt91bMtEg_yA5Vf-x5JmuId1xOna8l_y31yfS3IVWt4if',
      categories: ['battles', 'brands'],
      cities: ['karachi', 'islamabad'],
      searchable: 'sneaker battle versus brands duel trend',
      showVs: true,
    ),
  ];

  final List<_FoodCardData> _foodCards = const [
    _FoodCardData(
      title: 'The Bistro Garden',
      meta: 'Continental • Gulgasht',
      imageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuAAq5ZcX5zkG-K3E2yFNqoBzh1SMgFcHcqABP7LO3T9vZWDinEGP_4X0oqgC5RRpOo7f2fUXiHP-YBNx938RaQJB3O_wfoZxfNf-GN6YT6h1Ye5A1TpcJ4IZ2cSyJ15IHRNO6IHwWslrjX21THXX6IEP2S9hGfD4zUSBTdObIRApbBg__MzXwlNZIpLmg87CsJnRSHfTXIj5V2ylT7PY_Azlo47HDUO-udYApuzZ4G0KPbAHzD5e7_HwaNrUcs_gc9GpBsix-uMU6Il',
      rating: 4.9,
      categories: ['food'],
      cities: ['multan'],
      searchable:
          'bistro garden continental gulgasht taste quality ambience staff food',
      scores: {
        'Taste': '9.8',
        'Quality': '9.5',
        'Staff': '8.9',
        'Ambience': '9.2',
      },
    ),
    _FoodCardData(
      title: 'Saffron Grill',
      meta: 'Desi • Cantt',
      imageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuBJlxsZWLWZD7j80Hj-vv_XrRQlqsdWJEyUlVgf8VznDIC6SiAUo2FbXesb53wAm0j1fH2aBTa9XNfnglUzHIILhvMAI_Oq0rtCPqq7aHPYp4vybHGqfvD0vqihsSX0gSfLNeZM-uQxBiL6-IR1NC6PhM0OTxgD59aHXB24L_uieRphLfYsoW7EDY_VOCeBWVn2DSk2drMtnJmx_5sYG2LgDd9ij3qW4wwrwQm1zDRfxbECnwvrwfrsxaMsV6alBttImbLPd7iMVLQI',
      rating: 4.7,
      categories: ['food'],
      cities: ['lahore', 'karachi'],
      searchable:
          'saffron grill desi cantt taste quality ambience staff bbq food',
      scores: {
        'Taste': '9.4',
        'Quality': '9.1',
        'Staff': '9.5',
        'Ambience': '8.5',
      },
    ),
  ];

  final List<String> _tags = const [
    'streetwear',
    'multanfoodies',
    'summerfits',
    'brunchspots',
    'aesthetic',
  ];

  final Set<String> _savedCards = <String>{};
  String _activeTab = 'outfits';
  String _city = 'Multan';
  String _activeTag = '';
  bool _forceAll = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_ExploreCardData> get _visibleTrending => _trendingCards
      .where(
        (card) => _matchesFilter(card.categories, card.cities, card.searchable),
      )
      .toList(growable: false);

  List<_FoodCardData> get _visibleFood => _foodCards
      .where(
        (card) => _matchesFilter(card.categories, card.cities, card.searchable),
      )
      .toList(growable: false);

  bool get _hasAnyVisible =>
      _visibleTrending.isNotEmpty || _visibleFood.isNotEmpty;

  bool _matchesFilter(
    List<String> categories,
    List<String> cities,
    String searchable,
  ) {
    final normalizedCity = _city.toLowerCase();
    final query = _searchController.text.trim().toLowerCase().replaceAll(
      '#',
      '',
    );

    final tabPass = _forceAll || categories.contains(_activeTab);
    final cityPass = cities.contains('all') || cities.contains(normalizedCity);
    final queryPass = query.isEmpty || searchable.toLowerCase().contains(query);

    return tabPass && cityPass && queryPass;
  }

  void _showToast(String message) {
    if (!mounted) {
      return;
    }

    // Was a bottom-docked SnackBar, which sat behind this screen's own
    // Stack-positioned bottom nav (it isn't wired through Scaffold's real
    // bottomNavigationBar, so Flutter has no way to avoid it). The app's
    // standard toast helper already renders at the top instead.
    infoSnackBar(message: message);
  }

  Future<void> _openSheet(String title, String meta) async {
    final id = '${title.toLowerCase()}::${meta.toLowerCase()}';

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (context) {
        var isSaved = _savedCards.contains(id);

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 22),
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: const Color(0xFFAFADAC).withValues(alpha: 0.3),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(255, 77, 109, 0.22),
                    blurRadius: 30,
                    offset: Offset(0, 12),
                    spreadRadius: -12,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 50,
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE4E2E1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              meta,
                              style: AppFonts.beVietnam(
                                size: 11,
                                weight: FontWeight.w700,
                                color: AppColors.primary,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              title,
                              style: AppFonts.plusJakarta(
                                size: 22,
                                weight: FontWeight.w800,
                                color: AppColors.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: AppBackNavigation.handleBack,
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFF3F0EF),
                        ),
                        icon: const AppHeroIconData(
                          Icons.close_rounded,
                          color: AppColors.hintText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _sheetButton(
                          label: 'View',
                          onTap: () {
                            AppBackNavigation.handleBack();
                            _showToast('Opening $title');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _sheetButton(
                          label: isSaved ? 'Saved' : 'Save',
                          icon: isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          onTap: () {
                            if (isSaved) {
                              _savedCards.remove(id);
                              _showToast('Removed from saved');
                            } else {
                              _savedCards.add(id);
                              _showToast('Saved to your list');
                            }
                            setState(() {});
                            setSheetState(() {
                              isSaved = !isSaved;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _sheetButton(
                          label: 'Share',
                          onTap: () async {
                            final shareText = '$title - $meta';
                            await Clipboard.setData(
                              ClipboardData(text: shareText),
                            );
                            _showToast('Copied for sharing');
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _sheetButton({
    required String label,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F0EF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              AppHeroIconData(icon, size: 16, color: AppColors.text),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: AppFonts.beVietnam(
                size: 12,
                weight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trending = _visibleTrending;
    final food = _visibleFood;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final contentBottomPadding = safeBottom + 132;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildTopBar()),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, contentBottomPadding),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSearchAndCity(),
                      const SizedBox(height: 10),
                      _buildTopTabs(),
                      const SizedBox(height: 20),
                      if (trending.isNotEmpty) _buildTrending(trending),
                      if (trending.isNotEmpty) const SizedBox(height: 20),
                      if (food.isNotEmpty) _buildFoodSection(food),
                      if (food.isNotEmpty) const SizedBox(height: 18),
                      if (_hasAnyVisible) _buildTags(),
                      if (!_hasAnyVisible) _buildEmptyState(),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: LandingBottomNav(
              tabs: LandingTabModel.defaultTabs,
              currentIndex: -1,
              onTap: (index) =>
                  Get.offAll<void>(() => LandingScreen(initialIndex: index)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: SafeArea(
          bottom: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            color: AppColors.background.withValues(alpha: 0.7),
            child: Row(
              children: [
                InkWell(
                  onTap: AppBackNavigation.handleBack,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    child: const AppHeroIconData(
                      Icons.arrow_back_rounded,
                      color: AppColors.hintText,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(
                    'https://lh3.googleusercontent.com/aida-public/AB6AXuClgvgTERNW5qiqtOEwzVcwltrD8F1WmbcAVf9m4IC5jB4tABn-D-rHAsma0HGYER1-4f3rjddNX7gdLVBC4PQ3NA6h7drTm8ywgWjBeyJI8Ut5BTz1SCSlKzL8Pncq-67tdNsw-xlu8YVKDzuN_lYHUNyYPAu_xXKT9BGsuxmSrWY23QeQsR6mScE6BAfmxnDNkshIe-AiEkhpxUx6XkguIWOHHPj4xiFhnP3n1pt232J9O4Ck1cjWdLZWzWubT1faagfRI1XB7cdF',
                  ),
                ),
                const SizedBox(width: 10),
                InkWell(
                  onTap: () => Get.offAll<void>(
                    () => const LandingScreen(initialIndex: 0),
                  ),
                  borderRadius: BorderRadius.circular(999),
                  child: Row(
                    children: [
                      Image.asset(
                        AppAssets.brandLogo,
                        width: 30,
                        height: 30,
                        errorBuilder: (context, error, stackTrace) =>
                            const AppHeroIconData(
                              Icons.diamond_rounded,
                              color: AppColors.primary,
                            ),
                      ),
                      const SizedBox(width: 6),
                      Image.asset(
                        AppAssets.brandTextLogo,
                        height: 16,
                        errorBuilder: (context, error, stackTrace) => Text(
                          'StyleBite',
                          style: AppFonts.plusJakarta(
                            size: 16,
                            weight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () =>
                      _showToast('Streak boosted. Keep exploring.'),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF3F0EF),
                    minimumSize: const Size(40, 40),
                  ),
                  icon: const AppHeroIconData(
                    Icons.local_fire_department_rounded,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndCity() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F0EF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                const AppHeroIconData(
                  Icons.search_rounded,
                  color: Color(0xFF9A8F8A),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) {
                      setState(() {
                        _activeTag = '';
                      });
                    },
                    style: AppFonts.beVietnam(
                      size: 14,
                      weight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Users, tags, restaurants...',
                      hintStyle: AppFonts.beVietnam(
                        size: 13,
                        weight: FontWeight.w500,
                        color: const Color(0xFFAFADAC),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        PopupMenuButton<String>(
          onSelected: (value) {
            setState(() {
              _city = value;
            });
            _showToast('Switched to $value');
          },
          itemBuilder: (context) => _cities
              .map(
                (city) => PopupMenuItem<String>(
                  value: city,
                  child: Text(
                    city,
                    style: AppFonts.beVietnam(
                      size: 14,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              )
              .toList(growable: false),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.white,
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F0EF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                Text(
                  _city,
                  style: AppFonts.beVietnam(
                    size: 11,
                    weight: FontWeight.w800,
                    color: AppColors.hintText,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(width: 4),
                const AppHeroIconData(
                  Icons.expand_more_rounded,
                  color: AppColors.hintText,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopTabs() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _tabs.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tab = _tabs[index];
          final isActive = _activeTab == tab;
          return InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () {
              setState(() {
                _activeTab = tab;
                _forceAll = false;
              });
              _showToast('${_cap(tab)} tab selected');
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: isActive
                    ? const LinearGradient(
                        colors: [AppColors.primary, Color(0xFFFF8A5B)],
                      )
                    : null,
                color: isActive ? null : const Color(0xFFDFDCDC),
              ),
              child: Text(
                _cap(tab),
                style: AppFonts.beVietnam(
                  size: 13,
                  weight: FontWeight.w700,
                  color: isActive ? const Color(0xFFFFF7F3) : AppColors.text,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrending(List<_ExploreCardData> cards) {
    final first = cards.where((e) => e.isTall).toList(growable: false);
    final rest = cards.where((e) => !e.isTall).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                'Trending Now',
                style: AppFonts.plusJakarta(size: 32, weight: FontWeight.w800),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _forceAll = !_forceAll;
                });
                _showToast(_forceAll ? 'All categories on' : 'Tab filter on');
              },
              child: Text(
                _forceAll ? 'Tab Mode' : 'View All',
                style: AppFonts.beVietnam(
                  size: 13,
                  weight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: first.isNotEmpty
                  ? _TrendingCard(
                      card: first.first,
                      height: 292,
                      onTap: () =>
                          _openSheet(first.first.title, first.first.meta),
                    )
                  : const SizedBox.shrink(),
            ),
            if (rest.isNotEmpty) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    for (var i = 0; i < rest.length; i++) ...[
                      _TrendingCard(
                        card: rest[i],
                        height: 140,
                        onTap: () => _openSheet(rest[i].title, rest[i].meta),
                      ),
                      if (i != rest.length - 1) const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildFoodSection(List<_FoodCardData> cards) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: AppColors.primary.withValues(alpha: 0.12),
          ),
          child: Text(
            'CURATION',
            style: AppFonts.beVietnam(
              size: 10,
              weight: FontWeight.w800,
              letterSpacing: 1.6,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: Text(
                'Top in $_city',
                style: AppFonts.plusJakarta(size: 32, weight: FontWeight.w800),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: const Color(0xFFAFADAC).withValues(alpha: 0.24),
                ),
              ),
              child: Row(
                children: [
                  const AppHeroIconData(
                    Icons.tune_rounded,
                    size: 14,
                    color: AppColors.hintText,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Refine',
                    style: AppFonts.beVietnam(
                      size: 11,
                      weight: FontWeight.w700,
                      color: AppColors.hintText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 434,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cards.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final card = cards[index];
              return _FoodCard(
                card: card,
                onTap: () => _openSheet(card.title, card.meta),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTags() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'POPULAR TAGS',
          style: AppFonts.beVietnam(
            size: 11,
            weight: FontWeight.w700,
            letterSpacing: 2,
            color: AppColors.hintText,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _tags
              .map((tag) {
                final isActive = _activeTag == tag;
                return InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () {
                    setState(() {
                      _activeTag = _activeTag == tag ? '' : tag;
                      _searchController.text = _activeTag.isEmpty
                          ? ''
                          : '#$_activeTag';
                    });
                    _showToast(
                      _activeTag.isEmpty
                          ? 'Tag filter cleared'
                          : '#$_activeTag applied',
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFFAFADAC).withValues(alpha: 0.2),
                      ),
                      gradient: isActive
                          ? const LinearGradient(
                              colors: [AppColors.primary, Color(0xFFFF8A5B)],
                            )
                          : null,
                      color: isActive ? null : Colors.white,
                    ),
                    child: Text(
                      '#$tag',
                      style: AppFonts.beVietnam(
                        size: 12,
                        weight: FontWeight.w700,
                        color: isActive
                            ? const Color(0xFFFFF7F3)
                            : tag == 'streetwear'
                            ? AppColors.primary
                            : AppColors.hintText,
                      ),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F0EF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFAFADAC).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        children: [
          Text(
            'No matches found',
            style: AppFonts.beVietnam(
              size: 14,
              weight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Try another city, tag, or search keyword.',
            style: AppFonts.beVietnam(
              size: 12,
              weight: FontWeight.w500,
              color: AppColors.hintText,
            ),
          ),
        ],
      ),
    );
  }

  String _cap(String value) => value[0].toUpperCase() + value.substring(1);
}

class _TrendingCard extends StatelessWidget {
  const _TrendingCard({
    required this.card,
    required this.height,
    required this.onTap,
  });

  final _ExploreCardData card;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(card.imageUrl, fit: BoxFit.cover),
            if (card.isTall)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Color.fromRGBO(0, 0, 0, 0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: SizedBox(height: 90),
                ),
              ),
            if (card.isTall)
              Positioned(
                left: 12,
                bottom: 12,
                child: Text(
                  card.title,
                  style: AppFonts.beVietnam(
                    size: 14,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            if (card.showLiveBadge)
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD166),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'LIVE',
                    style: AppFonts.beVietnam(
                      size: 10,
                      weight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            if (card.showVs)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white.withValues(alpha: 0.2),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'VS',
                    style: AppFonts.plusJakarta(
                      size: 22,
                      weight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FoodCard extends StatelessWidget {
  const _FoodCard({required this.card, required this.onTap});

  final _FoodCardData card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final entries = card.scores.entries.toList(growable: false);
    final safeEntries = List<MapEntry<String, String>>.generate(
      4,
      (index) => index < entries.length
          ? entries[index]
          : const MapEntry('Metric', '--'),
      growable: false,
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 308,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8F4F3), Color(0xFFF1EEED)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(47, 47, 46, 0.15),
              blurRadius: 24,
              offset: Offset(0, 12),
              spreadRadius: -16,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 190,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(card.imageUrl, fit: BoxFit.cover),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: const [
                          BoxShadow(
                            color: Color.fromRGBO(47, 47, 46, 0.12),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                            spreadRadius: -6,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const AppHeroIconData(
                            Icons.star_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            card.rating.toStringAsFixed(1),
                            style: AppFonts.beVietnam(
                              size: 11,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.beVietnam(
                        size: 18,
                        weight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      card.meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.beVietnam(
                        size: 12,
                        weight: FontWeight.w500,
                        color: AppColors.hintText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: _ScoreTile(entry: safeEntries[0]),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _ScoreTile(entry: safeEntries[1]),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: _ScoreTile(entry: safeEntries[2]),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _ScoreTile(entry: safeEntries[3]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreTile extends StatelessWidget {
  const _ScoreTile({required this.entry});

  final MapEntry<String, String> entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFAFADAC).withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            entry.key.toUpperCase(),
            style: AppFonts.beVietnam(
              size: 9,
              weight: FontWeight.w700,
              color: AppColors.hintText,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            entry.value,
            style: AppFonts.beVietnam(
              size: 13,
              weight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExploreCardData {
  const _ExploreCardData({
    required this.title,
    required this.meta,
    required this.imageUrl,
    required this.categories,
    required this.cities,
    required this.searchable,
    this.isTall = false,
    this.showLiveBadge = false,
    this.showVs = false,
  });

  final String title;
  final String meta;
  final String imageUrl;
  final List<String> categories;
  final List<String> cities;
  final String searchable;
  final bool isTall;
  final bool showLiveBadge;
  final bool showVs;
}

class _FoodCardData {
  const _FoodCardData({
    required this.title,
    required this.meta,
    required this.imageUrl,
    required this.rating,
    required this.categories,
    required this.cities,
    required this.searchable,
    required this.scores,
  });

  final String title;
  final String meta;
  final String imageUrl;
  final double rating;
  final List<String> categories;
  final List<String> cities;
  final String searchable;
  final Map<String, String> scores;
}
