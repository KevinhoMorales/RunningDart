import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:running_dart/utils/constants.dart';
import 'package:running_dart/widgets/app_startup_loading.dart';

void main() {
  testWidgets('AppStartupLoading shows brand mark, name and progress', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppStartupLoading(),
      ),
    );

    expect(find.text(AppConstants.appName), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.directions_run_rounded), findsNothing);
  });
}
