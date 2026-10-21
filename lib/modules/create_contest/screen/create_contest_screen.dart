import 'dart:io';

import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:stylebite/core/widgets/app_hero_icon.dart';
import 'package:flutter/cupertino.dart';

import '../../../core/widgets/app_search_dropdown.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/widgets/app_media_source_sheet.dart';
import '../../../modules/upload/widgets/upload_tag_input.dart';
import '../../../core/media/media_type_resolver.dart';
import '../../../modules/contest/controllers/contest_controller.dart';
import '../controllers/create_contest_controller.dart';
import '../models/create_contest_model.dart';

class CreateContestScreen extends StatefulWidget {
  const CreateContestScreen({super.key});

  @override
  State<CreateContestScreen> createState() => _CreateContestScreenState();
}

class _CreateContestScreenState extends State<CreateContestScreen> {
  late final CreateContestController _controller;
  late final ContestController _contestController;

  @override
  void initState() {
    super.initState();
    _contestController = Get.isRegistered<ContestController>()
        ? Get.find<ContestController>()
        : Get.put(ContestController());
    _controller = Get.isRegistered<CreateContestController>()
        ? Get.find<CreateContestController>()
        : Get.put(CreateContestController());
  }

  Future<void> _pickCover() async {
    final source = await showMediaSourceSheet(context);
    if (source == null) return;
    await _controller.pickCoverAsset(
      fromCamera: source == MediaSourceChoice.camera,
    );
  }

  Future<void> _pickParticipant() async {
    final source = await showMediaSourceSheet(context);
    if (source == null) return;
    await _controller.pickParticipantAsset(
      fromCamera: source == MediaSourceChoice.camera,
    );
  }

  Future<void> _pickVotingEndAt() async {
    final initial =
        _controller.votingEndAt.value ??
        DateTime.now().add(const Duration(hours: 1));
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        var temp = initial;
        return Container(
          height: 320,
          color: Colors.white,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      _controller.setVotingEndAt(temp);
                      Navigator.of(sheetContext).pop();
                    },
                    child: const Text('Done'),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.dateAndTime,
                  initialDateTime: initial,
                  minimumDate: DateTime.now(),
                  onDateTimeChanged: (value) => temp = value,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickEnrollmentEndAt() async {
    final initial =
        _controller.enrollmentEndAt.value ??
        DateTime.now().add(const Duration(hours: 1));
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        var temp = initial;
        return Container(
          height: 320,
          color: Colors.white,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      _controller.setEnrollmentEndAt(temp);
                      Navigator.of(sheetContext).pop();
                    },
                    child: const Text('Done'),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.dateAndTime,
                  initialDateTime: initial,
                  minimumDate: DateTime.now(),
                  onDateTimeChanged: (value) => temp = value,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onPrimaryAction() async {
    if (_controller.activeStep.value == 1) {
      if (!_controller.validateStep1()) {
        return;
      }
      _controller.setStep(2);
      return;
    }
    if (_controller.activeStep.value == 2) {
      if (!_controller.validateStep2()) {
        return;
      }
      _controller.setStep(3);
      return;
    }
    final success = await _controller.submitContest();
    if (!mounted || !success) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Obx(() {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: [
              _topBar(),
              const SizedBox(height: 14),
              _heroHeader(),
              const SizedBox(height: 16),
              _stepIndicator(),
              const SizedBox(height: 16),
              _surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_controller.activeStep.value == 1) _step1(),
                    if (_controller.activeStep.value == 2) _step2(),
                    if (_controller.activeStep.value == 3) _step3(),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _actionsRow(),
            ],
          );
        }),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.of(context).pop(),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const AppHeroIconData(Icons.arrow_back_rounded, color: AppColors.text),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Create Contest',
          style: AppFonts.plusJakarta(size: 20, weight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _heroHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1F1B1A), Color(0xFF3A2D2A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Launch Your Style Arena',
            style: AppFonts.plusJakarta(
              size: 24,
              weight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Create a polished challenge in minutes with a premium workflow.',
            style: AppFonts.beVietnam(
              size: 13,
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepIndicator() {
    Widget dot(int step, String label) {
      final active = _controller.activeStep.value == step;
      final done = _controller.activeStep.value > step;
      return Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active || done ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              '$step. $label',
              style: AppFonts.beVietnam(
                size: 12,
                weight: FontWeight.w700,
                color: active || done ? Colors.white : AppColors.hintText,
              ),
            ),
          ),
        ),
      );
    }

    return Row(children: [dot(1, 'Format'), dot(2, 'Basics'), dot(3, 'Rules')]);
  }

