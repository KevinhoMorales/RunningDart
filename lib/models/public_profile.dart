import 'package:cloud_firestore/cloud_firestore.dart';

class PublicProfile {
  const PublicProfile({
    required this.id,
    required this.displayName,
    this.photoUrl,
    this.bio,
    this.username,
  });

  final String id;
  final String displayName;
  final String? photoUrl;
  final String? bio;
  final String? username;

  Map<String, dynamic> toFirestore() {
    final normalizedUsername = username?.trim().toLowerCase();
    final trimmedBio = bio?.trim();
    return {
      'displayName': displayName,
      'displayNameLower': displayName.trim().toLowerCase(),
      if (photoUrl != null && photoUrl!.isNotEmpty) 'photoUrl': photoUrl,
      // Se escribe siempre, incluso vacía, porque los `set` son con merge y de
      // otro modo el usuario no podría quitar su descripción.
      'bio': (trimmedBio == null || trimmedBio.isEmpty)
          ? FieldValue.delete()
          : trimmedBio,
      if (normalizedUsername != null && normalizedUsername.isNotEmpty) ...{
        'username': normalizedUsername,
        'usernameLower': normalizedUsername,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory PublicProfile.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const {};
    return PublicProfile(
      id: doc.id,
      displayName: data['displayName'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      bio: data['bio'] as String?,
      username: data['username'] as String?,
    );
  }
}
