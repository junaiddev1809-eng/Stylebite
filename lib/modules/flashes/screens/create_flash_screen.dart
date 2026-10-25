import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/media/picked_media.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../controllers/flash_controller.dart';
import '../models/flash_model.dart';

class CreateFlashScreen extends StatefulWidget {
  const CreateFlashScreen({
    super.key,
    required this.media,
    this.kind = FlashKind.outfit,
  });

  final PickedMedia media;
  final FlashKind kind;

  @override
  State<CreateFlashScreen> createState() => _CreateFlashScreenState();
}

class _CreateFlashScreenState extends State<CreateFlashScreen> {
  final _caption = TextEditingController();
  late FlashKind _kind = widget.kind;
  var _saving = false;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    await FlashController.ensure().addFlash(
      media: widget.media,
      caption: _caption.text,
      kind: _kind,
    );
    if (mounted) {
      Get.back(result: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(File(widget.media.path), fit: BoxFit.cover),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: Get.back,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        flashSingularLabel(_kind),
                        style: AppFonts.plusJakarta(
                          size: 16,
                          weight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: _TypeChoice(
                          label: 'Flash',
                          icon: Icons.bolt_rounded,
                          selected: _kind == FlashKind.outfit,
                          color: AppColors.primary,
                          onTap: () =>
                              setState(() => _kind = FlashKind.outfit),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TypeChoice(
                          label: 'Bite',
                          icon: Icons.restaurant_rounded,
                          selected: _kind == FlashKind.food,
                          color: const Color(0xFF1F8A4C),
                          onTap: () => setState(() => _kind = FlashKind.food),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _caption,
                    maxLines: 2,
                    style: AppFonts.beVietnam(
                      size: 14,
                      weight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Add a caption…',
                      hintStyle: AppFonts.beVietnam(
                        size: 14,
                        weight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.35),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _saving ? null : _publish,
                      style: FilledButton.styleFrom(
                        backgroundColor: _kind == FlashKind.food
                            ? const Color(0xFF1F8A4C)
                            : AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _kind == FlashKind.food
                                  ? 'Share Bite'
                                  : 'Share Flash',
                              style: AppFonts.beVietnam(
                                size: 15,
                                weight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeChoice extends StatelessWidget {
  const _TypeChoice({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : Colors.white24,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppFonts.beVietnam(
                size: 14,
                weight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
