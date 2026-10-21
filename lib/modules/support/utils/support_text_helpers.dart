String humanizeSupportValue(String value) {
  return value
      .split('_')
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

const supportedSupportAttachmentExtensions = <String>['jpg', 'jpeg', 'png', 'webp'];

bool isSupportedSupportAttachment(String path) {
  final extension = path.split('.').last.toLowerCase();
  return supportedSupportAttachmentExtensions.contains(extension);
}
