// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/constants/ocpt_breakdown_palette.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_scene.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_tag.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_target.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_scene_bars.dart';

/// Builds a tag pointing at [targetId] of [targetKind], the rest at neutral values.
OcptBreakdownTag _buildTag({
  required OcptBreakdownTargetKind targetKind,
  required String targetId,
}) => OcptBreakdownTag(
  id: "tag-$targetId",
  sceneId: "scene-1",
  targetKind: targetKind,
  targetId: targetId,
  startOffset: 0,
  endOffset: 1,
  taggedText: "x",
  needsCheck: false,
);

/// Builds an element target of [category].
OcptBreakdownTarget _buildElementTarget({required String id, required OcptElementCategory category}) =>
    OcptBreakdownTarget(
      kind: OcptBreakdownTargetKind.element,
      id: id,
      name: id,
      category: category,
      status: OcptElementStatus.toFind,
      sceneIds: const [],
      occurrenceCount: 1,
    );

/// Builds a role or a set target.
OcptBreakdownTarget _buildTarget({required OcptBreakdownTargetKind kind, required String id}) =>
    OcptBreakdownTarget(
      kind: kind,
      id: id,
      name: id,
      category: null,
      status: null,
      sceneIds: const [],
      occurrenceCount: 1,
    );

void main() {
  final propA = _buildElementTarget(id: "prop-a", category: OcptElementCategory.prop);
  final propB = _buildElementTarget(id: "prop-b", category: OcptElementCategory.prop);
  final costume = _buildElementTarget(id: "costume-a", category: OcptElementCategory.costume);
  final role = _buildTarget(kind: OcptBreakdownTargetKind.role, id: "role-a");
  final set = _buildTarget(kind: OcptBreakdownTargetKind.set, id: "set-a");

  final targetById = ocptBreakdownTargetsById([propA, propB, costume, role, set]);

  test("a scene with no tag resolves to no target and no bucket", () {
    const scene = OcptBreakdownScene(
      id: "scene-1",
      position: 0,
      heading: "INT. HOUSE - DAY",
      sceneNumber: null,
      charStart: 0,
      charEnd: 10,
      status: OcptBreakdownSceneStatus.toDo,
      notes: "",
      tags: [],
    );

    expect(ocptBreakdownSceneTargetsOf(scene, targetById), isEmpty);
    expect(ocptBreakdownSceneBarBucketsOf(scene, targetById), isEmpty);
  });

  test("two elements of the same category count as one bucket, sized by their count", () {
    final scene = OcptBreakdownScene(
      id: "scene-1",
      position: 0,
      heading: "INT. HOUSE - DAY",
      sceneNumber: null,
      charStart: 0,
      charEnd: 10,
      status: OcptBreakdownSceneStatus.toDo,
      notes: "",
      tags: [
        _buildTag(targetKind: OcptBreakdownTargetKind.element, targetId: "prop-a"),
        _buildTag(targetKind: OcptBreakdownTargetKind.element, targetId: "prop-b"),
      ],
    );

    final targets = ocptBreakdownSceneTargetsOf(scene, targetById);
    expect(targets, containsAll([propA, propB]));

    final buckets = ocptBreakdownSceneBarBucketsOf(scene, targetById);
    expect(buckets, hasLength(1));
    expect(buckets.single.kind, OcptBreakdownTargetKind.element);
    expect(buckets.single.category, OcptElementCategory.prop);
    expect(buckets.single.count, 2);
    expect(
      buckets.single.color,
      ocptBreakdownColorOf(kind: OcptBreakdownTargetKind.element, category: OcptElementCategory.prop),
    );
  });

  test("a tag repeated in the same scene still counts its target once", () {
    final scene = OcptBreakdownScene(
      id: "scene-1",
      position: 0,
      heading: "INT. HOUSE - DAY",
      sceneNumber: null,
      charStart: 0,
      charEnd: 10,
      status: OcptBreakdownSceneStatus.toDo,
      notes: "",
      tags: [
        _buildTag(targetKind: OcptBreakdownTargetKind.element, targetId: "prop-a"),
        const OcptBreakdownTag(
          id: "tag-prop-a-again",
          sceneId: "scene-1",
          targetKind: OcptBreakdownTargetKind.element,
          targetId: "prop-a",
          startOffset: 5,
          endOffset: 6,
          taggedText: "y",
          needsCheck: false,
        ),
      ],
    );

    expect(ocptBreakdownSceneTargetsOf(scene, targetById), [propA]);
    expect(ocptBreakdownSceneBarBucketsOf(scene, targetById).single.count, 1);
  });

  test("elements, roles and sets each get their own bucket, elements before roles before sets", () {
    final scene = OcptBreakdownScene(
      id: "scene-1",
      position: 0,
      heading: "INT. HOUSE - DAY",
      sceneNumber: null,
      charStart: 0,
      charEnd: 10,
      status: OcptBreakdownSceneStatus.toDo,
      notes: "",
      tags: [
        _buildTag(targetKind: OcptBreakdownTargetKind.set, targetId: "set-a"),
        _buildTag(targetKind: OcptBreakdownTargetKind.role, targetId: "role-a"),
        _buildTag(targetKind: OcptBreakdownTargetKind.element, targetId: "costume-a"),
      ],
    );

    final buckets = ocptBreakdownSceneBarBucketsOf(scene, targetById);
    expect(buckets.map((bucket) => bucket.kind).toList(), [
      OcptBreakdownTargetKind.element,
      OcptBreakdownTargetKind.role,
      OcptBreakdownTargetKind.set,
    ]);
    expect(buckets[1].color, ocptBreakdownRoleColor);
    expect(buckets[2].color, ocptBreakdownSetColor);
  });

  test("a tag whose target has since been dropped from the snapshot is skipped", () {
    final scene = OcptBreakdownScene(
      id: "scene-1",
      position: 0,
      heading: "INT. HOUSE - DAY",
      sceneNumber: null,
      charStart: 0,
      charEnd: 10,
      status: OcptBreakdownSceneStatus.toDo,
      notes: "",
      tags: [_buildTag(targetKind: OcptBreakdownTargetKind.element, targetId: "gone")],
    );

    expect(ocptBreakdownSceneTargetsOf(scene, targetById), isEmpty);
    expect(ocptBreakdownSceneBarBucketsOf(scene, targetById), isEmpty);
  });
}
