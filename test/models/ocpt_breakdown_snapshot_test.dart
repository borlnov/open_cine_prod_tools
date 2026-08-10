// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_scene.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_tag.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_set.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';

/// Builds a scene at [position] with the given [status], no tags of its own — the tests attach
/// tags through [OcptBreakdownSnapshot.build] itself.
OcptBreakdownScene _buildScene({
  required String id,
  required int position,
  OcptBreakdownSceneStatus status = OcptBreakdownSceneStatus.toDo,
  String notes = "",
}) => OcptBreakdownScene(
  id: id,
  position: position,
  heading: "INT. HOUSE - DAY",
  sceneNumber: null,
  charStart: 0,
  charEnd: 40,
  status: status,
  notes: notes,
  tags: const [],
  episodeNumber: null,
);

/// Builds a tag pointing scene [sceneId] at ([targetKind], [targetId]), everything else left at a
/// neutral value: these tests only read the scene/target/offset it carries.
OcptBreakdownTag _buildTag({
  required String id,
  required String sceneId,
  required OcptBreakdownTargetKind targetKind,
  required String targetId,
  int startOffset = 0,
  bool needsCheck = false,
}) => OcptBreakdownTag(
  id: id,
  sceneId: sceneId,
  targetKind: targetKind,
  targetId: targetId,
  startOffset: startOffset,
  endOffset: startOffset + 3,
  taggedText: "tag",
  needsCheck: needsCheck,
);

/// Builds an element named [name] of [category] and [status].
OcptElement _buildElement({
  required String id,
  required String name,
  OcptElementCategory category = OcptElementCategory.prop,
  OcptElementStatus status = OcptElementStatus.toFind,
}) => OcptElement(
  id: id,
  category: category,
  subCategory: "",
  name: name,
  code: "",
  quantity: "",
  sourceKind: OcptElementSourceKind.owned,
  status: status,
  ownerPersonId: null,
  ownerNotes: "",
  broughtByPersonId: null,
  storageNotes: "",
  isSecured: false,
  isReadyForShoot: false,
  isReturned: false,
  cost: null,
  purposeNotes: "",
  notes: "",
  photoAssetId: null,
  photo: null,
  sceneLinks: const [],
  roleLinks: const [],
);

/// Builds a role named [name].
OcptRole _buildRole({required String id, required String name}) => OcptRole(
  id: id,
  name: name,
  personId: null,
  kind: OcptRoleKind.speaking,
  isFromScreenplay: true,
  orphanedName: null,
  castingNotes: "",
  number: 1,
  episodeIds: const [],
);

/// Builds a set named [name].
OcptSet _buildSet({required String id, required String name}) =>
    OcptSet(id: id, locationId: "location", code: "", name: name, notes: "", sceneIds: const []);

