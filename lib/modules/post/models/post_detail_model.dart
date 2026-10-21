import '../../contest/services/contest_enrollment_store.dart';
import '../../home/models/home_post_model.dart';
import 'post_comment_model.dart';

class PostDetailResponse {
  const PostDetailResponse({
    required this.statusCode,
    required this.message,
    required this.post,
    required this.canVote,
    required this.comments,
    required this.commentsPagination,
  });

  final int statusCode;
  final String message;
  final HomePostModel post;
  final bool canVote;
  final List<PostCommentModel> comments;
  final PostCommentsPagination commentsPagination;

  factory PostDetailResponse.fromJson(Map<String, dynamic> json) {
    final postJson = json['post'] as Map<String, dynamic>? ?? const {};

    return PostDetailResponse(
      statusCode: _asInt(json['status_code']),
      message: (json['message'] ?? '').toString(),
      post: HomePostModel.fromJson(
        postJson,
        responseType: (postJson['post_type'] ?? json['type'] ?? '').toString(),
      ),
      canVote: _asBool(postJson['in_contest'] ?? json['in_contest']) ||
          ContestEnrollmentStore.instance.contains(
            (postJson['id'] ?? '').toString(),
          ),
      comments: (json['comments'] as List<dynamic>? ?? const [])
          .map(
            (item) => PostCommentModel.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      commentsPagination: PostCommentsPagination.fromJson(
        json['comments_pagination'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

class PostCommentsResponse {
  const PostCommentsResponse({
    required this.statusCode,
    required this.message,
    required this.comments,
    required this.pagination,
  });

  final int statusCode;
  final String message;
  final List<PostCommentModel> comments;
  final PostCommentsPagination pagination;

  factory PostCommentsResponse.fromJson(Map<String, dynamic> json) {
    return PostCommentsResponse(
      statusCode: _asInt(json['status_code']),
      message: (json['message'] ?? '').toString(),
      comments: (json['comments'] as List<dynamic>? ?? const [])
          .map(
            (item) => PostCommentModel.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      pagination: PostCommentsPagination.fromJson(
        json['pagination'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  return int.tryParse('${value ?? ''}') ?? fallback;
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  final raw = (value ?? '').toString().toLowerCase();
  if (raw == 'true' || raw == '1') {
    return true;
  }
  if (raw == 'false' || raw == '0') {
    return false;
  }
  return fallback;
}
