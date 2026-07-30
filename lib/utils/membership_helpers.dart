import 'package:flutter/services.dart';

import '../models/business_model.dart';
import '../models/membership_modality.dart';
import '../models/membership_status.dart';

class MembershipHelpers {
  MembershipHelpers._();

  static DateTime defaultOfficialExpiry([DateTime? from]) {
    final base = from ?? DateTime.now();
    return DateTime(base.year, 12, 31, 23, 59, 59);
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

  /// Estado tal como se muestra junto a la credencial. Comunidad no incluye
  /// credencial, y ver "Activo" sin QR debajo se lee como un fallo de la app.
  static String credentialStatusLabel({
    required MembershipStatus status,
    required MembershipModality modality,
    required bool isExpired,
    required bool hasCredential,
  }) {
    if (!hasCredential && !modality.requiresAdminApproval) {
      return 'Sin credencial';
    }
    return membershipStatusLabel(status: status, isExpired: isExpired);
  }

  /// Explicación de por qué no hay QR, en el orden en que le importa al socio.
  static String credentialLockedMessage({
    required MembershipModality modality,
    required bool isPending,
    required bool isExpired,
  }) {
    if (isPending) {
      return 'Tu credencial estará disponible cuando SAINTS active tu membresía.';
    }
    if (!modality.requiresAdminApproval) {
      return 'La modalidad Comunidad no incluye credencial digital. '
          'Pásate a Miembro Oficial o Pro Team para obtener la tuya.';
    }
    if (isExpired) {
      return 'Tu membresía venció. Contacta a SAINTS para reactivarla.';
    }
    return 'Contacta a SAINTS para activar tu credencial digital.';
  }

  static bool isValidNationalIdLast4(String value) {
    return RegExp(r'^\d{4}$').hasMatch(value.trim());
  }

  static List<TextInputFormatter> get nationalIdLast4InputFormatters => [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(4),
      ];

  static const String defaultWhatsappCountryCode = '593';
  static const String defaultWhatsappCountryPrefix = '+593';

  static List<TextInputFormatter> get whatsappLocalInputFormatters =>
      internationalPhoneInputFormatters;

  static List<TextInputFormatter> get internationalPhoneInputFormatters => [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s()-]')),
        LengthLimitingTextInputFormatter(20),
      ];

  static bool isValidWhatsapp(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 9 && digits.length <= 15;
  }

  static bool isValidWhatsappLocal(String value) {
    return isValidNationalPhoneNumber(
      value,
      countryCode: defaultWhatsappCountryCode,
    );
  }

  static bool isValidNationalPhoneNumber(
    String value, {
    required String countryCode,
  }) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return false;
    }

    final normalized = digits.startsWith('0') ? digits.substring(1) : digits;
    final code = countryCode.replaceAll(RegExp(r'\D'), '');

    if (code == defaultWhatsappCountryCode) {
      return normalized.length == 9 && normalized.startsWith('9');
    }

    return normalized.length >= 6 && normalized.length <= 14;
  }

  static String formatWhatsappForStorage(
    String localNumber, {
    String countryCode = defaultWhatsappCountryCode,
  }) {
    var localDigits = localNumber.replaceAll(RegExp(r'\D'), '');
    if (localDigits.startsWith('0')) {
      localDigits = localDigits.substring(1);
    }

    final countryDigits = countryCode.replaceAll(RegExp(r'\D'), '');
    if (localDigits.startsWith(countryDigits)) {
      localDigits = localDigits.substring(countryDigits.length);
    }

    return '+$countryDigits$localDigits';
  }

  static bool canRedeemBusinessBenefits({
    required bool canUseMembershipFeatures,
    required MembershipModality? membershipModality,
    required BusinessModel business,
    bool isAdmin = false,
  }) {
    if (isAdmin) {
      return true;
    }
    if (!canUseMembershipFeatures || membershipModality == null) {
      return false;
    }
    return business.appliesToModality(membershipModality);
  }
}
