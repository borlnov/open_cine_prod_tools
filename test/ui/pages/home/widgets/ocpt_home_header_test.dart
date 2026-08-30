// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/home/widgets/ocpt_home_header.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_logo.dart';

/// Builds an [OcptHomeHeader] whose actions do nothing, themed and localized as the app does.
Widget _buildHeader() => MaterialApp(
  theme: ocptTheme.lightThemeData,
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(
    body: OcptHomeHeader(
      onNewProject: () {},
      onOpenProject: () {},
      onImport: () {},
      onJoinSharedProject: () {},
      onOpenSettings: () {},
    ),
  ),
);

void main() {
  testWidgets("the app logo leads the header, before the title", (tester) async {
    // The default test surface (800x600) is too narrow for the header's five actions side by
    // side, which this app never runs at in practice (a resizable desktop window).
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildHeader());
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptHomeHeader)));

    expect(find.byType(OcptLogo), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(OcptLogo)).dx,
      lessThan(tester.getTopLeft(find.text(tr.appTitle)).dx),
    );
  });
}
