// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_show_notice.dart';

/// Pump a button showing a notice, tap it, and return the theme the notice was shown under.
Future<ThemeData> _showNotice(
  WidgetTester tester, {
  required bool isError,
  ThemeData? theme,
}) async {
  final themeData = theme ?? ThemeData();
  await tester.pumpWidget(
    MaterialApp(
      theme: themeData,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => ocptShowNotice(context, "Notice text", isError: isError),
            child: const Text("show"),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text("show"));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return themeData;
}

/// Test the shared notice: the error variant's colours and icon in both themes, the neutral
/// variant's unchanged look, and the replacement of the notice on screen.
void main() {
  for (final brightness in Brightness.values) {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: brightness),
    );

    testWidgets("an error notice uses the error container and an icon in $brightness", (
      tester,
    ) async {
      await _showNotice(tester, isError: true, theme: theme);

      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.backgroundColor, theme.colorScheme.errorContainer);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline));
      expect(icon.color, theme.colorScheme.onErrorContainer);
      final text = tester.widget<Text>(find.text("Notice text"));
      expect(text.style?.color, theme.colorScheme.onErrorContainer);
    });
  }

  testWidgets("a neutral notice keeps the default look and has no icon", (tester) async {
    await _showNotice(tester, isError: false);

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.backgroundColor, isNull);
    expect(find.byIcon(Icons.error_outline), findsNothing);
    expect(find.text("Notice text"), findsOneWidget);
  });

  testWidgets("a new notice replaces the one on screen", (tester) async {
    await _showNotice(tester, isError: true);
    await tester.tap(find.text("show"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SnackBar), findsOneWidget);
  });
}
