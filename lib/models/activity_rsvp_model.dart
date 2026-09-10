import 'package:cloud_firestore/cloud_firestore.dart';

enum ActivityRsvpStatus {
  confirmed('confirmed', 'Confirmado'),
  cancelled('cancelled', 'Cancelado');

  const ActivityRsvpStatus(this.firestoreValue, this.displayName);

  final String firestoreValue;
  final String displayName;

  static ActivityRsvpStatus fromFirestore(String? value) {
    return ActivityRsvpStatus.values.firstWhere(
      (status) => status.firestoreValue == value,
      orElse: () => ActivityRsvpStatus.cancelled,
    );
  }
}

class ActivityRsvpModel {
  const ActivityRsvpModel({
    required this.id,
    required this.activityId,
    required this.userId,
    required this.displayName,
    required this.status,
    required this.updatedAt,
    this.confirmedAt,
    this.cancelledAt,
  });

  final String id;
  final String activityId;
  final String userId;
  final String displayName;
  final ActivityRsvpStatus status;
  final DateTime updatedAt;
  final DateTime? confirmedAt;
  final DateTime? cancelledAt;

  bool get isConfirmed => status == ActivityRsvpStatus.confirmed;

  static String docId(String activityId, String userId) =>
      '${activityId}_$userId';

  Map<String, dynamic> toFirestore() {
    return {
      'activityId': activityId,
      'userId': userId,
      'displayName': displayName,
      'status': status.firestoreValue,
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (confirmedAt != null) 'confirmedAt': Timestamp.fromDate(confirmedAt!),
      if (cancelledAt != null) 'cancelledAt': Timestamp.fromDate(cancelledAt!),
    };
  }

  factory ActivityRsvpModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;

    DateTime readDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      }
      return DateTime.parse(value as String);
    }

    DateTime? readOptionalDate(dynamic value) {
      if (value == null) {
        return null;
      }
      return readDate(value);
    }

    return ActivityRsvpModel(
      id: doc.id,
      activityId: data['activityId'] as String,
      userId: data['userId'] as String,
      displayName: data['displayName'] as String? ?? 'Miembro',
      status: ActivityRsvpStatus.fromFirestore(data['status'] as String?),
      updatedAt: readDate(data['updatedAt']),
      confirmedAt: readOptionalDate(data['confirmedAt']),
      cancelledAt: readOptionalDate(data['cancelledAt']),
    );
  }
}
