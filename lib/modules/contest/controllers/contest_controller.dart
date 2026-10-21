import 'package:flutter/widgets.dart';
import 'package:get/get.dart' hide FormData;

import '../../../core/utils/app_helper.dart';
import '../../contest/services/contest_enrollment_store.dart';
import '../../home/controllers/home_controller.dart';
import '../../reports/api/reports_api.dart';
import '../api/contest_api.dart';
import '../models/contest_detail_model.dart';
import '../models/contest_invitation_model.dart';
import '../models/contest_model.dart';
import '../repositories/contest_repository.dart';

class ContestController extends GetxController {
  ContestController({ContestRepository? repository})
    : _repository = repository ?? ContestRepository();

  final ContestRepository _repository;
  ScrollController? _scrollController;

  void attachScrollController(ScrollController controller) {
    _scrollController = controller;
  }

  void detachScrollController(ScrollController controller) {
    if (identical(_scrollController, controller)) {
      _scrollController = null;
    }
  }

  Future<void> scrollToTop() async {
    final controller = _scrollController;
    if (controller != null && controller.hasClients && controller.offset > 0) {
      await controller.animateTo(
        0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
    await refreshContests();
  }

  final Rx<ContestCategory> selectedCategory = ContestCategory.admin.obs;
  final RxString selectedTypeFilter = ''.obs;
  final RxString searchQuery = ''.obs;

  final RxList<ContestModel> _contests = <ContestModel>[].obs;
  final RxBool isInitialLoading = true.obs;
  final RxBool isRefreshing = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = true.obs;
  final RxInt currentPage = 0.obs;

  final Rxn<ContestDetailModel> selectedContestDetail =
      Rxn<ContestDetailModel>();
  final RxBool isDetailLoading = false.obs;

  final RxMap<int, bool> actionLoadingByContestId = <int, bool>{}.obs;
  final RxBool isCreatingOneVsOne = false.obs;
  final RxBool isCreatingCity = false.obs;
  final RxBool isSubmittingOutfit = false.obs;

  final RxList<ContestInvitationModel> invitations =
      <ContestInvitationModel>[].obs;
  final RxBool isInvitationsLoading = false.obs;
  final RxBool invitationsHasMore = true.obs;
  int _invitationPage = 0;

  final RxList<ContestModel> profileResults = <ContestModel>[].obs;
  final RxBool isProfileResultsLoading = false.obs;
  final RxBool profileResultsHasMore = true.obs;
  int _profilePage = 0;

  final RxInt createStep = 1.obs;
  final RxString createFormat = '1v1'.obs;
  final RxList<String> tagSuggestions = <String>[].obs;
  final RxList<ContestMetaOption> opponentOptions = <ContestMetaOption>[].obs;
  final RxList<String> cityOptions = <String>[].obs;
  final RxBool isMetaLoading = false.obs;

  List<ContestModel> get adminContests => _applySearch(
    _contests.where((item) => item.isAdminTabItem).toList(growable: false),
  );

  List<ContestModel> get communityContests => _applySearch(
    _contests.where((item) => !item.isAdminTabItem).toList(growable: false),
  );

  ContestModel? get nearestEnrollmentContest {
    final now = DateTime.now();
    final open = _contests
        .where(
          (item) =>
              item.enrollmentEndAt != null &&
              item.enrollmentEndAt!.isAfter(now),
        )
        .toList(growable: false);
    if (open.isEmpty) {
      return _contests.isEmpty ? null : _contests.first;
    }
    open.sort((a, b) {
      final aMinutes = a.enrollmentEndAt!.difference(now).inMinutes;
      final bMinutes = b.enrollmentEndAt!.difference(now).inMinutes;
      return aMinutes.compareTo(bMinutes);
    });
    return open.first;
  }

  @override
  void onInit() {
    super.onInit();
    fetchContests(reset: true);
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      if (isClosed) {
        return;
      }
      fetchTags();
    });
  }

  void setCategory(ContestCategory value) {
    selectedCategory.value = value;
    fetchContests(reset: true);
  }

  void setSearchQuery(String value) {
    searchQuery.value = value.trim();
  }

  void setCreateStep(int value) {
    createStep.value = value.clamp(1, 4);
  }

  Future<void> setTypeFilter(String? value) async {
    selectedTypeFilter.value = value?.trim() ?? '';
    await fetchContests(reset: true);
  }

