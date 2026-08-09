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
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_toolbar.dart';

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

  testWidgets("the banner sits between the toolbar and the docks row, and only when given", (
    tester,
  ) async {
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

    expect(find.text("banner"), findsNothing);

    await tester.pumpWidget(
      _wrapInApp(
        OcptWorkspaceShell(
          title: "My Movie",
          isDirty: false,
          isReadOnly: true,
          onBack: () {},
          centre: const Text("centre"),
          banner: const Text("banner"),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final toolbarBottom = tester.getBottomLeft(find.byType(OcptWorkspaceToolbar)).dy;
    final bannerTop = tester.getTopLeft(find.text("banner")).dy;
    final centreTop = tester.getTopLeft(find.text("centre")).dy;

    expect(bannerTop, greaterThanOrEqualTo(toolbarBottom));
    expect(centreTop, greaterThan(bannerTop));
  });

  testWidgets("the shell's read-only flag reaches its own toolbar", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptWorkspaceShell(
          title: "My Movie",
          isDirty: false,
          isReadOnly: true,
          onBack: () {},
          centre: const Text("centre"),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptWorkspaceShell)));
    expect(find.text(tr.workspaceReadOnlyPill), findsOneWidget);
  });

  testWidgets("a dock toggle is rendered only for the side that wired a callback", (tester) async {
    var leftToggleCount = 0;

    await tester.pumpWidget(
      _wrapInApp(
        OcptWorkspaceShell(
          title: "My Movie",
          isDirty: false,
          onBack: () {},
          centre: const Text("centre"),
          isLeftDockOpen: true,
          onToggleLeftDock: () => leftToggleCount++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptWorkspaceShell)));
    expect(find.byTooltip(tr.workspaceToggleRightDockTooltip), findsNothing);

    final leftToggle = find.byTooltip(tr.workspaceToggleLeftDockTooltip);
    expect(leftToggle, findsOneWidget);
    // The open dock's toggle reads as selected, so the icon-button theme paints its accent wash.
    final toggleButton = tester.widget<IconButton>(
      find.ancestor(of: leftToggle, matching: find.byType(IconButton)),
    );
    expect(toggleButton.isSelected, isTrue);

    await tester.tap(leftToggle);
    await tester.pumpAndSettle();

    expect(leftToggleCount, 1);
  });

  testWidgets("the save control swaps for a spinner while a save is in flight", (tester) async {
    var saveCount = 0;

    await tester.pumpWidget(
      _wrapInApp(
        OcptWorkspaceShell(
          title: "My Movie",
          isDirty: true,
          onBack: () {},
          centre: const Text("centre"),
          onSave: () => saveCount++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptWorkspaceShell)));
    expect(find.byTooltip(tr.editorSaveTooltip), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.byTooltip(tr.editorSaveTooltip));
    await tester.pumpAndSettle();
    expect(saveCount, 1);

    await tester.pumpWidget(
      _wrapInApp(
        OcptWorkspaceShell(
          title: "My Movie",
          isDirty: true,
          onBack: () {},
          centre: const Text("centre"),
          onSave: () => saveCount++,
          isSaving: true,
        ),
      ),
    );
    await tester.pump();

    expect(find.byTooltip(tr.editorSaveTooltip), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets(
    "the export action is rendered only when the mode wired it, sits before the dock toggles, and "
    "clicking it fires the callback",
    (tester) async {
      var requestCount = 0;

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

      final tr = Tr.of(tester.element(find.byType(OcptWorkspaceShell)));
      expect(find.byTooltip(tr.workspaceExportTooltip), findsNothing);

      await tester.pumpWidget(
        _wrapInApp(
          OcptWorkspaceShell(
            title: "My Movie",
            isDirty: false,
            onBack: () {},
            centre: const Text("centre"),
            onExportRequested: () => requestCount++,
            isLeftDockOpen: true,
            onToggleLeftDock: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final action = find.byTooltip(tr.workspaceExportTooltip);
      expect(action, findsOneWidget);

      final actionLeft = tester.getTopLeft(action).dx;
      final toggleLeft = tester.getTopLeft(find.byTooltip(tr.workspaceToggleLeftDockTooltip)).dx;
      expect(actionLeft, lessThan(toggleLeft));

      await tester.tap(action);
      await tester.pumpAndSettle();

      expect(requestCount, 1);
    },
  );

  testWidgets(
    "the project settings action is rendered only when the mode wired it, and clicking it fires "
    "the callback",
    (tester) async {
      var requestCount = 0;

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

      final tr = Tr.of(tester.element(find.byType(OcptWorkspaceShell)));
      expect(find.byTooltip(tr.workspaceProjectSettingsTooltip), findsNothing);

      await tester.pumpWidget(
        _wrapInApp(
          OcptWorkspaceShell(
            title: "My Movie",
            isDirty: false,
            onBack: () {},
            centre: const Text("centre"),
            onProjectSettingsRequested: () => requestCount++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final action = find.byTooltip(tr.workspaceProjectSettingsTooltip);
      expect(action, findsOneWidget);

      await tester.tap(action);
      await tester.pumpAndSettle();

      expect(requestCount, 1);
    },
  );

  testWidgets("a mode that wires none of the chrome slots renders none of them", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptWorkspaceShell(
          title: "My Movie",
          isDirty: false,
          onBack: () {},
          centre: const Text("centre"),
          modeLabel: "Production budget",
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptWorkspaceShell)));
    expect(find.text("Production budget"), findsOneWidget);
    expect(find.byTooltip(tr.workspaceExportTooltip), findsNothing);
    expect(find.byTooltip(tr.workspaceToggleLeftDockTooltip), findsNothing);
    expect(find.byTooltip(tr.workspaceToggleRightDockTooltip), findsNothing);
    expect(find.byTooltip(tr.editorSaveTooltip), findsNothing);
    expect(find.byTooltip(tr.workspaceProjectSettingsTooltip), findsNothing);
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