  Widget _surface({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.06),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _actionsRow() {
    // Depend on formTick so button state updates on text edits immediately.
    _controller.formTick.value;
    final canProceed = _controller.canProceedStep(_controller.activeStep.value);
    final isSubmitting = _controller.isSubmittingContest;
    return Row(
      children: [
        if (_controller.activeStep.value > 1)
          Expanded(
            child: OutlinedButton(
              onPressed: isSubmitting
                  ? null
                  : () => _controller.setStep(_controller.activeStep.value - 1),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: const Text('Back'),
            ),
          ),
        if (_controller.activeStep.value > 1) const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: canProceed && !isSubmitting
                    ? const [AppColors.primary, AppColors.secondary]
                    : const [Color(0xFFC9C5C3), Color(0xFFB4AEAB)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: ElevatedButton(
              onPressed: (!canProceed || isSubmitting)
                  ? null
                  : _onPrimaryAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _controller.activeStep.value < 3
                          ? 'Next Step'
                          : 'Create Contest',
                      style: AppFonts.plusJakarta(
                        size: 15,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _step1() {
    final selected = _controller.selectedType.value;
    Widget typeCard(
      CreateContestType type,
      String title,
      String subtitle,
      IconData icon,
    ) {
      final active = selected == type;
      return InkWell(
        onTap: () => _controller.setType(type),
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary.withValues(alpha: 0.09)
                : const Color(0xFFF7F4F3),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: active ? AppColors.primary : Colors.transparent,
              width: 1.4,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : Colors.white,
                  shape: BoxShape.circle,
                ),
                child: AppHeroIconData(
                  icon,
                  color: active ? Colors.white : AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppFonts.plusJakarta(
                        size: 16,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppFonts.beVietnam(
                        size: 12,
                        color: AppColors.hintText,
                      ),
                    ),
                  ],
                ),
              ),
              if (active)
                const AppHeroIconData(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose Contest Format',
          style: AppFonts.plusJakarta(size: 19, weight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Pick the battle style to unlock the right setup fields.',
          style: AppFonts.beVietnam(size: 12, color: AppColors.hintText),
        ),
        const SizedBox(height: 12),
        typeCard(
          CreateContestType.oneVsOne,
          '1v1 Battle',
          'Challenge creators head-to-head.',
          Icons.sports_martial_arts_rounded,
        ),
        typeCard(
          CreateContestType.city,
          'City vs City',
          'Represent your city and compete collectively.',
          Icons.location_city_rounded,
        ),
      ],
    );
  }

  Widget _step2() {
    return Column(
      children: [
        _field('Title', _controller.titleController),
        const SizedBox(height: 10),
        Obx(
          () => UploadTagInput(
            controller: _controller.tagsController,
            tags: _controller.tags,
            options: _controller.filteredTagOptions(),
            hintText: 'streetwear, minimalist, vintage',
            onAddTag: _controller.addTag,
            onRemoveTag: _controller.removeTag,
            onChanged: _controller.setTagQuery,
          ),
        ),
        const SizedBox(height: 8),
        _field('Description', _controller.descriptionController, maxLines: 4),
      ],
    );
  }

  Widget _step3() {
    final isOneVsOne =
        _controller.selectedType.value == CreateContestType.oneVsOne;
    return Column(
      children: [
        if (isOneVsOne) ...[
          CommonSearchableDropDown(
            itemList: const ['Followers only', 'Global'],
            selectedItem: _controller.challengeScope.value == 'global'
                ? 'Global'
                : 'Followers only',
            hintText: 'Challenge scope',
            hintTextOfField: 'Search scope',
            onChangeValue: (value) async {
              _controller.challengeScope.value =
                  (value ?? '').toLowerCase() == 'global'
                  ? 'global'
                  : 'followers_only';
              await _controller.refreshOpponents();
            },
          ),
          const SizedBox(height: 10),
          Obx(() {
            final selectedLabels = _contestController.opponentOptions
                .where(
                  (item) => _controller.selectedOpponentIds.contains(item.id),
                )
                .map((item) => item.label)
                .toList(growable: false);
            return CommonSearchableDropDown(
              itemList: _contestController.opponentOptions
                  .map((item) => item.label)
                  .toList(growable: false),
              isMultiSelect: true,
              selectedItems: selectedLabels,
              hintText: 'Opponent',
              hintTextOfField: 'Search opponent',
              onChangeMultiValue: (labels) {
                final ids = _contestController.opponentOptions
                    .where((item) => labels.contains(item.label))
                    .map((item) => item.id)
                    .toList(growable: false);
                _controller.selectedOpponentIds.assignAll(ids);
              },
            );
          }),
        ] else ...[
          Obx(
            () => CommonSearchableDropDown(
              itemList: _contestController.cityOptions,
              selectedItem: _controller.cityOne.value.isEmpty
                  ? null
                  : _controller.cityOne.value,
              hintText: 'City One',
              hintTextOfField: 'Search city',
              onChangeValue: (value) => _controller.cityOne.value = value ?? '',
            ),
          ),
          const SizedBox(height: 10),
          Obx(
            () => CommonSearchableDropDown(
              itemList: _contestController.cityOptions,
              selectedItem: _controller.cityTwo.value.isEmpty
                  ? null
                  : _controller.cityTwo.value,
              hintText: 'City Two',
              hintTextOfField: 'Search city',
              onChangeValue: (value) => _controller.cityTwo.value = value ?? '',
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: _pickEnrollmentEndAt,
            borderRadius: BorderRadius.circular(14),
            child: IgnorePointer(
              child: Obx(
                () => TextField(
                  controller: _controller.enrollmentEndController,
                  style: AppFonts.beVietnam(),
                  decoration: _inputDecoration(
                    _controller.enrollmentEndAt.value == null
                        ? 'Enrollment end at'
                        : _formatDateTime(_controller.enrollmentEndAt.value!),
                    suffixIcon: const AppHeroIconData(
                      Icons.calendar_month_rounded,
                      color: AppColors.hintText,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _field(
            'Max participants (optional)',
            _controller.maxParticipantsController,
          ),
        ],
        const SizedBox(height: 10),
        InkWell(
          onTap: _pickVotingEndAt,
          borderRadius: BorderRadius.circular(14),
          child: IgnorePointer(
            child: Obx(
              () => TextField(
                controller: _controller.votingEndController,
                style: AppFonts.beVietnam(),
                decoration: _inputDecoration(
                  _controller.votingEndAt.value == null
                      ? 'Voting end at'
                      : _formatDateTime(_controller.votingEndAt.value!),
                  suffixIcon: const AppHeroIconData(
                    Icons.calendar_month_rounded,
                    color: AppColors.hintText,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _uploadCard(
          title: 'Cover asset',
          subtitle:
              _controller.coverAsset.value?.path ??
              'Pick image from camera/gallery',
          onTap: _pickCover,
        ),
        const SizedBox(height: 8),
        _imagePreview(path: _controller.coverAsset.value?.path),
        if (isOneVsOne) ...[
          const SizedBox(height: 10),
          _uploadCard(
            title: 'Participant asset',
            subtitle:
                _controller.participantAsset.value?.path ??
                'Pick image/video from camera/gallery',
            onTap: _pickParticipant,
          ),
          const SizedBox(height: 8),
          _imagePreview(path: _controller.participantAsset.value?.path),
        ],
      ],
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: (_) => _controller.markFormChanged(),
      style: AppFonts.beVietnam(),
      decoration: _inputDecoration(label),
    );
  }

  Widget _uploadCard({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F1F0),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const AppHeroIconData(Icons.upload_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppFonts.plusJakarta(weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.beVietnam(
                      size: 12,
                      color: AppColors.hintText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePreview({required String? path}) {
    if (path == null || path.isEmpty) {
      return const SizedBox.shrink();
    }
    final isImage =
        MediaTypeResolver.resolve(path, fallback: AppMediaType.image) ==
        AppMediaType.image;
    if (!isImage) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F1F0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('Video selected'),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        File(path),
        height: 170,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppFonts.beVietnam(color: AppColors.hintText),
      filled: true,
      fillColor: Colors.white,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderSide: BorderSide(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final two = (int v) => v.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} ${two(value.hour)}:${two(value.minute)}';
  }
}