  Future<void> fetchContests({required bool reset}) async {
    if (reset) {
      isInitialLoading.value = true;
      currentPage.value = 0;
      hasMore.value = true;
    } else {
      if (isLoadingMore.value || !hasMore.value) {
        return;
      }
      isLoadingMore.value = true;
    }

    try {
      final page = reset ? 1 : currentPage.value + 1;
      final result = selectedCategory.value == ContestCategory.admin
          ? await _repository.getAdminContests(page: page)
          : await _repository.getContests(
              type: selectedTypeFilter.value.isEmpty
                  ? null
                  : selectedTypeFilter.value,
              page: page,
            );
      if (reset) {
        _contests.assignAll(result.items);
      } else {
        _contests.addAll(result.items);
      }
      _ingestEnrollment(result.items);
      currentPage.value = result.pagination.currentPage;
      hasMore.value = result.pagination.hasMorePages;
    } catch (error) {
      hasMore.value = false;
      errorSnackBar(message: _friendlyError(error));
    } finally {
      if (reset) {
        isInitialLoading.value = false;
        isRefreshing.value = false;
      } else {
        isLoadingMore.value = false;
      }
    }
  }

  Future<void> refreshContests() async {
    isRefreshing.value = true;
    await fetchContests(reset: true);
  }

  Future<void> fetchDetail(int contestId) async {
    isDetailLoading.value = true;
    try {
      selectedContestDetail.value = await _repository.getContestDetail(
        contestId,
      );
      final detail = selectedContestDetail.value;
      if (detail != null) {
        ContestEnrollmentStore.instance.addAll(
          detail.visibleSubmissions.map((item) => item.postId),
          contestId: detail.id,
          contestTitle: detail.title,
        );
      }
    } catch (error) {
      errorSnackBar(message: _friendlyError(error));
    } finally {
      isDetailLoading.value = false;
    }
  }

