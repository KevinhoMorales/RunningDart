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

/// Motivos por los que un administrador puede ocultar una publicación. En
/// Firestore se guarda [key] y en pantalla se muestra [label].
enum PostHiddenReason {
  offensive('offensive', 'Contenido ofensivo'),
  nudity('nudity', 'Desnudos o contenido sexual'),
  spam('spam', 'Spam o publicidad'),
  harassment('harassment', 'Acoso a otra persona'),
  other('other', 'Otro motivo');

  const PostHiddenReason(this.key, this.label);

  final String key;
  final String label;

  static PostHiddenReason? fromKey(String? key) {
    if (key == null) {
      return null;
    }
    for (final reason in values) {
      if (reason.key == key) {
        return reason;
      }
    }
    return null;
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
    this.hiddenReason,
    this.hiddenNote,
    this.hiddenAt,
    this.hiddenBy,
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

  /// Moderación: solo la escribe un administrador al ocultar la publicación,
  /// nunca el autor al publicar o editar.
  final PostHiddenReason? hiddenReason;
  final String? hiddenNote;
  final DateTime? hiddenAt;
  final String? hiddenBy;

  bool get isHidden => hiddenAt != null;

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
      'hiddenReason': hiddenReason?.key,
      'hiddenNote': hiddenNote,
      'hiddenAt': hiddenAt?.toIso8601String(),
      'hiddenBy': hiddenBy,
    };
  }

  /// `likesCount`, `recentLikes` y el detalle de moderación quedan fuera a
  /// propósito: los escriben la Cloud Function y el administrador, así que
  /// publicar o editar no debe pisarlos.
  ///
  /// `isHidden` sí va: duplica lo que ya dice [hiddenAt], pero las reglas no
  /// dejan listar publicaciones ocultas y `hiddenAt` se borra al restaurarlas,
  /// así que hace falta un booleano presente en todos los documentos para poder
  /// filtrar en el servidor.
  Map<String, dynamic> toFirestore() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      if (authorPhotoUrl != null && authorPhotoUrl!.isNotEmpty)
        'authorPhotoUrl': authorPhotoUrl,
      if (imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
      if (caption != null && caption!.isNotEmpty) 'caption': caption,
      'createdAt': Timestamp.fromDate(createdAt),
      'isHidden': isHidden,
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
      hiddenReason: PostHiddenReason.fromKey(json['hiddenReason'] as String?),
      hiddenNote: json['hiddenNote'] as String?,
      hiddenAt: json['hiddenAt'] == null
          ? null
          : DateTime.parse(json['hiddenAt'] as String),
      hiddenBy: json['hiddenBy'] as String?,
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
      hiddenReason: PostHiddenReason.fromKey(data['hiddenReason'] as String?),
      hiddenNote: data['hiddenNote'] as String?,
      hiddenAt: data['hiddenAt'] == null ? null : readDate(data['hiddenAt']),
      hiddenBy: data['hiddenBy'] as String?,
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
    PostHiddenReason? hiddenReason,
    String? hiddenNote,
    DateTime? hiddenAt,
    String? hiddenBy,
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
      hiddenReason: hiddenReason ?? this.hiddenReason,
      hiddenNote: hiddenNote ?? this.hiddenNote,
      hiddenAt: hiddenAt ?? this.hiddenAt,
      hiddenBy: hiddenBy ?? this.hiddenBy,
    );
  }
}
