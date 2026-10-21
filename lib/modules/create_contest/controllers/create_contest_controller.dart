import 'package:flutter/material.dart';
import 'package:stylebite/core/widgets/app_hero_icon.dart';
import 'package:get/get.dart' hide FormData;

import '../../../core/media/media_picker_service.dart';
import '../../../core/media/picked_media.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/app_helper.dart';
import '../../../core/utils/app_back_navigation.dart';
import '../../../modules/contest/api/contest_api.dart';
import '../../../modules/contest/controllers/contest_controller.dart';
import '../../../modules/profile/controllers/profile_controller.dart';
import '../models/create_contest_model.dart';

class CreateContestController extends GetxController {
  static const int cityContestMinimumFollowers = 1000;

  final Rxn<CreateContestType> selectedType = Rxn<CreateContestType>();
  final RxInt activeStep = 1.obs;

  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController tagsController = TextEditingController();
  final TextEditingController votingEndController = TextEditingController();
  final TextEditingController enrollmentEndController = TextEditingController();
  final TextEditingController maxParticipantsController =
      TextEditingController();

  final RxString challengeScope = 'followers_only'.obs;
  final Rxn<DateTime> votingEndAt = Rxn<DateTime>();
  final Rxn<DateTime> enrollmentEndAt = Rxn<DateTime>();
  final RxList<int> selectedOpponentIds = <int>[].obs;
  final RxString cityOne = ''.obs;
  final RxString cityTwo = ''.obs;
  final RxString tagQuery = ''.obs;
  final RxList<String> tags = <String>[].obs;
  final RxInt formTick = 0.obs;

  final Rxn<PickedMedia> coverAsset = Rxn<PickedMedia>();
  final Rxn<PickedMedia> participantAsset = Rxn<PickedMedia>();

  final List<ContestTypeOption> typeOptions = const [
    ContestTypeOption(
      type: CreateContestType.oneVsOne,
      title: '1v1 Battle',
      description: 'Face-to-face style showdown between two creators.',
      icon: 'swords',
    ),
    ContestTypeOption(
      type: CreateContestType.city,
      title: 'City vs City',
      description: 'Represent your city against another fashion scene.',
      icon: 'location_city',
    ),
  ];

  final List<ContestRuleCardModel> ruleCards = const [
    ContestRuleCardModel(label: 'Format', value: '1v1 / City', icon: 'timer'),
    ContestRuleCardModel(
      label: 'Enrollment',
      value: 'Configurable',
      icon: 'timer',
    ),
    ContestRuleCardModel(
      label: 'Voting',
      value: 'Configurable',
      icon: 'how_to_vote',
    ),
  ];

  ContestController get _contestController => Get.find<ContestController>();

  bool get isSubmittingContest =>
      _contestController.isCreatingOneVsOne.value ||
      _contestController.isCreatingCity.value;

  ProfileController get _profileController =>
      Get.isRegistered<ProfileController>()
      ? Get.find<ProfileController>()
      : Get.put(ProfileController());

  @override
  void onInit() {
    super.onInit();
    _contestController.fetchTags();
    _contestController.fetchCities();
    _contestController.fetchUsers(scope: challengeScope.value);
  }

  Future<void> setType(CreateContestType type) async {
    if (type == CreateContestType.city &&
        !await _canCreateCityContest(showMessage: true)) {
      return;
    }

    selectedType.value = type;
  }

  void setStep(int step) {
    activeStep.value = step.clamp(1, 3);
  }

  Future<void> refreshOpponents() {
    return _contestController.fetchUsers(scope: challengeScope.value);
  }

  Future<void> pickCoverAsset({required bool fromCamera}) async {
    coverAsset.value = fromCamera
        ? await MediaPickerService.pickFromCamera()
        : await MediaPickerService.pickFromGallery();
  }

  Future<void> pickParticipantAsset({required bool fromCamera}) async {
    participantAsset.value = fromCamera
        ? await MediaPickerService.pickFromCamera()
        : await MediaPickerService.pickFromGallery();
  }

