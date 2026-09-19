// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_panel.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_tool.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_storyboard_panel_strip.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, and sets the test
/// surface past the 800 px compact breakpoint (`docs/architecture/foundations.md`), matching every
/// other shot list widget/bloc test of this milestone.
Future<void> _pumpStrip(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        Tr.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: Tr.delegate.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

/// A minimal panel of [id], with no image and an empty comment, for a test that only cares about
/// the strip's own affordances.
OcptStoryboardPanel _panel(String id, {String comment = ""}) => OcptStoryboardPanel(
  id: id,
  shotId: "shot-1",
  sortKey: id,
  imageAssetId: null,
  imagePath: null,
  comment: comment,
  annotations: const [],
);

void main() {
  testWidgets("a shot with no panel shows the import slot alone, labelled 'no panel yet'", (
    tester,
  ) async {
    await _pumpStrip(
      tester,
      OcptStoryboardPanelStrip(
        panels: const [],
        aspectRatio: 16 / 9,
        height: 160,
        selectedPanelId: null,
        isReadOnly: false,
        onPanelSelected: (_) {},
        onReplaceRequested: (_) {},
        onImportRequested: () {},
        onReordered: (_, __) {},
        activeAnnotationTool: null,
        selectedAnnotationId: null,
        onAnnotationDrawn: (_, __, ___, ____, _____, ______) {},
        onLabelPlaced: (_, __, ___) {},
        onAnnotationSelected: (_) {},
      ),
    );

    expect(find.text("no panel yet"), findsOneWidget);
    expect(find.byType(OcptStoryboardPanelFrame), findsNothing);
  });

  testWidgets("tapping a frame reports its panel's id", (tester) async {
    final selected = <String>[];

    await _pumpStrip(
      tester,
      OcptStoryboardPanelStrip(
        panels: [_panel("p1"), _panel("p2")],
        aspectRatio: 16 / 9,
        height: 160,
        selectedPanelId: null,
        isReadOnly: false,
        onPanelSelected: selected.add,
        onReplaceRequested: (_) {},
        onImportRequested: () {},
        onReordered: (_, __) {},
        activeAnnotationTool: null,
        selectedAnnotationId: null,
        onAnnotationDrawn: (_, __, ___, ____, _____, ______) {},
        onLabelPlaced: (_, __, ___) {},
        onAnnotationSelected: (_) {},
      ),
    );

    await tester.tap(find.byType(OcptStoryboardPanelFrame).last);
    await tester.pump();

    expect(selected, ["p2"]);
  });

  testWidgets(
    "read-only withholds the import slot, the replace action and reordering, "
    "while selecting still reports",
    (tester) async {
      await _pumpStrip(
        tester,
        OcptStoryboardPanelStrip(
          panels: [_panel("p1")],
          aspectRatio: 16 / 9,
          height: 160,
          selectedPanelId: null,
          isReadOnly: true,
          onPanelSelected: (_) {},
          onReplaceRequested: null,
          onImportRequested: null,
          onReordered: null,
          activeAnnotationTool: null,
          selectedAnnotationId: null,
          onAnnotationDrawn: null,
          onLabelPlaced: null,
          onAnnotationSelected: null,
        ),
      );

      // The import slot is still drawn (a shot may still need one described), but its own tap
      // does nothing: there is no `onTap` to report through.
      final importSlotFinder = find.byIcon(Icons.add_photo_alternate_outlined);
      expect(importSlotFinder, findsOneWidget);
      final inkWell = tester.widget<InkWell>(
        find
            .ancestor(of: importSlotFinder, matching: find.byType(InkWell))
            .first,
      );
      expect(inkWell.onTap, isNull);

      // The frame's own `Replace image` icon button is never built at all while withheld.
      expect(find.byIcon(Icons.swap_horiz), findsNothing);
    },
  );

  testWidgets("a panel's own comment reads under its frame", (tester) async {
    await _pumpStrip(
      tester,
      OcptStoryboardPanelStrip(
        panels: [_panel("p1", comment: "Push in on the door")],
        aspectRatio: 16 / 9,
        height: 160,
        selectedPanelId: null,
        isReadOnly: false,
        onPanelSelected: (_) {},
        onReplaceRequested: (_) {},
        onImportRequested: () {},
        onReordered: (_, __) {},
        activeAnnotationTool: null,
        selectedAnnotationId: null,
        onAnnotationDrawn: (_, __, ___, ____, _____, ______) {},
        onLabelPlaced: (_, __, ___) {},
        onAnnotationSelected: (_) {},
      ),
    );

    expect(find.textContaining("Push in on the door"), findsOneWidget);
  });

  testWidgets("a drag over the selected panel with an arrow tool draws it", (tester) async {
    final drawn = <(OcptStoryboardAnnotationKind, double, double, double, double)>[];

    await _pumpStrip(
      tester,
      OcptStoryboardPanelStrip(
        panels: [_panel("p1")],
        aspectRatio: 16 / 9,
        height: 160,
        selectedPanelId: "p1",
        isReadOnly: false,
        onPanelSelected: (_) {},
        onReplaceRequested: (_) {},
        onImportRequested: () {},
        onReordered: (_, __) {},
        activeAnnotationTool: OcptStoryboardAnnotationTool.movementArrow,
        selectedAnnotationId: null,
        onAnnotationDrawn: (_, kind, x1, y1, x2, y2) => drawn.add((kind, x1, y1, x2, y2)),
        onLabelPlaced: (_, __, ___) {},
        onAnnotationSelected: (_) {},
      ),
    );

    final frameCenter = tester.getCenter(find.byType(OcptStoryboardPanelFrame));
    final gesture = await tester.startGesture(frameCenter - const Offset(40, 0));
    await gesture.moveBy(const Offset(80, 0));
    await gesture.up();
    await tester.pump();

    expect(drawn, hasLength(1));
    expect(drawn.single.$1, OcptStoryboardAnnotationKind.movementArrow);
  });

  testWidgets(
    "a tool active on the selected panel suspends this strip's reorder, "
    "and turning it off restores it",
    (tester) async {
      final reordered = <String>[];

      Widget buildStrip(OcptStoryboardAnnotationTool? tool) => OcptStoryboardPanelStrip(
        panels: [_panel("p1"), _panel("p2")],
        aspectRatio: 16 / 9,
        height: 160,
        selectedPanelId: "p1",
        isReadOnly: false,
        onPanelSelected: (_) {},
        onReplaceRequested: (_) {},
        onImportRequested: () {},
        onReordered: (panelId, _) => reordered.add(panelId),
        activeAnnotationTool: tool,
        selectedAnnotationId: null,
        onAnnotationDrawn: (_, __, ___, ____, _____, ______) {},
        onLabelPlaced: (_, __, ___) {},
        onAnnotationSelected: (_) {},
      );

      await _pumpStrip(tester, buildStrip(OcptStoryboardAnnotationTool.movementArrow));
      final strip = tester.widget<OcptStoryboardPanelStrip>(find.byType(OcptStoryboardPanelStrip));
      expect(strip.effectiveOnReordered, isNull);

      await _pumpStrip(tester, buildStrip(null));
      final restoredStrip = tester.widget<OcptStoryboardPanelStrip>(
        find.byType(OcptStoryboardPanelStrip),
      );
      expect(restoredStrip.effectiveOnReordered, isNotNull);
    },
  );
}
