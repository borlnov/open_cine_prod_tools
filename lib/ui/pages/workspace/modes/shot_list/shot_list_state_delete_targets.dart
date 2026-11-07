// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:collection/collection.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_shot_list_labels.dart';

/// The reads the floor plans' symbol deletion is decided from: how far deleting a symbol reaches,
/// and so which of the confirmation dialogs the mode asks.
extension OcptShotListStateDeleteTargetsExtension on OcptShotListState {
  /// Tell whether [symbolId] names a **set-scope** symbol (or a scene-scope override of one) whose
  /// own
  /// set is linked to two or more sequences — the condition under which deleting it asks the
  /// sequence-level extended three-button dialog — or null while it doesn't (a scene-/shot-scope
  /// symbol, or a set-scope one on a single-sequence set), in which case [multiShotDeleteTargetOf]
  /// or the plain two-button dialog applies instead.
  ({int otherSequenceCount, String focusedSequenceCode, String targetSceneId})?
  multiSequenceDeleteTargetOf(String symbolId) {
    final selectedSet = this.selectedSet;
    if (selectedSet == null) {
      return null;
    }
    final symbol = selectedSet.symbols.firstWhereOrNull((candidate) => candidate.id == symbolId);
    if (symbol == null) {
      return null;
    }
    if (symbol.shotId != null) {
      return null; // shot-scope: never a candidate.
    }
    if (symbol.overridesSymbolId == null && symbol.sceneId != null) {
      return null; // a plain scene-scope symbol (a prop): never a candidate either.
    }

    final sequenceCount = floorPlanSnapshot?.sequenceCountOfSet(selectedSet.id) ?? 0;
    if (sequenceCount < 2) {
      return null;
    }

    // The sequence to mask it for: the override's own sceneId when [symbolId] already names one,
    // the focused sequence's own scene id when it names the original instead.
    final targetSceneId = symbol.sceneId ?? selectedSequenceId;
    if (targetSceneId == null) {
      return null;
    }
    final targetSequence = sequences.firstWhereOrNull((sequence) => sequence.id == targetSceneId);

    return (
      otherSequenceCount: sequenceCount - 1,
      focusedSequenceCode: ocptShotSequenceDisplayNumberOf(targetSequence),
      targetSceneId: targetSceneId,
    );
  }

  /// Tell whether [symbolId] names a **scene-scope** symbol (a prop, the sequence's own furniture,
  /// or
  /// itself a sequence-scope override — or a shot-scope override of one) of a sequence holding two
  /// or more shots — the condition under which deleting it asks the shot-level extended
  /// three-button dialog — or null while it doesn't
  /// (a set-scope symbol, already handled by [multiSequenceDeleteTargetOf], or a single-shot
  /// sequence's own scene-scope symbol), in which case the plain two-button dialog applies.
  ({int otherShotCount, String focusedShotCode, String targetShotId})? multiShotDeleteTargetOf(
    String symbolId,
  ) {
    final selectedSet = this.selectedSet;
    if (selectedSet == null) {
      return null;
    }
    final symbol = selectedSet.symbols.firstWhereOrNull((candidate) => candidate.id == symbolId);
    if (symbol == null || (symbol.sceneId == null && symbol.shotId == null)) {
      return null; // set-scope: never a candidate here.
    }

    final sequence = selectedSequence;
    if (sequence is! OcptSceneShotSequence || sequence.shots.length < 2) {
      return null;
    }

    // The shot to mask it for: the override's own shotId when [symbolId] already names one, the
    // focused shot's own id when it names the scene-scope symbol instead.
    final targetShotId = symbol.shotId ?? selectedShotId;
    if (targetShotId == null) {
      return null;
    }
    final targetShot = sequence.shots.firstWhereOrNull((shot) => shot.id == targetShotId);

    return (
      otherShotCount: sequence.shots.length - 1,
      focusedShotCode: targetShot?.code ?? "",
      targetShotId: targetShotId,
    );
  }
}
