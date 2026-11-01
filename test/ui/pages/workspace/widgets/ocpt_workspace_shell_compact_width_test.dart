// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_episode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock_layout_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_shell.dart';
import 'ocpt_workspace_shell_test_doubles.dart';

/// Run the tests of the workspace shell compact width.
void main() {
  const pilotEpisode = OcptEpisode(id: "ep-1", number: 1, title: "Pilot");

  group("compact-width edge drawers", () {
    OcptWorkspaceDockLayoutController buildController() => OcptWorkspaceDockLayoutController(
      leftFraction: OcptWorkspaceDock.leftDefaultFraction,
      rightFraction: OcptWorkspaceDock.rightDefaultFraction,
    );

    testWidgets("an expanded width keeps the persistent columns with their divider", (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = buildController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrapInApp(
          OcptWorkspaceShell(
            title: "My Movie",
            isDirty: false,
            onBack: () {},
            centre: const Text("centre"),
            leftPanel: const Text("left"),
            dockLayoutController: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OcptWorkspaceDockDivider), findsOneWidget);
      expect(find.text("left"), findsOneWidget);
    });

    testWidgets(
      "a compact width starts with the panel closed, and shows it as a drawer once its toggle is "
      "tapped",
      (tester) async {
        tester.view.physicalSize = const Size(700, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final controller = buildController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          wrapInApp(
            OcptWorkspaceShell(
              title: "My Movie",
              isDirty: false,
              onBack: () {},
              centre: const Text("centre"),
              leftPanel: const Text("left"),
              // The mode's own flag defaults to open — a compact width ignores it, so the drawer
              // still starts closed.
              isLeftDockOpen: true,
              onToggleLeftDock: () {},
              dockLayoutController: controller,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Nothing is shown while the panel is closed: no drawer, and so no resize divider either.
        expect(find.byType(OcptWorkspaceDockDivider), findsNothing);
        expect(find.text("left"), findsNothing);
        expect(find.text("centre"), findsOneWidget);

        final tr = Tr.of(tester.element(find.byType(OcptWorkspaceShell)));
        await tester.tap(find.byTooltip(tr.workspaceToggleLeftDockTooltip));
        await tester.pumpAndSettle();

        expect(find.text("left"), findsOneWidget);
        expect(find.text("centre"), findsOneWidget);

        // A tablet-compact drawer opens to its fraction and is resizable, so it now carries a
        // divider. The left dock's default 0.18 fraction of 700px clamps up to its 180px minimum.
        expect(find.byType(OcptWorkspaceDockDivider), findsOneWidget);
        expect(
          tester.getSize(find.byType(OcptWorkspaceDock)).width,
          closeTo(OcptWorkspaceDock.leftMinWidth, 0.001),
        );
      },
    );

    testWidgets("dragging a tablet-compact drawer's divider resizes it and persists the fraction", (
      tester,
    ) async {
      tester.view.physicalSize = const Size(760, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = buildController();
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
            rightPanel: const Text("right"),
            onToggleRightDock: () {},
            dockLayoutController: controller,
            onDockFractionsChanged: (fractions) {
              callCount++;
              lastReported = fractions;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptWorkspaceShell)));
      await tester.tap(find.byTooltip(tr.workspaceToggleRightDockTooltip));
      await tester.pumpAndSettle();

      final widthBefore = tester.getSize(find.byType(OcptWorkspaceDock)).width;

      // Drag the right drawer's handle towards the centre (leftwards) to widen it.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(OcptWorkspaceDockDivider)),
      );
      await gesture.moveBy(const Offset(-80, 0));
      await tester.pump();
      // Mid-drag: the drawer has grown but nothing has been persisted yet.
      expect(tester.getSize(find.byType(OcptWorkspaceDock)).width, greaterThan(widthBefore));
      expect(callCount, 0);

      await gesture.up();
      await tester.pumpAndSettle();

      // Exactly one persist call, for the right side alone.
      expect(callCount, 1);
      expect(lastReported?.right, isNotNull);
      expect(lastReported?.left, isNull);
    });

    testWidgets("a phone-width drawer fills the whole row once opened", (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = buildController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrapInApp(
          OcptWorkspaceShell(
            title: "My Movie",
            isDirty: false,
            onBack: () {},
            centre: const Text("centre"),
            rightPanel: const Text("right"),
            onToggleRightDock: () {},
            dockLayoutController: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("right"), findsNothing);

      final tr = Tr.of(tester.element(find.byType(OcptWorkspaceShell)));
      await tester.tap(find.byTooltip(tr.workspaceToggleRightDockTooltip));
      await tester.pumpAndSettle();

      expect(find.byType(OcptWorkspaceDockDivider), findsNothing);
      expect(tester.getSize(find.byType(OcptWorkspaceDock)).width, 390);
    });

    testWidgets(
      "opening the left drawer then the right leaves only the right open (mutual exclusivity)",
      (tester) async {
        tester.view.physicalSize = const Size(700, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final controller = buildController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          wrapInApp(
            OcptWorkspaceShell(
              title: "My Movie",
              isDirty: false,
              onBack: () {},
              centre: const Text("centre"),
              leftPanel: const Text("left"),
              rightPanel: const Text("right"),
              onToggleLeftDock: () {},
              onToggleRightDock: () {},
              dockLayoutController: controller,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final tr = Tr.of(tester.element(find.byType(OcptWorkspaceShell)));
        await tester.tap(find.byTooltip(tr.workspaceToggleLeftDockTooltip));
        await tester.pumpAndSettle();

        expect(find.text("left"), findsOneWidget);
        expect(find.text("right"), findsNothing);

        await tester.tap(find.byTooltip(tr.workspaceToggleRightDockTooltip));
        await tester.pumpAndSettle();

        // Opening the right drawer closed the left one — at most one is ever open at once.
        expect(find.text("left"), findsNothing);
        expect(find.text("right"), findsOneWidget);
      },
    );

    testWidgets("opening a compact drawer whose mode dock is closed fires the mode's own toggle", (
      tester,
    ) async {
      // A mode builds a dock's panel gated on its own flag, so a closed dock's panel is null and
      // its drawer would have nothing to show. Opening the drawer therefore also fires the mode's
      // toggle so the panel gets built — the same tap the desktop dock button makes.
      tester.view.physicalSize = const Size(700, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var rightToggleCount = 0;
      final controller = buildController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrapInApp(
          OcptWorkspaceShell(
            title: "My Movie",
            isDirty: false,
            onBack: () {},
            centre: const Text("centre"),
            rightPanel: const Text("right"),
            // The mode's own right dock is closed: without firing its toggle, tapping the drawer
            // open would leave the mode none the wiser and its panel unbuilt.
            onToggleRightDock: () => rightToggleCount++,
            dockLayoutController: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptWorkspaceShell)));
      await tester.tap(find.byTooltip(tr.workspaceToggleRightDockTooltip));
      await tester.pumpAndSettle();

      expect(rightToggleCount, 1);
    });

    testWidgets("tapping its own toggle again closes an open drawer", (tester) async {
      tester.view.physicalSize = const Size(700, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = buildController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrapInApp(
          OcptWorkspaceShell(
            title: "My Movie",
            isDirty: false,
            onBack: () {},
            centre: const Text("centre"),
            leftPanel: const Text("left"),
            onToggleLeftDock: () {},
            dockLayoutController: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptWorkspaceShell)));
      final toggle = find.byTooltip(tr.workspaceToggleLeftDockTooltip);

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.text("left"), findsOneWidget);

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.text("left"), findsNothing);
    });

    testWidgets("tapping the scrim beside a drawer closes it", (tester) async {
      tester.view.physicalSize = const Size(700, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = buildController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrapInApp(
          OcptWorkspaceShell(
            title: "My Movie",
            isDirty: false,
            onBack: () {},
            centre: const Text("centre"),
            leftPanel: const Text("left"),
            onToggleLeftDock: () {},
            dockLayoutController: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptWorkspaceShell)));
      await tester.tap(find.byTooltip(tr.workspaceToggleLeftDockTooltip));
      await tester.pumpAndSettle();
      expect(find.text("left"), findsOneWidget);

      // The left drawer is only its clamped fraction wide at the left; a tap well to its right
      // lands on the scrim over the centre, which closes the drawer.
      await tester.tapAt(const Offset(600, 600));
      await tester.pumpAndSettle();

      expect(find.text("left"), findsNothing);
    });
  });

  group("phone-width toolbar overflow", () {
    testWidgets("folds export, settings and help into the overflow menu on a phone", (
      tester,
    ) async {
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var exportCount = 0;
      var settingsCount = 0;

      await tester.pumpWidget(
        wrapInApp(
          OcptWorkspaceShell(
            title: "My Movie",
            isDirty: false,
            onBack: () {},
            centre: const Text("centre"),
            onExportRequested: (_) => exportCount++,
            onProjectSettingsRequested: () => settingsCount++,
            onHelpRequested: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptWorkspaceShell)));

      // None of the three are toolbar controls at this width.
      expect(find.byTooltip(tr.workspaceExportTooltip), findsNothing);
      expect(find.byTooltip(tr.workspaceProjectSettingsTooltip), findsNothing);
      expect(find.byTooltip(tr.workspaceHelpTooltip), findsNothing);

      // They live in the overflow menu instead: open it and act on them there.
      final overflow = find.byType(PopupMenuButton<void>);
      expect(overflow, findsOneWidget);

      await tester.tap(overflow);
      await tester.pumpAndSettle();

      expect(find.text(tr.workspaceExportAction), findsOneWidget);
      expect(find.text(tr.workspaceProjectSettingsTooltip), findsOneWidget);
      expect(find.text(tr.workspaceHelpTooltip), findsOneWidget);

      await tester.tap(find.text(tr.workspaceExportAction));
      await tester.pumpAndSettle();
      expect(exportCount, 1);

      await tester.tap(overflow);
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr.workspaceProjectSettingsTooltip));
      await tester.pumpAndSettle();
      expect(settingsCount, 1);
    });

    testWidgets("keeps export and settings as toolbar controls above a phone width", (
      tester,
    ) async {
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
            onExportRequested: (_) {},
            onProjectSettingsRequested: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptWorkspaceShell)));

      // The controls are on the toolbar, and nothing folded, so there is no overflow button.
      expect(find.byTooltip(tr.workspaceExportTooltip), findsOneWidget);
      expect(find.byTooltip(tr.workspaceProjectSettingsTooltip), findsOneWidget);
      expect(find.byType(PopupMenuButton<void>), findsNothing);
    });

    testWidgets("keeps the mode's own overflow entries below the folded ones", (tester) async {
      tester.view.physicalSize = const Size(500, 900);
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
            onExportRequested: (_) {},
            overflowEntries: const [PopupMenuItem<void>(child: Text("Mode entry"))],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptWorkspaceShell)));

      await tester.tap(find.byType(PopupMenuButton<void>));
      await tester.pumpAndSettle();

      expect(find.text(tr.workspaceExportAction), findsOneWidget);
      expect(find.text("Mode entry"), findsOneWidget);
      expect(find.byType(PopupMenuDivider), findsOneWidget);
    });
  });

  group("phone-width episode control", () {
    testWidgets(
      "the single-episode add button is withheld outright at a phone width, which is always "
      "compact too",
      (tester) async {
        tester.view.physicalSize = const Size(360, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          wrapInApp(
            OcptWorkspaceShell(
              title: "A Rather Long Movie Project Title Here",
              isDirty: false,
              onBack: () {},
              modeLabel: "Screenplay",
              centre: const Text("centre"),
              episodes: const [OcptEpisode(id: "ep-1", number: 1, title: "Pilot")],
              selectedEpisodeId: "ep-1",
              onEpisodeSelected: (_) {},
              onAddEpisodeRequested: () {},
              onSave: () {},
              isLeftDockOpen: true,
              onToggleLeftDock: () {},
              onToggleRightDock: () {},
            ),
          ),
        );
        await tester.pump();

        // A RenderFlex overflow throws during paint; a clean pump proves the toolbar fits.
        expect(tester.takeException(), isNull);

        final tr = Tr.of(tester.element(find.byType(OcptWorkspaceShell)));
        // ocptPhoneWidthBreakpoint is always below ocptCompactWidthBreakpoint, so the button is
        // withheld here exactly as it is at any other compact width — it never gets to reduce to
        // an icon-only trigger of its own.
        expect(find.byTooltip(tr.workspaceAddEpisodeTooltip), findsNothing);
        expect(find.text(tr.workspaceAddEpisodeAction), findsNothing);
      },
    );

    testWidgets("the multi-episode selector is icon-only and does not overflow the toolbar", (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        wrapInApp(
          OcptWorkspaceShell(
            title: "A Rather Long Movie Project Title Here",
            isDirty: false,
            onBack: () {},
            modeLabel: "Screenplay",
            centre: const Text("centre"),
            episodes: const [
              OcptEpisode(id: "ep-1", number: 1, title: "A Very Long Episode Title Indeed"),
              OcptEpisode(id: "ep-2", number: 2, title: "Another Long One"),
            ],
            selectedEpisodeId: "ep-1",
            onEpisodeSelected: (_) {},
            onSave: () {},
            isLeftDockOpen: true,
            onToggleLeftDock: () {},
            onToggleRightDock: () {},
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);

      final tr = Tr.of(tester.element(find.byType(OcptWorkspaceShell)));
      // The selector is reachable by its tooltip, but the selected episode's title is not drawn
      // in the toolbar (icon-only trigger); it appears only once the menu is opened.
      expect(find.byTooltip(tr.workspaceEpisodeSelectorTooltip), findsOneWidget);
      expect(
        find.text(tr.workspaceEpisodeTitledLabel(1, "A Very Long Episode Title Indeed")),
        findsNothing,
      );
    });
  });

  group("compact-width toolbar reductions", () {
    testWidgets("hides the title and mode label, and the single-episode add button, below "
        "ocptCompactWidthBreakpoint", (tester) async {
      // Explicitly below the 816px breakpoint — the default 800px test surface is compact too,
      // but this test is about the reduction itself, so it states the width it relies on.
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        wrapInApp(
          OcptWorkspaceShell(
            title: "My Movie",
            isDirty: false,
            onBack: () {},
            modeLabel: "Screenplay",
            centre: const Text("centre"),
            episodes: const [pilotEpisode],
            selectedEpisodeId: pilotEpisode.id,
            onEpisodeSelected: (_) {},
            onAddEpisodeRequested: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptWorkspaceShell)));
      expect(find.text("My Movie"), findsNothing);
      expect(find.text("Screenplay"), findsNothing);
      expect(find.byTooltip(tr.workspaceAddEpisodeTooltip), findsNothing);
      expect(find.text(tr.workspaceAddEpisodeAction), findsNothing);
    });

    testWidgets(
      "keeps the title, the mode label and the single-episode add button at a wide width",
      (tester) async {
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
              modeLabel: "Screenplay",
              centre: const Text("centre"),
              episodes: const [pilotEpisode],
              selectedEpisodeId: pilotEpisode.id,
              onEpisodeSelected: (_) {},
              onAddEpisodeRequested: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        final tr = Tr.of(tester.element(find.byType(OcptWorkspaceShell)));
        expect(find.text("My Movie"), findsOneWidget);
        expect(find.text("Screenplay"), findsOneWidget);
        expect(find.byTooltip(tr.workspaceAddEpisodeTooltip), findsOneWidget);
      },
    );
  });
}
