// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_floor_plan_set.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_reveal_request.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';

/// Get [revealRequest]'s own sequence id, when it names one still live in [snapshot], or null
/// otherwise (no reveal pending, or it names a sequence no longer live — a dangling reveal reads
/// the same as none, `OcptShotListRevealRequest`'s own doc comment) — the default sequence
/// selection applies instead.
String? ocptRevealedSequenceIdOf({
  required OcptShotListRevealRequest? revealRequest,
  required OcptShotListSnapshot snapshot,
}) {
  final sceneId = revealRequest?.sceneId;
  if (sceneId == null) {
    return null;
  }
  return snapshot.sequences.any((sequence) => sequence.id == sceneId) ? sceneId : null;
}

/// Get [revealRequest]'s own set id, when it still names one of [sequenceId]'s own live linked sets
/// in [floorPlanSnapshot], or null otherwise.
String? ocptRevealedSetIdOf({
  required OcptShotListRevealRequest? revealRequest,
  required OcptFloorPlanSnapshot floorPlanSnapshot,
  required String? sequenceId,
}) {
  final setId = revealRequest?.setId;
  if (setId == null || sequenceId == null) {
    return null;
  }
  return floorPlanSnapshot.setsOfScene(sequenceId).any((floorPlanSet) => floorPlanSet.id == setId)
      ? setId
      : null;
}

/// Get the id of [sequenceId]'s own first floor plan set (its first tab), or null while
/// [floorPlanSnapshot] holds none for it, [sequenceId] is null, or it isn't a real scene (the
/// orphan group can never hold a set) — what a freshly selected sequence's floor plans view
/// defaults to.
String? ocptFirstSetIdOf({
  required OcptFloorPlanSnapshot? floorPlanSnapshot,
  required String? sequenceId,
}) {
  if (sequenceId == null || floorPlanSnapshot == null) {
    return null;
  }
  final sets = floorPlanSnapshot.setsOfScene(sequenceId);
  return sets.isEmpty ? null : sets.first.id;
}

/// Get the id of [sequenceId]'s own first shot, or null while [sequenceId] is null, doesn't name a
/// real scene (the orphan group holds no floor plan set, but it does hold shots — this still
/// returns null for it, since a floor plan focus only ever makes sense on a real scene) or holds
/// none in [snapshot] — what a freshly loaded snapshot, or a freshly selected sequence, defaults
/// `OcptShotListState.selectedShotId` to, guaranteeing it is never null while the sequence holds
/// at least one shot: every camera, character, light, prop and arrow
/// placed on the floor plans view lands on this very shot.
String? ocptFirstShotIdOf({required OcptShotListSnapshot? snapshot, required String? sequenceId}) {
  if (snapshot == null || sequenceId == null) {
    return null;
  }
  for (final sequence in snapshot.sequences) {
    if (sequence.id == sequenceId && sequence is OcptSceneShotSequence) {
      return sequence.shots.isEmpty ? null : sequence.shots.first.id;
    }
  }
  return null;
}

/// Get the sequence of [sequences] holding the shot [shotId], or null if no sequence does.
OcptShotSequence? ocptSequenceHolding({
  required List<OcptShotSequence> sequences,
  required String shotId,
}) {
  for (final sequence in sequences) {
    for (final shot in sequence.shots) {
      if (shot.id == shotId) {
        return sequence;
      }
    }
  }

  return null;
}

/// Get the live `floor_plan_symbols` row [symbolId] names, searched across every set of
/// [floorPlanSnapshot], or null while it holds none by that id.
OcptFloorPlanSymbol? ocptFloorPlanSymbolById({
  required OcptFloorPlanSnapshot? floorPlanSnapshot,
  required String symbolId,
}) {
  for (final floorPlanSet in floorPlanSnapshot?.setsById.values ?? const <OcptFloorPlanSet>[]) {
    for (final symbol in floorPlanSet.symbols) {
      if (symbol.id == symbolId) {
        return symbol;
      }
    }
  }
  return null;
}

/// Tell whether symbol [symbolId] is masked where the floor plans canvas looks, at [sceneId] and
/// [shotId] (null while no sequence or no shot is focused): a live hidden override of it exists
/// for that sequence (a sequence-level one, with no shot of its own) or for that shot — what
/// hiding a symbol "for this sequence" or "for this shot" writes, and what makes the canvas stop
/// drawing it as itself.
///
/// A hidden override is not itself masked by this: the canvas draws it as a ghost, and a ghost can
/// be selected to be restored. False while [floorPlanSnapshot] holds no such symbol at all.
bool ocptIsFloorPlanSymbolMaskedAt({
  required OcptFloorPlanSnapshot? floorPlanSnapshot,
  required String symbolId,
  required String? sceneId,
  required String? shotId,
}) {
  for (final floorPlanSet in floorPlanSnapshot?.setsById.values ?? const <OcptFloorPlanSet>[]) {
    for (final candidate in floorPlanSet.symbols) {
      if (!candidate.isHidden || candidate.overridesSymbolId != symbolId) {
        continue;
      }
      final masksShot = candidate.shotId != null && candidate.shotId == shotId;
      final masksSequence =
          candidate.shotId == null && candidate.sceneId != null && candidate.sceneId == sceneId;
      if (masksShot || masksSequence) {
        return true;
      }
    }
  }
  return false;
}

/// Tell whether [floorPlanSnapshot] holds a live arrow [arrowId], in any of its sets.
bool ocptFloorPlanArrowExists({
  required OcptFloorPlanSnapshot? floorPlanSnapshot,
  required String arrowId,
}) {
  for (final floorPlanSet in floorPlanSnapshot?.setsById.values ?? const <OcptFloorPlanSet>[]) {
    for (final arrow in floorPlanSet.arrows) {
      if (arrow.id == arrowId) {
        return true;
      }
    }
  }
  return false;
}

/// Get the first of [shot]'s own `OcptShot.characters` not already carried by one of its live
/// character symbols on [floorPlanSet], or `""` while it has none left (or none at all) — the
/// convenience pre-fill a freshly placed character symbol's own label gets.
String ocptDefaultCharacterLabelOf({
  required OcptShot? shot,
  required OcptFloorPlanSet? floorPlanSet,
}) {
  if (shot == null || shot.characters.isEmpty) {
    return "";
  }

  final alreadyLabelled = {
    for (final symbol in floorPlanSet?.symbols ?? const <OcptFloorPlanSymbol>[])
      if (symbol.shotId == shot.id &&
          symbol.layer == OcptFloorPlanLayer.characters &&
          symbol.label.isNotEmpty)
        symbol.label,
  };

  for (final characterName in shot.characters) {
    if (!alreadyLabelled.contains(characterName)) {
      return characterName;
    }
  }
  return "";
}
