enum MembershipStatus {
  pending,
  active,
  inactive;

  String get firestoreValue => name;

  String get displayName => switch (this) {
        MembershipStatus.pending => 'Pendiente',
        MembershipStatus.active => 'Activo',
        MembershipStatus.inactive => 'Inactivo',
      };

  static MembershipStatus fromFirestore(String? value) {
    return switch (value) {
      'pending' => MembershipStatus.pending,
      'inactive' => MembershipStatus.inactive,
      _ => MembershipStatus.active,
    };
  }
}
