import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/api_helper.dart';
import '../../../core/utils/app_helper.dart';
import '../models/earnings_model.dart';

class EarningsController extends GetxController {
  final Rxn<EarningsSummaryModel> summary = Rxn<EarningsSummaryModel>();
  final RxList<EarningTransactionModel> breakdownPreview =
      <EarningTransactionModel>[].obs;
  final RxList<EarningsWithdrawalModel> withdrawalsPreview =
      <EarningsWithdrawalModel>[].obs;

  final Rxn<AdEligibilityModel> eligibility = Rxn<AdEligibilityModel>();
  final RxBool isEligibilityLoading = false.obs;
  final RxBool isTogglingAds = false.obs;

  final RxList<EarningTransactionModel> breakdowns =
      <EarningTransactionModel>[].obs;
  final RxList<EarningsWithdrawalModel> withdrawals =
      <EarningsWithdrawalModel>[].obs;

  final RxBool isOverviewLoading = false.obs;
  final RxBool hasOverviewError = false.obs;
  final RxString overviewErrorMessage = ''.obs;

  final RxBool isBreakdownsInitialLoading = false.obs;
  final RxBool isBreakdownsLoadingMore = false.obs;
  final RxBool hasBreakdownsError = false.obs;
  final RxString breakdownsErrorMessage = ''.obs;
  final RxBool hasMoreBreakdowns = true.obs;

  final RxBool isWithdrawalsInitialLoading = false.obs;
  final RxBool isWithdrawalsLoadingMore = false.obs;
  final RxBool hasWithdrawalsError = false.obs;
  final RxString withdrawalsErrorMessage = ''.obs;
  final RxBool hasMoreWithdrawals = true.obs;

  final TextEditingController amountController = TextEditingController();
  final TextEditingController accountRefController = TextEditingController();
  final RxString selectedWithdrawalMethod = 'bank_transfer'.obs;
  final RxBool isSubmittingWithdrawal = false.obs;

  int _breakdownsCurrentPage = 0;
  int _withdrawalsCurrentPage = 0;

  EarningsSummaryModel get currentSummary =>
      summary.value ??
      const EarningsSummaryModel(
        currencyCode: 'PKR',
        availableBalance: 0,
        pendingBalance: 0,
        contestWins: 0,
        lastMonthIncomeChangePercent: 0,
        lastMonthIncomeChangeDisplay: '0%',
        lastMonthIncomeAmount: 0,
        adEarnings: 0,
      );

  @override
  void onInit() {
    super.onInit();
    fetchOverview();
    fetchEligibility();
  }

  @override
  void onClose() {
    amountController.dispose();
    accountRefController.dispose();
    super.onClose();
  }

  String get availableBalanceDisplay => formatMoney(
    currentSummary.currencyCode,
    currentSummary.availableBalance,
  );

  String get pendingBalanceDisplay => formatMoney(
    currentSummary.currencyCode,
    currentSummary.pendingBalance,
  );

  String get adEarningsDisplay => formatMoney(
    currentSummary.currencyCode,
    currentSummary.adEarnings,
  );

  String get lastMonthChangeDisplay {
    final provided = currentSummary.lastMonthIncomeChangeDisplay.trim();
    if (provided.isNotEmpty) {
      return provided;
    }
    final percent = currentSummary.lastMonthIncomeChangePercent;
    if (percent > 0) {
      return '+${_formatCompactDecimal(percent)}%';
    }
    return '${_formatCompactDecimal(percent)}%';
  }

  Future<void> fetchOverview({bool forceRefresh = false}) async {
    if (isOverviewLoading.value && !forceRefresh) {
      return;
    }

    isOverviewLoading.value = true;
    hasOverviewError.value = false;
    overviewErrorMessage.value = '';

    try {
      final payload = await _getPayload('earnings/overview');
      final parsed = EarningsOverviewResponseModel.fromJson(payload);
      summary.value = parsed.summary;
      breakdownPreview.assignAll(parsed.earningBreakdownPreview);
      withdrawalsPreview.assignAll(parsed.recentWithdrawals);
    } catch (error) {
      hasOverviewError.value = true;
      overviewErrorMessage.value = error.toString().replaceFirst(
        'Exception: ',
        '',
      );
    } finally {
      isOverviewLoading.value = false;
    }
  }

