enum UserRole {
  user,
  member,
  admin;

  String get firestoreValue => name;

  bool get isUser => this == UserRole.user;

  bool get isMember => this == UserRole.member;

  bool get isAdmin => this == UserRole.admin;

  bool get hasMembershipPrivileges => isMember || isAdmin;

  String get displayName {
    return switch (this) {
      UserRole.user => 'Usuario',
      UserRole.member => 'Miembro',
      UserRole.admin => 'Administrador',
    };
  }

  static UserRole fromFirestore(String? value) {
    return switch (value) {
      'member' => UserRole.member,
      'admin' => UserRole.admin,
      'business' => UserRole.member,
      _ => UserRole.user,
    };
  }
}
