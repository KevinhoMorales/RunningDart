import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:running_dart/widgets/force_update_screen.dart';
import 'package:running_dart/widgets/modern_text_field.dart';

void main() {
  testWidgets('ForceUpdateScreen shows update message and action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ForceUpdateScreen(
          currentVersion: '1.0.0',
          requiredVersion: '1.0.2',
        ),
      ),
    );

    expect(find.text('Actualización requerida'), findsOneWidget);
    expect(find.text('1.0.0'), findsOneWidget);
    expect(find.text('1.0.2'), findsOneWidget);
    expect(find.text('Actualizar ahora'), findsOneWidget);
  });
}
