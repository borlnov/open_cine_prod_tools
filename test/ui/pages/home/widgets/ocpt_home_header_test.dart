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

    // The wide layout shows all five actions side by side, with no overflow menu.
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  testWidgets(
    "below the breakpoint, the header collapses every action into an overflow menu",
    (tester) async {
      // Narrower than the compact-width breakpoint (816): the title stays on one line, "New
      // project" is dropped entirely (it lives in the page's own FAB at this width) and only the
      // overflow trigger remains visible directly.
      tester.view.physicalSize = const Size(500, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildHeader());
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptHomeHeader)));

      // The title never stacks its letters: it stays a single line and may only ellipsize.
      final titleText = tester.widget<Text>(find.text(tr.appTitle));
      expect(titleText.maxLines, 1);
      expect(titleText.overflow, TextOverflow.ellipsis);

      // "New project" is gone from the compact header; only the overflow trigger remains, and
      // every other action is behind it.
      expect(find.text(tr.homeNewProjectAction), findsNothing);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      expect(find.text(tr.homeOpenProjectAction), findsNothing);
      expect(find.text(tr.homeImportAction), findsNothing);
      expect(find.text(tr.homeJoinSharedProjectAction), findsNothing);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(MenuItemButton, tr.homeOpenProjectAction), findsOneWidget);
      expect(find.widgetWithText(MenuItemButton, tr.homeImportAction), findsOneWidget);
      expect(find.widgetWithText(MenuItemButton, tr.homeJoinSharedProjectAction), findsOneWidget);
      expect(find.widgetWithText(MenuItemButton, tr.homeSettingsTooltip), findsOneWidget);
    },
  );
}
