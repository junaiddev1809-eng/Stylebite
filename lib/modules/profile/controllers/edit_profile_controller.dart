import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/api_helper.dart';
import '../../../core/utils/app_helper.dart';
import '../models/profile_model.dart';
import 'profile_controller.dart';

class EditProfileController extends GetxController {
  late final ProfileController profileController;

  final usernameController = TextEditingController();
  final fullNameController = TextEditingController();
  final displayNameController = TextEditingController();
  final headlineController = TextEditingController();
  final bioController = TextEditingController();
  final websiteController = TextEditingController();
  final cityController = TextEditingController();
  final countryController = TextEditingController();
  final birthDateController = TextEditingController();
  final phoneCountryCodeController = TextEditingController();
  final phoneNumberController = TextEditingController();
  final timezoneController = TextEditingController();

  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxBool isVerifying = false.obs;
  final RxBool isCheckingUsername = false.obs;

  final RxString selectedGender = ''.obs;
  final RxString selectedVisibility = 'public'.obs;
  final RxBool isPrivate = false.obs;
  final RxString usernameMessage = ''.obs;
  final RxBool isUsernameAvailable = false.obs;

  final Rxn<ProfileUserModel> user = Rxn<ProfileUserModel>();
  Timer? _usernameDebounce;
  String _initialUsername = '';

  @override
  void onInit() {
    super.onInit();
    profileController = Get.isRegistered<ProfileController>()
        ? Get.find<ProfileController>()
        : Get.put(ProfileController());

    final existingUser = profileController.user.value;
    if (existingUser != null) {
      _applyUser(existingUser);
    } else {
      loadProfile();
    }
  }

  @override
  void onClose() {
    _usernameDebounce?.cancel();
    usernameController.dispose();
    fullNameController.dispose();
    displayNameController.dispose();
    headlineController.dispose();
    bioController.dispose();
    websiteController.dispose();
    cityController.dispose();
    countryController.dispose();
    birthDateController.dispose();
    phoneCountryCodeController.dispose();
    phoneNumberController.dispose();
    timezoneController.dispose();
    super.onClose();
  }

