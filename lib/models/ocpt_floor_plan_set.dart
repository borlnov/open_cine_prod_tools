// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_arrow.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol.dart';

/// One set of a sequence's floor plan, as `OcptFloorPlanService.loadFloorPlans` builds it: its
/// stored fields, the underlay's resolved path (through the `assets` table, ADR 0013) and its live
/// symbols and arrows.
///
/// A sequence may hold several of these, in [sortKey] order (its tabs). See
/// `OcptFloorPlanSetsTable`'s own doc comment for why a set whose scene has vanished from the
/// screenplay is simply unreachable rather than cascaded — nothing here handles that state
/// specially, the loader just never surfaces it.
class OcptFloorPlanSet extends Equatable {
  /// The stable, unique id of this set (a UUID).
  final String id;

  /// The sequence (scene) this set belongs to.
  final String sceneId;

  /// The set's own name.
  final String name;

  /// The order this set's tab takes among the sequence's other sets.
  final String sortKey;

  /// The underlay's `assets` row id, or null until one is imported.
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

  /// This set's live symbols.
  final List<OcptFloorPlanSymbol> symbols;

  /// This set's live arrows.
  final List<OcptFloorPlanArrow> arrows;

  /// Class constructor
  const OcptFloorPlanSet({
    required this.id,
    required this.sceneId,
    required this.name,
    required this.sortKey,
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

  /// Builds an [OcptFloorPlanSet] from its stored [row], the resolved [underlayPath] of its
  /// underlay asset (or null), and its live [symbols] and [arrows].
  factory OcptFloorPlanSet.fromRow({
    required OcptFloorPlanSetRow row,
    required String? underlayPath,
    required List<OcptFloorPlanSymbol> symbols,
    required List<OcptFloorPlanArrow> arrows,
  }) => OcptFloorPlanSet(
    id: row.id,
    sceneId: row.sceneId,
    name: row.name,
    sortKey: row.sortKey,
    underlayAssetId: row.underlayAssetId,
    underlayPath: underlayPath,
    underlayXM: row.underlayXM,
    underlayYM: row.underlayYM,
    underlayWidthM: row.underlayWidthM,
    underlayHeightM: row.underlayHeightM,
    underlayRotationDeg: row.underlayRotationDeg,
    symbols: symbols,
    arrows: arrows,
  );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptFloorPlanSet(id: $id, sceneId: $sceneId, name: $name, symbols: ${symbols.length}, "
      "arrows: ${arrows.length})";

  /// Object properties
  @override
  List<Object?> get props => [
    id,
    sceneId,
    name,
    sortKey,
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
