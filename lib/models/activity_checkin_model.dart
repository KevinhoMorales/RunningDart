import 'package:cloud_firestore/cloud_firestore.dart';

enum ActivityCheckInMethod {
  qr('qr', 'QR'),
  admin('admin', 'Admin');

  const ActivityCheckInMethod(this.firestoreValue, this.displayName);

  final String firestoreValue;
  final String displayName;

  static ActivityCheckInMethod fromFirestore(String? value) {
    return ActivityCheckInMethod.values.firstWhere(
      (method) => method.firestoreValue == value,
      orElse: () => ActivityCheckInMethod.qr,
    );
  }
}

class ActivityCheckInModel {
  const ActivityCheckInModel({
    required this.id,
    required this.activityId,
    required this.userId,
    required this.displayName,
    required this.checkedInAt,
    required this.method,
    this.checkedInBy,
    this.pointsAwarded = 0,
    this.pointEventId,
  });

  final String id;
  final String activityId;
  final String userId;
  final String displayName;
  final DateTime checkedInAt;
  final ActivityCheckInMethod method;
  final String? checkedInBy;
  final int pointsAwarded;
  final String? pointEventId;

  static String docId(String activityId, String userId) =>
      '${activityId}_$userId';

  factory ActivityCheckInModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;

    DateTime readDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      }
      return DateTime.parse(value as String);
    }

    return ActivityCheckInModel(
      id: doc.id,
      activityId: data['activityId'] as String,
      userId: data['userId'] as String,
      displayName: data['displayName'] as String? ?? 'Miembro',
      checkedInAt: readDate(data['checkedInAt']),
      method: ActivityCheckInMethod.fromFirestore(data['method'] as String?),
      checkedInBy: data['checkedInBy'] as String?,
      pointsAwarded: (data['pointsAwarded'] as num?)?.toInt() ?? 0,
      pointEventId: data['pointEventId'] as String?,
    );
  }
}
