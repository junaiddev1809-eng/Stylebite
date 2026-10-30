import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/app_back_navigation.dart';
import '../../../core/widgets/states/app_shimmer_box.dart';
import '../../earnings/controllers/earnings_controller.dart';
import '../../earnings/widgets/earnings_widgets.dart';

class WithdrawRequestScreen extends StatelessWidget {
  WithdrawRequestScreen({super.key})
    : _controller = Get.isRegistered<EarningsController>()
          ? Get.find<EarningsController>()
          : Get.put(EarningsController());

  final EarningsController _controller;

  Future<void> _submit() async {
    final success = await _controller.submitWithdrawalRequest();
    if (success) {
      AppBackNavigation.handleBack();
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
            if (_controller.isOverviewLoading.value &&
                _controller.summary.value == null) {
              return _WithdrawRequestShimmer(
                safeTop: safeTop,
                safeBottom: safeBottom,
              );
            }

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                safeTop + 78,
                16,
                safeBottom + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromRGBO(255, 77, 109, 0.12),
                          blurRadius: 40,
                          offset: Offset(0, 12),
                          spreadRadius: -12,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Available Balance',
                          style: AppFonts.beVietnam(
                            size: 13,
                            weight: FontWeight.w600,
                            color: AppColors.hintText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _controller.availableBalanceDisplay,
                          style: AppFonts.plusJakarta(
                            size: 30,
                            weight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Pending: ${_controller.pendingBalanceDisplay}',
                          style: AppFonts.beVietnam(
                            size: 12,
                            weight: FontWeight.w500,
                            color: AppColors.hintText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _WithdrawField(
                    label: 'Amount',
                    controller: _controller.amountController,
                    keyboardType: TextInputType.number,
                    hintText: 'Enter withdrawal amount',
                  ),
                  const SizedBox(height: 14),
                  _WithdrawDropdown(
                    value: _controller.selectedWithdrawalMethod.value,
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      _controller.selectedWithdrawalMethod.value = value;
                    },
                  ),
                  const SizedBox(height: 14),
                  _WithdrawField(
                    label: 'Bank Name',
                    controller: _controller.bankNameController,
                    hintText: 'e.g. HBL, Meezan Bank',
                  ),
                  const SizedBox(height: 14),
                  _WithdrawField(
                    label: 'Bank Account Number',
                    controller: _controller.bankAccountNumberController,
                    keyboardType: TextInputType.text,
                    hintText: 'Enter account / IBAN number',
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.secondary],
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: ElevatedButton(
                        onPressed: _controller.isSubmittingWithdrawal.value
                            ? null
                            : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          disabledBackgroundColor: Colors.transparent,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: _controller.isSubmittingWithdrawal.value
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                'Submit Withdrawal',
                                style: AppFonts.plusJakarta(
                                  size: 18,
                                  weight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: EarningsTopBar(title: 'Withdraw'),
          ),
        ],
      ),
    );
  }
}

class _WithdrawRequestShimmer extends StatelessWidget {
  const _WithdrawRequestShimmer({
    required this.safeTop,
    required this.safeBottom,
  });

  final double safeTop;
  final double safeBottom;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, safeTop + 78, 16, safeBottom + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(255, 77, 109, 0.12),
                  blurRadius: 40,
                  offset: Offset(0, 12),
                  spreadRadius: -12,
                ),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppShimmerBox(
                  height: 13,
                  width: 110,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                SizedBox(height: 8),
                AppShimmerBox(
                  height: 32,
                  width: 180,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                SizedBox(height: 8),
                AppShimmerBox(
                  height: 12,
                  width: 94,
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _WithdrawFieldShimmer(),
          const SizedBox(height: 14),
          const _WithdrawFieldShimmer(),
          const SizedBox(height: 14),
          const _WithdrawFieldShimmer(),
          const SizedBox(height: 14),
          const _WithdrawFieldShimmer(),
          const SizedBox(height: 22),
          const AppShimmerBox(
            height: 50,
            borderRadius: BorderRadius.all(Radius.circular(999)),
          ),
        ],
      ),
    );
  }
}

class _WithdrawFieldShimmer extends StatelessWidget {
  const _WithdrawFieldShimmer();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppShimmerBox(
          height: 13,
          width: 92,
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        SizedBox(height: 8),
        AppShimmerBox(
          height: 52,
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ],
    );
  }
}

class _WithdrawField extends StatelessWidget {
  const _WithdrawField({
    required this.label,
    required this.controller,
    required this.hintText,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppFonts.beVietnam(
            size: 13,
            weight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AppFonts.beVietnam(
              size: 13,
              weight: FontWeight.w500,
              color: AppColors.hintText,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _WithdrawDropdown extends StatelessWidget {
  const _WithdrawDropdown({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Method',
          style: AppFonts.beVietnam(
            size: 13,
            weight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              borderRadius: BorderRadius.circular(16),
              items: const [
                DropdownMenuItem<String>(
                  value: 'bank_transfer',
                  child: Text('Bank Transfer'),
                ),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
