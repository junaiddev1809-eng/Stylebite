import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/states/app_shimmer_box.dart';
import '../../earnings/controllers/earnings_controller.dart';
import '../../earnings/widgets/earnings_widgets.dart';

class EarningsWithdrawalsScreen extends StatefulWidget {
  const EarningsWithdrawalsScreen({super.key});

  @override
  State<EarningsWithdrawalsScreen> createState() =>
      _EarningsWithdrawalsScreenState();
}

class _EarningsWithdrawalsScreenState extends State<EarningsWithdrawalsScreen> {
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
      _controller.ensureWithdrawalsLoaded();
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
      _controller.fetchWithdrawals(reset: false);
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
            if (_controller.isWithdrawalsInitialLoading.value &&
                _controller.withdrawals.isEmpty) {
              return _WithdrawalsShimmer(
                safeTop: safeTop,
                safeBottom: safeBottom,
              );
            }

            if (_controller.hasWithdrawalsError.value &&
                _controller.withdrawals.isEmpty) {
              return Center(
                child: EarningsEmptyCard(
                  message: _controller.withdrawalsErrorMessage.value,
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () => _controller.fetchWithdrawals(reset: true),
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(
                  16,
                  safeTop + 78,
                  16,
                  safeBottom + 24,
                ),
                itemCount: _controller.withdrawals.length + 1,
                itemBuilder: (context, index) {
                  if (index == _controller.withdrawals.length) {
                    return EarningsPaginationFooter(
                      isLoading: _controller.isWithdrawalsLoadingMore.value,
                      hasMore: _controller.hasMoreWithdrawals.value,
                    );
                  }

                  return Container(
                    margin: EdgeInsets.only(
                      bottom: index == _controller.withdrawals.length - 1
                          ? 0
                          : 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F0EF),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: EarningsWithdrawalTile(
                      item: _controller.withdrawals[index],
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
            child: EarningsTopBar(title: 'Recent Withdrawals'),
          ),
        ],
      ),
    );
  }
}

class _WithdrawalsShimmer extends StatelessWidget {
  const _WithdrawalsShimmer({required this.safeTop, required this.safeBottom});

  final double safeTop;
  final double safeBottom;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, safeTop + 78, 16, safeBottom + 24),
      itemCount: 5,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F0EF),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          children: [
            AppShimmerBox(
              width: 34,
              height: 34,
              borderRadius: BorderRadius.all(Radius.circular(999)),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppShimmerBox(
                    height: 13,
                    width: 145,
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  SizedBox(height: 6),
                  AppShimmerBox(
                    height: 10,
                    width: 120,
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
                  height: 13,
                  width: 90,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                SizedBox(height: 6),
                AppShimmerBox(
                  height: 10,
                  width: 60,
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
