import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/widgets/app_text_field.dart';
import '../api/reports_api.dart';

class ReportReasonResult {
  const ReportReasonResult({required this.reasonCode, this.details});

  final String reasonCode;
  final String? details;
}

Future<ReportReasonResult?> showReportReasonSheet(
  BuildContext context, {
  required String title,
  String subtitle = 'Your report is anonymous and will be reviewed by our team.',
}) {
  return showModalBottomSheet<ReportReasonResult>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _ReportReasonSheet(title: title, subtitle: subtitle),
  );
}

class _ReportReasonSheet extends StatefulWidget {
  const _ReportReasonSheet({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  State<_ReportReasonSheet> createState() => _ReportReasonSheetState();
}

class _ReportReasonSheetState extends State<_ReportReasonSheet> {
  final TextEditingController _detailsController = TextEditingController();
  late Future<ReportsMeta> _metaFuture;
  String? _selectedCode;

  @override
  void initState() {
    super.initState();
    _metaFuture = ReportsApi.fetchMeta();
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  bool get _isOther => _selectedCode == 'other';

  bool _canSubmit(List<ReportReasonOption> reasons) {
    if (_selectedCode == null) {
      return false;
    }
    if (_isOther) {
      return _detailsController.text.trim().isNotEmpty;
    }
    return true;
  }

  void _submit(List<ReportReasonOption> reasons) {
    if (!_canSubmit(reasons)) {
      return;
    }
    final details = _detailsController.text.trim();
    Navigator.of(context).pop(
      ReportReasonResult(
        reasonCode: _selectedCode!,
        details: details.isEmpty ? null : details,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 100),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7E2E0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  widget.title,
                  style: AppFonts.plusJakarta(
                    size: 20,
                    weight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.subtitle,
                  style: AppFonts.beVietnam(
                    size: 13,
                    weight: FontWeight.w500,
                    color: AppColors.hintText,
                  ),
                ),
                const SizedBox(height: 16),
                FutureBuilder<ReportsMeta>(
                  future: _metaFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (snapshot.hasError) {
                      return _MetaError(
                        onRetry: () {
                          setState(() {
                            _metaFuture = ReportsApi.fetchMeta();
                          });
                        },
                      );
                    }

                    final reasons = snapshot.data!.reasons;
                    final maxLength = snapshot.data!.descriptionMaxLength;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            for (final reason in reasons) ...[
                              _ReasonRow(
                                label: reason.label,
                                selected: _selectedCode == reason.value,
                                onTap: () {
                                  setState(() => _selectedCode = reason.value);
                                },
                              ),
                              if (reason != reasons.last)
                                const SizedBox(height: 8),
                            ],
                          ],
                        ),
                        if (_isOther) ...[
                          const SizedBox(height: 14),
                          AppTextField(
                            controller: _detailsController,
                            label: 'Tell us more',
                            hintText: 'Describe what\'s wrong',
                            textInputAction: TextInputAction.done,
                            maxLength: maxLength,
                          ),
                          const SizedBox(height: 4),
                        ],
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _canSubmit(reasons)
                                ? () => _submit(reasons)
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              disabledBackgroundColor: AppColors.hintText
                                  .withValues(alpha: 0.25),
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            child: Text(
                              'Submit report',
                              style: AppFonts.beVietnam(
                                size: 14,
                                weight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaError extends StatelessWidget {
  const _MetaError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unable to load report reasons.',
            style: AppFonts.beVietnam(
              size: 13,
              weight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.hintText.withValues(alpha: 0.2)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: Text(
              'Retry',
              style: AppFonts.beVietnam(
                size: 13,
                weight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
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
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : const Color(0xFFF4F1F0),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppFonts.beVietnam(
                  size: 14,
                  weight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: selected
                      ? AppColors.primary
                      : AppColors.hintText.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
