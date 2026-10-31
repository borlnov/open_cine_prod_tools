// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_set.dart';
import 'package:open_cine_prod_tools/models/ocpt_removed_role_alert.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_collision_alert.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_word_layout.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_coverage_range.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_panel.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_scene_set_suggestion.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';

/// The reads derived on demand from an `OcptShotListState`: its sequences, selections, counters,
/// role alerts and scenario coverage views, none of them stored.
extension OcptShotListStateDerivedExtension on OcptShotListState {
  /// Every sequence of [snapshot], in display order (empty while nothing is loaded).
  List<OcptShotSequence> get sequences => snapshot?.sequences ?? const [];

  /// The sequence [selectedSequenceId] identifies, or null if none is selected (or the selected
  /// one disappeared from a freshly loaded [snapshot]).
  OcptShotSequence? get selectedSequence {
    final selectedSequenceId = this.selectedSequenceId;
    if (selectedSequenceId == null) {
      return null;
    }

    for (final sequence in sequences) {
      if (sequence.id == selectedSequenceId) {
        return sequence;
      }
    }

    return null;
  }

  /// The shot [selectedShotId] identifies, or null if none is selected (or the selected one
  /// disappeared from a freshly loaded [snapshot]).
  OcptShot? get selectedShot {
    final selectedShotId = this.selectedShotId;
    return selectedShotId == null ? null : snapshot?.shotsById[selectedShotId];
  }

  /// [shotId]'s own panels, in order, or an empty list while [storyboardSnapshot] hasn't loaded yet
  /// or the shot has none.
  List<OcptStoryboardPanel> panelsOfShot(String shotId) =>
      storyboardSnapshot?.panelsOfShot(shotId) ?? const [];

  /// The selected shot's own panels, or an empty list while no shot is selected.
  List<OcptStoryboardPanel> get panelsOfSelectedShot {
    final selectedShotId = this.selectedShotId;
    return selectedShotId == null ? const [] : panelsOfShot(selectedShotId);
  }

  /// Whether any live shot of the screenplay holds at least one storyboard panel — what the
  /// export panel's storyboard card checks to decide whether it has anything to print: a shot
  /// list can hold shots without holding a single panel,
  /// which is a state of its own, not the same as holding no shot at all.
  bool get hasAnyStoryboardPanel =>
      storyboardSnapshot?.panelsByShotId.values.any((panels) => panels.isNotEmpty) ?? false;

  /// The selected sequence's own floor plan sets, in tab order, or an empty list while
  /// [floorPlanSnapshot] hasn't loaded yet, no sequence is selected, or the selected sequence is
  /// the orphan group (which has no scene, so it can never hold a set).
  List<OcptFloorPlanSet> get setsOfSelectedSequence {
    final sequence = selectedSequence;
    if (floorPlanSnapshot == null || sequence is! OcptSceneShotSequence) {
      return const [];
    }
    return floorPlanSnapshot!.setsOfScene(sequence.sceneId);
  }

  /// Whether any live floor plan set of the screenplay holds at least one camera symbol, on any
  /// shot — what the export panel's floor plans card checks to decide whether it has anything to
  /// print.
  bool get hasAnyFloorPlanCamera =>
      floorPlanSnapshot?.setsById.values.any(
        (floorPlanSet) =>
            floorPlanSet.symbols.any((symbol) => symbol.layer == OcptFloorPlanLayer.cameras),
      ) ??
      false;

  /// The id of the Resources set `ocptSceneSetSuggestionOf` suggests for [sequence]'s own heading,
  /// or null while it suggests none, or while it already names one of [sequence]'s own linked sets
  /// — the gallery's own starred card and the `＋ Set` menu's own top entry both read this, never
  /// offering to link what is already linked.
  String? suggestedSetIdOf(OcptSceneShotSequence sequence) {
    final suggested = ocptSceneSetSuggestionOf(heading: sequence.heading, locations: locations);
    if (suggested == null) {
      return null;
    }
    final alreadyLinked = setsOfSelectedSequence.any(
      (floorPlanSet) => floorPlanSet.id == suggested,
    );
    return alreadyLinked ? null : suggested;
  }

