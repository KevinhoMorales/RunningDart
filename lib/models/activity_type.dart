enum ActivityType {
  socialRun('social_run', 'Social Run'),
  specialEvent('special_event', 'Evento especial');

  const ActivityType(this.firestoreValue, this.displayName);

  final String firestoreValue;
  final String displayName;

  static ActivityType fromFirestore(String? value) {
    return ActivityType.values.firstWhere(
      (type) => type.firestoreValue == value,
      orElse: () => ActivityType.socialRun,
    );
  }
}
