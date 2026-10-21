class MemoriesModel {
  int? statusCode;
  String? message;
  List<Memories>? memories;
  Pagination? pagination;

  MemoriesModel({
    this.statusCode,
    this.message,
    this.memories,
    this.pagination,
  });

  MemoriesModel.fromJson(Map<String, dynamic> json) {
    statusCode = json['status_code'];
    message = json['message'];
    if (json['memories'] != null) {
      memories = <Memories>[];
      json['memories'].forEach((v) {
        memories!.add(Memories.fromJson(v));
      });
    }
    pagination = json['pagination'] != null
        ? Pagination.fromJson(json['pagination'])
        : null;
  }
}

class Memories {
  int? id;
  int? userId;
  String? title;
  String? shortTitle;
  String? shortDescription;
  String? description;
  String? note;
  String? memoryDate;
  String? location;
  String? city;
  String? country;
  double? lat;
  double? lng;
  int? rating;
  int? ratingCount;
  bool? isFavorite;
  String? visibility;
  String? status;
  int? likeCount;
  int? commentCount;
  int? saveCount;
  List<Images>? images;
  String? createdAt;
  String? updatedAt;

  Memories({
    this.id,
    this.userId,
    this.title,
    this.shortTitle,
    this.shortDescription,
    this.description,
    this.note,
    this.memoryDate,
    this.location,
    this.city,
    this.country,
    this.lat,
    this.lng,
    this.rating,
    this.ratingCount,
    this.isFavorite,
    this.visibility,
    this.status,
    this.likeCount,
    this.commentCount,
    this.saveCount,
    this.images,
    this.createdAt,
    this.updatedAt,
  });

  Memories.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    userId = json['user_id'];
    title = json['title'];
    shortTitle = json['short_title'];
    shortDescription = json['short_description'];
    description = json['description'];
    note = json['note'];
    memoryDate = json['memory_date'];
    location = json['location'];
    city = json['city'];
    country = json['country'];
    lat = json['lat'];
    lng = json['lng'];
    rating = json['rating'];
    ratingCount = json['rating_count'];
    isFavorite = json['is_favorite'];
    visibility = json['visibility'];
    status = json['status'];
    likeCount = json['like_count'];
    commentCount = json['comment_count'];
    saveCount = json['save_count'];
    if (json['images'] != null) {
      images = <Images>[];
      json['images'].forEach((v) {
        images!.add(Images.fromJson(v));
      });
    }
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
  }
}

class Images {
  int? id;
  String? fileUrl;
  String? filePath;
  String? thumbnailUrl;
  String? mimeType;
  int? sizeBytes;
  int? sortOrder;

  Images({
    this.id,
    this.fileUrl,
    this.filePath,
    this.thumbnailUrl,
    this.mimeType,
    this.sizeBytes,
    this.sortOrder,
  });

  Images.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    fileUrl = json['file_url'];
    filePath = json['file_path'];
    thumbnailUrl = json['thumbnail_url'];
    mimeType = json['mime_type'];
    sizeBytes = json['size_bytes'];
    sortOrder = json['sort_order'];
  }
}

class Pagination {
  int? total;
  int? perPage;
  int? currentPage;
  int? lastPage;
  int? offset;
  int? skip;

  Pagination({
    this.total,
    this.perPage,
    this.currentPage,
    this.lastPage,
    this.offset,
    this.skip,
  });

  Pagination.fromJson(Map<String, dynamic> json) {
    total = json['total'];
    perPage = json['per_page'];
    currentPage = json['current_page'];
    lastPage = json['last_page'];
    offset = json['offset'];
    skip = json['skip'];
  }
}
