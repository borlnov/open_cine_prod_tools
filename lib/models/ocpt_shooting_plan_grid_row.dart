// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_grids.dart';

/// One row of the locations, sequences or crew-and-cast summary grid: its own leading label and its
/// already-resolved cells, one per [OcptShootingPlanGrids.slotColumns] entry, in the same order.
///
/// A cell is the empty string when the row's own subject does not apply to that column at all (a
/// location's row against a slot shot somewhere else, a role's row against a slot that doesn't
/// convoke it) — never a placeholder standing in for a missing value, the distinction
/// `OcptShootingPlanGridSections.gridDataCell`'s own doc comment already draws between a blank grid
/// cell and a blank shot-table one. A caller substitutes its own "nothing here" mark for a
/// genuinely missing value elsewhere; this model never does.
class OcptShootingPlanGridRow extends Equatable {
  /// Class constructor
  const OcptShootingPlanGridRow({
    required this.label,
    required this.cells,
    this.isBold = false,
    this.isMuted = false,
    this.isIndented = false,
  });

  /// This row's own leading label (a location's name, a sequence's own tag, a crew position's or a
  /// role's own label).
  final String label;

  /// This row's own resolved value at every one of [OcptShootingPlanGrids.slotColumns], in order.
  final List<String> cells;

  /// Whether [label] is meant to be printed bold — a location's or a sequence's own name, a crew
  /// position.
  final bool isBold;

  /// Whether this row's own cells are meant to be printed muted — the locations grid's own nested
  /// `Perso.` row.
  final bool isMuted;

  /// Whether [label] is meant to be printed indented — the locations grid's own nested `Perso.`
  /// row.
  final bool isIndented;

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptShootingPlanGridRow(label: $label, cells: ${cells.length})";

  /// Object properties
  @override
  List<Object?> get props => [label, cells, isBold, isMuted, isIndented];
}
