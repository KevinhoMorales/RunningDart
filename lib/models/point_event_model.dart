import 'package:cloud_firestore/cloud_firestore.dart';

enum PointEventType {
  activityCheckIn('activity_checkin', 'Check-in'),
  weeklyBonus('weekly_bonus', 'Bonus semanal'),
  challengeComplete('challenge_complete', 'Reto completado'),
  adminAdjustment('admin_adjustment', 'Ajuste admin'),
  reversal('reversal', 'Reverso');

  const PointEventType(this.firestoreValue, this.displayName);

  final String firestoreValue;
  final String displayName;

  static PointEventType fromFirestore(String? value) {
    return PointEventType.values.firstWhere(
      (type) => type.firestoreValue == value,
      orElse: () => PointEventType.activityCheckIn,
    );
  }
}

/// Entrada del ledger de puntos (base para League en el punto 2).
class PointEventModel {
  const PointEventModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.points,
    required this.createdAt,
    this.activityId,
    this.sourceCheckInId,
    this.weekKey,
    this.periodKey,
    this.note,
  });

  final String id;
  final String userId;
  final PointEventType type;
  final int points;
  final DateTime createdAt;
  final String? activityId;
  final String? sourceCheckInId;
  final String? weekKey;
  final String? periodKey;
  final String? note;

  factory PointEventModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;

    DateTime readDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      }
      return DateTime.parse(value as String);
    }

    return PointEventModel(
      id: doc.id,
      userId: data['userId'] as String,
      type: PointEventType.fromFirestore(data['type'] as String?),
      points: (data['points'] as num?)?.toInt() ?? 0,
      createdAt: readDate(data['createdAt']),
      activityId: data['activityId'] as String?,
      sourceCheckInId: data['sourceCheckInId'] as String?,
      weekKey: data['weekKey'] as String?,
      periodKey: data['periodKey'] as String?,
      note: data['note'] as String?,
    );
  }
}
