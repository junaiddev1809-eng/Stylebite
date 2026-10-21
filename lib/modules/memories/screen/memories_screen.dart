import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:stylebite/core/widgets/app_hero_icon.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/app_back_navigation.dart';
import '../controllers/memories_controller.dart';
import '../models/memory_item_model.dart';
import '../widgets/memory_featured_card.dart';
import 'add_memory_screen.dart';
import '../widgets/memory_filter_chips.dart';
import '../widgets/memory_list_card.dart';

class MemoriesScreen extends StatefulWidget {
  const MemoriesScreen({super.key});

  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen> {
  late final MemoriesController _controller;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<MemoriesController>()
        ? Get.find<MemoriesController>()
        : Get.put(MemoriesController());

    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_controller.isMoreLoading.value) {
      _controller.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => Get.to(() => const AddMemoryScreen()),
        elevation: 4,
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const AppHeroIconData(Icons.add_rounded, color: Colors.white, size: 28),
      ),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header Section
            Container(
              height: 72,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.92),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ),
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
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Memories',
                          style: AppFonts.plusJakarta(
                            size: 30,
                            weight: FontWeight.w800,
                            color: AppColors.text,
                            height: 1,
                          ),
                        ),
                        Text(
                          'Style moments you never want to lose',
                          style: AppFonts.beVietnam(
                            size: 11,
                            weight: FontWeight.w500,
                            color: AppColors.hintText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 26),
                children: [
                  // Top Banner Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFFEEF6), Color(0xFFF6EDF8)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 28,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD9EA),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const AppHeroIconData(
                                Icons.location_on_rounded,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Travel Memories',
                                style: AppFonts.beVietnam(
                                  size: 11,
                                  weight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your Journey in Looks',
                          style: AppFonts.plusJakarta(
                            size: 33,
                            weight: FontWeight.w800,
                            color: AppColors.text,
                            height: 1.06,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 290,
                          child: Text(
                            'Capture moments, outfits, and vibes from every place you visit.',
                            style: AppFonts.beVietnam(
                              size: 14,
                              weight: FontWeight.w500,
                              color: AppColors.hintText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Filter Chips
                  Obx(() => MemoryFilterChips(
                    active: _controller.currentFilter.value,
                    onChanged: _controller.setFilter,
                  )),
                  
                  const SizedBox(height: 12),
                  
                  // Main Content Area
                  Obx(() {
                    if (_controller.isLoading.value && _controller.memories.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 80),
                        child: Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      );
                    }

                    if (_controller.hasError.value && _controller.memories.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),
                            const Text('Failed to load memories'),
                            TextButton(
                              onPressed: _controller.refreshMemories,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }

                    final selected = _controller.selectedMemory;
                    final filtered = _controller.filteredMemories;

                    if (filtered.isEmpty && !_controller.isLoading.value) {
                      return _buildEmptyState();
                    }

                    return Column(
                      children: [
                        if (_controller.isLoading.value)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: LinearProgressIndicator(
                              backgroundColor: Colors.transparent,
                              color: AppColors.primary,
                              minHeight: 2,
                            ),
                          ),
                          
                        if (selected != null)
                          MemoryFeaturedCard(
                            memory: selected,
                            onTap: () => _openDetails(selected),
                            onFavoriteTap: () =>
                                _controller.toggleFavorite(selected.id),
                          ),
                        const SizedBox(height: 12),
                        ...filtered
                            .where((m) => m.id != selected?.id)
                            .map(
                              (memory) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: MemoryListCard(
                                  memory: memory,
                                  selected:
                                      memory.id ==
                                      _controller.selectedMemoryId.value,
                                  onTap: () {
                                    _controller.selectMemory(memory.id);
                                    _openDetails(memory);
                                  },
                                  onFavoriteTap: () =>
                                      _controller.toggleFavorite(memory.id),
                                ),
                              ),
                            ),
                      ],
                    );
                  }),
                  
                  // Load More Indicator
                  Obx(() => _controller.isMoreLoading.value
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      : const SizedBox.shrink()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final filter = _controller.currentFilter.value;
    String message;
    IconData icon;

    if (filter == 'all') {
      message = 'No memories found.\nStart capturing your style journey!';
      icon = Icons.auto_stories_outlined;
    } else if (filter == 'favorites') {
      message = 'No favorites yet.\nTap the heart icon to save your moments!';
      icon = Icons.favorite_border_rounded;
    } else if (filter == 'last_week') {
      message = 'No style moments found from the last 7 days.';
      icon = Icons.calendar_view_week_rounded;
    } else if (filter == 'last_month') {
      message = 'No style moments found from the last 30 days.';
      icon = Icons.calendar_month_rounded;
    } else {
      message = 'No memories found for $filter.';
      icon = Icons.event_note_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppHeroIconData(
            icon,
            size: 64,
            color: AppColors.hintText.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppFonts.beVietnam(
              size: 15,
              weight: FontWeight.w500,
              color: AppColors.hintText,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  void _openDetails(Memories? memory) {
    if (memory == null) return;

    final images = memory.images ?? [];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        int currentImageIndex = 0;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                margin: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 20,
                ),
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Image Section with CachedNetworkImage
                          Stack(
                            children: [
                              SizedBox(
                                height: 420,
                                width: double.infinity,
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(32),
                                  ),
                                  child: images.isEmpty
                                      ? const DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: Color(0xFFE9E6E6),
                                          ),
                                          child: AppHeroIconData(
                                            Icons.image_not_supported_outlined,
                                            size: 48,
                                          ),
                                        )
                                      : PageView.builder(
                                          itemCount: images.length,
                                          onPageChanged: (index) =>
                                              setModalState(
                                                () => currentImageIndex = index,
                                              ),
                                          itemBuilder: (context, index) =>
                                              CachedNetworkImage(
                                                imageUrl: images[index].fileUrl ?? '',
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) => Container(
                                                  color: const Color(0xFFF3F0EF),
                                                  child: const Center(
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: AppColors.primary,
                                                    ),
                                                  ),
                                                ),
                                                errorWidget: (context, url, error) => const DecoratedBox(
                                                  decoration: BoxDecoration(color: Color(0xFFE9E6E6)),
                                                  child: AppHeroIconData(Icons.image_not_supported_outlined),
                                                ),
                                              ),
                                        ),
                                ),
                              ),
                              // Close Button
                              Positioned(
                                top: 20,
                                right: 20,
                                child: GestureDetector(
                                  onTap: AppBackNavigation.handleBack,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.4,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const AppHeroIconData(
                                      Icons.close_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                              // Image Indicators
                              if (images.length > 1)
                                Positioned(
                                  bottom: 30,
                                  left: 0,
                                  right: 0,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(images.length, (
                                      index,
                                    ) {
                                      final isActive =
                                          index == currentImageIndex;
                                      return AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        width: isActive ? 24 : 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? Colors.white
                                              : Colors.white.withValues(
                                                  alpha: 0.5,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                            ],
                          ),

                          // Content Section
                          Transform.translate(
                            offset: const Offset(0, -20),
                            child: Container(
                              width: double.infinity,
                              decoration: const BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(24),
                                ),
                              ),
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                24,
                                20,
                                100,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.secondary.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          memory.location ?? 'Unknown',
                                          style: AppFonts.beVietnam(
                                            size: 11,
                                            weight: FontWeight.w700,
                                            color: AppColors.secondary,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        memory.memoryDate ?? '',
                                        style: AppFonts.beVietnam(
                                          size: 13,
                                          weight: FontWeight.w600,
                                          color: AppColors.hintText,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    memory.title ?? '',
                                    style: AppFonts.plusJakarta(
                                      size: 32,
                                      weight: FontWeight.w800,
                                      color: AppColors.text,
                                      height: 1.1,
                                    ),
                                  ),
                                  if (memory.note != null &&
                                      memory.note!.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      memory.note!,
                                      style: AppFonts.beVietnam(
                                        size: 16,
                                        weight: FontWeight.w500,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 20),
                                  const Divider(height: 1),
                                  const SizedBox(height: 20),
                                  Text(
                                    'The Story',
                                    style: AppFonts.plusJakarta(
                                      size: 18,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    memory.description ??
                                        'No description provided.',
                                    style: AppFonts.beVietnam(
                                      size: 15,
                                      weight: FontWeight.w400,
                                      color: AppColors.text.withValues(
                                        alpha: 0.8,
                                      ),
                                      height: 1.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Actions
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Container(
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    AppColors.secondary,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.3,
                                    ),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: () {
                                  AppBackNavigation.handleBack();
                                  Get.to(() => AddMemoryScreen(memory: memory));
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  'Edit Memory',
                                  style: AppFonts.beVietnam(
                                    size: 16,
                                    weight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => _handleDelete(memory),
                            child: Container(
                              height: 56,
                              width: 56,
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const AppHeroIconData(
                                Icons.delete_outline_rounded,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleDelete(Memories memory) async {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 24),
            AppHeroIconData(
              Icons.delete_forever_rounded,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Delete Memory?',
              style: AppFonts.plusJakarta(size: 24, weight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to remove this style moment? This cannot be undone.',
              textAlign: TextAlign.center,
              style: AppFonts.beVietnam(
                size: 15,
                color: AppColors.hintText,
                weight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: AppBackNavigation.handleBack,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      'Nah, keep it',
                      style: AppFonts.beVietnam(
                        size: 16,
                        weight: FontWeight.w700,
                        color: AppColors.hintText,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ElevatedButton(
                      onPressed: () async {
                        AppBackNavigation.handleBack();
                        final success = await _controller.deleteMemory(
                          memory.id!,
                        );
                        if (success && Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        'Delete It',
                        style: AppFonts.beVietnam(
                          size: 16,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }
}
