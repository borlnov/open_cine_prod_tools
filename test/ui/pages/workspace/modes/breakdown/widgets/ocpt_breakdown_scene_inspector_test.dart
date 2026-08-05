// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_scene.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_tag.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_target.dart';
import 'package:open_cine_prod_tools/models/ocpt_set.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_scene_inspector.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_scene_bars.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve.
Widget _wrapInApp(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 320, height: 900, child: child)),
);

/// Builds a scene at [position] carrying [tags] and [status], everything else neutral.
OcptBreakdownScene _buildScene({
  required String id,
  int position = 0,
  String heading = "INT. HOUSE - DAY",
  String? sceneNumber,
  OcptBreakdownSceneStatus status = OcptBreakdownSceneStatus.toDo,
  List<OcptBreakdownTag> tags = const [],
}) => OcptBreakdownScene(
  id: id,
  position: position,
  heading: heading,
  sceneNumber: sceneNumber,
  charStart: 0,
  charEnd: 40,
  status: status,
  notes: "",
  tags: tags,
);

/// Builds a set of location `location-1`, shot in [sceneIds].
OcptSet _buildSet({
  required String id,
  required String name,
  String locationId = "location-1",
  List<String> sceneIds = const [],
}) => OcptSet(
  id: id,
  locationId: locationId,
  code: "",
  name: name,
  notes: "",
  sceneIds: sceneIds,
);

/// Builds a live tag of [taggedText] pointing at [targetKind]/[targetId].
OcptBreakdownTag _buildTag({
  required String id,
  required String sceneId,
  required OcptBreakdownTargetKind targetKind,
  required String targetId,
  String taggedText = "a lamp",
  bool needsCheck = false,
}) => OcptBreakdownTag(
  id: id,
  sceneId: sceneId,
  targetKind: targetKind,
  targetId: targetId,
  startOffset: 0,
  endOffset: taggedText.length,
  taggedText: taggedText,
  needsCheck: needsCheck,
);

/// Builds an element target of [category]/[status].
OcptBreakdownTarget _buildElementTarget({
  required String id,
  required String name,
  OcptElementCategory category = OcptElementCategory.prop,
  OcptElementStatus status = OcptElementStatus.toFind,
}) => OcptBreakdownTarget(
  kind: OcptBreakdownTargetKind.element,
  id: id,
  name: name,
  category: category,
  status: status,
  sceneIds: const ["scene-1"],
  occurrenceCount: 1,
);

