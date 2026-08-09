// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_toolbar.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_logo.dart';

/// Wraps [child] with the localization delegates so the toolbar's [Tr.of] tooltip lookups resolve.
Widget _wrapInApp(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets("the back action fires onBack when clicked", (tester) async {
    var backCount = 0;

    await tester.pumpWidget(
      _wrapInApp(
        OcptWorkspaceToolbar(
          title: "My Movie",
          isDirty: false,
          onBack: () => backCount++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptWorkspaceToolbar)));
    await tester.tap(find.byTooltip(tr.editorBackToProjectsTooltip));
    await tester.pumpAndSettle();

    expect(backCount, 1);
  });

  testWidgets("the back badge carries the app logo, tinted to read on the accent fill", (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptWorkspaceToolbar(title: "My Movie", isDirty: false, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(OcptWorkspaceToolbar));
    final glyph = tester.widget<OcptLogoGlyph>(find.byType(OcptLogoGlyph));

    expect(glyph.color, Theme.of(context).colorScheme.onPrimary);
  });

  testWidgets("the dirty marker is shown only while there are unsaved changes", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptWorkspaceToolbar(title: "My Movie", isDirty: false, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptWorkspaceToolbar)));
    expect(find.byTooltip(tr.editorUnsavedChangesTooltip), findsNothing);

    await tester.pumpWidget(
      _wrapInApp(
        OcptWorkspaceToolbar(title: "My Movie", isDirty: true, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip(tr.editorUnsavedChangesTooltip), findsOneWidget);
  });

  testWidgets("the read-only pill replaces the unsaved-changes dot while previewing", (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptWorkspaceToolbar(
          title: "My Movie",
          // Deliberately dirty as well: a preview has nothing to save, so what may not be edited
          // is what the toolbar has to say.
          isDirty: true,
          isReadOnly: true,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptWorkspaceToolbar)));

    expect(find.text(tr.workspaceReadOnlyPill), findsOneWidget);
    expect(find.byTooltip(tr.workspaceReadOnlyTooltip), findsOneWidget);
    expect(find.byTooltip(tr.editorUnsavedChangesTooltip), findsNothing);
  });

  testWidgets("no read-only pill is shown outside a preview", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptWorkspaceToolbar(title: "My Movie", isDirty: true, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptWorkspaceToolbar)));

    expect(find.text(tr.workspaceReadOnlyPill), findsNothing);
    expect(find.byTooltip(tr.editorUnsavedChangesTooltip), findsOneWidget);
  });

  testWidgets("the mode label is rendered only when one is given", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptWorkspaceToolbar(title: "My Movie", isDirty: false, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Screenplay editor"), findsNothing);

    await tester.pumpWidget(
      _wrapInApp(
        OcptWorkspaceToolbar(
          title: "My Movie",
          isDirty: false,
          onBack: () {},
          modeLabel: "Screenplay editor",
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Screenplay editor"), findsOneWidget);
  });

  testWidgets("the export action is rendered only when one is given", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptWorkspaceToolbar(title: "My Movie", isDirty: false, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextButton), findsNothing);

    await tester.pumpWidget(
      _wrapInApp(
        OcptWorkspaceToolbar(
          title: "My Movie",
          isDirty: false,
          onBack: () {},
          exportAction: const Text("export"),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("export"), findsOneWidget);
  });

  testWidgets("the trailing controls follow the mode actions in the shell's own order", (
    tester,
  ) async {
    // A wide surface, so the placeholders standing in for the real (compact) controls all fit on
    // the one row this test is about.
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrapInApp(
        OcptWorkspaceToolbar(
          title: "My Movie",
          isDirty: false,
          onBack: () {},
          actions: const [Text("action")],
          modeLabel: "Screenplay editor",
          exportAction: const Text("export"),
          dockToggles: const [Text("left dock"), Text("right dock")],
          saveAction: const Text("save"),
          overflowEntries: const [PopupMenuItem<void>(child: Text("Entry"))],
        ),
      ),
    );
    await tester.pumpAndSettle();

    /// The horizontal offset of the widget [finder] resolves to, in the toolbar's own row.
    double leftOf(Finder finder) => tester.getTopLeft(finder).dx;

    expect(leftOf(find.text("action")), lessThan(leftOf(find.text("Screenplay editor"))));
    expect(leftOf(find.text("Screenplay editor")), lessThan(leftOf(find.text("export"))));
    expect(leftOf(find.text("export")), lessThan(leftOf(find.text("left dock"))));
    expect(leftOf(find.text("left dock")), lessThan(leftOf(find.text("right dock"))));
    expect(leftOf(find.text("right dock")), lessThan(leftOf(find.text("save"))));
    expect(leftOf(find.text("save")), lessThan(leftOf(find.byType(PopupMenuButton<void>))));
  });

  testWidgets("an empty overflowEntries list renders no ⋮ button", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptWorkspaceToolbar(title: "My Movie", isDirty: false, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PopupMenuButton<void>), findsNothing);
  });
}
