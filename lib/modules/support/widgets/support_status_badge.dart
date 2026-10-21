import 'package:flutter/material.dart';

import '../../../core/theme/app_fonts.dart';
import '../utils/support_text_helpers.dart';

class SupportStatusBadge extends StatelessWidget {
  const SupportStatusBadge({super.key, required this.status, this.label});

  final String status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(status);
    final resolvedLabel = (label != null && label!.trim().isNotEmpty)
        ? label!
        : style.label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        resolvedLabel,
        style: AppFonts.beVietnam(
          size: 10,
          weight: FontWeight.w800,
          color: style.color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  _StatusStyle _styleFor(String status) {
    switch (status) {
      case 'in_progress':
      case 'under_review':
        return const _StatusStyle('In Progress', Color(0xFFB8860B));
      case 'waiting_on_user':
        return const _StatusStyle('Awaiting Your Reply', Color(0xFFDB6B0B));
      case 'resolved':
        return const _StatusStyle('Resolved', Color(0xFF16A34A));
      case 'closed':
        return _StatusStyle(humanizeSupportValue(status), const Color(0xFF6B7280));
      case 'open':
        return const _StatusStyle('Open', Color(0xFF2563EB));
      default:
        return _StatusStyle(
          status.trim().isEmpty ? 'Unknown' : humanizeSupportValue(status),
          const Color(0xFF6B7280),
        );
    }
  }
}

class _StatusStyle {
  const _StatusStyle(this.label, this.color);

  final String label;
  final Color color;
}
