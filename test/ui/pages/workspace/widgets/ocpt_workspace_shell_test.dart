// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_episode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock_layout_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_shell.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_toolbar.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve (the shell's own
/// toolbar reads them for its tooltips), a wide test surface so the docks row has room for both
/// docks plus the centre floor, and a [Scaffold] (as the real workspace page already provides):
/// the episode selector's trigger is a [PopupMenuButton] built with its own `child`, which wraps
/// it in a plain [InkWell] rather than a self-contained button, so it needs a [Material] ancestor
/// to paint into.
///
/// [theme] is the application's own only where a test measures the chrome: the stock theme's
/// [Divider] is 16 px tall, which alone takes the toolbar's own band down from 44 px to 28, so a
/// height read under it is not the height the app draws.
Widget _wrapInApp(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme,
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

  testWidgets(
    "the export action is exactly as tall as a dock toggle on a desktop platform",
    (tester) async {
      // The density a [TextButton] takes from the ambient theme is the platform's own, and on a
      // desktop one it is [VisualDensity.compact] — which takes 8 px off every minimum size. An
      // [IconButton] never follows it, so without this override the test would report the Android
      // density and the two controls would agree at a height neither has on Linux or Windows.
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      await tester.pumpWidget(
        _wrapInApp(
          OcptWorkspaceShell(
            title: "My Movie",
            isDirty: false,
            onBack: () {},
            centre: const Text("centre"),
            onExportRequested: (_) {},
            isLeftDockOpen: true,
            onToggleLeftDock: () {},
          ),
          theme: ocptTheme.lightThemeData,
        ),
      );
      await tester.pumpAndSettle();
      // Put back before anything can fail: the framework's own invariant check runs before this
      // test's tear-downs would, and a leaked foundation override fails the *next* test instead.
      debugDefaultTargetPlatformOverride = null;

      final tr = Tr.of(tester.element(find.byType(OcptWorkspaceShell)));
      final exportHeight = tester.getSize(find.byTooltip(tr.workspaceExportTooltip)).height;
      final toggleHeight = tester
          .getSize(find.byTooltip(tr.workspaceToggleLeftDockTooltip))
          .height;

      expect(exportHeight, ocptToolbarChromeButtonSize);
      expect(exportHeight, toggleHeight);
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
    // A wide surface: below ocptCompactWidthBreakpoint the mode label is withheld outright (see
    // the "compact-width toolbar reductions" group below), and this test is about the chrome
    // slots rather than that reduction.
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

  const pilotEpisode = OcptEpisode(id: "ep-1", number: 1, title: "Pilot");
  const untitledEpisode = OcptEpisode(id: "ep-2", number: 3, title: "");

  testWidgets("no episode selector when the project holds at most one episode", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
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
      _wrapInApp(
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
        _wrapInApp(
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

  testWidgets(
    "no Manage episodes… entry when no project settings callback is wired",
    (tester) async {
      await tester.pumpWidget(
        _wrapInApp(
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
    },
  );

  testWidgets(
    "the Manage episodes… entry is the menu's last one, and clicking it fires "
    "onProjectSettingsRequested",
    (tester) async {
      var settingsCount = 0;

      await tester.pumpWidget(
        _wrapInApp(
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
    },
  );

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
        _wrapInApp(
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
      _wrapInApp(
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
        _wrapInApp(
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
        _wrapInApp(
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
        _wrapInApp(
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
          _wrapInApp(
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
        _wrapInApp(
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
        _wrapInApp(
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
          _wrapInApp(
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

    testWidgets(
      "opening a compact drawer whose mode dock is closed fires the mode's own toggle",
      (tester) async {
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
          _wrapInApp(
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
      },
    );

    testWidgets("tapping its own toggle again closes an open drawer", (tester) async {
      tester.view.physicalSize = const Size(700, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = buildController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrapInApp(
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
        _wrapInApp(
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
        _wrapInApp(
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
        _wrapInApp(
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
        _wrapInApp(
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
          _wrapInApp(
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

    testWidgets(
      "the multi-episode selector is icon-only and does not overflow the toolbar",
      (tester) async {
        tester.view.physicalSize = const Size(360, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _wrapInApp(
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
        expect(find.text(tr.workspaceEpisodeTitledLabel(1, "A Very Long Episode Title Indeed")),
            findsNothing);
      },
    );
  });

  group("compact-width toolbar reductions", () {
    testWidgets(
      "hides the title and mode label, and the single-episode add button, below "
      "ocptCompactWidthBreakpoint",
      (tester) async {
        // Explicitly below the 816px breakpoint — the default 800px test surface is compact too,
        // but this test is about the reduction itself, so it states the width it relies on.
        tester.view.physicalSize = const Size(500, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _wrapInApp(
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
      },
    );

    testWidgets(
      "keeps the title, the mode label and the single-episode add button at a wide width",
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _wrapInApp(
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
