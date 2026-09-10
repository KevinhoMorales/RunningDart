enum MembershipModality {
  community,
  official;

  String get firestoreValue => switch (this) {
        MembershipModality.community => 'community',
        MembershipModality.official => 'official',
      };

  String get displayName => switch (this) {
        MembershipModality.community => 'Comunidad SAINTS',
        MembershipModality.official => 'Miembro Oficial',
      };

  /// Oficial queda pendiente hasta que un admin active la membresía.
  bool get requiresAdminApproval => this == MembershipModality.official;

  /// Brief product copy for Official (no IAP in-app).
  static const String officialProductBlurb = 'Miembro Oficial · USD 5/mes';

  /// Soft upsell: Official adds a Reward Spot perk; never ranking advantage.
  static const String officialPerkUpsellBlurb =
      'Misma Liga y mismos puntos que Comunidad. Si ganas un Reward Spot '
      'siendo Miembro Oficial activo, recibes el premio general + el perk '
      'del mes. Miembro Oficial · USD 5/mes.';

  /// Short line for Official members about the monthly perk.
  static const String officialPerkMemberBlurb =
      'Como Oficial activo, si ganas un Reward Spot recibes el premio '
      'general + el perk del mes. No suma puntos extra en la Liga.';

  /// Reads Firestore modality strings.
  ///
  /// Legacy `proTeam` docs are mapped to [official] so existing users keep
  /// credential/benefit access without crashing. New writes never persist
  /// `proTeam` (enum removed from active product paths).
  static MembershipModality fromFirestore(String? value) {
    return switch (value) {
      'official' || 'proTeam' => MembershipModality.official,
      _ => MembershipModality.community,
    };
  }

  /// Modalities a member/admin can choose in product UX.
  static List<MembershipModality> get registrableOptions => [
        MembershipModality.community,
        MembershipModality.official,
      ];

  /// Same as [registrableOptions]; kept for admin dropdowns / business forms.
  static List<MembershipModality> get selectableOptions => registrableOptions;
}