  /// The set [selectedSetId] identifies, or null if none is selected (or the selected one
  /// disappeared from a freshly loaded [floorPlanSnapshot]).
  OcptFloorPlanSet? get selectedSet {
    final selectedSetId = this.selectedSetId;
    if (selectedSetId == null) {
      return null;
    }
    for (final floorPlanSet in setsOfSelectedSequence) {
      if (floorPlanSet.id == selectedSetId) {
        return floorPlanSet;
      }
    }
    return null;
  }

  /// The floor plans view's own focus — **derived, never a second field**: `true` while a shot is
  /// selected (the shot focus), `false`
  /// while none is (the `Sequence` focus). Every floor plans widget that needs to know which of the
  /// two is showing reads this rather than [selectedShotId] directly, so the one rule ("no shot
  /// selected means the sequence focus") lives in exactly one place.
  bool get isFloorPlanShotFocusActive => selectedShotId != null;

  /// The selected sequence's own shot immediately before [selectedShotId], or null while none is
  /// selected, it is the sequence's first shot, or the selected sequence is the orphan group (no
  /// floor plan set can ever belong to it) — the onion skin's own previous-shot ghost.
  OcptShot? get previousShotOfSelectedShot => _neighbourShotOf(-1);

  /// The selected sequence's own shot immediately after [selectedShotId]. See
  /// [previousShotOfSelectedShot].
  OcptShot? get nextShotOfSelectedShot => _neighbourShotOf(1);

  /// [selectedShotId]'s own neighbour [offset] shots away in the selected sequence's own shot
  /// order, or null while there is none (out of range, nothing selected, or the orphan group) — the
  /// body [previousShotOfSelectedShot]/[nextShotOfSelectedShot] share.
  OcptShot? _neighbourShotOf(int offset) {
    final sequence = selectedSequence;
    final selectedShotId = this.selectedShotId;
    if (selectedShotId == null || sequence is! OcptSceneShotSequence) {
      return null;
    }

    final shots = sequence.shots;
    final index = shots.indexWhere((shot) => shot.id == selectedShotId);
    final neighbourIndex = index + offset;
    if (index < 0 || neighbourIndex < 0 || neighbourIndex >= shots.length) {
      return null;
    }
    return shots[neighbourIndex];
  }

  /// The total number of live panels across every shot of the selected sequence — the board
  /// header's own `· N panels` read-out.
  int get boardPanelCountOfSelectedSequence {
    final sequence = selectedSequence;
    if (sequence == null) {
      return 0;
    }
    return sequence.shots.fold(0, (total, shot) => total + panelsOfShot(shot.id).length);
  }

  /// The total number of shots across every sequence, orphan group included.
  int get totalShotCount => snapshot?.totalShotCount ?? 0;

  /// The number of sequences the shot list holds, orphan group included: the status bar's first
  /// counter.
  int get sequenceCount => sequences.length;

  /// The number of shots already filmed across every sequence, orphan group included.
  int get filmedShotCount =>
      snapshot?.shotsById.values.where((shot) => shot.status == OcptShotStatus.shot).length ?? 0;

  /// The number of shots currently flagged as needing checking, across every sequence.
  int get shotsToCheckCount =>
      snapshot?.shotsById.values.where((shot) => shot.needsCheck).length ?? 0;

  /// One alert per orphaned role of [roles] — the screenplay no longer names it, but its casting
  /// and notes are kept — the orphaned variant of the shared role alert banner, shown above the
  /// shot table (ADR 0030, decision 4).
  ///
  /// Derived on demand from [roles], like [otherShotsCoverageOfSelectedScene] and
  /// [buildSelectedCoverageLayout] are, rather than stored: it is already in memory, and computing
  /// it here is what keeps it impossible for a banner to survive the write that resolved it.
  List<OcptRemovedRoleAlert> get orphanedRoleAlerts => OcptRemovedRoleAlert.buildAll(roles);

