import 'package:cloud_firestore/cloud_firestore.dart';

/// En qué punto de la revisión está un reporte. Los reportes creados antes de
/// que existiera la cola de moderación no traen el campo, así que un documento
/// sin `status` se considera pendiente.
enum PostReportStatus {
  pending,
  resolved,
  dismissed;

  String get firestoreValue => name;

  String get displayName => switch (this) {
        PostReportStatus.pending => 'Pendiente',
        PostReportStatus.resolved => 'Resuelto',
        PostReportStatus.dismissed => 'Descartado',
      };

  static PostReportStatus fromFirestore(String? value) {
    return switch (value) {
      'resolved' => PostReportStatus.resolved,
      'dismissed' => PostReportStatus.dismissed,
      _ => PostReportStatus.pending,
    };
  }
}

class PostReportModel {
  const PostReportModel({
    required this.id,
    required this.postId,
    required this.reportedByUserId,
    required this.status,
    this.reason,
    this.createdAt,
    this.reviewedAt,
    this.reviewedBy,
  });

  final String id;
  final String postId;
  final String reportedByUserId;
  final PostReportStatus status;
  final String? reason;
  final DateTime? createdAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;

  bool get isPending => status == PostReportStatus.pending;

  factory PostReportModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const {};

    DateTime? readDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is String) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    return PostReportModel(
      id: doc.id,
      postId: data['postId'] as String? ?? '',
      reportedByUserId: data['reportedByUserId'] as String? ?? '',
      status: PostReportStatus.fromFirestore(data['status'] as String?),
      reason: data['reason'] as String?,
      createdAt: readDate(data['createdAt']),
      reviewedAt: readDate(data['reviewedAt']),
      reviewedBy: data['reviewedBy'] as String?,
    );
  }
}
