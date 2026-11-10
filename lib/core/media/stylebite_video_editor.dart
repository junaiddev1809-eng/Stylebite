import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as pve;
import 'package:video_player/video_player.dart';

import '../theme/app_colors.dart';
import 'media_type_resolver.dart';
import 'picked_media.dart';
import 'stylebite_editor_configs.dart';

/// VSCO-like video editor: filter-first tools, baked export via pro_video_editor.
///
/// Returns [PickedMedia] on Done. Cancel returns null. Export failure returns
/// the original file so upload/reel share never breaks.
class StyleBiteVideoEditor extends StatefulWidget {
  const StyleBiteVideoEditor({super.key, required this.file});

  final File file;

  @override
  State<StyleBiteVideoEditor> createState() => _StyleBiteVideoEditorState();
}

class _StyleBiteVideoEditorState extends State<StyleBiteVideoEditor> {
  late final VideoPlayerController _player;
  late final pve.EditorVideo _editorVideo;

  ProVideoController? _proVideo;
  pve.VideoMetadata? _metadata;
  List<ImageProvider>? _thumbnails;

  TrimDurationSpan? _trimSpan;
  TrimDurationSpan? _pendingTrim;
  var _seeking = false;
  var _exporting = false;
  var _closed = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _editorVideo = pve.EditorVideo.file(widget.file);
    _player = VideoPlayerController.file(widget.file);
    unawaited(_boot());
  }

  @override
  void dispose() {
    _player.removeListener(_onTick);
    _player.dispose();
    _proVideo?.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    try {
      final metaFuture = pve.ProVideoEditor.instance.getMetadata(_editorVideo);
      await Future.wait<void>([
        _player.initialize(),
        _player.setLooping(false),
        _player.setVolume(1),
        _player.pause(),
      ]);
      final meta = await metaFuture;
      if (!mounted) return;

      _metadata = meta;
      _proVideo = ProVideoController(
        videoPlayer: _buildPlayer(),
        initialResolution: meta.resolution,
        videoDuration: meta.duration,
        fileSize: meta.fileSize,
        bitrate: meta.bitrate,
        thumbnails: _thumbnails,
      );
      _player.addListener(_onTick);
      setState(() {});
      unawaited(_loadThumbnails());
    } catch (_) {
      if (!mounted) return;
      setState(() => _initError = 'Could not open that video for editing.');
    }
  }

  Future<void> _loadThumbnails() async {
    try {
      final count = 7;
      final width =
          (MediaQuery.sizeOf(context).width / count) *
          MediaQuery.devicePixelRatioOf(context);
      final frames = await pve.ProVideoEditor.instance.getKeyFrames(
        pve.KeyFramesConfigs(
          video: _editorVideo,
          outputSize: Size.square(width.clamp(48, 160)),
          boxFit: pve.ThumbnailBoxFit.cover,
          maxOutputFrames: count,
          outputFormat: pve.ThumbnailFormat.jpeg,
        ),
      );
      if (!mounted) return;
      final providers = frames.map<ImageProvider>(MemoryImage.new).toList();
      _thumbnails = providers;
      _proVideo?.thumbnails = providers;
      if (mounted) setState(() {});
    } catch (_) {
      // Thumbnails are optional; editor still works without them.
    }
  }

  void _onTick() {
    final meta = _metadata;
    final pro = _proVideo;
    if (meta == null || pro == null) return;

    final position = _player.value.position;
    pro.setPlayTime(position);

    final span = _trimSpan;
    if (span != null && position >= span.end) {
      unawaited(_seekTo(span));
    } else if (position >= meta.duration) {
      unawaited(
        _seekTo(
          TrimDurationSpan(start: Duration.zero, end: meta.duration),
        ),
      );
    }
  }

  Future<void> _seekTo(TrimDurationSpan span) async {
    _trimSpan = span;
    if (_seeking) {
      _pendingTrim = span;
      return;
    }
    _seeking = true;
    _proVideo?.pause();
    _proVideo?.setPlayTime(span.start);
    await _player.pause();
    await _player.seekTo(span.start);
    _seeking = false;
    final pending = _pendingTrim;
    if (pending != null) {
      _pendingTrim = null;
      await _seekTo(pending);
    }
  }

  Future<void> _onComplete(CompleteParameters parameters) async {
    if (_exporting || _closed) return;
    setState(() => _exporting = true);

    final meta = _metadata;
    if (meta == null) {
      _finishWithOriginal();
      return;
    }

    try {
      final directory = await getTemporaryDirectory();
      final taskId = DateTime.now().microsecondsSinceEpoch.toString();
      final outPath =
          '${directory.path}/stylebite_video_$taskId.mp4';

      final export = pve.VideoRenderData(
        id: taskId,
        videoSegments: [pve.VideoSegment(video: _editorVideo)],
        imageLayers: [
          if (parameters.layers.isNotEmpty)
            pve.ImageLayer(
              image: pve.EditorLayerImage.memory(parameters.image),
            ),
        ],
        blur: parameters.blur > 0 ? parameters.blur : null,
        colorFilters: [
          pve.ColorFilter(matrix: parameters.colorFiltersCombined),
        ],
        startTime: parameters.startTime,
        endTime: parameters.endTime,
        transform: parameters.isTransformed
            ? pve.ExportTransform(
                width: parameters.cropWidth,
                height: parameters.cropHeight,
                rotateTurns: 4 - parameters.rotateTurns,
                x: parameters.cropX,
                y: parameters.cropY,
                flipX: parameters.flipX,
                flipY: parameters.flipY,
              )
            : null,
        enableAudio: _proVideo?.isAudioEnabled ?? true,
        outputFormat: pve.VideoOutputFormat.mp4,
        bitrate: meta.bitrate,
      );

      final rendered = await pve.ProVideoEditor.instance.renderVideoToFile(
        outPath,
        export,
      );
      if (!mounted || _closed) return;
      _closed = true;
      Get.back(
        result: PickedMedia(
          file: File(rendered),
          type: AppMediaType.video,
        ),
      );
    } catch (_) {
      _finishWithOriginal();
    }
  }

  void _finishWithOriginal() {
    if (_closed) return;
    _closed = true;
    Get.back(
      result: PickedMedia(file: widget.file, type: AppMediaType.video),
    );
  }

  void _onClose(EditorMode _) {
    if (_closed || _exporting) return;
    _closed = true;
    Get.back();
  }

  Widget _buildPlayer() {
    final size = _player.value.size;
    final ratio = size.width <= 0 || size.height <= 0
        ? 9 / 16
        : size.aspectRatio;
    return Center(
      child: AspectRatio(
        aspectRatio: ratio,
        child: VideoPlayer(_player),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_initError != null) {
      return Scaffold(
        backgroundColor: StyleBiteEditorConfigs.canvas,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _initError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      if (_closed) return;
                      _closed = true;
                      Get.back();
                    },
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final pro = _proVideo;
    if (pro == null) {
      return const Scaffold(
        backgroundColor: StyleBiteEditorConfigs.canvas,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ProImageEditor.video(
          pro,
          configs: StyleBiteEditorConfigs.build(forVideo: true),
          callbacks: ProImageEditorCallbacks(
            onCompleteWithParameters: _onComplete,
            onCloseEditor: _onClose,
            videoEditorCallbacks: VideoEditorCallbacks(
              onPause: _player.pause,
              onPlay: _player.play,
              onMuteToggle: (muted) {
                unawaited(_player.setVolume(muted ? 0 : 1));
              },
              onTrimSpanUpdate: (_) {
                if (_player.value.isPlaying) {
                  _proVideo?.pause();
                }
              },
              onTrimSpanEnd: _seekTo,
            ),
          ),
        ),
        if (_exporting)
          const ColoredBox(
            color: Color(0x99000000),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 12),
                  Text(
                    'Applying filters…',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
