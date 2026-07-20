import 'package:cloud_firestore/cloud_firestore.dart';

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

  bool get isAccountActive => isActive;
  bool get isAdmin => role.isAdmin;
  bool get isMember => role.isMember;
  bool get hasMembershipPrivileges => role.hasMembershipPrivileges;
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
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final createdAt = data['createdAt'];

    return UserModel(
      id: doc.id,
      email: data['email'] as String,
      displayName: data['displayName'] as String,
      qrCode: data['qrCode'] as String,
      createdAt: createdAt is Timestamp
          ? createdAt.toDate()
          : DateTime.parse(createdAt as String),
      isActive: data['isActive'] as bool? ?? false,
      role: UserRole.fromFirestore(data['role'] as String?),
      businessId: data['businessId'] as String?,
      photoUrl: data['photoUrl'] as String?,
    );
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
    );
  }
}
