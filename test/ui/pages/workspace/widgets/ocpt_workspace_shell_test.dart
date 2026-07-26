// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock_layout_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_shell.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve (the shell's own
/// toolbar reads them for its tooltips), and a wide test surface so the docks row has room for
/// both docks plus the centre floor.
Widget _wrapInApp(Widget child) => MaterialApp(
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
  testWidgets("a null leftPanel renders neither a left dock nor its divider", (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = OcptWorkspaceDockLayoutController(
      leftFraction: OcptWorkspaceDock.leftDefaultFraction,
      rightFraction: OcptWorkspaceDock.rightDefaultFraction,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrapInApp(
        OcptWorkspaceShell(
          title: "My Movie",
          isDirty: false,
          onBack: () {},
          centre: const Text("centre"),
          rightPanel: const ColoredBox(color: Colors.blue, child: Text("right")),
          dockLayoutController: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OcptWorkspaceDockDivider), findsOneWidget);
    // The one dock present is the right one (no left panel was given at all).
    expect(find.byType(OcptWorkspaceDock), findsOneWidget);
    expect(find.text("right"), findsOneWidget);
  });

  testWidgets("an empty overflowEntries list renders no ⋮ button", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptWorkspaceShell(
          title: "My Movie",
          isDirty: false,
          onBack: () {},
          centre: const Text("centre"),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PopupMenuButton<void>), findsNothing);
  });

  testWidgets("a non-empty overflowEntries list renders the ⋮ button", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptWorkspaceShell(
          title: "My Movie",
          isDirty: false,
          onBack: () {},
          centre: const Text("centre"),
          overflowEntries: const [PopupMenuItem<void>(child: Text("Entry"))],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PopupMenuButton<void>), findsOneWidget);
  });

  testWidgets(
    "the onDockFractionsChanged callback fires exactly once per completed drag gesture",
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = OcptWorkspaceDockLayoutController(
        leftFraction: OcptWorkspaceDock.leftDefaultFraction,
        rightFraction: OcptWorkspaceDock.rightDefaultFraction,
      );
      addTearDown(controller.dispose);

      var callCount = 0;
      ({double? left, double? right})? lastReported;

      await tester.pumpWidget(
        _wrapInApp(
          OcptWorkspaceShell(
            title: "My Movie",
            isDirty: false,
            onBack: () {},
            centre: const Text("centre"),
            leftPanel: const Text("left"),
            dockLayoutController: controller,
            onDockFractionsChanged: (fractions) {
              callCount++;
              lastReported = fractions;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(OcptWorkspaceDockDivider).first),
      );
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      // Mid-drag: no callback yet.
      expect(callCount, 0);

      await gesture.up();
      await tester.pumpAndSettle();

      expect(callCount, 1);
      expect(lastReported?.left, isNotNull);
      expect(lastReported?.right, isNull);
    },
  );
}
