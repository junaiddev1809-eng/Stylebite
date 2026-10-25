import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../controllers/flash_controller.dart';
import '../models/flash_model.dart';

/// Instants-style entry: "+ Flashes" for others; separate "Yours" for mine.
class FlashTray extends StatelessWidget {
  const FlashTray({super.key, this.kind = FlashKind.outfit});

  final FlashKind kind;

  bool get _isFood => kind == FlashKind.food;

  @override
  Widget build(BuildContext context) {
    final controller = FlashController.ensure();
    return Obx(() {
      final hasPeers = controller.hasUnseenPeers(kind);
      final mineCount = controller.mineCount(kind);
      final title = flashPluralLabel(kind);
      final accent = _isFood ? const Color(0xFF1F8A4C) : AppColors.primary;

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Row(
          children: [
            _GlowEntry(
              label: title,
              accent: accent,
              glowing: hasPeers,
              onTap: () => controller.openCombined(kind: kind),
              onLongPress: () => controller.openMineArchive(kind: kind),
            ),
            const SizedBox(width: 10),
            _YoursButton(
              count: mineCount,
              accent: accent,
              onView: () => controller.openMineViewer(kind: kind),
              onManage: () => controller.openMineArchive(kind: kind),
            ),
            const Spacer(),
            if (hasPeers)
              Text(
                'New',
                style: AppFonts.beVietnam(
                  size: 11,
                  weight: FontWeight.w800,
                  color: accent,
                ),
              ),
          ],
        ),
      );
    });
  }
}

class _YoursButton extends StatelessWidget {
  const _YoursButton({
    required this.count,
    required this.accent,
    required this.onView,
    required this.onManage,
  });

  final int count;
  final Color accent;
  final VoidCallback onView;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: count > 0 ? onView : onManage,
        onLongPress: onManage,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: Colors.white,
            border: Border.all(
              color: accent.withValues(alpha: count > 0 ? 0.55 : 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_outline_rounded,
                size: 16,
                color: accent,
              ),
              const SizedBox(width: 4),
              Text(
                count > 0 ? 'Yours ($count)' : 'Yours',
                style: AppFonts.beVietnam(
                  size: 13,
                  weight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlowEntry extends StatefulWidget {
  const _GlowEntry({
    required this.label,
    required this.accent,
    required this.glowing,
    required this.onTap,
    required this.onLongPress,
  });

  final String label;
  final Color accent;
  final bool glowing;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  State<_GlowEntry> createState() => _GlowEntryState();
}

class _GlowEntryState extends State<_GlowEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.glowing) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _GlowEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.glowing && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.glowing && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final t = widget.glowing ? _pulse.value : 0.0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: Colors.white,
              border: Border.all(
                color: Color.lerp(
                      widget.accent.withValues(alpha: 0.4),
                      widget.accent,
                      t,
                    ) ??
                    widget.accent,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.accent.withValues(
                    alpha: widget.glowing ? (0.22 + t * 0.35) : 0.1,
                  ),
                  blurRadius: widget.glowing ? (12 + t * 14) : 6,
                  spreadRadius: widget.glowing ? t * 2 : 0,
                ),
              ],
            ),
            child: child,
          );
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 18, color: widget.accent),
            const SizedBox(width: 4),
            Text(
              widget.label,
              style: AppFonts.plusJakarta(
                size: 15,
                weight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
