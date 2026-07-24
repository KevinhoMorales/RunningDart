import 'package:flutter_test/flutter_test.dart';
import 'package:running_dart/utils/membership_code.dart';

void main() {
  group('MembershipCode.normalize', () {
    test('recorta y elimina espacios internos', () {
      expect(
        MembershipCode.normalize('  RD-abc def  '),
        'RD-abcdef',
      );
    });

    test('deja el prefijo en mayusculas y el cuerpo en minusculas', () {
      expect(
        MembershipCode.normalize('rd-550E8400-E29B-41D4-A716-446655440000'),
        'RD-550e8400-e29b-41d4-a716-446655440000',
      );
    });

    test('coincide con el valor almacenado (canonico ya normalizado)', () {
      const stored = 'RD-550e8400-e29b-41d4-a716-446655440000';
      expect(MembershipCode.normalize(stored), stored);
    });

    test('no modifica valores sin prefijo reconocible', () {
      expect(MembershipCode.normalize('  hello world  '), 'helloworld');
    });
  });

  group('MembershipCode.isValid', () {
    test('acepta un codigo con formato RD-<uuid>', () {
      expect(
        MembershipCode.isValid('RD-550e8400-e29b-41d4-a716-446655440000'),
        isTrue,
      );
    });

    test('acepta distinta capitalizacion y espacios', () {
      expect(
        MembershipCode.isValid('  rd-550E8400-E29B-41D4-A716-446655440000 '),
        isTrue,
      );
    });

    test('rechaza cadenas vacias o muy cortas', () {
      expect(MembershipCode.isValid(''), isFalse);
      expect(MembershipCode.isValid('RD-'), isFalse);
      expect(MembershipCode.isValid('RD-1'), isFalse);
    });

    test('rechaza codigos sin el prefijo esperado', () {
      expect(
        MembershipCode.isValid('XX-550e8400-e29b-41d4-a716-446655440000'),
        isFalse,
      );
    });

    test('rechaza caracteres no permitidos en el cuerpo', () {
      expect(
        MembershipCode.isValid('RD-550e8400-e29b-41d4-a716-44665544zzzz'),
        isFalse,
      );
    });
  });

  group('MembershipCode.formatForDisplay', () {
    test('devuelve el codigo en su forma canonica', () {
      expect(
        MembershipCode.formatForDisplay(
          'rd-550E8400-E29B-41D4-A716-446655440000',
        ),
        'RD-550e8400-e29b-41d4-a716-446655440000',
      );
    });
  });
}
