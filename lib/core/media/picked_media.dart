import 'dart:io';

import 'media_type_resolver.dart';

class PostGalleryPick {
  const PostGalleryPick({this.media = const [], this.notice = ''});

  final List<PickedMedia> media;
  final String notice;
}

class PickedMedia {
  const PickedMedia({required this.file, required this.type});

  final File file;
  final AppMediaType type;

  String get path => file.path;
}
