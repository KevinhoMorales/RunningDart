enum UserRole {
  user,
  member,
  admin,
  coach;

  String get firestoreValue => name;

  bool get isUser => this == UserRole.user;

  bool get isMember => this == UserRole.member;

  bool get isAdmin => this == UserRole.admin;

  bool get isCoach => this == UserRole.coach;

  bool get hasMembershipPrivileges => isMember || isAdmin;

  bool get canManageSchedules => isAdmin || isCoach;

  bool get canAccessAdminPanel => isAdmin;

  String get displayName {
    return switch (this) {
      UserRole.user => 'Usuario',
      UserRole.member => 'Miembro',
      UserRole.admin => 'Administrador',
      UserRole.coach => 'Coach',
    };
  }

  static UserRole fromFirestore(String? value) {
    return switch (value) {
      'member' => UserRole.member,
      'admin' => UserRole.admin,
      'coach' => UserRole.coach,
      'business' => UserRole.member,
      _ => UserRole.user,
    };
  }
}
