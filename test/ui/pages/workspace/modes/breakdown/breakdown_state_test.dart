// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_scene.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_tag.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_state.dart';

/// The first scene's own text, tagged in the state every test here builds.
const _sceneAText = "A desk lamp glows softly.\n";

/// The second scene's own text, holding an untagged occurrence of the first scene's tag.
const _sceneBText = "He switches the desk lamp on.\n";

/// The whole screenplay both scenes are sliced out of.
const _screenplayText = "$_sceneAText$_sceneBText";

/// The id of the element both the tag and its suggestion point at.
const _elementId = "element-lamp";

/// Builds the snapshot every test here starts from: two scenes, the first carrying one tag on
/// `desk lamp`, the second holding the same words untagged — exactly one suggestion to find.
OcptBreakdownSnapshot _snapshot() {
  const taggedStart = 2;
  const taggedEnd = taggedStart + "desk lamp".length;

  return OcptBreakdownSnapshot.build(
    screenplayId: "screenplay",
    scenes: [
      const OcptBreakdownScene(
        id: "scene-a",
        position: 0,
        heading: "INT. BEDROOM - NIGHT",
        sceneNumber: null,
        charStart: 0,
        charEnd: _sceneAText.length,
        status: OcptBreakdownSceneStatus.toDo,
        notes: "",
        tags: [],
      ),
      const OcptBreakdownScene(
        id: "scene-b",
        position: 1,
        heading: "INT. OFFICE - NIGHT",
        sceneNumber: null,
        charStart: _sceneAText.length,
        charEnd: _screenplayText.length,
        status: OcptBreakdownSceneStatus.toDo,
        notes: "",
        tags: [],
      ),
    ],
    tags: const [
      OcptBreakdownTag(
        id: "tag-a",
        sceneId: "scene-a",
        targetKind: OcptBreakdownTargetKind.element,
        targetId: _elementId,
        startOffset: taggedStart,
        endOffset: taggedEnd,
        taggedText: "desk lamp",
        needsCheck: false,
      ),
    ],
    elements: [
      const OcptElement(
        id: _elementId,
        code: "PR-01",
        name: "Desk lamp",
        category: OcptElementCategory.prop,
        subCategory: "",
        sourceKind: OcptElementSourceKind.owned,
        status: OcptElementStatus.toFind,
        quantity: "",
        ownerPersonId: null,
        ownerNotes: "",
        broughtByPersonId: null,
        isSecured: false,
        isReadyForShoot: false,
        isReturned: false,
        storageNotes: "",
        cost: null,
        purposeNotes: "",
        notes: "",
        photoAssetId: null,
        sceneLinks: [],
      ),
    ],
    roles: const [],
    sets: const [],
    people: const [],
  );
}

/// The state every test here starts from: the snapshot above, its screenplay text, and the tagged
/// element selected — so there is exactly one suggestion to carry over or recompute.
OcptBreakdownState _loadedState() => OcptBreakdownState.init().copyWith(
  snapshot: _snapshot(),
  screenplayText: _screenplayText,
  selectedTargetRef: (OcptBreakdownTargetKind.element, _elementId),
);

void main() {
  group("OcptBreakdownState.selectedTargetSuggestions", () {
    test("is empty while no target is selected", () {
      final state = OcptBreakdownState.init().copyWith(
        snapshot: _snapshot(),
        screenplayText: _screenplayText,
      );

      expect(state.selectedTargetSuggestions, isEmpty);
    });

    test("holds the selected target's own untagged occurrences", () {
      final state = _loadedState();

      expect(state.selectedTargetSuggestions, hasLength(1));
      expect(state.selectedTargetSuggestions.single.sceneId, "scene-b");
      expect(state.selectedTargetSuggestions.single.targetId, _elementId);
      expect(state.selectedTargetSuggestions.single.text, "desk lamp");
    });

    test("is carried over, list instance included, when nothing it derives from changes", () {
      final state = _loadedState();

      final next = state.copyWith(searchQuery: "lamp", isListPanelVisible: false);

      expect(
        identical(next.selectedTargetSuggestions, state.selectedTargetSuggestions),
        isTrue,
        reason: "an edit touching neither the snapshot, the text nor the selection must not pay "
            "the cost of folding the screenplay again",
      );
    });

    test("is recomputed when the snapshot is reloaded, even into an equal one", () {
      final state = _loadedState();

      final next = state.copyWith(snapshot: _snapshot());

      expect(next.selectedTargetSuggestions, state.selectedTargetSuggestions);
      expect(identical(next.selectedTargetSuggestions, state.selectedTargetSuggestions), isFalse);
    });

    test("is recomputed when the selected target changes", () {
      final state = _loadedState();

      final next = state.copyWith(clearSelectedTargetRef: true);

      expect(next.selectedTargetSuggestions, isEmpty);
    });
  });
}
