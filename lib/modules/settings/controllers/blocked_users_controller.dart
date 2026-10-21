import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/api_helper.dart';
import '../../../core/utils/app_helper.dart';
import '../models/blocked_user_model.dart';

class BlockedUsersController extends GetxController {
  final RxList<BlockedUserModel> users = <BlockedUserModel>[].obs;
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
    fetchBlockedUsers(reset: true);
  }

  @override
  void onClose() {
    scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.onClose();
  }

  Future<void> fetchBlockedUsers({required bool reset}) async {
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
      final response = await ApiHelper.fetchDataWithAuthorization(
        'profile/me/blocked-users?page=$page',
      );
      if (response == null) {
        throw Exception('No response returned from blocked users endpoint.');
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          payload['status_code'] != 1) {
        throw Exception(
          (payload['message'] ?? 'Unable to fetch blocked users').toString(),
        );
      }

      final parsed = BlockedUsersResponseModel.fromJson(payload);
      if (reset) {
        users.assignAll(parsed.users);
      } else {
        users.addAll(parsed.users);
      }
      _currentPage = parsed.pagination.currentPage;
      hasMore.value = parsed.pagination.hasMorePages;
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

  Future<void> refreshBlockedUsers() async {
    await fetchBlockedUsers(reset: true);
  }

  Future<void> toggleBlockedUser(BlockedUserModel user) async {
    final username = user.username.trim().replaceFirst('@', '');
    if (username.isEmpty) {
      return;
    }

    try {
      final response = await ApiHelper.postRequestWithAuthorization(
        'profiles/${Uri.encodeComponent(username)}/block',
        body: <String, dynamic>{},
      );
      if (response == null) {
        throw Exception('No response returned from block toggle endpoint.');
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          payload['status_code'] != 1) {
        throw Exception(
          (payload['message'] ?? 'Unable to update block status').toString(),
        );
      }

      users.removeWhere((item) => item.username == user.username);
      successSnackBar(
        message: (payload['message'] ?? 'Block status updated successfully.')
            .toString(),
      );
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _onScroll() {
    if (!scrollController.hasClients) {
      return;
    }
    final position = scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 180) {
      fetchBlockedUsers(reset: false);
    }
  }
}
