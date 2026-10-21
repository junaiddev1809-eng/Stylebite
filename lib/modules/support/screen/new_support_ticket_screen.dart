import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:heroicons/heroicons.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/app_back_navigation.dart';
import '../../../core/utils/app_helper.dart';
import '../../../core/widgets/app_text_field.dart';
import '../api/support_api.dart';
import '../controllers/support_tickets_controller.dart';
import '../models/support_meta_model.dart';
import '../utils/support_text_helpers.dart';

class NewSupportTicketScreen extends StatefulWidget {
  const NewSupportTicketScreen({super.key});

  @override
  State<NewSupportTicketScreen> createState() => _NewSupportTicketScreenState();
}

class _NewSupportTicketScreenState extends State<NewSupportTicketScreen> {
  late final SupportTicketsController _controller;
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  late Future<SupportMetaModel> _metaFuture;
  final List<String> _attachmentPaths = [];
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<SupportTicketsController>()
        ? Get.find<SupportTicketsController>()
        : Get.put(SupportTicketsController());
    _metaFuture = SupportApi.fetchMeta();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
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
                  bottom: BorderSide(color: Colors.white.withValues(alpha: 0.8)),
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
                        'New Ticket',
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
              child: FutureBuilder<SupportMetaModel>(
                future: _metaFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Unable to load ticket options.',
                              style: AppFonts.beVietnam(
                                size: 14,
                                weight: FontWeight.w600,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _metaFuture = SupportApi.fetchMeta();
                                });
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final meta = snapshot.data!;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Category',
                          style: AppFonts.beVietnam(
                            size: 13,
                            weight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final category in meta.categories)
                              _CategoryChip(
                                label: category.label,
                                selected: _selectedCategory == category.value,
                                onTap: () => setState(
                                  () => _selectedCategory = category.value,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          controller: _subjectController,
                          label: 'Subject',
                          hintText: 'Briefly describe the issue',
                          maxLength: meta.subjectMaxLength,
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          controller: _bodyController,
                          label: 'Details',
                          hintText: 'Steps to reproduce, what you expected, etc.',
                          maxLines: 6,
                          maxLength: meta.bodyMaxLength,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Attachments (optional, up to ${meta.maxAttachments})',
                          style: AppFonts.beVietnam(
                            size: 13,
                            weight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _AttachmentPicker(
                          paths: _attachmentPaths,
                          maxAttachments: meta.maxAttachments,
                          maxSizeMb: meta.maxAttachmentSizeMb,
                          onChanged: () => setState(() {}),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: Obx(
                            () => ElevatedButton(
                              onPressed: _controller.isCreatingTicket.value
                                  ? null
                                  : () => _submit(meta),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                disabledBackgroundColor: AppColors.hintText
                                    .withValues(alpha: 0.25),
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              child: _controller.isCreatingTicket.value
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'Submit Ticket',
                                      style: AppFonts.beVietnam(
                                        size: 14,
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
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(SupportMetaModel meta) async {
    if (_selectedCategory == null) {
      errorSnackBar(message: 'Please select a category.');
      return;
    }
    if (_subjectController.text.trim().isEmpty) {
      errorSnackBar(message: 'Please enter a subject.');
      return;
    }
    if (_bodyController.text.trim().isEmpty) {
      errorSnackBar(message: 'Please describe the issue.');
      return;
    }

    final ticket = await _controller.createTicket(
      category: _selectedCategory!,
      subject: _subjectController.text.trim(),
      body: _bodyController.text.trim(),
      attachmentPaths: _attachmentPaths,
    );

    if (!mounted || ticket == null) {
      return;
    }
    Get.back(result: ticket.id);
    Get.toNamed(
      AppRoutes.supportTicketDetail,
      arguments: {'ticketId': ticket.id},
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : const Color(0xFFF4F1F0),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: AppFonts.beVietnam(
            size: 13,
            weight: FontWeight.w700,
            color: selected ? AppColors.primary : AppColors.text,
          ),
        ),
      ),
    );
  }
}

class _AttachmentPicker extends StatelessWidget {
  const _AttachmentPicker({
    required this.paths,
    required this.maxAttachments,
    required this.maxSizeMb,
    required this.onChanged,
  });

  final List<String> paths;
  final int maxAttachments;
  final int maxSizeMb;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final path in paths)
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(path),
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: InkWell(
                  onTap: () {
                    paths.remove(path);
                    onChanged();
                  },
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Colors.black87,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        if (paths.length < maxAttachments)
          InkWell(
            onTap: () => _pickAttachments(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F1F0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.hintText.withValues(alpha: 0.25),
                ),
              ),
              child: const HeroIcon(
                HeroIcons.photo,
                color: AppColors.hintText,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _pickAttachments(BuildContext context) async {
    final remaining = maxAttachments - paths.length;
    if (remaining <= 0) {
      return;
    }

    final picked = await ImagePicker().pickMultiImage(limit: remaining);
    if (picked.isEmpty) {
      return;
    }

    final maxBytes = maxSizeMb * 1024 * 1024;
    var skippedForSize = false;
    var skippedForType = false;
    for (final file in picked) {
      if (paths.length >= maxAttachments) {
        break;
      }
      if (!isSupportedSupportAttachment(file.path)) {
        skippedForType = true;
        continue;
      }
      final size = await File(file.path).length();
      if (size > maxBytes) {
        skippedForSize = true;
        continue;
      }
      paths.add(file.path);
    }

    if (skippedForType) {
      errorSnackBar(message: 'Only JPG, PNG, or WEBP images are supported.');
    }
    if (skippedForSize) {
      errorSnackBar(
        message: 'Some images were skipped for exceeding ${maxSizeMb}MB.',
      );
    }
    onChanged();
  }
}
