import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/media/picked_media.dart';
import '../../../core/media/media_type_resolver.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/widgets/app_cached_video_player.dart';
import '../controllers/story_controller.dart';
import '../models/story_model.dart';

class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({
    super.key,
    required this.media,
    this.kind = StoryKind.outfit,
  });

  final PickedMedia media;
  final StoryKind kind;

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  final _caption = TextEditingController();
  late StoryKind _kind = widget.kind;
  var _saving = false;

  bool get _isVideo => widget.media.type == AppMediaType.video;

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
    await StoryController.ensure().addStory(
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
          if (_isVideo)
            AppCachedVideoPlayer(
              videoUrl: widget.media.path,
              autoPlay: true,
              isMuted: false,
              showControls: false,
              showLoadingIndicator: false,
            )
          else
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
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                      ),
                      const Spacer(),
                      Text(
                        _kind == StoryKind.food ? 'Food story' : 'Outfit story',
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
                          label: 'Outfit',
                          icon: Icons.checkroom_rounded,
                          selected: _kind == StoryKind.outfit,
                          color: AppColors.primary,
                          onTap: () => setState(() => _kind = StoryKind.outfit),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TypeChoice(
                          label: 'Food',
                          icon: Icons.restaurant_rounded,
                          selected: _kind == StoryKind.food,
                          color: const Color(0xFF1F8A4C),
                          onTap: () => setState(() => _kind = StoryKind.food),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _caption,
                    maxLines: 3,
                    style: AppFonts.beVietnam(
                      size: 15,
                      weight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Add a caption',
                      hintStyle: AppFonts.beVietnam(
                        size: 15,
                        weight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.35),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _publish,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kind == StoryKind.food
                            ? const Color(0xFF1F8A4C)
                            : AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _kind == StoryKind.food
                                  ? 'Share to Bite'
                                  : 'Share to Style',
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
    return Material(
      color: selected ? color : Colors.black.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? color : Colors.white24,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
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
      ),
    );
  }
}
