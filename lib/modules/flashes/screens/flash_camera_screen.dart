import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/media/media_type_resolver.dart';
import '../../../core/media/picked_media.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/app_helper.dart';
import '../controllers/flash_controller.dart';
import '../models/flash_model.dart';

/// Instants-style camera: caption first, shutter shares immediately.
/// Zoom + mid/wide frame; no gallery, no editor.
class FlashCameraScreen extends StatefulWidget {
  const FlashCameraScreen({super.key, this.kind = FlashKind.outfit});

  final FlashKind kind;

  @override
  State<FlashCameraScreen> createState() => _FlashCameraScreenState();
}

class _FlashCameraScreenState extends State<FlashCameraScreen> {
  CameraController? _camera;
  final _caption = TextEditingController();
  var _ready = false;
  var _capturing = false;
  var _sharing = false;
  var _zoom = 1.0;
  var _minZoom = 1.0;
  var _maxZoom = 1.0;
  var _wide = false; // false = mid 4:5, true = wide ~16:9
  var _pinchBase = 1.0;
  late FlashKind _kind = widget.kind;
  String? _lastSharedId;
  String? _error;

  bool get _isFood => _kind == FlashKind.food;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _caption.dispose();
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'No camera found on this device.');
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      final minZ = await controller.getMinZoomLevel();
      final maxZ = await controller.getMaxZoomLevel();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = controller;
        _minZoom = minZ;
        _maxZoom = maxZ.clamp(minZ, 8.0);
        _zoom = minZ;
        _ready = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Camera unavailable. Check permissions.');
    }
  }

  Future<void> _setZoom(double value) async {
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) return;
    final next = value.clamp(_minZoom, _maxZoom);
    await cam.setZoomLevel(next);
    if (mounted) setState(() => _zoom = next);
  }

  Future<void> _shutter() async {
    final cam = _camera;
    if (cam == null ||
        !cam.value.isInitialized ||
        _capturing ||
        _sharing ||
        cam.value.isTakingPicture) {
      return;
    }
    setState(() => _capturing = true);
    try {
      final shot = await cam.takePicture();
      final docs = await getTemporaryDirectory();
      final target = File(
        '${docs.path}/flash_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await File(shot.path).copy(target.path);

      setState(() => _sharing = true);
      final localId = await FlashController.ensure().addFlash(
        media: PickedMedia(file: target, type: AppMediaType.image),
        caption: _caption.text,
        kind: _kind,
        quiet: true,
      );
      if (!mounted) return;
      setState(() {
        _lastSharedId = localId;
        _sharing = false;
        _capturing = false;
      });
      successSnackBar(
        message: '${flashSingularLabel(_kind)} shared. Tap Undo to take it back.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _sharing = false;
      });
      errorSnackBar(message: 'Could not share that flash.');
    }
  }

  Future<void> _undo() async {
    final id = _lastSharedId;
    if (id == null) return;
    await FlashController.ensure().deleteFlash(id);
    if (!mounted) return;
    setState(() => _lastSharedId = null);
    successSnackBar(message: 'Taken back.');
  }

  @override
  Widget build(BuildContext context) {
    final accent = _isFood ? const Color(0xFF1F8A4C) : AppColors.primary;
    final aspect = _wide ? 16 / 9 : 4 / 5;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: Get.back,
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      flashPluralLabel(_kind),
                      textAlign: TextAlign.center,
                      style: AppFonts.plusJakarta(
                        size: 16,
                        weight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => FlashController.ensure().openMineArchive(
                      kind: _kind,
                    ),
                    icon: const Icon(
                      Icons.grid_view_rounded,
                      color: Colors.white,
                    ),
                    tooltip: 'Your archive',
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: aspect,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: ColoredBox(
                      color: const Color(0xFF1A1A1A),
                      child: _buildPreview(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _Chip(
                    label: 'Mid',
                    selected: !_wide,
                    color: accent,
                    onTap: () => setState(() => _wide = false),
                  ),
                  const SizedBox(width: 8),
                  _Chip(
                    label: 'Wide',
                    selected: _wide,
                    color: accent,
                    onTap: () => setState(() => _wide = true),
                  ),
                  const Spacer(),
                  _Chip(
                    label: 'Flash',
                    selected: !_isFood,
                    color: AppColors.primary,
                    onTap: () => setState(() => _kind = FlashKind.outfit),
                  ),
                  const SizedBox(width: 8),
                  _Chip(
                    label: 'Bite',
                    selected: _isFood,
                    color: const Color(0xFF1F8A4C),
                    onTap: () => setState(() => _kind = FlashKind.food),
                  ),
                ],
              ),
            ),
            if (_maxZoom > _minZoom + 0.05)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  children: [
                    const Icon(Icons.zoom_out, color: Colors.white70, size: 18),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: accent,
                          thumbColor: accent,
                          inactiveTrackColor: Colors.white24,
                        ),
                        child: Slider(
                          value: _zoom.clamp(_minZoom, _maxZoom),
                          min: _minZoom,
                          max: _maxZoom,
                          onChanged: _setZoom,
                        ),
                      ),
                    ),
                    const Icon(Icons.zoom_in, color: Colors.white70, size: 18),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: TextField(
                controller: _caption,
                style: AppFonts.beVietnam(
                  size: 14,
                  weight: FontWeight.w600,
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  hintText: 'Caption (optional)…',
                  hintStyle: AppFonts.beVietnam(
                    size: 14,
                    weight: FontWeight.w500,
                    color: Colors.white54,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Row(
                children: [
                  if (_lastSharedId != null)
                    TextButton(
                      onPressed: _undo,
                      child: Text(
                        'Undo',
                        style: AppFonts.beVietnam(
                          size: 14,
                          weight: FontWeight.w800,
                          color: AppColors.accent,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 64),
                  const Spacer(),
                  GestureDetector(
                    onTap: (_ready && !_capturing && !_sharing) ? _shutter : null,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      padding: const EdgeInsets.all(5),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _sharing || _capturing
                              ? Colors.white54
                              : Colors.white,
                          gradient: _sharing || _capturing
                              ? null
                              : LinearGradient(
                                  colors: [
                                    accent,
                                    AppColors.accent,
                                    AppColors.primary,
                                  ],
                                ),
                        ),
                        child: _sharing || _capturing
                            ? const Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.black87,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 64),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: AppFonts.beVietnam(
              size: 14,
              weight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
        ),
      );
    }
    final cam = _camera;
    if (!_ready || cam == null || !cam.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return GestureDetector(
      onScaleStart: (_) => _pinchBase = _zoom,
      onScaleUpdate: (details) {
        final next = (_pinchBase * details.scale).clamp(_minZoom, _maxZoom);
        _setZoom(next);
      },
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: cam.value.previewSize?.height ?? 720,
          height: cam.value.previewSize?.width ?? 1280,
          child: CameraPreview(cam),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? color : Colors.white24),
        ),
        child: Text(
          label,
          style: AppFonts.beVietnam(
            size: 12,
            weight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