  Future<void> reportContest(
    int contestId,
    String reasonCode,
    String? details,
  ) async {
    try {
      final result = await ReportsApi.submitReport(
        targetType: 'contest',
        targetId: contestId,
        reason: reasonCode,
        description: details,
      );
      if (result.alreadyReported) {
        infoSnackBar(
          message: 'You already reported this. Our team is reviewing it.',
        );
      } else {
        successSnackBar(message: 'Contest reported. Thanks for letting us know.');
      }
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> fetchTags() async {
    isMetaLoading.value = true;
    try {
      tagSuggestions.assignAll(await _repository.getTags());
    } catch (_) {
      tagSuggestions.clear();
    } finally {
      isMetaLoading.value = false;
    }
  }

  Future<void> fetchUsers({required String scope, String? q}) async {
    isMetaLoading.value = true;
    try {
      opponentOptions.assignAll(
        await _repository.getContestUsers(scope: scope, q: q),
      );
    } catch (_) {
      opponentOptions.clear();
    } finally {
      isMetaLoading.value = false;
    }
  }

  Future<void> fetchCities({String? q}) async {
    isMetaLoading.value = true;
    try {
      cityOptions.assignAll(await _repository.getCities(q: q));
    } catch (_) {
      cityOptions.clear();
    } finally {
      isMetaLoading.value = false;
    }
  }

  Future<bool> createOneVsOne(ContestFormData data) async {
    isCreatingOneVsOne.value = true;
    try {
      await _repository.createOneVsOne(data);
      successSnackBar(message: '1v1 contest created');
      await fetchContests(reset: true);
      return true;
    } catch (error) {
      errorSnackBar(message: _friendlyError(error));
      return false;
    } finally {
      isCreatingOneVsOne.value = false;
    }
  }

  Future<bool> createCity(ContestFormData data) async {
    isCreatingCity.value = true;
    try {
      await _repository.createCityVsCity(data);
      successSnackBar(message: 'City contest created');
      await fetchContests(reset: true);
      return true;
    } catch (error) {
      errorSnackBar(message: _friendlyError(error));
      return false;
    } finally {
      isCreatingCity.value = false;
    }
  }

  Future<void> joinCityContest(int contestId) async {
    await _withAction(contestId, () async {
      await _repository.joinCityContest(contestId);
      await fetchDetail(contestId);
      await fetchContests(reset: true);
    });
  }

  Future<void> joinContest(int contestId, ContestFormData data) async {
    await _withAction(contestId, () async {
      await _repository.joinContest(contestId, data);
      final joinedPostId = data.fields['post_id'];
      if (joinedPostId != null && joinedPostId.trim().isNotEmpty) {
        final contestTitle = _titleForContest(contestId);
        ContestEnrollmentStore.instance.add(
          joinedPostId,
          contestId: contestId,
          contestTitle: contestTitle,
        );
        if (Get.isRegistered<HomeController>()) {
          Get.find<HomeController>().markPostContestEnrolled(
            joinedPostId.trim(),
            contestId: contestId,
            contestTitle: contestTitle,
          );
        }
      }
      await fetchDetail(contestId);
      await fetchContests(reset: true);
    });
  }

  Future<void> requestJoin1v1(int contestId) async {
    await _withAction(contestId, () async {
      await _repository.requestJoin1v1(contestId);
      await fetchDetail(contestId);
      await fetchContests(reset: true);
    });
  }

  Future<void> requestJoin1v1WithProfile(
    int contestId,
    ContestFormData formData,
  ) async {
    await _withAction(contestId, () async {
      await _repository.requestJoin1v1WithProfile(contestId, formData);
      await fetchDetail(contestId);
      await fetchContests(reset: true);
    });
  }

  Future<void> respondInvitation(int invitationId, String status) async {
    try {
      await _repository.respondInvitation(invitationId, status);
      await fetchInvitations(reset: true);
      await fetchContests(reset: true);
    } catch (error) {
      errorSnackBar(message: _friendlyError(error));
    }
  }

  Future<void> selectOpponent(int contestId, int participantUserId) async {
    await _withAction(contestId, () async {
      await _repository.selectOpponent(contestId, participantUserId);
      await fetchDetail(contestId);
    });
  }

  Future<void> submitOutfit(int contestId, ContestFormData data) async {
    isSubmittingOutfit.value = true;
    try {
      await _repository.submitContestOutfit(contestId, data);
      successSnackBar(message: 'Submission uploaded successfully');
      await fetchDetail(contestId);
    } catch (error) {
      errorSnackBar(message: _friendlyError(error));
    } finally {
      isSubmittingOutfit.value = false;
    }
  }

  Future<bool> vote(
    int contestId,
    int submissionId,
    double score, {
    bool refreshDetail = false,
  }) async {
    try {
      final detail = await _repository.voteContest(
        contestId,
        submissionId,
        score,
      );
      if (detail != null) {
        selectedContestDetail.value = detail;
      } else if (refreshDetail) {
        await fetchDetail(contestId);
      }
      return true;
    } catch (error) {
      errorSnackBar(message: _friendlyError(error));
      return false;
    }
  }

  Future<void> fetchInvitations({required bool reset}) async {
    if (reset) {
      isInvitationsLoading.value = true;
      _invitationPage = 0;
      invitationsHasMore.value = true;
    } else if (!invitationsHasMore.value) {
      return;
    }

    try {
      final page = reset ? 1 : _invitationPage + 1;
      final result = await _repository.getInvitations(page: page);
      if (reset) {
        invitations.assignAll(result.items);
      } else {
        invitations.addAll(result.items);
      }
      _invitationPage = result.pagination.currentPage;
      invitationsHasMore.value = result.pagination.hasMorePages;
    } catch (error) {
      errorSnackBar(message: _friendlyError(error));
    } finally {
      isInvitationsLoading.value = false;
    }
  }

  Future<void> fetchProfileResults({required bool reset}) async {
    if (reset) {
      isProfileResultsLoading.value = true;
      _profilePage = 0;
      profileResultsHasMore.value = true;
    } else if (!profileResultsHasMore.value) {
      return;
    }

    try {
      final page = reset ? 1 : _profilePage + 1;
      final result = await _repository.getProfileResults(page: page);
      if (reset) {
        profileResults.assignAll(result.items);
      } else {
        profileResults.addAll(result.items);
      }
      _profilePage = result.pagination.currentPage;
      profileResultsHasMore.value = result.pagination.hasMorePages;
    } catch (error) {
      errorSnackBar(message: _friendlyError(error));
    } finally {
      isProfileResultsLoading.value = false;
    }
  }

  Future<void> _withAction(
    int contestId,
    Future<void> Function() action,
  ) async {
    if (actionLoadingByContestId[contestId] == true) {
      return;
    }
    actionLoadingByContestId[contestId] = true;
    try {
      await action();
    } catch (error) {
      errorSnackBar(message: _friendlyError(error));
    } finally {
      actionLoadingByContestId[contestId] = false;
    }
  }

  List<ContestModel> _applySearch(List<ContestModel> source) {
    final q = searchQuery.value.trim().toLowerCase();
    if (q.isEmpty) {
      return source;
    }
    return source.where((item) => item.matchesParticipantSearch(q)).toList(
      growable: false,
    );
  }

  String _friendlyError(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    final message = text.toLowerCase();
    if (message.contains('invalid opponent')) return text;
    if (message.contains('city not eligible')) return text;
    if (message.contains('enrollment')) return text;
    if (message.contains('max') && message.contains('participant')) return text;
    if (message.contains('voting')) return text;
    if (message.contains('forbidden') || message.contains('not participant')) {
      return text;
    }
    return text;
  }

  Future<bool> hasPendingInvitationForContest(int contestId) async {
    if (invitations.isEmpty) {
      await fetchInvitations(reset: true);
    }
    return invitations.any(
      (item) => item.contestId == contestId && item.isPending,
    );
  }

  void _ingestEnrollment(Iterable<ContestModel> items) {
    for (final contest in items) {
      ContestEnrollmentStore.instance.addAll(
        contest.enrolledPostIds,
        contestId: contest.id,
        contestTitle: contest.title,
      );
    }
  }

  String _titleForContest(int contestId) {
    final detail = selectedContestDetail.value;
    if (detail != null && detail.id == contestId) {
      return detail.title;
    }
    for (final contest in _contests) {
      if (contest.id == contestId) {
        return contest.title;
      }
    }
    return '';
  }
}