  /// One alert per hand-added role sharing a name with a live screenplay role — the collision
  /// variant of the shared role alert banner (ADR 0030, decision 2). Derived the same way
  /// [orphanedRoleAlerts] is.
  List<OcptRoleCollisionAlert> get roleCollisionAlerts => OcptRoleCollisionAlert.buildAll(roles);

  /// The roles [alert]'s own role can be merged into: every live, `isFromScreenplay` role of
  /// [roles] that isn't itself orphaned and isn't [alert]'s own — the orphaned banner's `Merge
  /// with:` chips.
  List<OcptRole> mergeTargetsOf(OcptRemovedRoleAlert alert) => [
    for (final role in roles)
      if (role.isFromScreenplay && role.orphanedName == null && role.id != alert.roleId) role,
  ];

  /// Builds the scenario coverage layout of the selected shot's scene, or null when no shot is
  /// selected, none is (or the selected sequence is the orphan group: an orphaned shot's scene
  /// text is gone, so there is nothing left to lay out).
  ///
  /// Rebuilt on demand every time this is called, rather than cached in the state: laying a
  /// scene's few hundred characters out is cheap, and caching it here would only mean
  /// invalidating it by hand on every snapshot or [screenplayText] reload instead of simply
  /// calling this again.
  OcptScriptWordLayout? buildSelectedCoverageLayout() {
    final sequence = selectedSequence;
    if (selectedShot == null || sequence is! OcptSceneShotSequence) {
      return null;
    }

    return OcptScriptWordLayout.of(
      sceneId: sequence.sceneId,
      sceneText: screenplayText.substring(sequence.charStart, sequence.charEnd),
    );
  }

  /// Every shot other than the selected one that has a scenario coverage range of the selected
  /// scene, keyed by that shot's [OcptShot.code], in code order, skipping a shot with no range of
  /// this scene at all: the inspector's "also covered by" wash.
  ///
  /// Derived from [snapshot], already held in memory, rather than through
  /// `OcptShotCoverageService.shotIdsCoveringRange`: the snapshot already carries every shot's own
  /// ranges, so querying the database for each block rendered would mean an async call inside a
  /// build. Empty when no shot is selected or the selected sequence is the orphan group.
  Map<String, List<OcptShotCoverageRange>> otherShotsCoverageOfSelectedScene() {
    final sequence = selectedSequence;
    final selectedShotId = this.selectedShotId;
    if (selectedShotId == null || sequence is! OcptSceneShotSequence) {
      return const {};
    }

    final entries = <MapEntry<String, List<OcptShotCoverageRange>>>[];
    for (final shot in snapshot?.shotsById.values ?? const <OcptShot>[]) {
      if (shot.id == selectedShotId) {
        continue;
      }
      final ranges = shot.coverageRanges
          .where((range) => range.sceneId == sequence.sceneId)
          .toList(growable: false);
      if (ranges.isNotEmpty) {
        entries.add(MapEntry(shot.code, ranges));
      }
    }
    entries.sort((a, b) => a.key.compareTo(b.key));

    return {for (final entry in entries) entry.key: entry.value};
  }

  /// The selected shot's own coverage ranges of [layout]'s scene that currently disagree with its
  /// current text, decided range by range through `OcptShotCoverageService.isRangeStale` rather
  /// than through the coarser, shot-wide `OcptShotCoverageRange.isStale` (which mirrors the whole
  /// shot's `needsCheck` flag): this is what lets the inspector's `modified` badge mark exactly
  /// the blocks whose covered text actually changed.
  Set<String> staleCoverageRangeIdsOfSelectedShot(OcptScriptWordLayout layout) {
    final shot = selectedShot;
    if (shot == null) {
      return const {};
    }

    return {
      for (final range in shot.coverageRanges)
        if (range.sceneId == layout.sceneId &&
            OcptShotCoverageService.isRangeStale(range: range, sceneText: layout.sceneText))
          range.id,
    };
  }
}