  Future<bool> submitContest() async {
    if (isSubmittingContest) {
      return false;
    }

    if (selectedType.value == null) {
      errorSnackBar(message: 'Please select contest type.');
      return false;
    }
    if (titleController.text.trim().isEmpty) {
      errorSnackBar(message: 'Title is required.');
      return false;
    }
    if (descriptionController.text.trim().isEmpty) {
      errorSnackBar(message: 'Description is required.');
      return false;
    }
    if (votingEndAt.value == null) {
      errorSnackBar(message: 'Please select voting end date and time.');
      return false;
    }

    final tagValues = tags
        .map((e) => e.trim().replaceAll('#', ''))
        .where((e) => e.isNotEmpty)
        .join(',');

    if (selectedType.value == CreateContestType.oneVsOne) {
      if (selectedOpponentIds.isEmpty) {
        errorSnackBar(message: 'Please select at least one opponent.');
        return false;
      }
      if (coverAsset.value == null) {
        errorSnackBar(message: 'Cover asset is required.');
        return false;
      }
      if (participantAsset.value == null) {
        errorSnackBar(message: 'Participant asset is required.');
        return false;
      }

      final form = ContestFormData(
        fields: <String, String>{
          'title': titleController.text.trim(),
          'tags': tagValues,
          'description': descriptionController.text.trim(),
          'challenge_scope': challengeScope.value,
          // Backend requires singular opponent_user_id; first selected is primary.
          'opponent_user_id': '${selectedOpponentIds.first}',
          'voting_end_at': (votingEndAt.value ?? DateTime.now())
              .toUtc()
              .toIso8601String(),
        },
        arrayFields: <String, String>{
          for (var i = 0; i < selectedOpponentIds.length; i++)
            'opponent_user_ids[$i]': '${selectedOpponentIds[i]}',
        },
        filePaths: <String, String>{
          if (coverAsset.value != null) 'cover_asset': coverAsset.value!.path,
          if (participantAsset.value != null)
            'participant_asset': participantAsset.value!.path,
        },
      );
      return _contestController.createOneVsOne(form);
    }

    if (!await _canCreateCityContest(showMessage: true)) {
      return false;
    }

    if (cityOne.value.trim().isEmpty || cityTwo.value.trim().isEmpty) {
      errorSnackBar(message: 'Please select both cities.');
      return false;
    }
    if (coverAsset.value == null) {
      errorSnackBar(message: 'Cover asset is required.');
      return false;
    }

    final form = ContestFormData(
      fields: <String, String>{
        'title': titleController.text.trim(),
        'tags': tagValues,
        'description': descriptionController.text.trim(),
        'city_one': cityOne.value,
        'city_two': cityTwo.value,
        'enrollment_end_at': (enrollmentEndAt.value ?? DateTime.now())
            .toUtc()
            .toIso8601String(),
        'voting_end_at': (votingEndAt.value ?? DateTime.now())
            .toUtc()
            .toIso8601String(),
        'max_participants': maxParticipantsController.text.trim(),
      },
      filePaths: <String, String>{
        if (coverAsset.value != null) 'cover_asset': coverAsset.value!.path,
      },
    );
    return _contestController.createCity(form);
  }

  bool validateStep1() {
    if (selectedType.value == null) {
      errorSnackBar(message: 'Please select contest type before continuing.');
      return false;
    }
    return true;
  }

  bool validateStep2() {
    _commitPendingTags();
    if (titleController.text.trim().isEmpty ||
        tags.isEmpty ||
        descriptionController.text.trim().isEmpty) {
      errorSnackBar(message: 'Title, tags, and description are required.');
      return false;
    }
    return true;
  }

  bool get isStep1Valid => selectedType.value != null;

  bool get isStep2Valid =>
      titleController.text.trim().isNotEmpty &&
      (tags.isNotEmpty || tagsController.text.trim().isNotEmpty) &&
      descriptionController.text.trim().isNotEmpty;

  bool get isStep3Valid {
    if (votingEndAt.value == null) {
      return false;
    }
    if (selectedType.value == CreateContestType.oneVsOne) {
      return selectedOpponentIds.isNotEmpty &&
          coverAsset.value != null &&
          participantAsset.value != null;
    }
    return cityOne.value.trim().isNotEmpty &&
        cityTwo.value.trim().isNotEmpty &&
        coverAsset.value != null;
  }

