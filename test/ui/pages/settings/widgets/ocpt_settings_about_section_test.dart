// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/settings/widgets/ocpt_settings_about_section.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_logo.dart';

/// Builds an [OcptSettingsAboutSection] for [appVersion], themed and localized as the app does.
Widget _buildSection(String appVersion) => MaterialApp(
  theme: ocptTheme.lightThemeData,
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: OcptSettingsAboutSection(appVersion: appVersion)),
);

void main() {
  testWidgets("the app logo stands next to the name and version of the application", (
    tester,
  ) async {
    await tester.pumpWidget(_buildSection("1.2.3"));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptSettingsAboutSection)));

    expect(find.byType(OcptLogo), findsOneWidget);
    expect(find.text(tr.appTitle), findsOneWidget);
    expect(find.text(tr.settingsAboutVersionLabel("1.2.3")), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(OcptLogo)).dx,
      lessThan(tester.getTopLeft(find.text(tr.appTitle)).dx),
    );
  });
}