void main() {
  testWidgets("shows the mode's own empty message while nothing is selected", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        const OcptBreakdownSceneInspector(
          scene: null,
          targetById: {},
          sets: [],
          locationNameById: {},
          suggestedSetId: null,
          onSetLinked: null,
          onSetUnlinked: null,
          locations: [],
          newSetName: "",
          onSetCreationRequested: null,
          notesValue: "",
          onTargetSelected: _noop3,
          onStatusChanged: null,
          onNotesChanged: null,
          onTagNeedsCheckCleared: null,
          onFlaggedTagRemoved: null,
        ),
      ),
    );

    expect(find.text("Select a scene or a tagged word to see its sheet."), findsOneWidget);
  });

  testWidgets("shows the dashed hint while the selected scene has no live tag", (tester) async {
    final scene = _buildScene(id: "scene-1", sceneNumber: "4");

    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownSceneInspector(
          scene: scene,
          targetById: const {},
          sets: const [],
          locationNameById: const {},
          suggestedSetId: null,
          onSetLinked: null,
          onSetUnlinked: null,
          locations: const [],
          newSetName: "",
          onSetCreationRequested: null,
          notesValue: "",
          onTargetSelected: _noop3,
          onStatusChanged: (_) {},
          onNotesChanged: (_) {},
          onTagNeedsCheckCleared: (_) {},
          onFlaggedTagRemoved: (_) {},
        ),
      ),
    );

    expect(find.text("Scene 4"), findsOneWidget);
    expect(
      find.text(
        "Nothing tagged for this scene yet. Click a word or a passage in the script to break it down.",
      ),
      findsOneWidget,
    );
  });

  testWidgets("shows the tagged/to-find counts and the warning callout", (tester) async {
    final target = _buildElementTarget(id: "element-1", name: "Desk lamp");
    final scene = _buildScene(
      id: "scene-1",
      status: OcptBreakdownSceneStatus.inProgress,
      tags: [
        _buildTag(
          id: "tag-1",
          sceneId: "scene-1",
          targetKind: OcptBreakdownTargetKind.element,
          targetId: "element-1",
        ),
      ],
    );
    final targetById = ocptBreakdownTargetsById([target]);

    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownSceneInspector(
          scene: scene,
          targetById: targetById,
          sets: const [],
          locationNameById: const {},
          suggestedSetId: null,
          onSetLinked: null,
          onSetUnlinked: null,
          locations: const [],
          newSetName: "",
          onSetCreationRequested: null,
          notesValue: "",
          onTargetSelected: _noop3,
          onStatusChanged: (_) {},
          onNotesChanged: (_) {},
          onTagNeedsCheckCleared: (_) {},
          onFlaggedTagRemoved: (_) {},
        ),
      ),
    );

    expect(find.text("TAGGED"), findsOneWidget);
    expect(find.text("1"), findsWidgets); // the tagged tile's own count, among others
    expect(find.text("1 element still to find"), findsOneWidget);
    expect(find.text("Desk lamp"), findsWidgets);
  });

  testWidgets("clicking a target row reports it, together with the scene's own id", (tester) async {
    final reported = <(OcptBreakdownTargetKind, String, String)>[];
    final target = _buildElementTarget(id: "element-1", name: "Desk lamp");
    final scene = _buildScene(
      id: "scene-1",
      tags: [
        _buildTag(
          id: "tag-1",
          sceneId: "scene-1",
          targetKind: OcptBreakdownTargetKind.element,
          targetId: "element-1",
        ),
      ],
    );
    final targetById = ocptBreakdownTargetsById([target]);

    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownSceneInspector(
          scene: scene,
          targetById: targetById,
          sets: const [],
          locationNameById: const {},
          suggestedSetId: null,
          onSetLinked: null,
          onSetUnlinked: null,
          locations: const [],
          newSetName: "",
          onSetCreationRequested: null,
          notesValue: "",
          onTargetSelected: (kind, id, sceneId) => reported.add((kind, id, sceneId)),
          onStatusChanged: (_) {},
          onNotesChanged: (_) {},
          onTagNeedsCheckCleared: (_) {},
          onFlaggedTagRemoved: (_) {},
        ),
      ),
    );

    await tester.tap(find.text("Desk lamp").last);
    await tester.pump();

    expect(reported, [(OcptBreakdownTargetKind.element, "element-1", "scene-1")]);
  });

  testWidgets("the status chips show the scene's own status and report a pick", (tester) async {
    final reported = <OcptBreakdownSceneStatus>[];
    final scene = _buildScene(id: "scene-1", status: OcptBreakdownSceneStatus.inProgress);

    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownSceneInspector(
          scene: scene,
          targetById: const {},
          sets: const [],
          locationNameById: const {},
          suggestedSetId: null,
          onSetLinked: null,
          onSetUnlinked: null,
          locations: const [],
          newSetName: "",
          onSetCreationRequested: null,
          notesValue: "",
          onTargetSelected: _noop3,
          onStatusChanged: reported.add,
          onNotesChanged: (_) {},
          onTagNeedsCheckCleared: (_) {},
          onFlaggedTagRemoved: (_) {},
        ),
      ),
    );

    expect(find.text("In progress"), findsOneWidget);

    await tester.tap(find.text("Done"));
    await tester.pump();

    expect(reported, [OcptBreakdownSceneStatus.done]);
  });

  testWidgets("the notes field shows its value and reports typing", (tester) async {
    final reported = <String>[];
    final scene = _buildScene(id: "scene-1");

    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownSceneInspector(
          scene: scene,
          targetById: const {},
          sets: const [],
          locationNameById: const {},
          suggestedSetId: null,
          onSetLinked: null,
          onSetUnlinked: null,
          locations: const [],
          newSetName: "",
          onSetCreationRequested: null,
          notesValue: "Fragile prop",
          onTargetSelected: _noop3,
          onStatusChanged: (_) {},
          onNotesChanged: reported.add,
          onTagNeedsCheckCleared: (_) {},
          onFlaggedTagRemoved: (_) {},
        ),
      ),
    );

    expect(find.text("Fragile prop"), findsOneWidget);

    await tester.enterText(find.text("Fragile prop"), "Fragile prop, handle with care");
    await tester.pump();

    expect(reported, ["Fragile prop, handle with care"]);
  });

  testWidgets("isReadOnly withholds the status chips and the notes field while the sheet reads",
      (tester) async {
    final statusReported = <OcptBreakdownSceneStatus>[];
    final notesReported = <String>[];
    final scene = _buildScene(id: "scene-1", status: OcptBreakdownSceneStatus.inProgress);

    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownSceneInspector(
          scene: scene,
          targetById: const {},
          sets: const [],
          locationNameById: const {},
          suggestedSetId: null,
          onSetLinked: null,
          onSetUnlinked: null,
          locations: const [],
          newSetName: "",
          onSetCreationRequested: null,
          notesValue: "Fragile prop",
          onTargetSelected: _noop3,
          onStatusChanged: statusReported.add,
          onNotesChanged: notesReported.add,
          onTagNeedsCheckCleared: (_) {},
          onFlaggedTagRemoved: (_) {},
          isReadOnly: true,
        ),
      ),
    );

    // Both are still readable…
    expect(find.text("In progress"), findsOneWidget);
    expect(find.text("Fragile prop"), findsOneWidget);

    // …but neither writes: the status chip reports nothing, and the notes field refuses typing.
    await tester.tap(find.text("Done"));
    await tester.pump();
    expect(statusReported, isEmpty);

    final fieldWidget = tester.widget<TextField>(find.byType(TextField));
    expect(fieldWidget.onChanged, isNull);
    expect(notesReported, isEmpty);
  });

  testWidgets(
    "the to-check alert lists a flagged tag and reports its two actions",
    (tester) async {
      final clearedTagIds = <String>[];
      final removedTagIds = <String>[];
      final target = _buildElementTarget(id: "element-1", name: "Desk lamp");
      final scene = _buildScene(
        id: "scene-1",
        tags: [
          _buildTag(
            id: "tag-1",
            sceneId: "scene-1",
            targetKind: OcptBreakdownTargetKind.element,
            targetId: "element-1",
            needsCheck: true,
          ),
        ],
      );
      final targetById = ocptBreakdownTargetsById([target]);

      await tester.pumpWidget(
        _wrapInApp(
          OcptBreakdownSceneInspector(
            scene: scene,
            targetById: targetById,
            sets: const [],
            locationNameById: const {},
            suggestedSetId: null,
            onSetLinked: null,
            onSetUnlinked: null,
            locations: const [],
            newSetName: "",
            onSetCreationRequested: null,
            notesValue: "",
            onTargetSelected: _noop3,
            onStatusChanged: (_) {},
            onNotesChanged: (_) {},
            onTagNeedsCheckCleared: clearedTagIds.add,
            onFlaggedTagRemoved: removedTagIds.add,
          ),
        ),
      );

      expect(find.text("1 tag to check"), findsOneWidget);
      expect(find.text('"a lamp" · Desk lamp'), findsOneWidget);

      await tester.tap(find.text("Mark as checked"));
      await tester.pump();
      expect(clearedTagIds, ["tag-1"]);

      await tester.tap(find.text("Remove"));
      await tester.pump();
      expect(removedTagIds, ["tag-1"]);
    },
  );

  testWidgets(
    "a flagged tag whose target is gone is still listed, by its passage alone",
    (tester) async {
      final scene = _buildScene(
        id: "scene-1",
        tags: [
          _buildTag(
            id: "tag-1",
            sceneId: "scene-1",
            targetKind: OcptBreakdownTargetKind.element,
            targetId: "element-gone",
            needsCheck: true,
          ),
        ],
      );

      await tester.pumpWidget(
        _wrapInApp(
          OcptBreakdownSceneInspector(
            scene: scene,
            targetById: const {},
            sets: const [],
            locationNameById: const {},
            suggestedSetId: null,
            onSetLinked: null,
            onSetUnlinked: null,
            locations: const [],
            newSetName: "",
            onSetCreationRequested: null,
            notesValue: "",
            onTargetSelected: _noop3,
            onStatusChanged: (_) {},
            onNotesChanged: (_) {},
            onTagNeedsCheckCleared: (_) {},
            onFlaggedTagRemoved: (_) {},
          ),
        ),
      );

      expect(find.text("1 tag to check"), findsOneWidget);
      expect(find.text('"a lamp"'), findsOneWidget);
    },
  );

  testWidgets("isReadOnly withholds the to-check alert's two actions", (tester) async {
    final clearedTagIds = <String>[];
    final removedTagIds = <String>[];
    final target = _buildElementTarget(id: "element-1", name: "Desk lamp");
    final scene = _buildScene(
      id: "scene-1",
      tags: [
        _buildTag(
          id: "tag-1",
          sceneId: "scene-1",
          targetKind: OcptBreakdownTargetKind.element,
          targetId: "element-1",
          needsCheck: true,
        ),
      ],
    );
    final targetById = ocptBreakdownTargetsById([target]);

    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownSceneInspector(
          scene: scene,
          targetById: targetById,
          sets: const [],
          locationNameById: const {},
          suggestedSetId: null,
          onSetLinked: null,
          onSetUnlinked: null,
          locations: const [],
          newSetName: "",
          onSetCreationRequested: null,
          notesValue: "",
          onTargetSelected: _noop3,
          onStatusChanged: (_) {},
          onNotesChanged: (_) {},
          onTagNeedsCheckCleared: clearedTagIds.add,
          onFlaggedTagRemoved: removedTagIds.add,
          isReadOnly: true,
        ),
      ),
    );

    // The alert still reads…
    expect(find.text("1 tag to check"), findsOneWidget);
    expect(find.text('"a lamp" · Desk lamp'), findsOneWidget);

    // …but neither of its actions writes.
    final clearButton = tester.widget<TextButton>(find.widgetWithText(TextButton, "Mark as checked"));
    expect(clearButton.onPressed, isNull);
    final removeButton = tester.widget<TextButton>(find.widgetWithText(TextButton, "Remove"));
    expect(removeButton.onPressed, isNull);
  });

  testWidgets("names the sets the scene is shot in, and offers the rest", (tester) async {
    final linkedSetIds = <String>[];
    final unlinkedSetIds = <String>[];

    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownSceneInspector(
          scene: _buildScene(id: "scene-1"),
          targetById: const {},
          sets: [
            _buildSet(id: "set-kitchen", name: "Cuisine", sceneIds: const ["scene-1"]),
            _buildSet(id: "set-garden", name: "Jardin"),
          ],
          locationNameById: const {"location-1": "Maison des Martin"},
          suggestedSetId: "set-garden",
          onSetLinked: linkedSetIds.add,
          onSetUnlinked: unlinkedSetIds.add,
          locations: const [],
          newSetName: "",
          onSetCreationRequested: null,
          notesValue: "",
          onTargetSelected: _noop3,
          onStatusChanged: (_) {},
          onNotesChanged: (_) {},
          onTagNeedsCheckCleared: (_) {},
          onFlaggedTagRemoved: (_) {},
        ),
      ),
    );

    // The set the scene is shot in is a chip, named with the location holding it; the other one is
    // only in the picker, marked there as this heading's own suggestion.
    expect(find.text("Cuisine · Maison des Martin"), findsOneWidget);
    expect(find.text("Jardin · Maison des Martin"), findsNothing);

    await tester.tap(find.text("Set"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Jardin · Maison des Martin — suggested"));
    await tester.pumpAndSettle();

    expect(linkedSetIds, ["set-garden"]);
    expect(unlinkedSetIds, isEmpty);
  });

  testWidgets("a read-only sheet names its sets but offers no picker and no dismissal", (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownSceneInspector(
          scene: _buildScene(id: "scene-1"),
          targetById: const {},
          sets: [_buildSet(id: "set-kitchen", name: "Cuisine", sceneIds: const ["scene-1"])],
          locationNameById: const {"location-1": "Maison des Martin"},
          suggestedSetId: null,
          onSetLinked: null,
          onSetUnlinked: null,
          locations: const [],
          newSetName: "",
          onSetCreationRequested: null,
          notesValue: "",
          onTargetSelected: _noop3,
          onStatusChanged: null,
          onNotesChanged: null,
          onTagNeedsCheckCleared: null,
          onFlaggedTagRemoved: null,
          isReadOnly: true,
        ),
      ),
    );

    expect(find.text("Cuisine · Maison des Martin"), findsOneWidget);
    expect(find.text("Set"), findsNothing);
    expect(find.text("Create a set…"), findsNothing);
  });

  testWidgets("creates a set named after the heading, in the location picked", (tester) async {
    final creationLocationIds = <String?>[];

    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownSceneInspector(
          scene: _buildScene(id: "scene-1"),
          targetById: const {},
          sets: const [],
          locationNameById: const {},
          suggestedSetId: null,
          onSetLinked: (_) {},
          onSetUnlinked: (_) {},
          locations: const [("location-1", "Maison des Martin")],
          newSetName: "CUISINE",
          onSetCreationRequested: creationLocationIds.add,
          notesValue: "",
          onTargetSelected: _noop3,
          onStatusChanged: (_) {},
          onNotesChanged: (_) {},
          onTagNeedsCheckCleared: (_) {},
          onFlaggedTagRemoved: (_) {},
        ),
      ),
    );

    // The project holds no set at all, so there is nothing to pick — only something to create.
    expect(find.text("Set"), findsNothing);

    await tester.tap(find.text("Create a set…"));
    await tester.pumpAndSettle();

    // The menu says what it is about to create before it asks where.
    expect(find.text('Create "CUISINE" in…'), findsOneWidget);

    await tester.tap(find.text("In Maison des Martin"));
    await tester.pumpAndSettle();

    expect(creationLocationIds, ["location-1"]);

    // And the entry minting a location to hold it reports null rather than an id.
    await tester.tap(find.text("Create a set…"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("In a new location"));
    await tester.pumpAndSettle();

    expect(creationLocationIds, ["location-1", null]);
  });
}

/// A no-op `onTargetSelected` for tests that never click a row.
void _noop3(OcptBreakdownTargetKind kind, String id, String sceneId) {}