  Future<void> fetchEligibility() async {
    isEligibilityLoading.value = true;
    try {
      final response = await ApiHelper.fetchDataWithAuthorization('ads/eligibility');
      if (response != null && response.statusCode == 200) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        if (payload['status_code'] == 1 || payload['status_code'] == '1') {
          eligibility.value = AdEligibilityModel.fromJson(payload['data'] ?? payload);
        }
      }
    } catch (e) {
      debugPrint('Error fetching eligibility: $e');
    } finally {
      isEligibilityLoading.value = false;
    }
  }

  Future<void> toggleAds(bool enable) async {
    if (isTogglingAds.value) return;

    // Optimistic UI update
    final current = eligibility.value;
    if (current == null) return;
    
    eligibility.value = AdEligibilityModel(
      isEligible: current.isEligible,
      adsEnabled: enable,
      requirements: current.requirements,
    );

    isTogglingAds.value = true;
    try {
      final response = await ApiHelper.postRequestWithAuthorization(
        'ads/toggle',
        body: {'enabled': enable},
      );
      
      if (response == null || response.statusCode != 200) {
        throw Exception('Failed to update ad settings');
      }
      
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (payload['status_code'] != 1 && payload['status_code'] != '1') {
        throw Exception(payload['message'] ?? 'Failed to update ad settings');
      }

      successSnackBar(message: enable ? 'Ads enabled successfully' : 'Ads disabled');
    } catch (e) {
      // Revert on error
      eligibility.value = current;
      errorSnackBar(message: e.toString().replaceFirst('Exception: ', ''));
    } finally {
      isTogglingAds.value = false;
    }
  }

  Future<void> refreshOverview() async {
    await Future.wait([
      fetchOverview(forceRefresh: true),
      fetchEligibility(),
    ]);
  }

  Future<void> ensureBreakdownsLoaded() async {
    if (breakdowns.isNotEmpty || isBreakdownsInitialLoading.value) {
      return;
    }
    await fetchBreakdowns(reset: true);
  }

  Future<void> ensureWithdrawalsLoaded() async {
    if (withdrawals.isNotEmpty || isWithdrawalsInitialLoading.value) {
      return;
    }
    await fetchWithdrawals(reset: true);
  }

  Future<void> fetchBreakdowns({required bool reset}) async {
    if (reset) {
      isBreakdownsInitialLoading.value = true;
      hasBreakdownsError.value = false;
      breakdownsErrorMessage.value = '';
      _breakdownsCurrentPage = 0;
      hasMoreBreakdowns.value = true;
    } else {
      if (isBreakdownsLoadingMore.value || !hasMoreBreakdowns.value) {
        return;
      }
      isBreakdownsLoadingMore.value = true;
    }

    try {
      final page = reset ? 1 : _breakdownsCurrentPage + 1;
      final payload = await _getPayload('earnings/breakdowns?page=$page');
      final parsed = EarningsBreakdownsResponseModel.fromJson(payload);
      if (reset) {
        breakdowns.assignAll(parsed.breakdowns);
      } else {
        breakdowns.addAll(parsed.breakdowns);
      }
      _breakdownsCurrentPage = parsed.pagination.currentPage;
      hasMoreBreakdowns.value = parsed.pagination.hasMorePages;
    } catch (error) {
      hasBreakdownsError.value = true;
      breakdownsErrorMessage.value = error.toString().replaceFirst(
        'Exception: ',
        '',
      );
      if (!reset) {
        errorSnackBar(message: breakdownsErrorMessage.value);
      }
    } finally {
      if (reset) {
        isBreakdownsInitialLoading.value = false;
      } else {
        isBreakdownsLoadingMore.value = false;
      }
    }
  }

  Future<void> fetchWithdrawals({required bool reset}) async {
    if (reset) {
      isWithdrawalsInitialLoading.value = true;
      hasWithdrawalsError.value = false;
      withdrawalsErrorMessage.value = '';
      _withdrawalsCurrentPage = 0;
      hasMoreWithdrawals.value = true;
    } else {
      if (isWithdrawalsLoadingMore.value || !hasMoreWithdrawals.value) {
        return;
      }
      isWithdrawalsLoadingMore.value = true;
    }

    try {
      final page = reset ? 1 : _withdrawalsCurrentPage + 1;
      final payload = await _getPayload('earnings/withdrawals?page=$page');
      final parsed = EarningsWithdrawalsResponseModel.fromJson(payload);
      if (reset) {
        withdrawals.assignAll(parsed.withdrawals);
      } else {
        withdrawals.addAll(parsed.withdrawals);
      }
      _withdrawalsCurrentPage = parsed.pagination.currentPage;
      hasMoreWithdrawals.value = parsed.pagination.hasMorePages;
    } catch (error) {
      hasWithdrawalsError.value = true;
      withdrawalsErrorMessage.value = error.toString().replaceFirst(
        'Exception: ',
        '',
      );
      if (!reset) {
        errorSnackBar(message: withdrawalsErrorMessage.value);
      }
    } finally {
      if (reset) {
        isWithdrawalsInitialLoading.value = false;
      } else {
        isWithdrawalsLoadingMore.value = false;
      }
    }
  }

  Future<bool> submitWithdrawalRequest() async {
    if (isSubmittingWithdrawal.value) {
      return false;
    }

    final rawAmount = amountController.text.trim().replaceAll(',', '');
    final accountRef = accountRefController.text.trim();
    final amount = int.tryParse(rawAmount);

    if (amount == null || amount <= 0) {
      errorSnackBar(message: 'Please enter a valid withdrawal amount.');
      return false;
    }
    if (accountRef.isEmpty) {
      errorSnackBar(message: 'Please enter an account reference.');
      return false;
    }
    if (amount > currentSummary.availableBalance) {
      errorSnackBar(
        message: 'Insufficient available balance for this withdrawal request.',
      );
      return false;
    }

    isSubmittingWithdrawal.value = true;
    try {
      final response = await ApiHelper.postRequestWithAuthorization(
        'earnings/withdrawals',
        body: <String, dynamic>{
          'amount': amount,
          'method': selectedWithdrawalMethod.value,
          'account_ref': accountRef,
        },
      );
      if (response == null) {
        throw Exception('No response returned from withdrawal endpoint.');
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          (payload['status_code'] != 1 && payload['status_code'] != '1')) {
        throw Exception(
          (payload['message'] ?? 'Failed to submit withdrawal request')
              .toString(),
        );
      }

      final parsed = WithdrawalRequestResponseModel.fromJson(payload);
      final previousSummary = currentSummary;
      summary.value = previousSummary.copyWith(
        currencyCode: parsed.wallet.currencyCode,
        availableBalance: parsed.wallet.availableBalance,
        pendingBalance: parsed.wallet.pendingBalance,
      );

      withdrawalsPreview.insert(0, parsed.withdrawal);
      if (withdrawalsPreview.length > 3) {
        withdrawalsPreview.removeRange(3, withdrawalsPreview.length);
      }

      if (withdrawals.isNotEmpty) {
        withdrawals.insert(0, parsed.withdrawal);
      }

      breakdownPreview.insert(0, parsed.transaction);
      if (breakdownPreview.length > 3) {
        breakdownPreview.removeRange(3, breakdownPreview.length);
      }

      if (breakdowns.isNotEmpty) {
        breakdowns.insert(0, parsed.transaction);
      }

      amountController.clear();
      accountRefController.clear();
      selectedWithdrawalMethod.value = 'bank_transfer';
      successSnackBar(message: 'Withdrawal request submitted successfully.');
      await fetchOverview(forceRefresh: true);
      return true;
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
      return false;
    } finally {
      isSubmittingWithdrawal.value = false;
    }
  }

  Future<Map<String, dynamic>> _getPayload(String endpoint) async {
    final response = await ApiHelper.fetchDataWithAuthorization(endpoint);
    if (response == null) {
      throw Exception('No response returned from earnings endpoint.');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        (payload['status_code'] != 1 && payload['status_code'] != '1')) {
      throw Exception((payload['message'] ?? 'Request failed').toString());
    }
    return payload;
  }

  static String formatMoney(String currencyCode, double amount, {bool signed = false}) {
    final buffer = StringBuffer();
    if (signed) {
      buffer.write(amount >= 0 ? '+ ' : '- ');
    }
    
    final code = currencyCode.toUpperCase();
    final symbol = _currencySymbols[code] ?? '$code ';
    
    buffer
      ..write(symbol)
      ..write(_formatAmountValue(amount.abs(), code));
    return buffer.toString();
  }

  static String _formatAmountValue(num value, String currencyCode) {
    final isDecimalCurrency = !['PKR', 'INR', 'AED', 'SAR', 'QAR', 'KWD', 'BHD', 'OMR'].contains(currencyCode);
    
    if (!isDecimalCurrency) {
      final rounded = value.round().toString();
      return _addThousandSeparators(rounded);
    } else {
      final fixed = value.toStringAsFixed(2);
      final parts = fixed.split('.');
      return '${_addThousandSeparators(parts[0])}.${parts[1]}';
    }
  }

  static String _addThousandSeparators(String digits) {
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      final reverseIndex = digits.length - index;
      buffer.write(digits[index]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }

  String _formatCompactDecimal(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  static const Map<String, String> _currencySymbols = {
    'PKR': 'Rs. ',
    'INR': '₹',
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'AED': 'AED ',
    'SAR': 'SAR ',
    'QAR': 'QAR ',
    'KWD': 'KWD ',
    'BHD': 'BHD ',
    'OMR': 'OMR ',
    'CAD': 'CAD',
    'AUD': 'AUD',
    'TRY': '₺',
    'MYR': 'RM ',
    'IDR': 'Rp ',
    'SGD': 'SGD',
    'CNY': '¥',
    'JPY': '¥',
    'BDT': '৳',
  };
}
