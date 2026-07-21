import 'package:cloud_firestore/cloud_firestore.dart';

import 'membership_modality.dart';
import 'membership_status.dart';
import 'user_role.dart';

class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    required this.qrCode,
    required this.createdAt,
    this.isActive = true,
    this.role = UserRole.user,
    this.businessId,
    this.photoUrl,
    this.password,
    this.whatsapp,
    this.nationalIdLast4,
    this.birthDate,
    this.membershipModality = MembershipModality.community,
    this.membershipStatus = MembershipStatus.active,
    this.expiresAt,
    this.activatedAt,
    this.internalNotes,
    this.acceptedTermsAt,
  });

  final String id;
  final String email;
  final String displayName;
  final String qrCode;
  final DateTime createdAt;
  final bool isActive;
  final UserRole role;
  final String? businessId;
  final String? photoUrl;
  final String? password;
  final String? whatsapp;
  final String? nationalIdLast4;
  final DateTime? birthDate;
  final MembershipModality membershipModality;
  final MembershipStatus membershipStatus;
  final DateTime? expiresAt;
  final DateTime? activatedAt;
  final String? internalNotes;
  final DateTime? acceptedTermsAt;

  bool get isAccountActive => isActive;
  bool get isAdmin => role.isAdmin;
  bool get isCoach => role.isCoach;
  bool get canManageSchedules => role.canManageSchedules;
  bool get isMember => role.isMember;
  bool get isMembershipExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool get hasMembershipPrivileges {
    if (isAdmin && isActive) {
      return true;
    }
    return role.hasMembershipPrivileges &&
        membershipStatus == MembershipStatus.active &&
        isActive &&
        !isMembershipExpired;
  }
  bool get isMembershipPending =>
      membershipStatus == MembershipStatus.pending;
  bool get isBusinessOperator =>
      businessId != null && businessId!.isNotEmpty;
  bool get canScanQr => isActive && isBusinessOperator;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'qrCode': qrCode,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
      'role': role.firestoreValue,
      'businessId': businessId,
      'photoUrl': photoUrl,
      'password': password,
      'whatsapp': whatsapp,
      'nationalIdLast4': nationalIdLast4,
      'birthDate': birthDate?.toIso8601String(),
      'membershipModality': membershipModality.firestoreValue,
      'membershipStatus': membershipStatus.firestoreValue,
      'expiresAt': expiresAt?.toIso8601String(),
      'activatedAt': activatedAt?.toIso8601String(),
      'internalNotes': internalNotes,
      'acceptedTermsAt': acceptedTermsAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'qrCode': qrCode,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
      'role': role.firestoreValue,
      if (businessId != null) 'businessId': businessId,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (whatsapp != null && whatsapp!.isNotEmpty) 'whatsapp': whatsapp,
      if (nationalIdLast4 != null && nationalIdLast4!.isNotEmpty)
        'nationalIdLast4': nationalIdLast4,
      if (birthDate != null) 'birthDate': Timestamp.fromDate(birthDate!),
      'membershipModality': membershipModality.firestoreValue,
      'membershipStatus': membershipStatus.firestoreValue,
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
      if (activatedAt != null) 'activatedAt': Timestamp.fromDate(activatedAt!),
      if (internalNotes != null && internalNotes!.isNotEmpty)
        'internalNotes': internalNotes,
      if (acceptedTermsAt != null)
        'acceptedTermsAt': Timestamp.fromDate(acceptedTermsAt!),
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      qrCode: json['qrCode'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isActive: json['isActive'] as bool? ?? false,
      role: UserRole.fromFirestore(json['role'] as String?),
      businessId: json['businessId'] as String?,
      photoUrl: json['photoUrl'] as String?,
      password: json['password'] as String?,
      whatsapp: json['whatsapp'] as String?,
      nationalIdLast4: json['nationalIdLast4'] as String?,
      birthDate: json['birthDate'] != null
          ? DateTime.parse(json['birthDate'] as String)
          : null,
      membershipModality: MembershipModality.fromFirestore(
        json['membershipModality'] as String?,
      ),
      membershipStatus: MembershipStatus.fromFirestore(
        json['membershipStatus'] as String?,
      ),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      activatedAt: json['activatedAt'] != null
          ? DateTime.parse(json['activatedAt'] as String)
          : null,
      internalNotes: json['internalNotes'] as String?,
      acceptedTermsAt: json['acceptedTermsAt'] != null
          ? DateTime.parse(json['acceptedTermsAt'] as String)
          : null,
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final createdAt = data['createdAt'];
    final role = UserRole.fromFirestore(data['role'] as String?);
    final isActive = data['isActive'] as bool? ?? false;

    DateTime? readOptionalDate(dynamic value) {
      if (value == null) {
        return null;
      }
      if (value is Timestamp) {
        return value.toDate();
      }
      return DateTime.parse(value as String);
    }

    final membershipModality = MembershipModality.fromFirestore(
      data['membershipModality'] as String?,
    );
    final membershipStatus = data.containsKey('membershipStatus')
        ? MembershipStatus.fromFirestore(data['membershipStatus'] as String?)
        : _legacyMembershipStatus(role: role, isActive: isActive);

    return UserModel(
      id: doc.id,
      email: data['email'] as String,
      displayName: data['displayName'] as String,
      qrCode: data['qrCode'] as String,
      createdAt: createdAt is Timestamp
          ? createdAt.toDate()
          : DateTime.parse(createdAt as String),
      isActive: isActive,
      role: role,
      businessId: data['businessId'] as String?,
      photoUrl: data['photoUrl'] as String?,
      whatsapp: data['whatsapp'] as String?,
      nationalIdLast4: data['nationalIdLast4'] as String?,
      birthDate: readOptionalDate(data['birthDate']),
      membershipModality: data.containsKey('membershipModality')
          ? membershipModality
          : _legacyMembershipModality(role),
      membershipStatus: membershipStatus,
      expiresAt: readOptionalDate(data['expiresAt']),
      activatedAt: readOptionalDate(data['activatedAt']),
      internalNotes: data['internalNotes'] as String?,
      acceptedTermsAt: readOptionalDate(data['acceptedTermsAt']),
    );
  }

  static MembershipStatus _legacyMembershipStatus({
    required UserRole role,
    required bool isActive,
  }) {
    if (!isActive) {
      return MembershipStatus.inactive;
    }
    if (role.hasMembershipPrivileges) {
      return MembershipStatus.active;
    }
    return MembershipStatus.active;
  }

  static MembershipModality _legacyMembershipModality(UserRole role) {
    if (role.hasMembershipPrivileges) {
      return MembershipModality.official;
    }
    return MembershipModality.community;
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? displayName,
    String? qrCode,
    DateTime? createdAt,
    bool? isActive,
    UserRole? role,
    String? businessId,
    String? photoUrl,
    String? password,
    String? whatsapp,
    String? nationalIdLast4,
    DateTime? birthDate,
    MembershipModality? membershipModality,
    MembershipStatus? membershipStatus,
    DateTime? expiresAt,
    DateTime? activatedAt,
    String? internalNotes,
    DateTime? acceptedTermsAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      qrCode: qrCode ?? this.qrCode,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      role: role ?? this.role,
      businessId: businessId ?? this.businessId,
      photoUrl: photoUrl ?? this.photoUrl,
      password: password ?? this.password,
      whatsapp: whatsapp ?? this.whatsapp,
      nationalIdLast4: nationalIdLast4 ?? this.nationalIdLast4,
      birthDate: birthDate ?? this.birthDate,
      membershipModality: membershipModality ?? this.membershipModality,
      membershipStatus: membershipStatus ?? this.membershipStatus,
      expiresAt: expiresAt ?? this.expiresAt,
      activatedAt: activatedAt ?? this.activatedAt,
      internalNotes: internalNotes ?? this.internalNotes,
      acceptedTermsAt: acceptedTermsAt ?? this.acceptedTermsAt,
    );
  }
}
