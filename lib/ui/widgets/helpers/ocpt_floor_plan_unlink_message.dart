// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_set.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_floor_plan_unlink_counts.dart';

/// The unlink dialog's own message: `The set's plan is kept.` alone, or followed by what leaves
/// the view — the cameras, characters and props [sequence] placed on [floorPlanSet], joined
/// naturally, when there is at least one.
String ocptFloorPlanUnlinkSetMessageOf(
  Tr tr, {
  required OcptShotSequence? sequence,
  required OcptFloorPlanSet? floorPlanSet,
}) {
  if (sequence is! OcptSceneShotSequence || floorPlanSet == null) {
    return tr.shotListFloorPlanDeleteSetConfirmMessage;
  }

  final counts = ocptFloorPlanUnlinkCountsOf(
    floorPlanSet: floorPlanSet,
    sceneId: sequence.sceneId,
    shotIdsOfScene: sequence.shots.map((shot) => shot.id).toSet(),
  );
  final total = counts.cameras + counts.characters + counts.props;
  if (total <= 0) {
    return tr.shotListFloorPlanDeleteSetConfirmMessage;
  }

  final parts = [
    if (counts.cameras > 0) tr.shotListFloorPlanUnlinkCountCamerasPart(counts.cameras),
    if (counts.characters > 0) tr.shotListFloorPlanUnlinkCountCharactersPart(counts.characters),
    if (counts.props > 0) tr.shotListFloorPlanUnlinkCountPropsPart(counts.props),
  ];
  final list = _naturalJoin(parts, tr.shotListFloorPlanUnlinkCountConjunction);

  return "${tr.shotListFloorPlanDeleteSetConfirmMessage} "
      "${tr.shotListFloorPlanUnlinkCountMessage(total, list)}";
}

/// Joins [parts] the way a natural sentence would: the word alone for one, `A {conjunction} B`
/// for two, `A, B {conjunction} C` for three or more (no comma before the last part — the
/// convention French and English share here) — a plain helper rather than an ICU message, since
/// ICU has no construct for joining however many non-zero parts a caller hands in.
String _naturalJoin(List<String> parts, String conjunction) {
  if (parts.isEmpty) {
    return "";
  }
  if (parts.length == 1) {
    return parts.single;
  }
  final allButLast = parts.sublist(0, parts.length - 1).join(", ");
  return "$allButLast $conjunction ${parts.last}";
}
