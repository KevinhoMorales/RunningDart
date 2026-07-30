enum MembershipModality {
  community,
  official,
  proTeam;

  String get firestoreValue => switch (this) {
        MembershipModality.community => 'community',
        MembershipModality.official => 'official',
        MembershipModality.proTeam => 'proTeam',
      };

  String get displayName => switch (this) {
        MembershipModality.community => 'Comunidad SAINTS',
        MembershipModality.official => 'Miembro Oficial 2026',
        MembershipModality.proTeam => 'SAINTS Pro Team',
      };

  /// Oficial / Pro Team quedan pendientes hasta que un admin active la membresía.
  bool get requiresAdminApproval =>
      this == MembershipModality.official || this == MembershipModality.proTeam;

  static MembershipModality fromFirestore(String? value) {
    return switch (value) {
      'official' => MembershipModality.official,
      'proTeam' => MembershipModality.proTeam,
      _ => MembershipModality.community,
    };
  }

  static List<MembershipModality> get registrableOptions => [
        MembershipModality.community,
        MembershipModality.official,
        MembershipModality.proTeam,
      ];
}
