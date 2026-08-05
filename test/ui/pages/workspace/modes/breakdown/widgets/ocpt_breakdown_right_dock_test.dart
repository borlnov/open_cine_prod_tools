// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_right_dock_tab.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_right_dock.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve.
Widget _wrapInApp(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 320, height: 600, child: child)),
);

void main() {
  testWidgets("shows the active tab's body and the other tab's label", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownRightDock(
          activeTab: OcptBreakdownRightDockTab.inspector,
          inspectorChild: const Text("inspector body"),
          versionsChild: const Text("versions body"),
          onTabSelected: (_) {},
          onClose: () {},
        ),
      ),
    );

    expect(find.text("inspector body"), findsOneWidget);
    expect(find.text("versions body"), findsNothing);
    expect(find.text("Inspector"), findsOneWidget);
    expect(find.text("Versions"), findsOneWidget);
  });

  testWidgets("clicking the other tab's label reports it", (tester) async {
    final selected = <OcptBreakdownRightDockTab>[];

    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownRightDock(
          activeTab: OcptBreakdownRightDockTab.inspector,
          inspectorChild: const Text("inspector body"),
          versionsChild: const Text("versions body"),
          onTabSelected: selected.add,
          onClose: () {},
        ),
      ),
    );

    await tester.tap(find.text("Versions"));
    await tester.pump();

    expect(selected, [OcptBreakdownRightDockTab.versions]);
  });

  testWidgets("clicking the close button reports it", (tester) async {
    var closed = false;

    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownRightDock(
          activeTab: OcptBreakdownRightDockTab.versions,
          inspectorChild: const Text("inspector body"),
          versionsChild: const Text("versions body"),
          onTabSelected: (_) {},
          onClose: () => closed = true,
        ),
      ),
    );

    expect(find.text("versions body"), findsOneWidget);
    expect(find.text("inspector body"), findsNothing);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(closed, isTrue);
  });
}
