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

/// Builds a live tag of [taggedText] pointing at [targetKind]/[targetId].
OcptBreakdownTag _buildTag({
  required String id,
  required String sceneId,
  required OcptBreakdownTargetKind targetKind,
  required String targetId,
  String taggedText = "a lamp",
}) => OcptBreakdownTag(
  id: id,
  sceneId: sceneId,
  targetKind: targetKind,
  targetId: targetId,
  startOffset: 0,
  endOffset: taggedText.length,
  taggedText: taggedText,
  needsCheck: false,
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
        const OcptBreakdownSceneInspector(scene: null, targetById: {}, onTargetSelected: _noop3),
      ),
    );

    expect(find.text("Select a scene or a tagged word to see its sheet."), findsOneWidget);
  });

  testWidgets("shows the dashed hint while the selected scene has no live tag", (tester) async {
    final scene = _buildScene(id: "scene-1", sceneNumber: "4");

    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownSceneInspector(scene: scene, targetById: const {}, onTargetSelected: _noop3),
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

  testWidgets("shows the tagged/to-find counts, the status tile and the warning callout",
      (tester) async {
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
        OcptBreakdownSceneInspector(scene: scene, targetById: targetById, onTargetSelected: _noop3),
      ),
    );

    expect(find.text("TAGGED"), findsOneWidget);
    expect(find.text("1"), findsWidgets); // the tagged tile's own count, among others
    expect(find.text("In progress"), findsOneWidget); // the status tile's own value
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
          onTargetSelected: (kind, id, sceneId) => reported.add((kind, id, sceneId)),
        ),
      ),
    );

    await tester.tap(find.text("Desk lamp").last);
    await tester.pump();

    expect(reported, [(OcptBreakdownTargetKind.element, "element-1", "scene-1")]);
  });
}

/// A no-op `onTargetSelected` for tests that never click a row.
void _noop3(OcptBreakdownTargetKind kind, String id, String sceneId) {}
