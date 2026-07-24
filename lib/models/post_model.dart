import 'package:cloud_firestore/cloud_firestore.dart';

/// Datos mínimos de alguien que dio "me gusta", desnormalizados dentro del
/// post por la Cloud Function para poder mostrar nombres en el feed sin leer
/// los likes de cada publicación.
class PostLikePreview {
  const PostLikePreview({
    required this.userId,
    required this.displayName,
    this.photoUrl,
  });

  final String userId;
  final String displayName;
  final String? photoUrl;

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'displayName': displayName,
      'photoUrl': photoUrl,
    };
  }

  factory PostLikePreview.fromJson(Map<String, dynamic> json) {
    return PostLikePreview(
      userId: json['userId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      photoUrl: json['photoUrl'] as String?,
    );
  }

  static List<PostLikePreview> listFrom(dynamic value) {
    if (value is! List) {
      return const [];
    }
    final items = <PostLikePreview>[];
    for (final entry in value) {
      if (entry is Map) {
        final preview = PostLikePreview.fromJson(
          entry.map((key, value) => MapEntry(key.toString(), value)),
        );
        if (preview.userId.isNotEmpty) {
          items.add(preview);
        }
      }
    }
    return items;
  }
}

class PostModel {
  const PostModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
    this.authorPhotoUrl,
    this.imageUrl,
    this.caption,
    this.likesCount = 0,
    this.recentLikes = const [],
  });

  final String id;
  final String authorId;
  final String authorName;
  final DateTime createdAt;
  final String? authorPhotoUrl;
  final String? imageUrl;
  final String? caption;

  /// Lo mantiene la Cloud Function `onPostLikeWritten`, no la app.
  final int likesCount;
  final List<PostLikePreview> recentLikes;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'authorId': authorId,
      'authorName': authorName,
      'authorPhotoUrl': authorPhotoUrl,
      'imageUrl': imageUrl,
      'caption': caption,
      'createdAt': createdAt.toIso8601String(),
      'likesCount': likesCount,
      'recentLikes': recentLikes.map((like) => like.toJson()).toList(),
    };
  }

  /// `likesCount` y `recentLikes` quedan fuera a propósito: los escribe la
  /// Cloud Function y publicar no debe pisarlos.
  Map<String, dynamic> toFirestore() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      if (authorPhotoUrl != null && authorPhotoUrl!.isNotEmpty)
        'authorPhotoUrl': authorPhotoUrl,
      if (imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
      if (caption != null && caption!.isNotEmpty) 'caption': caption,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'] as String,
      authorId: json['authorId'] as String,
      authorName: json['authorName'] as String? ?? '',
      authorPhotoUrl: json['authorPhotoUrl'] as String?,
      imageUrl: json['imageUrl'] as String?,
      caption: json['caption'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      likesCount: (json['likesCount'] as num?)?.toInt() ?? 0,
      recentLikes: PostLikePreview.listFrom(json['recentLikes']),
    );
  }

  factory PostModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    DateTime readDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is String) {
        return DateTime.parse(value);
      }
      return DateTime.now();
    }

    return PostModel(
      id: doc.id,
      authorId: data['authorId'] as String,
      authorName: data['authorName'] as String? ?? '',
      authorPhotoUrl: data['authorPhotoUrl'] as String?,
      imageUrl: data['imageUrl'] as String?,
      caption: data['caption'] as String?,
      createdAt: readDate(data['createdAt']),
      likesCount: (data['likesCount'] as num?)?.toInt() ?? 0,
      recentLikes: PostLikePreview.listFrom(data['recentLikes']),
    );
  }

  PostModel copyWith({
    String? id,
    String? authorId,
    String? authorName,
    DateTime? createdAt,
    String? authorPhotoUrl,
    String? imageUrl,
    String? caption,
    int? likesCount,
    List<PostLikePreview>? recentLikes,
  }) {
    return PostModel(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      createdAt: createdAt ?? this.createdAt,
      authorPhotoUrl: authorPhotoUrl ?? this.authorPhotoUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      caption: caption ?? this.caption,
      likesCount: likesCount ?? this.likesCount,
      recentLikes: recentLikes ?? this.recentLikes,
    );
  }
}
