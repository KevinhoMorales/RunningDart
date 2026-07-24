import 'package:flutter_test/flutter_test.dart';
import 'package:running_dart/utils/username_helpers.dart';

void main() {
  group('UsernameHelpers.suggestFromEmail', () {
    test('usa la parte local del correo', () {
      expect(UsernameHelpers.suggestFromEmail('kevin@saints.com'), 'kevin');
    });

    test('normaliza mayúsculas', () {
      expect(UsernameHelpers.suggestFromEmail('Kevin.Mora@x.com'), 'kevin.mora');
    });

    test('colapsa separadores repetidos', () {
      expect(UsernameHelpers.suggestFromEmail('juan..perez@x.com'), 'juan.perez');
      expect(UsernameHelpers.suggestFromEmail('juan__perez@x.com'), 'juan.perez');
    });

    test('descarta caracteres no permitidos', () {
      expect(UsernameHelpers.suggestFromEmail('ana+news@x.com'), 'ananews');
    });

    test('quita los caracteres iniciales que no son letra', () {
      expect(UsernameHelpers.suggestFromEmail('123ana@x.com'), 'ana');
    });

    test('cae en saints cuando no queda nada usable', () {
      expect(UsernameHelpers.suggestFromEmail('123456@x.com'), 'saints');
    });

    test('rellena hasta el mínimo de caracteres', () {
      expect(UsernameHelpers.suggestFromEmail('jp@x.com'), 'jp0');
    });

    test('recorta al máximo permitido', () {
      final suggestion = UsernameHelpers.suggestFromEmail(
        'unnombredeusuariodemasiadolargo@x.com',
      );
      expect(suggestion.length, UsernameHelpers.maxLength);
    });

    test('siempre produce un username válido', () {
      const emails = [
        'kevin@saints.com',
        'Kevin.Mora@x.com',
        'juan..perez@x.com',
        'ana+news@x.com',
        '123ana@x.com',
        '123456@x.com',
        'jp@x.com',
        'unnombredeusuariodemasiadolargo@x.com',
        '_raro_@x.com',
        'punto.@x.com',
      ];
      for (final email in emails) {
        final suggestion = UsernameHelpers.suggestFromEmail(email);
        expect(
          UsernameHelpers.isValid(suggestion),
          isTrue,
          reason: '$email produjo "$suggestion"',
        );
      }
    });
  });

  group('UsernameHelpers.daysUntilChangeAllowed', () {
    test('permite el primer cambio cuando nunca se ha cambiado', () {
      expect(UsernameHelpers.daysUntilChangeAllowed(null), 0);
      expect(UsernameHelpers.canChange(null), isTrue);
    });

    test('bloquea dentro de la ventana de espera', () {
      final lastChange = DateTime.now().subtract(const Duration(days: 2));
      expect(
        UsernameHelpers.daysUntilChangeAllowed(lastChange),
        UsernameHelpers.cooldownDays - 2,
      );
    });

    test('libera al terminar la ventana', () {
      final lastChange = DateTime.now().subtract(
        const Duration(days: UsernameHelpers.cooldownDays + 1),
      );
      expect(UsernameHelpers.daysUntilChangeAllowed(lastChange), 0);
    });
  });
}
