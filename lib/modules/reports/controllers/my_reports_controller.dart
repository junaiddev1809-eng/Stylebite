import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_helper.dart';
import '../api/reports_api.dart';
import '../models/report_model.dart';

class MyReportsController extends GetxController {
  final RxList<ReportModel> reports = <ReportModel>[].obs;
  final RxBool isInitialLoading = true.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasError = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool hasMore = true.obs;

  final ScrollController scrollController = ScrollController();

  int _currentPage = 0;

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_onScroll);
    fetchReports(reset: true);
  }

  @override
  void onClose() {
    scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.onClose();
  }

  Future<void> fetchReports({required bool reset}) async {
    if (reset) {
      isInitialLoading.value = true;
      hasError.value = false;
      errorMessage.value = '';
      _currentPage = 0;
      hasMore.value = true;
    } else {
      if (isLoadingMore.value || !hasMore.value) {
        return;
      }
      isLoadingMore.value = true;
    }

    try {
      final page = reset ? 1 : _currentPage + 1;
      final response = await ReportsApi.fetchMine(page: page);
      if (reset) {
        reports.assignAll(response.reports);
      } else {
        reports.addAll(response.reports);
      }
      _currentPage = response.pagination.currentPage;
      hasMore.value = response.pagination.hasMorePages;
    } catch (error) {
      hasError.value = true;
      errorMessage.value = error.toString().replaceFirst('Exception: ', '');
      if (!reset) {
        errorSnackBar(message: errorMessage.value);
      }
    } finally {
      if (reset) {
        isInitialLoading.value = false;
      } else {
        isLoadingMore.value = false;
      }
    }
  }

  Future<void> refreshReports() => fetchReports(reset: true);

  void _onScroll() {
    if (!scrollController.hasClients) {
      return;
    }
    final position = scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 180) {
      fetchReports(reset: false);
    }
  }
}
