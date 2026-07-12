// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_page.dart';
import 'package:open_cine_prod_tools/ui/pages/home/home_page.dart';
import 'package:open_cine_prod_tools/ui/pages/settings/settings_page.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve in tests.
Widget _wrapWithLocalization(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: child,
);

void main() {
  testWidgets('HomePage displays the localized home title', (WidgetTester tester) async {
    await tester.pumpWidget(_wrapWithLocalization(const HomePage()));

    final context = tester.element(find.byType(HomePage));
    expect(find.text(Tr.of(context).homePageTitle), findsOneWidget);
  });

  testWidgets('EditorPage and SettingsPage build', (WidgetTester tester) async {
    await tester.pumpWidget(_wrapWithLocalization(const EditorPage()));
    expect(find.byType(EditorPage), findsOneWidget);

    await tester.pumpWidget(_wrapWithLocalization(const SettingsPage()));
    expect(find.byType(SettingsPage), findsOneWidget);
  });
}
