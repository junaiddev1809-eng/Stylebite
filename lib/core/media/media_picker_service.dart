import 'dart:io';
import 'dart:typed_data';

import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:path_provider/path_provider.dart';

import 'cover_image_crop_screen.dart';
import 'media_type_resolver.dart';
import 'picked_media.dart';

class MediaPickerService {
  MediaPickerService._();

  static final ImagePicker _picker = ImagePicker();

  static const int carouselPhotoLimit = 10;

  static Future<PickedMedia?> pickFromCamera() => _pickFromCamera();

  static Future<PickedMedia?> pickFromGallery() => _pickFromGallery();

  /// Gallery pick for a post. One photo still opens the editor. Several
  /// photos become one carousel, capped at [carouselPhotoLimit].
  static Future<PostGalleryPick> pickPostGallery() async {
    final picked = await _picker.pickMultipleMedia(
      limit: carouselPhotoLimit,
      imageQuality: 92,
    );
    if (picked.isEmpty) {
      return const PostGalleryPick();
    }

    final images = <PickedMedia>[];
    final videos = <PickedMedia>[];
    for (final file in picked) {
      final headerBytes = await _readHeaderBytes(file.path);
      final mimeType = lookupMimeType(file.path, headerBytes: headerBytes);
      final isVideo = mimeType?.startsWith('video/') ?? false;
      final media = PickedMedia(
        file: File(file.path),
        type: isVideo ? AppMediaType.video : AppMediaType.image,
      );
      if (isVideo) {
        videos.add(media);
      } else {
        images.add(media);
      }
    }

    if (videos.isNotEmpty && images.isNotEmpty) {
      return const PostGalleryPick(
        notice:
            'Pick up to 10 photos for a carousel, or one video on its own.',
      );
    }
    if (videos.length > 1) {
      return const PostGalleryPick(
        notice: 'Choose one video, or up to 10 photos.',
      );
    }
    if (videos.length == 1) {
      return PostGalleryPick(media: videos);
    }

    final limited = images.take(carouselPhotoLimit).toList(growable: false);
    final trimmed = images.length > carouselPhotoLimit;
    if (limited.length == 1) {
      final edited = await _editImage(limited.first.path);
      if (edited == null) {
        return const PostGalleryPick();
      }
      return PostGalleryPick(media: [edited]);
    }
    return PostGalleryPick(
      media: limited,
      notice: trimmed ? 'A post can include up to 10 photos.' : '',
    );
  }

  static Future<PickedMedia?> pickAvatarImage({required bool fromCamera}) {
    return _pickAndCrop(
      fromCamera: fromCamera,
      mode: PhotoCropMode.avatar,
      loopOnCancel: false,
    );
  }

  /// Cover/glance photos only. Closing the crop screen reopens the same
  /// picker so the user can choose another photo without returning to the
  /// glance page. Cancelling the native gallery/camera is the way out.
  static Future<PickedMedia?> pickCoverImage({required bool fromCamera}) {
    return _pickAndCrop(
      fromCamera: fromCamera,
      mode: PhotoCropMode.cover,
      loopOnCancel: true,
    );
  }

  static Future<PickedMedia?> _pickAndCrop({
    required bool fromCamera,
    required PhotoCropMode mode,
    required bool loopOnCancel,
  }) async {
    final source = fromCamera ? ImageSource.camera : ImageSource.gallery;
    while (true) {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 95,
      );
      if (image == null) {
        return null;
      }

      final croppedBytes = await Get.to<Uint8List?>(
        () => CoverImageCropScreen(
          imageFile: File(image.path),
          mode: mode,
        ),
        fullscreenDialog: true,
        transition: Transition.fadeIn,
        duration: const Duration(milliseconds: 180),
      );
      if (croppedBytes == null) {
        if (!loopOnCancel) {
          return null;
        }
        await Future<void>.delayed(const Duration(milliseconds: 180));
        continue;
      }

      final prefix = mode == PhotoCropMode.avatar ? 'avatar' : 'cover';
      final tempDir = await getTemporaryDirectory();
      final croppedFile = File(
        '${tempDir.path}/${prefix}_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await croppedFile.writeAsBytes(croppedBytes);
      return PickedMedia(file: croppedFile, type: AppMediaType.image);
    }
  }

  // pickImage() and pickVideo() each open their own filtered native picker.
  // Chaining them (try image, fall back to video on cancel) meant closing
  // the image-only gallery immediately reopened it filtered to videos only
  // — pickMedia() opens one unified gallery covering both media types.
  static Future<PickedMedia?> _pickFromGallery() async {
    final media = await _picker.pickMedia();
    if (media == null) {
      return null;
    }

    // Neither the path nor XFile.mimeType is trustworthy here:
    // image_picker_android's pickMedia() never populates mimeType at all
    // (its platform channel only returns bare paths), and the copied cache
    // path's extension isn't guaranteed either. Sniffing the file's actual
    // magic bytes is the only reliable signal — an unrecognized video
    // defaulting to "image" would route it into the image editor, which
    // can't handle video.
    final headerBytes = await _readHeaderBytes(media.path);
    final mimeType = lookupMimeType(media.path, headerBytes: headerBytes);
    final isVideo = mimeType?.startsWith('video/') ?? false;
    if (isVideo) {
      return PickedMedia(file: File(media.path), type: AppMediaType.video);
    }

    return _editImage(media.path);
  }

  // The camera has no unified photo/video mode, so it still has to launch
  // as either a photo or a video capture — falling back to video only when
  // the photo capture is cancelled.
  static Future<PickedMedia?> _pickFromCamera() async {
    final image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      return _editImage(image.path);
    }

    final video = await _picker.pickVideo(source: ImageSource.camera);
    if (video == null) {
      return null;
    }

    final type = MediaTypeResolver.resolve(
      video.path,
      fallback: AppMediaType.video,
    );
    return PickedMedia(
      file: File(video.path),
      type: type == AppMediaType.unknown ? AppMediaType.video : type,
    );
  }

  static Future<List<int>?> _readHeaderBytes(String path) async {
    try {
      final raf = await File(path).open();
      try {
        return await raf.read(defaultMagicNumbersMaxLength);
      } finally {
        await raf.close();
      }
    } catch (_) {
      return null;
    }
  }

  static Future<PickedMedia?> _editImage(String path) async {
    final Uint8List? editedBytes = await Get.to(
      () => ProImageEditor.file(
        File(path),
        callbacks: ProImageEditorCallbacks(
          onImageEditingComplete: (bytes) async {
            Get.back(result: bytes);
          },
        ),
      ),
    );

    if (editedBytes == null) {
      return null;
    }

    final tempDir = await getTemporaryDirectory();
    final editedFile = File('${tempDir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await editedFile.writeAsBytes(editedBytes);

    return PickedMedia(file: editedFile, type: AppMediaType.image);
  }
}
