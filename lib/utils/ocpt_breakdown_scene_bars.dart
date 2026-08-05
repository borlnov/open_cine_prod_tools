// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/constants/ocpt_breakdown_palette.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_scene.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_target.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';

/// `{(kind, id): target}`, built once from `OcptBreakdownSnapshot.targets` by the mode's own state
/// and handed to [ocptBreakdownSceneTargetsOf] so a scene's tags are looked up against it rather
/// than the whole target list being walked once per scene.
typedef OcptBreakdownTargetsById = Map<(OcptBreakdownTargetKind, String), OcptBreakdownTarget>;

/// Builds [OcptBreakdownTargetsById] from [targets] — `OcptBreakdownSnapshot.targets`.
OcptBreakdownTargetsById ocptBreakdownTargetsById(List<OcptBreakdownTarget> targets) => {
  for (final target in targets) (target.kind, target.id): target,
};

/// The live targets [scene]'s tags resolve to against [targetById], one entry per **distinct**
/// tagged target: a target tagged twice in the same scene counts once here, which is what both the
/// scene panel's bars and its `N elements` count read.
///
/// A tag whose target has since been dropped from the snapshot (`OcptBreakdownSnapshot.build`'s own
/// doc comment: a tombstoned catalogue row keeps its tag on the scene but drops it from the
/// snapshot's targets) resolves to nothing and is silently skipped — there is no sheet left behind
/// it to count.
List<OcptBreakdownTarget> ocptBreakdownSceneTargetsOf(
  OcptBreakdownScene scene,
  OcptBreakdownTargetsById targetById,
) {
  final distinct = <(OcptBreakdownTargetKind, String), OcptBreakdownTarget>{};
  for (final tag in scene.tags) {
    final target = targetById[(tag.targetKind, tag.targetId)];
    if (target != null) {
      distinct[(tag.targetKind, tag.targetId)] = target;
    }
  }

  return distinct.values.toList(growable: false);
}

/// One coloured bar of a scene's row in `OcptBreakdownScenePanel`: every element target of one
/// [category] tagged in the scene shares one bucket, and every role or set target shares its own
/// single bucket ([category] null then), mirroring the two cases [ocptBreakdownColorOf] itself
/// switches on.
class OcptBreakdownSceneBarBucket extends Equatable {
  /// What kind of target this bucket counts.
  final OcptBreakdownTargetKind kind;

  /// The element category this bucket counts, non-null only when [kind] is
  /// [OcptBreakdownTargetKind.element].
  final OcptElementCategory? category;

  /// This bucket's colour, as an ARGB integer — [ocptBreakdownColorOf] applied to [kind]/[category].
  final int color;

  /// The number of distinct targets of this bucket tagged in the scene, what the bar's width grows
  /// with.
  final int count;

  /// Class constructor
  const OcptBreakdownSceneBarBucket({
    required this.kind,
    required this.category,
    required this.color,
    required this.count,
  });

  /// Object properties
  @override
  List<Object?> get props => [kind, category, color, count];
}

/// The bar buckets of [scene]: one per [OcptElementCategory] present among its live tags (in
/// [OcptElementCategory.values] order), then — if present — one for its tagged roles and one for its
/// tagged sets. `OcptBreakdownScenePanel`'s own per-scene bars.
List<OcptBreakdownSceneBarBucket> ocptBreakdownSceneBarBucketsOf(
  OcptBreakdownScene scene,
  OcptBreakdownTargetsById targetById,
) {
  final elementCounts = <OcptElementCategory, int>{};
  var roleCount = 0;
  var setCount = 0;

  for (final target in ocptBreakdownSceneTargetsOf(scene, targetById)) {
    switch (target.kind) {
      case OcptBreakdownTargetKind.element:
        final category = target.category!;
        elementCounts[category] = (elementCounts[category] ?? 0) + 1;
      case OcptBreakdownTargetKind.role:
        roleCount++;
      case OcptBreakdownTargetKind.set:
        setCount++;
    }
  }

  return [
    for (final category in OcptElementCategory.values)
      if (elementCounts[category] case final count?)
        OcptBreakdownSceneBarBucket(
          kind: OcptBreakdownTargetKind.element,
          category: category,
          color: ocptBreakdownColorOf(kind: OcptBreakdownTargetKind.element, category: category),
          count: count,
        ),
    if (roleCount > 0)
      OcptBreakdownSceneBarBucket(
        kind: OcptBreakdownTargetKind.role,
        category: null,
        color: ocptBreakdownRoleColor,
        count: roleCount,
      ),
    if (setCount > 0)
      OcptBreakdownSceneBarBucket(
        kind: OcptBreakdownTargetKind.set,
        category: null,
        color: ocptBreakdownSetColor,
        count: setCount,
      ),
  ];
}