void main() {
  group("OcptBreakdownSnapshot.build", () {
    test("counts a target tagged twice in one scene as one target, two occurrences", () {
      final scene = _buildScene(id: "scene-1", position: 0);
      final element = _buildElement(id: "element-1", name: "Desk lamp");

      final snapshot = OcptBreakdownSnapshot.build(
        screenplayId: "screenplay",
        scenes: [scene],
        tags: [
          _buildTag(
            id: "tag-1",
            sceneId: "scene-1",
            targetKind: OcptBreakdownTargetKind.element,
            targetId: "element-1",
          ),
          _buildTag(
            id: "tag-2",
            sceneId: "scene-1",
            targetKind: OcptBreakdownTargetKind.element,
            targetId: "element-1",
            startOffset: 10,
          ),
        ],
        elements: [element],
        roles: const [],
        sets: const [],
        locations: const [],
        people: const [],
      );

      expect(snapshot.targets, hasLength(1));
      expect(snapshot.targets.single.occurrenceCount, 2);
      expect(snapshot.targets.single.sceneIds, ["scene-1"]);
      expect(snapshot.taggedTargetCount, 1);
    });

    test("a role and a set never count toward toFindCount, whatever their status", () {
      final scene = _buildScene(id: "scene-1", position: 0);
      final role = _buildRole(id: "role-1", name: "LÉA");
      final set = _buildSet(id: "set-1", name: "Kitchen");
      final elementToFind = _buildElement(id: "element-1", name: "Desk lamp");
      final elementConfirmed = _buildElement(
        id: "element-2",
        name: "Vintage car",
        category: OcptElementCategory.vehicle,
        status: OcptElementStatus.confirmed,
      );

      final snapshot = OcptBreakdownSnapshot.build(
        screenplayId: "screenplay",
        scenes: [scene],
        tags: [
          _buildTag(
            id: "tag-role",
            sceneId: "scene-1",
            targetKind: OcptBreakdownTargetKind.role,
            targetId: "role-1",
          ),
          _buildTag(
            id: "tag-set",
            sceneId: "scene-1",
            targetKind: OcptBreakdownTargetKind.set,
            targetId: "set-1",
            startOffset: 5,
          ),
          _buildTag(
            id: "tag-element-1",
            sceneId: "scene-1",
            targetKind: OcptBreakdownTargetKind.element,
            targetId: "element-1",
            startOffset: 10,
          ),
          _buildTag(
            id: "tag-element-2",
            sceneId: "scene-1",
            targetKind: OcptBreakdownTargetKind.element,
            targetId: "element-2",
            startOffset: 15,
          ),
        ],
        elements: [elementToFind, elementConfirmed],
        roles: [role],
        sets: [set],
        locations: const [],
        people: const [],
      );

      expect(snapshot.taggedTargetCount, 4);
      expect(snapshot.toFindCount, 1);
      // Role, set, prop, vehicle: four distinct palette entries.
      expect(snapshot.usedCategoryCount, 4);
    });

    test("usedCategoryCount counts a palette entry once however many targets share it", () {
      final scene = _buildScene(id: "scene-1", position: 0);
      final propOne = _buildElement(id: "element-1", name: "Desk lamp");
      final propTwo = _buildElement(id: "element-2", name: "Ashtray");

      final snapshot = OcptBreakdownSnapshot.build(
        screenplayId: "screenplay",
        scenes: [scene],
        tags: [
          _buildTag(
            id: "tag-1",
            sceneId: "scene-1",
            targetKind: OcptBreakdownTargetKind.element,
            targetId: "element-1",
          ),
          _buildTag(
            id: "tag-2",
            sceneId: "scene-1",
            targetKind: OcptBreakdownTargetKind.element,
            targetId: "element-2",
            startOffset: 10,
          ),
        ],
        elements: [propOne, propTwo],
        roles: const [],
        sets: const [],
        locations: const [],
        people: const [],
      );

      expect(snapshot.taggedTargetCount, 2);
      expect(snapshot.usedCategoryCount, 1);
    });

    test("drops a target whose catalogue row is gone, but keeps its tag on the scene", () {
      final scene = _buildScene(id: "scene-1", position: 0);

      final snapshot = OcptBreakdownSnapshot.build(
        screenplayId: "screenplay",
        scenes: [scene],
        tags: [
          _buildTag(
            id: "tag-1",
            sceneId: "scene-1",
            targetKind: OcptBreakdownTargetKind.element,
            targetId: "element-gone",
          ),
        ],
        elements: const [],
        roles: const [],
        sets: const [],
        locations: const [],
        people: const [],
      );

      expect(snapshot.targets, isEmpty);
      expect(snapshot.taggedTargetCount, 0);
      expect(snapshot.scenes.single.tags.map((tag) => tag.id), ["tag-1"]);
    });

    test("orders scenes as passed and targets by kind then name", () {
      final sceneA = _buildScene(id: "scene-1", position: 0);
      final sceneB = _buildScene(id: "scene-2", position: 1);
      final roleZoe = _buildRole(id: "role-1", name: "ZOE");
      final roleAlex = _buildRole(id: "role-2", name: "ALEX");
      final elementZip = _buildElement(id: "element-1", name: "Zip lighter");
      final elementAsh = _buildElement(id: "element-2", name: "Ashtray");

      final snapshot = OcptBreakdownSnapshot.build(
        screenplayId: "screenplay",
        scenes: [sceneA, sceneB],
        tags: [
          _buildTag(
            id: "tag-role-zoe",
            sceneId: "scene-1",
            targetKind: OcptBreakdownTargetKind.role,
            targetId: "role-1",
          ),
          _buildTag(
            id: "tag-role-alex",
            sceneId: "scene-1",
            targetKind: OcptBreakdownTargetKind.role,
            targetId: "role-2",
            startOffset: 5,
          ),
          _buildTag(
            id: "tag-element-zip",
            sceneId: "scene-1",
            targetKind: OcptBreakdownTargetKind.element,
            targetId: "element-1",
            startOffset: 10,
          ),
          _buildTag(
            id: "tag-element-ash",
            sceneId: "scene-1",
            targetKind: OcptBreakdownTargetKind.element,
            targetId: "element-2",
            startOffset: 15,
          ),
        ],
        elements: [elementZip, elementAsh],
        roles: [roleZoe, roleAlex],
        sets: const [],
        locations: const [],
        people: const [],
      );

      expect(snapshot.scenes.map((scene) => scene.id), ["scene-1", "scene-2"]);
      // Element kind sorts before role (declaration order), each group alphabetised by name.
      expect(snapshot.targets.map((target) => target.name), [
        "Ashtray",
        "Zip lighter",
        "ALEX",
        "ZOE",
      ]);
    });

    test("a scene with no scene_breakdowns row reads as toDo with empty notes", () {
      final scene = _buildScene(id: "scene-1", position: 0);

      final snapshot = OcptBreakdownSnapshot.build(
        screenplayId: "screenplay",
        scenes: [scene],
        tags: const [],
        elements: const [],
        roles: const [],
        sets: const [],
        locations: const [],
        people: const [],
      );

      expect(snapshot.scenes.single.status, OcptBreakdownSceneStatus.toDo);
      expect(snapshot.scenes.single.notes, "");
    });

    test("doneSceneCount counts only scenes marked done", () {
      final sceneDone = _buildScene(
        id: "scene-1",
        position: 0,
        status: OcptBreakdownSceneStatus.done,
      );
      final sceneInProgress = _buildScene(
        id: "scene-2",
        position: 1,
        status: OcptBreakdownSceneStatus.inProgress,
      );
      final sceneToDo = _buildScene(id: "scene-3", position: 2);

      final snapshot = OcptBreakdownSnapshot.build(
        screenplayId: "screenplay",
        scenes: [sceneDone, sceneInProgress, sceneToDo],
        tags: const [],
        elements: const [],
        roles: const [],
        sets: const [],
        locations: const [],
        people: const [],
      );

      expect(snapshot.doneSceneCount, 1);
    });

    test("needsCheckTagCount counts every live flagged tag, target gone or not", () {
      final scene = _buildScene(id: "scene-1", position: 0);
      final element = _buildElement(id: "element-1", name: "Desk lamp");

      final snapshot = OcptBreakdownSnapshot.build(
        screenplayId: "screenplay",
        scenes: [scene],
        tags: [
          _buildTag(
            id: "tag-flagged",
            sceneId: "scene-1",
            targetKind: OcptBreakdownTargetKind.element,
            targetId: "element-1",
            needsCheck: true,
          ),
          _buildTag(
            id: "tag-flagged-gone",
            sceneId: "scene-1",
            targetKind: OcptBreakdownTargetKind.element,
            targetId: "element-gone",
            startOffset: 10,
            needsCheck: true,
          ),
          _buildTag(
            id: "tag-fine",
            sceneId: "scene-1",
            targetKind: OcptBreakdownTargetKind.element,
            targetId: "element-1",
            startOffset: 20,
          ),
        ],
        elements: [element],
        roles: const [],
        sets: const [],
        locations: const [],
        people: const [],
      );

      // Both flagged tags count, including the one whose target has been dropped from `targets`.
      expect(snapshot.needsCheckTagCount, 2);
      expect(snapshot.targets, hasLength(1));
    });
  });
}