  bool canProceedStep(int step) {
    switch (step) {
      case 1:
        return isStep1Valid;
      case 2:
        return isStep2Valid;
      case 3:
        return isStep3Valid;
      default:
        return false;
    }
  }

  String stepErrorMessage(int step) {
    switch (step) {
      case 1:
        return 'Please select contest type before continuing.';
      case 2:
        return 'Title, tags, and description are required.';
      case 3:
        if (selectedType.value == CreateContestType.oneVsOne) {
          return 'Select opponent(s), voting end, cover asset, and participant asset.';
        }
        return 'Select city one, city two, voting end, and cover asset.';
      default:
        return 'Please complete required fields.';
    }
  }

  Future<bool> _canCreateCityContest({required bool showMessage}) async {
    final followers = await _currentFollowerCount();
    if (followers == null) {
      if (showMessage) {
        errorSnackBar(
          message: 'Unable to verify your follower count. Please try again.',
        );
      }
      return false;
    }

    final canCreate = followers >= cityContestMinimumFollowers;
    if (!canCreate && showMessage) {
      _showCityContestRequirementSheet(followers);
    }
    return canCreate;
  }

  void _showCityContestRequirementSheet(int followers) {
    if (Get.isBottomSheetOpen ?? false) {
      return;
    }

    Get.bottomSheet<void>(
      SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.hintText.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const AppHeroIconData(
                      Icons.groups_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'City vs City Locked',
                          style: AppFonts.plusJakarta(
                            size: 18,
                            weight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'City vs City contests require at least 1,000 followers. You currently have $followers.',
                          style: AppFonts.beVietnam(
                            size: 13,
                            weight: FontWeight.w500,
                            height: 1.45,
                            color: AppColors.hintText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: AppBackNavigation.handleBack,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Got it',
                    style: AppFonts.beVietnam(
                      size: 14,
                      weight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
    );
  }

  Future<int?> _currentFollowerCount() async {
    var profileUser = _profileController.user.value;
    if (profileUser != null) {
      return profileUser.followerCount;
    }

    await _profileController.fetchProfileOverview(forceRefresh: true);
    profileUser = _profileController.user.value;
    return profileUser?.followerCount;
  }

  void markFormChanged() {
    formTick.value++;
  }

  void _commitPendingTags() {
    final pending = tagsController.text.trim();
    if (pending.isNotEmpty) {
      addTag(pending);
    }
  }

  void setVotingEndAt(DateTime value) {
    votingEndAt.value = value;
    votingEndController.text = value.toLocal().toString().substring(0, 16);
  }

  void setEnrollmentEndAt(DateTime value) {
    enrollmentEndAt.value = value;
    enrollmentEndController.text = value.toLocal().toString().substring(0, 16);
  }

  void addTag(String rawValue) {
    final values = rawValue.split(',');
    for (final value in values) {
      final cleaned = value.trim().replaceAll('#', '');
      if (cleaned.isEmpty) continue;
      final normalized = '#$cleaned';
      if (!tags.contains(normalized)) {
        tags.add(normalized);
      }
    }
    tagsController.clear();
    tagQuery.value = '';
    markFormChanged();
  }

  void removeTag(String tag) {
    tags.remove(tag);
    markFormChanged();
  }

  void setTagQuery(String value) {
    tagQuery.value = value;
    markFormChanged();
  }

  List<String> filteredTagOptions() {
    final key = tagQuery.value.trim().toLowerCase().replaceAll('#', '');
    return _contestController.tagSuggestions
        .where((tag) => !tags.contains(tag))
        .where((tag) => key.isEmpty || tag.toLowerCase().contains(key))
        .toList(growable: false);
  }

  @override
  void onClose() {
    titleController.dispose();
    descriptionController.dispose();
    tagsController.dispose();
    votingEndController.dispose();
    enrollmentEndController.dispose();
    maxParticipantsController.dispose();
    super.onClose();
  }
}
