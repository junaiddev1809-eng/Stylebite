import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:heroicons/heroicons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/app_back_navigation.dart';
import '../../../core/utils/app_time_formatter.dart';
import '../../../core/widgets/states/app_shimmer_box.dart';
import '../controllers/my_reports_controller.dart';
import '../models/report_model.dart';

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  late final MyReportsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<MyReportsController>()
        ? Get.find<MyReportsController>()
        : Get.put(MyReportsController());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.88),
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
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: HeroIcon(
                        HeroIcons.arrowLeft,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'My Reports',
                        style: AppFonts.plusJakarta(
                          size: 20,
                          weight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: Obx(() {
                if (_controller.isInitialLoading.value &&
                    _controller.reports.isEmpty) {
                  return const _MyReportsShimmer();
                }

                if (_controller.hasError.value &&
                    _controller.reports.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _EmptyReportsState(
                        title: 'Could not load your reports',
                        subtitle: _controller.errorMessage.value,
                      ),
                    ),
                  );
                }

                if (_controller.reports.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: _EmptyReportsState(
                        title: 'No reports yet',
                        subtitle:
                            'Reports you submit will show up here so you can track their status.',
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _controller.refreshReports,
                  child: ListView.builder(
                    controller: _controller.scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    itemCount: _controller.reports.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _controller.reports.length) {
                        if (_controller.isLoadingMore.value) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (!_controller.hasMore.value) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            child: Center(
                              child: Text(
                                'No more data',
                                style: AppFonts.beVietnam(
                                  size: 12,
                                  weight: FontWeight.w600,
                                  color: AppColors.hintText,
                                ),
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }

                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == _controller.reports.length - 1
                              ? 0
                              : 10,
                        ),
                        child: _ReportCard(report: _controller.reports[index]),
                      );
                    },
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});

  final ReportModel report;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(47, 47, 46, 0.06),
            blurRadius: 18,
            offset: Offset(0, 8),
            spreadRadius: -10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _humanize(report.targetType),
                  style: AppFonts.plusJakarta(
                    size: 15,
                    weight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(status: report.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Reason: ${_humanize(report.reason)}',
            style: AppFonts.beVietnam(
              size: 12,
              weight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          if (report.description.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              report.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.beVietnam(
                size: 12,
                weight: FontWeight.w500,
                color: AppColors.hintText,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            AppTimeFormatter.formatCommentTime(report.createdAt),
            style: AppFonts.beVietnam(
              size: 11,
              weight: FontWeight.w600,
              color: AppColors.hintText,
            ),
          ),
        ],
      ),
    );
  }

  String _humanize(String value) {
    return value
        .split('_')
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        style.label,
        style: AppFonts.beVietnam(
          size: 10,
          weight: FontWeight.w800,
          color: style.color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  _StatusStyle _styleFor(String status) {
    switch (status) {
      case 'under_review':
        return const _StatusStyle('Under Review', Color(0xFFB8860B));
      case 'resolved':
        return const _StatusStyle('Resolved', Color(0xFF16A34A));
      case 'rejected':
        return const _StatusStyle('Rejected', Colors.redAccent);
      case 'open':
      default:
        return const _StatusStyle('Open', Color(0xFF2563EB));
    }
  }
}

class _StatusStyle {
  const _StatusStyle(this.label, this.color);

  final String label;
  final Color color;
}

class _EmptyReportsState extends StatelessWidget {
  const _EmptyReportsState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const HeroIcon(HeroIcons.flag, color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppFonts.plusJakarta(
              size: 17,
              weight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppFonts.beVietnam(
              size: 13,
              weight: FontWeight.w500,
              color: AppColors.hintText,
            ),
          ),
        ],
      ),
    );
  }
}

class _MyReportsShimmer extends StatelessWidget {
  const _MyReportsShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      itemCount: 6,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppShimmerBox(
                width: 120,
                height: 15,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              SizedBox(height: 8),
              AppShimmerBox(
                width: 92,
                height: 12,
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
              SizedBox(height: 8),
              AppShimmerBox(
                height: 12,
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
            ],
          ),
        );
      },
    );
  }
}
