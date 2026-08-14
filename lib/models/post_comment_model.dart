import 'package:cloud_firestore/cloud_firestore.dart';

/// Comentario de una publicación. Vive en `post_comments` (mismo prefijo de
/// ambiente que posts y likes) y el autor se guarda desnormalizado para pintar
/// el hilo sin leer perfiles en cada mensaje.
class PostCommentModel {
  const PostCommentModel({
    required this.id,
    required this.postId,
    required this.postAuthorId,
    required this.authorId,
    required this.authorName,
    required this.text,
    required this.createdAt,
    this.authorPhotoUrl,
  });

  static const maxTextLength = 500;

  final String id;
  final String postId;
  final String postAuthorId;
  final String authorId;
  final String authorName;
  final String text;
  final DateTime createdAt;
  final String? authorPhotoUrl;

  Map<String, dynamic> toFirestore() {
    return {
      'postId': postId,
      'postAuthorId': postAuthorId,
      'authorId': authorId,
      'authorName': authorName,
      if (authorPhotoUrl != null && authorPhotoUrl!.isNotEmpty)
        'authorPhotoUrl': authorPhotoUrl,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory PostCommentModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
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

    return PostCommentModel(
      id: doc.id,
      postId: data['postId'] as String? ?? '',
      postAuthorId: data['postAuthorId'] as String? ?? '',
      authorId: data['authorId'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '',
      authorPhotoUrl: data['authorPhotoUrl'] as String?,
      text: data['text'] as String? ?? '',
      createdAt: readDate(data['createdAt']),
    );
  }

  factory PostCommentModel.fromJson(Map<String, dynamic> json) {
    return PostCommentModel(
      id: json['id'] as String,
      postId: json['postId'] as String? ?? '',
      postAuthorId: json['postAuthorId'] as String? ?? '',
      authorId: json['authorId'] as String? ?? '',
      authorName: json['authorName'] as String? ?? '',
      authorPhotoUrl: json['authorPhotoUrl'] as String?,
      text: json['text'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'postId': postId,
      'postAuthorId': postAuthorId,
      'authorId': authorId,
      'authorName': authorName,
      'authorPhotoUrl': authorPhotoUrl,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
