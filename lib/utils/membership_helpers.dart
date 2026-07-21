import '../models/membership_modality.dart';
import '../models/membership_status.dart';

class MembershipHelpers {
  MembershipHelpers._();

  static const double officialLaunchAmount = 5;
  static const double proTeamLaunchAmount = 5;

  static DateTime defaultOfficialExpiry([DateTime? from]) {
    final base = from ?? DateTime.now();
    return DateTime(base.year, 12, 31, 23, 59, 59);
  }

  static double amountForModality(MembershipModality modality) {
    return switch (modality) {
      MembershipModality.official => officialLaunchAmount,
      MembershipModality.proTeam => proTeamLaunchAmount,
      MembershipModality.community => 0,
    };
  }

  static String membershipStatusLabel({
    required MembershipStatus status,
    required bool isExpired,
  }) {
    if (isExpired && status == MembershipStatus.active) {
      return 'Vencido';
    }
    return status.displayName;
  }

  static bool isValidNationalIdLast4(String value) {
    return RegExp(r'^\d{4}$').hasMatch(value.trim());
  }

  static bool isValidWhatsapp(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 9 && digits.length <= 15;
  }
}