  Future<void> loadProfile() async {
    if (isLoading.value) {
      return;
    }
    isLoading.value = true;
    try {
      await profileController.fetchProfileOverview(forceRefresh: true);
      final nextUser = profileController.user.value;
      if (nextUser != null) {
        _applyUser(nextUser);
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> saveProfile() async {
    if (isSaving.value) {
      return;
    }

    final trimmedUsername = usernameController.text.trim();
    if (trimmedUsername.isEmpty) {
      usernameMessage.value = 'Username is required.';
      isUsernameAvailable.value = false;
      return;
    }
    if (trimmedUsername != _initialUsername && !isUsernameAvailable.value) {
      usernameMessage.value = 'Please choose an available username.';
      return;
    }

    isSaving.value = true;
    try {
      final response = await ApiHelper.patchRequestWithAuthorization(
        'profile/me',
        body: <String, dynamic>{
          'username': usernameController.text.trim(),
          'full_name': fullNameController.text.trim(),
          'display_name': displayNameController.text.trim(),
          'headline': headlineController.text.trim(),
          'bio': bioController.text.trim(),
          'website_url': websiteController.text.trim(),
          'city': cityController.text.trim(),
          'country': countryController.text.trim(),
          'gender': selectedGender.value.trim().isEmpty
              ? null
              : selectedGender.value.trim(),
          'birth_date': birthDateController.text.trim(),
          'visibility': selectedVisibility.value,
          'is_private': isPrivate.value,
          'phone_country_code': phoneCountryCodeController.text.trim(),
          'phone_number': phoneNumberController.text.trim(),
          'timezone': timezoneController.text.trim(),
        },
      );

      if (response == null) {
        throw Exception('Unable to update profile.');
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          (payload.containsKey('status_code') && payload['status_code'] != 1)) {
        throw Exception(
          (payload['message'] ?? 'Unable to update profile').toString(),
        );
      }

      successSnackBar(
        message: (payload['message'] ?? 'Profile updated successfully.')
            .toString(),
      );
      await profileController.fetchProfileOverview(forceRefresh: true);
      final nextUser = profileController.user.value;
      if (nextUser != null) {
        _applyUser(nextUser);
      }
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> requestVerificationBadge() async {
    if (isVerifying.value) {
      return;
    }

    isVerifying.value = true;
    try {
      final response = await ApiHelper.postRequestWithAuthorization(
        'profile/me/verify',
      );
      if (response == null) {
        throw Exception('Unable to request verification.');
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          (payload.containsKey('status_code') && payload['status_code'] != 1)) {
        throw Exception(
          (payload['message'] ?? 'Unable to request verification').toString(),
        );
      }

      successSnackBar(
        message: (payload['message'] ?? 'Verification badge granted.')
            .toString(),
      );
      await profileController.fetchProfileOverview(forceRefresh: true);
      final nextUser = profileController.user.value;
      if (nextUser != null) {
        _applyUser(nextUser);
      }
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    } finally {
      isVerifying.value = false;
    }
  }

  Future<void> pickBirthDate(BuildContext context) async {
    final initialDate = _parseBirthDate() ?? DateTime(1995, 1, 15);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked == null) {
      return;
    }
    birthDateController.text = _formatDate(picked);
  }

  void _applyUser(ProfileUserModel nextUser) {
    user.value = nextUser;
    _initialUsername = nextUser.username;
    usernameController.text = nextUser.username;
    fullNameController.text = nextUser.fullName;
    displayNameController.text = nextUser.displayName;
    headlineController.text = nextUser.headline;
    bioController.text = nextUser.bio;
    websiteController.text = nextUser.websiteUrlOrEmpty;
    cityController.text = nextUser.city;
    countryController.text = nextUser.country;
    selectedGender.value = nextUser.genderOrEmpty;
    birthDateController.text = nextUser.birthDateOrEmpty;
    selectedVisibility.value = nextUser.visibility.isEmpty
        ? 'public'
        : nextUser.visibility;
    isPrivate.value = nextUser.isPrivate;
    phoneCountryCodeController.text = nextUser.phoneCountryCodeOrEmpty;
    phoneNumberController.text = nextUser.phoneNumberOrEmpty;
    timezoneController.text = nextUser.timezoneOrEmpty.isEmpty
        ? 'Asia/Karachi'
        : nextUser.timezoneOrEmpty;
    usernameMessage.value = '';
    isUsernameAvailable.value = true;
    isCheckingUsername.value = false;
  }

  void onUsernameChanged(String value) {
    _usernameDebounce?.cancel();

    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      usernameMessage.value = 'Username is required.';
      isUsernameAvailable.value = false;
      isCheckingUsername.value = false;
      return;
    }

    if (trimmed == _initialUsername) {
      usernameMessage.value = '';
      isUsernameAvailable.value = true;
      isCheckingUsername.value = false;
      return;
    }

    if (trimmed.length < 3) {
      usernameMessage.value = 'Username must be at least 3 characters.';
      isUsernameAvailable.value = false;
      isCheckingUsername.value = false;
      return;
    }

    isCheckingUsername.value = true;
    usernameMessage.value = '';
    isUsernameAvailable.value = false;

    _usernameDebounce = Timer(const Duration(milliseconds: 350), () {
      checkUsernameAvailability(trimmed);
    });
  }

  Future<void> checkUsernameAvailability(String username) async {
    try {
      final response = await ApiHelper.fetchDataWithAuthorization(
        'profile/me/username-availability?username=$username',
      );
      if (response == null) {
        throw Exception('Unable to check username availability.');
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          (payload.containsKey('status_code') && payload['status_code'] != 1)) {
        throw Exception(
          (payload['message'] ?? 'Unable to check username availability')
              .toString(),
        );
      }

      final latest = usernameController.text.trim();
      if (latest != username) {
        return;
      }

      final available = _resolveAvailability(payload);
      isUsernameAvailable.value = available;
      usernameMessage.value = (payload['message'] ?? '').toString();
    } catch (error) {
      final latest = usernameController.text.trim();
      if (latest != username) {
        return;
      }
      isUsernameAvailable.value = false;
      usernameMessage.value = error.toString().replaceFirst('Exception: ', '');
    } finally {
      final latest = usernameController.text.trim();
      if (latest == username) {
        isCheckingUsername.value = false;
      }
    }
  }

  bool _resolveAvailability(Map<String, dynamic> payload) {
    for (final key in <String>[
      'is_available',
      'available',
      'username_available',
    ]) {
      final value = payload[key];
      if (value is bool) {
        return value;
      }
      if (value is num) {
        return value != 0;
      }
      final normalized = value?.toString().toLowerCase().trim();
      if (normalized == 'true' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == '0') {
        return false;
      }
    }

    final data = payload['data'];
    if (data is Map<String, dynamic>) {
      return _resolveAvailability(data);
    }

    final message = (payload['message'] ?? '').toString().toLowerCase();
    if (message.contains('available')) {
      return true;
    }
    if (message.contains('taken') || message.contains('not available')) {
      return false;
    }
    return false;
  }

  DateTime? _parseBirthDate() {
    final raw = birthDateController.text.trim();
    if (raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  String _formatDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
