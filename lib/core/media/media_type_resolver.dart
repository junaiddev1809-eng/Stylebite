enum AppMediaType { image, video, unknown }

class MediaTypeResolver {
  MediaTypeResolver._();

  static const Set<String> _videoExt = {
    'mp4',
    'mov',
    'm4v',
    'webm',
    'avi',
    'mkv',
  };

  static const Set<String> _imageExt = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'heic',
  };

  static AppMediaType resolve(String url, {AppMediaType? fallback}) {
    final parsed = Uri.tryParse(url);
    final path = parsed?.path.toLowerCase() ?? url.toLowerCase();
    final ext = path.contains('.') ? path.split('.').last : '';

    if (_videoExt.contains(ext)) {
      return AppMediaType.video;
    }
    if (_imageExt.contains(ext)) {
      return AppMediaType.image;
    }
    return fallback ?? AppMediaType.unknown;
  }
}
