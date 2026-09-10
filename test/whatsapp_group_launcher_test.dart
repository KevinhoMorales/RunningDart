import 'package:flutter_test/flutter_test.dart';
import 'package:running_dart/utils/constants.dart';
import 'package:running_dart/utils/whatsapp_launcher.dart';

void main() {
  group('WhatsApp group invite URLs', () {
    test('community URL uses chat.whatsapp.com', () {
      expect(
        AppConstants.communityWhatsAppGroupUrl,
        startsWith('https://chat.whatsapp.com/'),
      );
    });

    test('rejects invalid invite hosts', () async {
      expect(
        await launchWhatsAppGroupInvite('https://example.com/not-whatsapp'),
        isFalse,
      );
      expect(await launchWhatsAppGroupInvite('not-a-url'), isFalse);
    });
  });

  group('whatsAppGroupUrlForScheduleSection', () {
    test('returns community URL for Comunidad and Oficial tabs', () {
      expect(
        whatsAppGroupUrlForScheduleSection('Comunidad SAINTS'),
        AppConstants.communityWhatsAppGroupUrl,
      );
      expect(
        whatsAppGroupUrlForScheduleSection('Miembro Oficial'),
        AppConstants.communityWhatsAppGroupUrl,
      );
    });

    test('returns null for unknown or retired Pro Team sections', () {
      expect(
        whatsAppGroupUrlForScheduleSection('SAINTS Pro Team'),
        isNull,
      );
      expect(whatsAppGroupUrlForScheduleSection('Otro'), isNull);
    });
  });

  group('whatsAppGroupCtaLabelForScheduleSection', () {
    test('uses a single community CTA label', () {
      expect(
        whatsAppGroupCtaLabelForScheduleSection('SAINTS Pro Team'),
        'Unirme al grupo de WhatsApp',
      );
      expect(
        whatsAppGroupCtaLabelForScheduleSection('Comunidad SAINTS'),
        'Unirme al grupo de WhatsApp',
      );
    });
  });
}
