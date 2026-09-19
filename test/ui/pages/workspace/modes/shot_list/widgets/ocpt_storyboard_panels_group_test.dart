// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_annotation.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_panel.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_tool.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_storyboard_panels_group.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, and sets the test
/// surface past the 800 px compact breakpoint, matching every other shot list widget/bloc test of
/// this milestone.
Future<void> _pumpGroup(WidgetTester tester, Widget child) async {
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

/// A minimal panel of [id], for a test that only cares about the group's own affordances.
OcptStoryboardPanel _panel(String id, {String comment = ""}) => OcptStoryboardPanel(
  id: id,
  shotId: "shot-1",
  sortKey: id,
  imageAssetId: null,
  imagePath: null,
  comment: comment,
  annotations: const [],
);

/// A minimal mark of [id] and [kind], for a test that only cares about the annotation section's
/// own affordances.
OcptStoryboardAnnotation _annotation(
  String id, {
  OcptStoryboardAnnotationKind kind = OcptStoryboardAnnotationKind.label,
  String text = "",
}) => OcptStoryboardAnnotation(
  id: id,
  panelId: "p1",
  kind: kind,
  sortKey: id,
  x1: 0.5,
  y1: 0.5,
  x2: 0.5,
  y2: 0.5,
  text: text,
);

void main() {
  testWidgets("lists every panel with its rank and its comment field", (tester) async {
    await _pumpGroup(
      tester,
      OcptStoryboardPanelsGroup(
        panels: [_panel("p1", comment: "Wide"), _panel("p2", comment: "Push in")],
        commentValueOf: (id) => id == "p1" ? "Wide" : "Push in",
        isReadOnly: false,
        onCommentChanged: (_, __) {},
        onReordered: (_, __) {},
        onDeleteRequested: (_) {},
        selectedPanelId: null,
        annotations: const [],
        selectedAnnotationId: null,
        activeAnnotationTool: null,
        onToolChanged: (_) {},
        annotationTextValueOf: (_) => "",
        onAnnotationSelected: (_) {},
        onAnnotationTextChanged: (_, __) {},
        onAnnotationDeleteRequested: (_) {},
      ),
    );

    expect(find.text("1/2"), findsOneWidget);
    expect(find.text("2/2"), findsOneWidget);
    expect(find.text("Wide"), findsOneWidget);
    expect(find.text("Push in"), findsOneWidget);
  });

  testWidgets("typing into a panel's comment field reports its id and the raw text", (
    tester,
  ) async {
    final changed = <(String, String)>[];

    await _pumpGroup(
      tester,
      OcptStoryboardPanelsGroup(
        panels: [_panel("p1")],
        commentValueOf: (_) => "",
        isReadOnly: false,
        onCommentChanged: (id, value) => changed.add((id, value)),
        onReordered: (_, __) {},
        onDeleteRequested: (_) {},
        selectedPanelId: null,
        annotations: const [],
        selectedAnnotationId: null,
        activeAnnotationTool: null,
        onToolChanged: (_) {},
        annotationTextValueOf: (_) => "",
        onAnnotationSelected: (_) {},
        onAnnotationTextChanged: (_, __) {},
        onAnnotationDeleteRequested: (_) {},
      ),
    );

    await tester.enterText(find.byType(TextField), "Dolly in");
    await tester.pump();

    expect(changed, [("p1", "Dolly in")]);
  });

  testWidgets("Delete panel only asks: it reports the panel's id and nothing else", (
    tester,
  ) async {
    final deleteRequested = <String>[];

    await _pumpGroup(
      tester,
      OcptStoryboardPanelsGroup(
        panels: [_panel("p1")],
        commentValueOf: (_) => "",
        isReadOnly: false,
        onCommentChanged: (_, __) {},
        onReordered: (_, __) {},
        onDeleteRequested: deleteRequested.add,
        selectedPanelId: null,
        annotations: const [],
        selectedAnnotationId: null,
        activeAnnotationTool: null,
        onToolChanged: (_) {},
        annotationTextValueOf: (_) => "",
        onAnnotationSelected: (_) {},
        onAnnotationTextChanged: (_, __) {},
        onAnnotationDeleteRequested: (_) {},
      ),
    );

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();

    expect(deleteRequested, ["p1"]);
  });

  testWidgets(
    "the reorder affordance withholds the boundary moves: no move-up on the first panel, no "
    "move-down on the last",
    (tester) async {
      await _pumpGroup(
        tester,
        OcptStoryboardPanelsGroup(
          panels: [_panel("p1"), _panel("p2")],
          commentValueOf: (_) => "",
          isReadOnly: false,
          onCommentChanged: (_, __) {},
          onReordered: (_, __) {},
          onDeleteRequested: (_) {},
          selectedPanelId: null,
          annotations: const [],
          selectedAnnotationId: null,
          activeAnnotationTool: null,
          onToolChanged: (_) {},
          annotationTextValueOf: (_) => "",
          onAnnotationSelected: (_) {},
          onAnnotationTextChanged: (_, __) {},
          onAnnotationDeleteRequested: (_) {},
        ),
      );

      final upButtons = tester
          .widgetList<IconButton>(find.widgetWithIcon(IconButton, Icons.arrow_upward))
          .toList();
      final downButtons = tester
          .widgetList<IconButton>(find.widgetWithIcon(IconButton, Icons.arrow_downward))
          .toList();

      // First panel: no move-up. Second (last) panel: no move-down.
      expect(upButtons[0].onPressed, isNull);
      expect(upButtons[1].onPressed, isNotNull);
      expect(downButtons[0].onPressed, isNotNull);
      expect(downButtons[1].onPressed, isNull);
    },
  );

  testWidgets(
    "read-only withholds the comment field, the reorder affordance and Delete panel",
    (tester) async {
      await _pumpGroup(
        tester,
        OcptStoryboardPanelsGroup(
          panels: [_panel("p1")],
          commentValueOf: (_) => "Wide",
          isReadOnly: true,
          onCommentChanged: null,
          onReordered: null,
          onDeleteRequested: null,
          selectedPanelId: null,
          annotations: const [],
          selectedAnnotationId: null,
          activeAnnotationTool: null,
          onToolChanged: null,
          annotationTextValueOf: (_) => "",
          onAnnotationSelected: (_) {},
          onAnnotationTextChanged: null,
          onAnnotationDeleteRequested: null,
        ),
      );

      expect(tester.widget<TextField>(find.byType(TextField)).onChanged, isNull);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      final upButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.arrow_upward),
      );
      expect(upButton.onPressed, isNull);
      final downButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.arrow_downward),
      );
      expect(downButton.onPressed, isNull);
    },
  );

  testWidgets("no panel at all shows the 'no panel yet' hint", (tester) async {
    await _pumpGroup(
      tester,
      OcptStoryboardPanelsGroup(
        panels: const [],
        commentValueOf: (_) => "",
        isReadOnly: false,
        onCommentChanged: (_, __) {},
        onReordered: (_, __) {},
        onDeleteRequested: (_) {},
        selectedPanelId: null,
        annotations: const [],
        selectedAnnotationId: null,
        activeAnnotationTool: null,
        onToolChanged: (_) {},
        annotationTextValueOf: (_) => "",
        onAnnotationSelected: (_) {},
        onAnnotationTextChanged: (_, __) {},
        onAnnotationDeleteRequested: (_) {},
      ),
    );

    expect(find.text("no panel yet"), findsOneWidget);
  });

  group("the annotation section", () {
    testWidgets("shown only while a panel is selected", (tester) async {
      await _pumpGroup(
        tester,
        OcptStoryboardPanelsGroup(
          panels: [_panel("p1")],
          commentValueOf: (_) => "",
          isReadOnly: false,
          onCommentChanged: (_, __) {},
          onReordered: (_, __) {},
          onDeleteRequested: (_) {},
          selectedPanelId: null,
          annotations: const [],
          selectedAnnotationId: null,
          activeAnnotationTool: null,
          onToolChanged: (_) {},
          annotationTextValueOf: (_) => "",
          onAnnotationSelected: (_) {},
          onAnnotationTextChanged: (_, __) {},
          onAnnotationDeleteRequested: (_) {},
        ),
      );

      expect(find.byType(SegmentedButton<OcptStoryboardAnnotationTool>), findsNothing);
    });

    testWidgets("lists every mark with its kind and its text field", (tester) async {
      await _pumpGroup(
        tester,
        OcptStoryboardPanelsGroup(
          panels: [_panel("p1")],
          commentValueOf: (_) => "",
          isReadOnly: false,
          onCommentChanged: (_, __) {},
          onReordered: (_, __) {},
          onDeleteRequested: (_) {},
          selectedPanelId: "p1",
          annotations: [
            _annotation("a1", kind: OcptStoryboardAnnotationKind.movementArrow, text: "Walks in"),
            _annotation("a2", text: "Key light"),
          ],
          selectedAnnotationId: null,
          activeAnnotationTool: null,
          onToolChanged: (_) {},
          annotationTextValueOf: (id) => id == "a1" ? "Walks in" : "Key light",
          onAnnotationSelected: (_) {},
          onAnnotationTextChanged: (_, __) {},
          onAnnotationDeleteRequested: (_) {},
        ),
      );

      expect(find.byType(SegmentedButton<OcptStoryboardAnnotationTool>), findsOneWidget);
      // "Movement arrow" and "Label" each read twice: once as the Annotate control's own segment
      // label, once as the matching row's own kind label — the same wording on purpose, so a mark
      // reads as what its own tool would have drawn.
      expect(find.text("Movement arrow"), findsNWidgets(2));
      expect(find.text("Camera-move arrow"), findsOneWidget);
      expect(find.text("Label"), findsNWidgets(2));
      expect(find.text("Walks in"), findsOneWidget);
      expect(find.text("Key light"), findsOneWidget);
    });

    testWidgets("picking a tool reports it, and picking it again turns it off", (tester) async {
      final picked = <OcptStoryboardAnnotationTool?>[];
      OcptStoryboardAnnotationTool? activeTool;

      await _pumpGroup(
        tester,
        StatefulBuilder(
          builder: (context, setState) => OcptStoryboardPanelsGroup(
            panels: [_panel("p1")],
            commentValueOf: (_) => "",
            isReadOnly: false,
            onCommentChanged: (_, __) {},
            onReordered: (_, __) {},
            onDeleteRequested: (_) {},
            selectedPanelId: "p1",
            annotations: const [],
            selectedAnnotationId: null,
            activeAnnotationTool: activeTool,
            onToolChanged: (tool) => setState(() {
              picked.add(tool);
              activeTool = tool;
            }),
            annotationTextValueOf: (_) => "",
            onAnnotationSelected: (_) {},
            onAnnotationTextChanged: (_, __) {},
            onAnnotationDeleteRequested: (_) {},
          ),
        ),
      );

      await tester.tap(find.text("Movement arrow"));
      await tester.pump();
      expect(picked, [OcptStoryboardAnnotationTool.movementArrow]);

      // Picking the tool already on again turns it off.
      await tester.tap(find.text("Movement arrow"));
      await tester.pump();
      expect(picked, [OcptStoryboardAnnotationTool.movementArrow, null]);
    });

    testWidgets(
      "the currently active tool shows selected in the control",
      (tester) async {
        await _pumpGroup(
          tester,
          OcptStoryboardPanelsGroup(
            panels: [_panel("p1")],
            commentValueOf: (_) => "",
            isReadOnly: false,
            onCommentChanged: (_, __) {},
            onReordered: (_, __) {},
            onDeleteRequested: (_) {},
            selectedPanelId: "p1",
            annotations: const [],
            selectedAnnotationId: null,
            activeAnnotationTool: OcptStoryboardAnnotationTool.label,
            onToolChanged: (_) {},
            annotationTextValueOf: (_) => "",
            onAnnotationSelected: (_) {},
            onAnnotationTextChanged: (_, __) {},
            onAnnotationDeleteRequested: (_) {},
          ),
        );

        final segmentedButton = tester.widget<SegmentedButton<OcptStoryboardAnnotationTool>>(
          find.byType(SegmentedButton<OcptStoryboardAnnotationTool>),
        );
        expect(segmentedButton.selected, {OcptStoryboardAnnotationTool.label});
      },
    );

    testWidgets("typing into a mark's text field reports its id and the raw text", (
      tester,
    ) async {
      final changed = <(String, String)>[];

      await _pumpGroup(
        tester,
        OcptStoryboardPanelsGroup(
          panels: [_panel("p1")],
          commentValueOf: (_) => "",
          isReadOnly: false,
          onCommentChanged: (_, __) {},
          onReordered: (_, __) {},
          onDeleteRequested: (_) {},
          selectedPanelId: "p1",
          annotations: [_annotation("a1")],
          selectedAnnotationId: null,
          activeAnnotationTool: null,
          onToolChanged: (_) {},
          annotationTextValueOf: (_) => "",
          onAnnotationSelected: (_) {},
          onAnnotationTextChanged: (id, value) => changed.add((id, value)),
          onAnnotationDeleteRequested: (_) {},
        ),
      );

      // The panel's own comment field is the first `TextField` of the tree, the mark's own text
      // field the last — the annotation section is drawn after every panel row.
      await tester.enterText(find.byType(TextField).last, "Dolly in");
      await tester.pump();

      expect(changed, [("a1", "Dolly in")]);
    });

    testWidgets("tapping a mark's row reports its id, selecting it", (tester) async {
      final selected = <String>[];

      await _pumpGroup(
        tester,
        OcptStoryboardPanelsGroup(
          panels: [_panel("p1")],
          commentValueOf: (_) => "",
          isReadOnly: false,
          onCommentChanged: (_, __) {},
          onReordered: (_, __) {},
          onDeleteRequested: (_) {},
          selectedPanelId: "p1",
          annotations: [_annotation("a1", text: "Key light")],
          selectedAnnotationId: null,
          activeAnnotationTool: null,
          onToolChanged: (_) {},
          annotationTextValueOf: (_) => "Key light",
          onAnnotationSelected: selected.add,
          onAnnotationTextChanged: (_, __) {},
          onAnnotationDeleteRequested: (_) {},
        ),
      );

      // The row's own kind label, rather than its text field (tapping the field would only focus
      // it, never select the row) — `.last`, since the Annotate control's own "Label" segment
      // reads first in the tree, the row's matching kind label second.
      await tester.tap(find.text("Label").last);
      await tester.pump();

      expect(selected, ["a1"]);
    });

    testWidgets("Remove mark only asks: it reports the mark's id and nothing else", (
      tester,
    ) async {
      final deleteRequested = <String>[];

      await _pumpGroup(
        tester,
        OcptStoryboardPanelsGroup(
          panels: [_panel("p1")],
          commentValueOf: (_) => "",
          isReadOnly: false,
          onCommentChanged: (_, __) {},
          onReordered: (_, __) {},
          onDeleteRequested: (_) {},
          selectedPanelId: "p1",
          annotations: [_annotation("a1")],
          selectedAnnotationId: null,
          activeAnnotationTool: null,
          onToolChanged: (_) {},
          annotationTextValueOf: (_) => "",
          onAnnotationSelected: (_) {},
          onAnnotationTextChanged: (_, __) {},
          onAnnotationDeleteRequested: deleteRequested.add,
        ),
      );

      // The panel row carries its own `Delete panel` icon too — disambiguated by tooltip, since
      // both share the same `delete_outline` icon.
      await tester.tap(find.byTooltip("Remove mark"));
      await tester.pump();

      expect(deleteRequested, ["a1"]);
    });

    testWidgets("no mark at all shows the 'no marks yet' hint", (tester) async {
      await _pumpGroup(
        tester,
        OcptStoryboardPanelsGroup(
          panels: [_panel("p1")],
          commentValueOf: (_) => "",
          isReadOnly: false,
          onCommentChanged: (_, __) {},
          onReordered: (_, __) {},
          onDeleteRequested: (_) {},
          selectedPanelId: "p1",
          annotations: const [],
          selectedAnnotationId: null,
          activeAnnotationTool: null,
          onToolChanged: (_) {},
          annotationTextValueOf: (_) => "",
          onAnnotationSelected: (_) {},
          onAnnotationTextChanged: (_, __) {},
          onAnnotationDeleteRequested: (_) {},
        ),
      );

      expect(find.text("no marks yet"), findsOneWidget);
    });

    testWidgets(
      "read-only withholds the Annotate control, the mark's text field and its remove action, "
      "while the mark itself still lists",
      (tester) async {
        await _pumpGroup(
          tester,
          OcptStoryboardPanelsGroup(
            panels: [_panel("p1")],
            commentValueOf: (_) => "",
            isReadOnly: true,
            onCommentChanged: null,
            onReordered: null,
            onDeleteRequested: null,
            selectedPanelId: "p1",
            annotations: [_annotation("a1", text: "Key light")],
            selectedAnnotationId: null,
            activeAnnotationTool: null,
            onToolChanged: null,
            annotationTextValueOf: (_) => "Key light",
            onAnnotationSelected: (_) {},
            onAnnotationTextChanged: null,
            onAnnotationDeleteRequested: null,
          ),
        );

        expect(find.byType(SegmentedButton<OcptStoryboardAnnotationTool>), findsNothing);
        expect(find.text("Key light"), findsOneWidget);
        expect(find.byIcon(Icons.delete_outline), findsNothing);
        // Both the panel's own comment field and the mark's own text field are still drawn (a
        // read), neither writable.
        final textFields = tester.widgetList<TextField>(find.byType(TextField)).toList();
        expect(textFields, hasLength(2));
        expect(textFields.map((field) => field.onChanged), everyElement(isNull));
      },
    );
  });
}
