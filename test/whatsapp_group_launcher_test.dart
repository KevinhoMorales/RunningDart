import 'package:flutter_test/flutter_test.dart';

import 'package:running_dart/utils/constants.dart';
import 'package:running_dart/utils/whatsapp_launcher.dart';

void main() {
  group('WhatsApp group constants', () {
    test('community and pro team URLs use chat.whatsapp.com', () {
      for (final url in [
        AppConstants.communityWhatsAppGroupUrl,
        AppConstants.proTeamWhatsAppGroupUrl,
      ]) {
        expect(url, isNotEmpty);
        expect(Uri.parse(url).host, 'chat.whatsapp.com');
        expect(Uri.parse(url).scheme, 'https');
      }
    });
  });

  group('whatsAppGroupUrlForScheduleSection', () {
    test('returns community URL for Comunidad and Oficial tabs', () {
      expect(
        whatsAppGroupUrlForScheduleSection(
          'Comunidad SAINTS',
          isProTeamMember: false,
        ),
        AppConstants.communityWhatsAppGroupUrl,
      );
      expect(
        whatsAppGroupUrlForScheduleSection(
          'Miembro Oficial 2026',
          isProTeamMember: false,
        ),
        AppConstants.communityWhatsAppGroupUrl,
      );
    });

    test('returns pro team URL only for Pro Team members', () {
      expect(
        whatsAppGroupUrlForScheduleSection(
          'SAINTS Pro Team',
          isProTeamMember: true,
        ),
        AppConstants.proTeamWhatsAppGroupUrl,
      );
      expect(
        whatsAppGroupUrlForScheduleSection(
          'SAINTS Pro Team',
          isProTeamMember: false,
        ),
        isNull,
      );
    });
  });

  group('whatsAppGroupCtaLabelForScheduleSection', () {
    test('uses distinct labels for Pro Team vs community', () {
      expect(
        whatsAppGroupCtaLabelForScheduleSection('SAINTS Pro Team'),
        'Grupo Pro Team en WhatsApp',
      );
      expect(
        whatsAppGroupCtaLabelForScheduleSection('Comunidad SAINTS'),
        'Unirme al grupo de WhatsApp',
      );
    });
  });

  group('launchWhatsAppGroupInvite', () {
    test('rejects invalid invite URLs', () async {
      expect(await launchWhatsAppGroupInvite(''), isFalse);
      expect(await launchWhatsAppGroupInvite('https://wa.me/123'), isFalse);
      expect(
        await launchWhatsAppGroupInvite('http://chat.whatsapp.com/abc'),
        isFalse,
      );
    });
  });
}
