import 'package:flutter/material.dart';

/// Double-tap zooms a photo in, and the next double-tap zooms it back out.
class DoubleTapZoom extends StatefulWidget {
  const DoubleTapZoom({
    super.key,
    required this.child,
    this.onTap,
    this.onDoubleTapLike,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// When set, a double tap likes the post instead of zooming.
  final VoidCallback? onDoubleTapLike;

  @override
  State<DoubleTapZoom> createState() => _DoubleTapZoomState();
}

class _DoubleTapZoomState extends State<DoubleTapZoom> {
  final TransformationController _transform = TransformationController();
  TapDownDetails? _doubleTapDetails;
  var _zoomed = false;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _zoomOut() {
    _transform.value = Matrix4.identity();
    _zoomed = false;
  }

  void _zoomIn() {
    final position = _doubleTapDetails?.localPosition ?? Offset.zero;
    const scale = 2.6;
    final dx = -position.dx * (scale - 1);
    final dy = -position.dy * (scale - 1);
    _transform.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
    _zoomed = true;
  }

  void _handleDoubleTap() {
    final onDoubleTapLike = widget.onDoubleTapLike;
    if (onDoubleTapLike != null) {
      onDoubleTapLike();
      return;
    }
    setState(() {
      if (_zoomed) {
        _zoomOut();
      } else {
        _zoomIn();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // InteractiveViewer always registers a scale recognizer. That recognizer
    // wins a one-finger drag and the feed under the photo stops moving.
    // Keep the photo plain while it is not zoomed so the list keeps the drag.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onDoubleTapDown: (details) => _doubleTapDetails = details,
      onDoubleTap: _handleDoubleTap,
      child: _zoomed
          ? InteractiveViewer(
              transformationController: _transform,
              minScale: 1,
              maxScale: 4,
              panEnabled: true,
              scaleEnabled: true,
              clipBehavior: Clip.hardEdge,
              child: widget.child,
            )
          : widget.child,
    );
  }
}
