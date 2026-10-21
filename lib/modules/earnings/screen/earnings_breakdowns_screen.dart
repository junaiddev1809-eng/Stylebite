import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/states/app_shimmer_box.dart';
import '../../earnings/controllers/earnings_controller.dart';
import '../../earnings/widgets/earnings_widgets.dart';

class EarningsBreakdownsScreen extends StatefulWidget {
  const EarningsBreakdownsScreen({super.key});

  @override
  State<EarningsBreakdownsScreen> createState() =>
      _EarningsBreakdownsScreenState();
}

class _EarningsBreakdownsScreenState extends State<EarningsBreakdownsScreen> {
  late final EarningsController _controller;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<EarningsController>()
        ? Get.find<EarningsController>()
        : Get.put(EarningsController());
    _scrollController = ScrollController()..addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.ensureBreakdownsLoaded();
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 180) {
      _controller.fetchBreakdowns(reset: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Obx(() {
            if (_controller.isBreakdownsInitialLoading.value &&
                _controller.breakdowns.isEmpty) {
              return _BreakdownsShimmer(
                safeTop: safeTop,
                safeBottom: safeBottom,
              );
            }

            if (_controller.hasBreakdownsError.value &&
                _controller.breakdowns.isEmpty) {
              return Center(
                child: EarningsEmptyCard(
                  message: _controller.breakdownsErrorMessage.value,
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () => _controller.fetchBreakdowns(reset: true),
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(
                  16,
                  safeTop + 78,
                  16,
                  safeBottom + 24,
                ),
                itemCount: _controller.breakdowns.length + 1,
                itemBuilder: (context, index) {
                  if (index == _controller.breakdowns.length) {
                    return EarningsPaginationFooter(
                      isLoading: _controller.isBreakdownsLoadingMore.value,
                      hasMore: _controller.hasMoreBreakdowns.value,
                    );
                  }

                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == _controller.breakdowns.length - 1
                          ? 0
                          : 8,
                    ),
                    child: EarningsBreakdownTile(
                      item: _controller.breakdowns[index],
                    ),
                  );
                },
              ),
            );
          }),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: EarningsTopBar(title: 'Earning Breakdown'),
          ),
        ],
      ),
    );
  }
}

class _BreakdownsShimmer extends StatelessWidget {
  const _BreakdownsShimmer({required this.safeTop, required this.safeBottom});

  final double safeTop;
  final double safeBottom;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, safeTop + 78, 16, safeBottom + 24),
      itemCount: 7,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            AppShimmerBox(
              width: 46,
              height: 46,
              borderRadius: BorderRadius.all(Radius.circular(999)),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppShimmerBox(
                    height: 14,
                    width: 118,
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  SizedBox(height: 6),
                  AppShimmerBox(
                    height: 11,
                    width: 170,
                    borderRadius: BorderRadius.all(Radius.circular(6)),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AppShimmerBox(
                  height: 14,
                  width: 84,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                SizedBox(height: 6),
                AppShimmerBox(
                  height: 10,
                  width: 54,
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
