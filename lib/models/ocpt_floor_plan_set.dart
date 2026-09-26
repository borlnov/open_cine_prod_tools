// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_arrow.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol.dart';

/// The floor plan of one Resources set, as `OcptFloorPlanService.loadFloorPlans` builds it: [id]
/// is the Resources set's own id (`sets.id`, `docs/plans/storyboard.md`, §10), [name] is read off
/// that very `sets` row, and the underlay/symbols/arrows come from its own `floor_plan_sets` row —
/// absent while nothing has been drawn on it yet (`OcptFloorPlanService.ensurePlan`'s lazy
/// creation), read the same as a plan with no underlay and no placements.
///
/// A sequence's floor-plan tabs are its live `scene_sets` links, so the very same [OcptFloorPlanSet]
/// (same [symbols], same [arrows]) can show up under two different sequences' tabs at once — this
/// is what lets a set-scope symbol moved on one of them show on the other too. [symbols] holds
/// every scope's rows at once (set, every linked sequence's own scene-scope, every shot's own
/// shot-scope); `OcptFloorPlanSheet.of` is what narrows them down to one focus.
class OcptFloorPlanSet extends Equatable {
  /// The stable, unique id of this set — the Resources set's own (`sets.id`).
  final String id;

  /// The set's own name, read off its Resources `sets` row.
  final String name;

  /// The underlay's `assets` row id, or null while none is placed (or the plan doesn't exist yet).
  final String? underlayAssetId;

  /// The underlay's resolved absolute path, or null — a non-null [underlayAssetId] whose `assets`
  /// row was somehow not found resolves this to null too, the same normal-state reading
  /// `OcptStoryboardPanel.imagePath` gives its own image.
  final String? underlayPath;

  /// The underlay's centre X, in metres — null until placed.
  final double? underlayXM;

  /// The underlay's centre Y, in metres. See [underlayXM].
  final double? underlayYM;

  /// The underlay's width, in metres. See [underlayXM].
  final double? underlayWidthM;

  /// The underlay's height, in metres. See [underlayXM].
  final double? underlayHeightM;

  /// The underlay's rotation, in degrees. See [underlayXM].
  final double? underlayRotationDeg;

  /// This set's live symbols, of every scope at once — see this class's own doc comment.
  final List<OcptFloorPlanSymbol> symbols;

  /// This set's live arrows.
  final List<OcptFloorPlanArrow> arrows;

  /// Class constructor
  const OcptFloorPlanSet({
    required this.id,
    required this.name,
    required this.underlayAssetId,
    required this.underlayPath,
    required this.underlayXM,
    required this.underlayYM,
    required this.underlayWidthM,
    required this.underlayHeightM,
    required this.underlayRotationDeg,
    required this.symbols,
    required this.arrows,
  });

  /// Builds an [OcptFloorPlanSet] from its Resources [setRow] (name), its own [planRow] — null
  /// while nothing has been drawn on it yet — the resolved [underlayPath] of its underlay asset (or
  /// null), and its live [symbols] and [arrows].
  factory OcptFloorPlanSet.fromRows({
    required OcptSetRow setRow,
    required OcptFloorPlanSetRow? planRow,
    required String? underlayPath,
    required List<OcptFloorPlanSymbol> symbols,
    required List<OcptFloorPlanArrow> arrows,
  }) => OcptFloorPlanSet(
    id: setRow.id,
    name: setRow.name,
    underlayAssetId: planRow?.underlayAssetId,
    underlayPath: planRow?.underlayAssetId == null ? null : underlayPath,
    underlayXM: planRow?.underlayXM,
    underlayYM: planRow?.underlayYM,
    underlayWidthM: planRow?.underlayWidthM,
    underlayHeightM: planRow?.underlayHeightM,
    underlayRotationDeg: planRow?.underlayRotationDeg,
    symbols: symbols,
    arrows: arrows,
  );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptFloorPlanSet(id: $id, name: $name, symbols: ${symbols.length}, arrows: ${arrows.length})";

  /// Object properties
  @override
  List<Object?> get props => [
    id,
    name,
    underlayAssetId,
    underlayPath,
    underlayXM,
    underlayYM,
    underlayWidthM,
    underlayHeightM,
    underlayRotationDeg,
    symbols,
    arrows,
  ];
}
