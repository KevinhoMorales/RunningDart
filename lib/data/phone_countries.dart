class PhoneCountry {
  const PhoneCountry({
    required this.name,
    required this.isoCode,
    required this.dialCode,
    required this.flag,
  });

  final String name;
  final String isoCode;
  final String dialCode;
  final String flag;

  String get displayLabel => '$flag +$dialCode';

  String get searchLabel => '$name $isoCode +$dialCode'.toLowerCase();
}

class PhoneCountries {
  PhoneCountries._();

  static const PhoneCountry ecuador = PhoneCountry(
    name: 'Ecuador',
    isoCode: 'EC',
    dialCode: '593',
    flag: '🇪🇨',
  );

  static const List<PhoneCountry> all = [
    ecuador,
    PhoneCountry(name: 'Estados Unidos', isoCode: 'US', dialCode: '1', flag: '🇺🇸'),
    PhoneCountry(name: 'Colombia', isoCode: 'CO', dialCode: '57', flag: '🇨🇴'),
    PhoneCountry(name: 'Perú', isoCode: 'PE', dialCode: '51', flag: '🇵🇪'),
    PhoneCountry(name: 'México', isoCode: 'MX', dialCode: '52', flag: '🇲🇽'),
    PhoneCountry(name: 'Argentina', isoCode: 'AR', dialCode: '54', flag: '🇦🇷'),
    PhoneCountry(name: 'Chile', isoCode: 'CL', dialCode: '56', flag: '🇨🇱'),
    PhoneCountry(name: 'España', isoCode: 'ES', dialCode: '34', flag: '🇪🇸'),
    PhoneCountry(name: 'Venezuela', isoCode: 'VE', dialCode: '58', flag: '🇻🇪'),
    PhoneCountry(name: 'Brasil', isoCode: 'BR', dialCode: '55', flag: '🇧🇷'),
    PhoneCountry(name: 'Panamá', isoCode: 'PA', dialCode: '507', flag: '🇵🇦'),
    PhoneCountry(name: 'Costa Rica', isoCode: 'CR', dialCode: '506', flag: '🇨🇷'),
    PhoneCountry(name: 'Rep. Dominicana', isoCode: 'DO', dialCode: '1', flag: '🇩🇴'),
    PhoneCountry(name: 'Uruguay', isoCode: 'UY', dialCode: '598', flag: '🇺🇾'),
    PhoneCountry(name: 'Paraguay', isoCode: 'PY', dialCode: '595', flag: '🇵🇾'),
    PhoneCountry(name: 'Bolivia', isoCode: 'BO', dialCode: '591', flag: '🇧🇴'),
    PhoneCountry(name: 'Guatemala', isoCode: 'GT', dialCode: '502', flag: '🇬🇹'),
    PhoneCountry(name: 'Honduras', isoCode: 'HN', dialCode: '504', flag: '🇭🇳'),
    PhoneCountry(name: 'El Salvador', isoCode: 'SV', dialCode: '503', flag: '🇸🇻'),
    PhoneCountry(name: 'Nicaragua', isoCode: 'NI', dialCode: '505', flag: '🇳🇮'),
    PhoneCountry(name: 'Canadá', isoCode: 'CA', dialCode: '1', flag: '🇨🇦'),
    PhoneCountry(name: 'Reino Unido', isoCode: 'GB', dialCode: '44', flag: '🇬🇧'),
    PhoneCountry(name: 'Italia', isoCode: 'IT', dialCode: '39', flag: '🇮🇹'),
    PhoneCountry(name: 'Francia', isoCode: 'FR', dialCode: '33', flag: '🇫🇷'),
    PhoneCountry(name: 'Alemania', isoCode: 'DE', dialCode: '49', flag: '🇩🇪'),
  ];

  static PhoneCountry get defaultCountry => ecuador;

  static PhoneCountry? findByDialCode(String dialCode) {
    final normalized = dialCode.replaceAll(RegExp(r'\D'), '');
    if (normalized.isEmpty) {
      return null;
    }

    final matches = all
        .where((country) => country.dialCode == normalized)
        .toList(growable: false);
    return matches.isEmpty ? null : matches.first;
  }

  static ({PhoneCountry country, String nationalNumber}) parseStoredNumber(
    String stored,
  ) {
    final digits = stored.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return (country: defaultCountry, nationalNumber: '');
    }

    final sorted = all.toList()
      ..sort((a, b) => b.dialCode.length.compareTo(a.dialCode.length));

    for (final country in sorted) {
      if (digits.startsWith(country.dialCode)) {
        return (
          country: country,
          nationalNumber: digits.substring(country.dialCode.length),
        );
      }
    }

    return (country: defaultCountry, nationalNumber: digits);
  }
}
