import 'package:cloud_firestore/cloud_firestore.dart';

import 'activity_type.dart';

class ActivityModel {
  const ActivityModel({
    required this.id,
    required this.title,
    required this.type,
    required this.startsAt,
    required this.createdAt,
    required this.updatedAt,
    this.endsAt,
    this.venue,
    this.location,
    this.description,
    this.isPublished = true,
    this.checkInEnabled = false,
    this.checkInOpensAt,
    this.checkInClosesAt,
    this.checkInToken,
    this.confirmedCount = 0,
    this.checkedInCount = 0,
    this.recurrenceKey,
    this.createdBy,
  });

  final String id;
  final String title;
  final ActivityType type;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String? venue;
  final String? location;
  final String? description;
  final bool isPublished;
  final bool checkInEnabled;
  final DateTime? checkInOpensAt;
  final DateTime? checkInClosesAt;
  final String? checkInToken;
  final int confirmedCount;
  final int checkedInCount;
  final String? recurrenceKey;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isSocialRun => type == ActivityType.socialRun;

  bool isCheckInWindowOpen([DateTime? now]) {
    final reference = now ?? DateTime.now();
    if (!checkInEnabled) {
      return false;
    }
    if (checkInOpensAt != null && reference.isBefore(checkInOpensAt!)) {
      return false;
    }
    if (checkInClosesAt != null && reference.isAfter(checkInClosesAt!)) {
      return false;
    }
    return true;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'type': type.firestoreValue,
      'startsAt': Timestamp.fromDate(startsAt),
      if (endsAt != null) 'endsAt': Timestamp.fromDate(endsAt!),
      if (venue != null && venue!.isNotEmpty) 'venue': venue,
      if (location != null && location!.isNotEmpty) 'location': location,
      if (description != null && description!.isNotEmpty)
        'description': description,
      'isPublished': isPublished,
      'checkInEnabled': checkInEnabled,
      if (checkInOpensAt != null)
        'checkInOpensAt': Timestamp.fromDate(checkInOpensAt!),
      if (checkInClosesAt != null)
        'checkInClosesAt': Timestamp.fromDate(checkInClosesAt!),
      // checkInToken NO va en activities (solo activity_checkin_secrets).
      'confirmedCount': confirmedCount,
      'checkedInCount': checkedInCount,
      if (recurrenceKey != null && recurrenceKey!.isNotEmpty)
        'recurrenceKey': recurrenceKey,
      if (createdBy != null && createdBy!.isNotEmpty) 'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory ActivityModel.fromFirestore(
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

    return ActivityModel(
      id: doc.id,
      title: data['title'] as String? ?? 'Actividad',
      type: ActivityType.fromFirestore(data['type'] as String?),
      startsAt: readDate(data['startsAt']),
      endsAt: readOptionalDate(data['endsAt']),
      venue: data['venue'] as String?,
      location: data['location'] as String?,
      description: data['description'] as String?,
      isPublished: data['isPublished'] as bool? ?? true,
      checkInEnabled: data['checkInEnabled'] as bool? ?? false,
      checkInOpensAt: readOptionalDate(data['checkInOpensAt']),
      checkInClosesAt: readOptionalDate(data['checkInClosesAt']),
      // El token vive en activity_checkin_secrets; no se expone al miembro.
      checkInToken: data['checkInToken'] as String?,
      confirmedCount: (data['confirmedCount'] as num?)?.toInt() ?? 0,
      checkedInCount: (data['checkedInCount'] as num?)?.toInt() ?? 0,
      recurrenceKey: data['recurrenceKey'] as String?,
      createdBy: data['createdBy'] as String?,
      createdAt: readDate(data['createdAt'] ?? data['startsAt']),
      updatedAt: readDate(data['updatedAt'] ?? data['startsAt']),
    );
  }

  ActivityModel copyWith({
    String? id,
    String? title,
    ActivityType? type,
    DateTime? startsAt,
    DateTime? endsAt,
    String? venue,
    String? location,
    String? description,
    bool? isPublished,
    bool? checkInEnabled,
    DateTime? checkInOpensAt,
    DateTime? checkInClosesAt,
    String? checkInToken,
    int? confirmedCount,
    int? checkedInCount,
    String? recurrenceKey,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearEndsAt = false,
    bool clearCheckInOpensAt = false,
    bool clearCheckInClosesAt = false,
    bool clearCheckInToken = false,
  }) {
    return ActivityModel(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      startsAt: startsAt ?? this.startsAt,
      endsAt: clearEndsAt ? null : (endsAt ?? this.endsAt),
      venue: venue ?? this.venue,
      location: location ?? this.location,
      description: description ?? this.description,
      isPublished: isPublished ?? this.isPublished,
      checkInEnabled: checkInEnabled ?? this.checkInEnabled,
      checkInOpensAt:
          clearCheckInOpensAt ? null : (checkInOpensAt ?? this.checkInOpensAt),
      checkInClosesAt: clearCheckInClosesAt
          ? null
          : (checkInClosesAt ?? this.checkInClosesAt),
      checkInToken:
          clearCheckInToken ? null : (checkInToken ?? this.checkInToken),
      confirmedCount: confirmedCount ?? this.confirmedCount,
      checkedInCount: checkedInCount ?? this.checkedInCount,
      recurrenceKey: recurrenceKey ?? this.recurrenceKey,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
