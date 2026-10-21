import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:heroicons/heroicons.dart';

import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../widgets/app_hero_icon.dart';

enum PhotoCropMode { cover, avatar }

class CoverImageCropScreen extends StatefulWidget {
  const CoverImageCropScreen({
    super.key,
    required this.imageFile,
    this.mode = PhotoCropMode.cover,
  });

  final File imageFile;
  final PhotoCropMode mode;

  @override
  State<CoverImageCropScreen> createState() => _CoverImageCropScreenState();
}

class _CoverImageCropScreenState extends State<CoverImageCropScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  final TransformationController _transform = TransformationController();

  Size? _imageSize;
  Size? _viewport;
  bool _saving = false;
  bool _didInitTransform = false;

  bool get _isAvatar => widget.mode == PhotoCropMode.avatar;

  @override
  void initState() {
    super.initState();
    _resolveImageSize();
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _resolveImageSize() {
    final stream = FileImage(widget.imageFile).resolve(
      const ImageConfiguration(),
    );
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        stream.removeListener(listener);
        if (!mounted) {
          return;
        }
        setState(() {
          _imageSize = Size(
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          );
        });
      },
      onError: (error, stack) {
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
  }

  double _containScale(Size viewport) {
    final imageSize = _imageSize!;
    return math.min(
      viewport.width / imageSize.width,
      viewport.height / imageSize.height,
    );
  }

  double _coverScale(Size viewport) {
    final imageSize = _imageSize!;
    return math.max(
      viewport.width / imageSize.width,
      viewport.height / imageSize.height,
    );
  }

  Size _containedSize(Size viewport) {
    final scale = _containScale(viewport);
    return Size(_imageSize!.width * scale, _imageSize!.height * scale);
  }

  Matrix4 _fitMatrix(Size viewport) {
    final displayed = _containedSize(viewport);
    final dx = (viewport.width - displayed.width) / 2;
    final dy = (viewport.height - displayed.height) / 2;
    return Matrix4.identity()..translateByDouble(dx, dy, 0, 1);
  }

  void _initOrResetTransform(Size viewport, {required bool force}) {
    if (_imageSize == null) {
      return;
    }
    if (!force && _didInitTransform && _viewport == viewport) {
      return;
    }
    _viewport = viewport;
    _didInitTransform = true;
    _transform.value = _fitMatrix(viewport);
  }

  void _resetToFullImage() {
    final viewport = _viewport;
    if (viewport == null || _imageSize == null) {
      return;
    }
    setState(() {
      _transform.value = _fitMatrix(viewport);
    });
  }

  void _closeWithoutSaving() {
    if (_saving) {
      return;
    }
    Navigator.of(context).pop<Uint8List?>(null);
  }

  Future<void> _confirm() async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      return;
    }

    try {
      final boundary =
          _boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        return;
      }
      final viewport = MediaQuery.sizeOf(context);
      final longest = math.max(viewport.width, viewport.height);
      var pixelRatio = (1600 / longest).clamp(1.0, 2.5);

      ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      Uint8List? bytes = data?.buffer.asUint8List();
      if (bytes == null) {
        return;
      }

      const maxBytes = 4 * 1024 * 1024;
      Uint8List captured = bytes;
      while (captured.lengthInBytes > maxBytes && pixelRatio > 1.0) {
        pixelRatio *= 0.75;
        image = await boundary.toImage(pixelRatio: pixelRatio);
        data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        final next = data?.buffer.asUint8List();
        if (next == null) {
          return;
        }
        captured = next;
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop<Uint8List>(captured);
    } finally {
      if (mounted && _saving) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final hint = _isAvatar
        ? 'Pinch to zoom  •  Drag to position  •  Starts fully zoomed out'
        : 'Pinch to zoom in or out  •  Drag to reposition';

    return PopScope(
      canPop: !_saving,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _saving) {
          return;
        }
        _closeWithoutSaving();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (_imageSize == null)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            else
              _isAvatar ? _buildAvatarCropper() : _buildCoverCropper(),
            Positioned(
              top: topInset + 8,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  _roundButton(
                    icon: HeroIcons.xMark,
                    onTap: _closeWithoutSaving,
                  ),
                  const Spacer(),
                  _roundButton(
                    icon: HeroIcons.arrowPath,
                    onTap: _resetToFullImage,
                  ),
                  const SizedBox(width: 8),
                  _roundButton(
                    icon: HeroIcons.check,
                    background: AppColors.primary,
                    iconColor: Colors.white,
                    onTap: _confirm,
                  ),
                ],
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: bottomInset + 28,
              child: IgnorePointer(
                child: Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: AppFonts.beVietnam(
                    size: 13,
                    weight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
              ),
            ),
            if (_saving)
              const ColoredBox(
                color: Color(0x66000000),
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverCropper() {
    return Positioned.fill(
      child: ClipRect(
        child: RepaintBoundary(
          key: _boundaryKey,
          child: ColoredBox(
            color: Colors.black,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return _zoomableImage(
                  Size(constraints.maxWidth, constraints.maxHeight),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarCropper() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final shortest = math.min(constraints.maxWidth, constraints.maxHeight);
        final cropSize = shortest * 0.82;
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Colors.black),
            Center(
              child: SizedBox(
                width: cropSize,
                height: cropSize,
                child: ClipOval(
                  child: RepaintBoundary(
                    key: _boundaryKey,
                    child: ColoredBox(
                      color: Colors.black,
                      child: _zoomableImage(Size(cropSize, cropSize)),
                    ),
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: CustomPaint(
                painter: _CircleCropOverlayPainter(cropSize: cropSize),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _zoomableImage(Size viewport) {
    final displayed = _containedSize(viewport);
    final coverRatio = _coverScale(viewport) / _containScale(viewport);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _initOrResetTransform(viewport, force: false);
    });

    return SizedBox(
      width: viewport.width,
      height: viewport.height,
      child: InteractiveViewer(
        transformationController: _transform,
        constrained: false,
        minScale: 0.6,
        maxScale: math.max(6.0, coverRatio * 3.0),
        panEnabled: true,
        scaleEnabled: true,
        boundaryMargin: const EdgeInsets.all(280),
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: displayed.width,
          height: displayed.height,
          child: Image.file(
            widget.imageFile,
            fit: BoxFit.fill,
            width: displayed.width,
            height: displayed.height,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }

  Widget _roundButton({
    required HeroIcons icon,
    required VoidCallback onTap,
    Color background = const Color(0xCC111111),
    Color iconColor = Colors.white,
  }) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _saving ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: AppHeroIconData(icon, color: iconColor, size: 22),
        ),
      ),
    );
  }
}

class _CircleCropOverlayPainter extends CustomPainter {
  const _CircleCropOverlayPainter({required this.cropSize});

  final double cropSize;

  @override
  void paint(Canvas canvas, Size size) {
    final hole = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: cropSize,
      height: cropSize,
    );
    final overlay = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(hole);
    canvas.drawPath(
      overlay,
      Paint()..color = const Color(0x99000000),
    );
    canvas.drawOval(
      hole,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
  }

  @override
  bool shouldRepaint(covariant _CircleCropOverlayPainter oldDelegate) {
    return oldDelegate.cropSize != cropSize;
  }
}
