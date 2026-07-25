import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Widgets de Material que no vibran por su cuenta. Cuando reciben un callback
/// de acción deben pasar por `AppHaptics` o por un envoltorio `Haptic*` de
/// `lib/widgets/haptic_controls.dart`, para que el toque se sienta igual en iOS
/// y en Android.
const _watchedWidgets = <String>[
  'IconButton',
  'TextButton',
  'TextButton.icon',
  'FilledButton',
  'FilledButton.icon',
  'OutlinedButton',
  'OutlinedButton.icon',
  'FloatingActionButton',
  'FloatingActionButton.extended',
  'ListTile',
  'RefreshIndicator',
];

const _callbackArguments = <String>['onPressed', 'onTap', 'onRefresh'];

/// Archivos donde el widget crudo es la implementación del propio haptic.
const _allowedFiles = <String>{
  'lib/widgets/haptic_controls.dart',
};

void main() {
  test('los widgets con acción vibran en iOS y Android', () {
    final violations = <String>[];

    for (final file in _dartFilesIn('lib')) {
      final path = file.path.replaceAll(r'\', '/');
      if (_allowedFiles.contains(path)) continue;

      violations.addAll(_violationsIn(path, file.readAsStringSync()));
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Estas acciones no dan feedback táctil. Usa los envoltorios de '
          'lib/widgets/haptic_controls.dart o envuelve el callback con '
          'AppHaptics.wrap:\n${violations.join('\n')}',
    );
  });

  group('la revisión detecta lo que debe', () {
    test('marca un botón crudo con acción', () {
      const source = '''
Widget build(BuildContext context) {
  return IconButton(
    icon: const Icon(Icons.close),
    onPressed: () => Navigator.pop(context),
  );
}
''';

      expect(_violationsIn('lib/demo.dart', source), [
        'lib/demo.dart:2 IconButton.onPressed',
      ]);
    });

    test('acepta los envoltorios, los callbacks envueltos y los widgets sin acción', () {
      const source = '''
Widget build(BuildContext context) {
  return Column(
    children: [
      HapticIconButton(
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.pop(context),
      ),
      TextButton(
        onPressed: AppHaptics.wrap(onPressed),
        child: const Text('Guardar'),
      ),
      FilledButton(
        onPressed: null,
        style: FilledButton.styleFrom(backgroundColor: Colors.red),
        child: const Text('Enviar'),
      ),
      ListTile(title: Text('(sin acción, con paréntesis)')),
    ],
  );
}
''';

      expect(_violationsIn('lib/demo.dart', source), isEmpty);
    });
  });
}

List<String> _violationsIn(String path, String source) {
  final violations = <String>[];

  for (final widget in _watchedWidgets) {
    for (final match in _constructorPattern(widget).allMatches(source)) {
      final openParen = source.indexOf('(', match.start);
      for (final argument in _topLevelArguments(source, openParen)) {
        if (!_callbackArguments.contains(argument.name)) continue;

        final value = argument.value.trim();
        if (value.isEmpty || value == 'null') continue;
        if (value.contains('AppHaptics')) continue;

        final line = source.substring(0, match.start).split('\n').length;
        violations.add('$path:$line $widget.${argument.name}');
      }
    }
  }

  return violations;
}

Iterable<File> _dartFilesIn(String directory) {
  return Directory(directory)
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));
}

/// Encuentra `Widget(` sin capturar `HapticWidget(` ni `Widget.styleFrom(`.
RegExp _constructorPattern(String widget) {
  final name = widget.replaceAll('.', r'\.');
  return RegExp(r'(?<![\w$.])' '$name' r'\s*\(');
}

class _Argument {
  const _Argument(this.name, this.value);

  final String name;
  final String value;
}

/// Devuelve los argumentos nombrados del primer nivel de una llamada, ignorando
/// los de los widgets anidados.
List<_Argument> _topLevelArguments(String source, int openParen) {
  final arguments = <_Argument>[];
  var depth = 0;
  var segmentStart = openParen + 1;
  var index = openParen;

  while (index < source.length) {
    final char = source[index];

    if (char == '/' && index + 1 < source.length && source[index + 1] == '/') {
      while (index < source.length && source[index] != '\n') {
        index++;
      }
      continue;
    }

    if (char == "'" || char == '"') {
      index = _endOfString(source, index);
      continue;
    }

    if (char == '(' || char == '[' || char == '{') {
      depth++;
      index++;
      continue;
    }

    if (char == ')' || char == ']' || char == '}') {
      depth--;
      if (depth == 0) {
        _addArgument(arguments, source.substring(segmentStart, index));
        return arguments;
      }
      index++;
      continue;
    }

    if (char == ',' && depth == 1) {
      _addArgument(arguments, source.substring(segmentStart, index));
      segmentStart = index + 1;
    }

    index++;
  }

  return arguments;
}

final _namedArgument = RegExp(r'^\s*([A-Za-z_]\w*)\s*:');

void _addArgument(List<_Argument> arguments, String segment) {
  final match = _namedArgument.firstMatch(segment);
  if (match == null) return;
  arguments.add(
    _Argument(match.group(1)!, segment.substring(match.end)),
  );
}

int _endOfString(String source, int quoteIndex) {
  final quote = source[quoteIndex];
  final isRaw = quoteIndex > 0 && source[quoteIndex - 1] == 'r';
  var index = quoteIndex + 1;

  while (index < source.length) {
    final char = source[index];
    if (!isRaw && char == r'\') {
      index += 2;
      continue;
    }
    if (char == quote) {
      return index + 1;
    }
    index++;
  }

  return source.length;
}
