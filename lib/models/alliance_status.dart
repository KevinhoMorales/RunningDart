enum AllianceStatus {
  active,
  inactive;

  String get firestoreValue => name;

  String get displayName => switch (this) {
        AllianceStatus.active => 'Activa',
        AllianceStatus.inactive => 'Inactiva',
      };

  static AllianceStatus fromFirestore(String? value) {
    return value == 'inactive' ? AllianceStatus.inactive : AllianceStatus.active;
  }
}
