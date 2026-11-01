// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_episode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock_layout_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_shell.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_toolbar.dart';
import 'ocpt_workspace_shell_test_doubles.dart';

/// Run the tests of the workspace shell docks and toolbar.
void main() {
  const pilotEpisode = OcptEpisode(id: "ep-1", number: 1, title: "Pilot");

  const untitledEpisode = OcptEpisode(id: "ep-2", number: 3, title: "");

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
      wrapInApp(
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
      wrapInApp(
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
      wrapInApp(
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
      wrapInApp(
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
      wrapInApp(
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
      wrapInApp(
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
    // A wide, desktop surface: this is about the mode-owned isLeftDockOpen/onToggleLeftDock pair,
    // which only drives the toggle above ocptCompactWidthBreakpoint — the default 800px test
    // surface is compact (below 816), where the toggle drives the shell's own local drawer state
    // instead (see the "compact-width edge drawers" group below).
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var leftToggleCount = 0;

    await tester.pumpWidget(
      wrapInApp(
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
      wrapInApp(
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
      wrapInApp(
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
        wrapInApp(
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
        wrapInApp(
          OcptWorkspaceShell(
            title: "My Movie",
            isDirty: false,
            onBack: () {},
            centre: const Text("centre"),
            onExportRequested: (_) => requestCount++,
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

  testWidgets("the export action is exactly as tall as a dock toggle on a desktop platform", (
    tester,
  ) async {
    // The density a [TextButton] takes from the ambient theme is the platform's own, and on a
    // desktop one it is [VisualDensity.compact] — which takes 8 px off every minimum size. An
    // [IconButton] never follows it, so without this override the test would report the Android
    // density and the two controls would agree at a height neither has on Linux or Windows.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;

    await tester.pumpWidget(
      wrapInApp(
        OcptWorkspaceShell(
          title: "My Movie",
          isDirty: false,
          onBack: () {},
          centre: const Text("centre"),
          onExportRequested: (_) {},
          isLeftDockOpen: true,
          onToggleLeftDock: () {},
        ),
        theme: ocpt_theme.ocptTheme.lightThemeData,
      ),
    );
    await tester.pumpAndSettle();
    // Put back before anything can fail: the framework's own invariant check runs before this
    // test's tear-downs would, and a leaked foundation override fails the *next* test instead.
    debugDefaultTargetPlatformOverride = null;

    final tr = Tr.of(tester.element(find.byType(OcptWorkspaceShell)));
    final exportHeight = tester.getSize(find.byTooltip(tr.workspaceExportTooltip)).height;
    final toggleHeight = tester.getSize(find.byTooltip(tr.workspaceToggleLeftDockTooltip)).height;

    expect(exportHeight, ocpt_theme.ocptToolbarChromeButtonSize);
    expect(exportHeight, toggleHeight);
  });

  testWidgets(
    "the project settings action is rendered only when the mode wired it, and clicking it fires "
    "the callback",
    (tester) async {
      var requestCount = 0;

      await tester.pumpWidget(
        wrapInApp(
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
        wrapInApp(
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
    // A wide surface: below ocptCompactWidthBreakpoint the mode label is withheld outright (see
    // the "compact-width toolbar reductions" group below), and this test is about the chrome
    // slots rather than that reduction.
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      wrapInApp(
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

  testWidgets("the onDockFractionsChanged callback fires exactly once per completed drag gesture", (
    tester,
  ) async {
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
      wrapInApp(
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
  });

  testWidgets("no episode selector when the project holds at most one episode", (tester) async {
    await tester.pumpWidget(
      wrapInApp(
        OcptWorkspaceShell(
          title: "My Movie",
          isDirty: false,
          onBack: () {},
          centre: const Text("centre"),
          episodes: const [pilotEpisode],
          selectedEpisodeId: pilotEpisode.id,
          onEpisodeSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptWorkspaceShell)));
    expect(find.byTooltip(tr.workspaceEpisodeSelectorTooltip), findsNothing);
  });

  testWidgets("no episode selector when the mode withholds it", (tester) async {
    await tester.pumpWidget(
      wrapInApp(
        OcptWorkspaceShell(
          title: "My Movie",
          isDirty: false,
          onBack: () {},
          centre: const Text("centre"),
          episodes: const [pilotEpisode, untitledEpisode],
          selectedEpisodeId: pilotEpisode.id,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptWorkspaceShell)));
    expect(find.byTooltip(tr.workspaceEpisodeSelectorTooltip), findsNothing);
  });

  testWidgets(
    "the episode selector lists every episode, an untitled one reading Episode 3, and clicking "
    "one fires onEpisodeSelected",
    (tester) async {
      String? selectedEpisodeId;

      await tester.pumpWidget(
        wrapInApp(
          OcptWorkspaceShell(
            title: "My Movie",
            isDirty: false,
            onBack: () {},
            centre: const Text("centre"),
            episodes: const [pilotEpisode, untitledEpisode],
            selectedEpisodeId: pilotEpisode.id,
            onEpisodeSelected: (episodeId) => selectedEpisodeId = episodeId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptWorkspaceShell)));
      final selector = find.byTooltip(tr.workspaceEpisodeSelectorTooltip);
      expect(selector, findsOneWidget);

      await tester.tap(selector);
      await tester.pumpAndSettle();

      expect(find.text(tr.workspaceEpisodeTitledLabel(1, "Pilot")), findsWidgets);
      expect(find.text(tr.workspaceEpisodeUntitledLabel(3)), findsOneWidget);

      await tester.tap(find.text(tr.workspaceEpisodeUntitledLabel(3)));
      await tester.pumpAndSettle();

      expect(selectedEpisodeId, untitledEpisode.id);
    },
  );

  testWidgets("no Manage episodes… entry when no project settings callback is wired", (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapInApp(
        OcptWorkspaceShell(
          title: "My Movie",
          isDirty: false,
          onBack: () {},
          centre: const Text("centre"),
          episodes: const [pilotEpisode, untitledEpisode],
          selectedEpisodeId: pilotEpisode.id,
          onEpisodeSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptWorkspaceShell)));
    await tester.tap(find.byTooltip(tr.workspaceEpisodeSelectorTooltip));
    await tester.pumpAndSettle();

    expect(find.text(tr.workspaceManageEpisodesAction), findsNothing);
  });

  testWidgets("the Manage episodes… entry is the menu's last one, and clicking it fires "
      "onProjectSettingsRequested", (tester) async {
    var settingsCount = 0;

    await tester.pumpWidget(
      wrapInApp(
        OcptWorkspaceShell(
          title: "My Movie",
          isDirty: false,
          onBack: () {},
          centre: const Text("centre"),
          episodes: const [pilotEpisode, untitledEpisode],
          selectedEpisodeId: pilotEpisode.id,
          onEpisodeSelected: (_) {},
          onProjectSettingsRequested: () => settingsCount++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptWorkspaceShell)));
    await tester.tap(find.byTooltip(tr.workspaceEpisodeSelectorTooltip));
    await tester.pumpAndSettle();

    final manageEntry = find.text(tr.workspaceManageEpisodesAction);
    expect(manageEntry, findsOneWidget);

    final entryTops = tester
        .widgetList<PopupMenuItem<String>>(find.byType(PopupMenuItem<String>))
        .toList();
    expect(entryTops.last.child, isA<Text>());
    expect((entryTops.last.child! as Text).data, tr.workspaceManageEpisodesAction);

    await tester.tap(manageEntry);
    await tester.pumpAndSettle();

    expect(settingsCount, 1);
  });

  testWidgets(
    "the Add an episode… button takes the selector's place on a single-episode project, and "
    "clicking it fires onAddEpisodeRequested",
    (tester) async {
      // A wide surface: below ocptCompactWidthBreakpoint the button is withheld outright (see the
      // "compact-width toolbar reductions" group below), and this test is about the button itself.
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var addCount = 0;

      await tester.pumpWidget(
        wrapInApp(
          OcptWorkspaceShell(
            title: "My Movie",
            isDirty: false,
            onBack: () {},
            centre: const Text("centre"),
            episodes: const [pilotEpisode],
            selectedEpisodeId: pilotEpisode.id,
            onEpisodeSelected: (_) {},
            onAddEpisodeRequested: () => addCount++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptWorkspaceShell)));
      expect(find.byTooltip(tr.workspaceEpisodeSelectorTooltip), findsNothing);

      final addButton = find.byTooltip(tr.workspaceAddEpisodeTooltip);
      expect(addButton, findsOneWidget);

      await tester.tap(addButton);
      await tester.pumpAndSettle();

      expect(addCount, 1);
    },
  );

  testWidgets("no Add an episode… button when the mode withholds it", (tester) async {
    await tester.pumpWidget(
      wrapInApp(
        OcptWorkspaceShell(
          title: "My Movie",
          isDirty: false,
          onBack: () {},
          centre: const Text("centre"),
          episodes: const [pilotEpisode],
          selectedEpisodeId: pilotEpisode.id,
          onEpisodeSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptWorkspaceShell)));
    expect(find.byTooltip(tr.workspaceAddEpisodeTooltip), findsNothing);
  });

  testWidgets(
    "no Add an episode… button once the project holds several episodes, nor before they are "
    "loaded",
    (tester) async {
      await tester.pumpWidget(
        wrapInApp(
          OcptWorkspaceShell(
            title: "My Movie",
            isDirty: false,
            onBack: () {},
            centre: const Text("centre"),
            episodes: const [pilotEpisode, untitledEpisode],
            selectedEpisodeId: pilotEpisode.id,
            onEpisodeSelected: (_) {},
            onAddEpisodeRequested: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptWorkspaceShell)));
      expect(find.byTooltip(tr.workspaceAddEpisodeTooltip), findsNothing);
      expect(find.byTooltip(tr.workspaceEpisodeSelectorTooltip), findsOneWidget);

      await tester.pumpWidget(
        wrapInApp(
          OcptWorkspaceShell(
            title: "My Movie",
            isDirty: false,
            onBack: () {},
            centre: const Text("centre"),
            onEpisodeSelected: (_) {},
            onAddEpisodeRequested: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip(tr.workspaceAddEpisodeTooltip), findsNothing);
    },
  );
}
