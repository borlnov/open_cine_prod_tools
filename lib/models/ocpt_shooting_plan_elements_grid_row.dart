// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_grid_row.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_grids.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';

/// One row of the elements summary grid — either an [OcptElementCategory] band or one element's own
/// data row. A sealed alternative to reusing [OcptShootingPlanGridRow] itself: that class's own
/// cells read a **slot** column, and the elements grid's own columns are **days**
/// ([OcptShootingPlanGrids]'s own doc comment), so reusing it would either force a slot-shaped
/// column onto a grid that has none or force every slot grid's own row to accept a column type it
/// never sees.
sealed class OcptShootingPlanElementsGridRow extends Equatable {
  /// Class constructor
  const OcptShootingPlanElementsGridRow();
}

/// An [OcptElementCategory] band row — the reference `.xlsx`'s own `ANIMAUX`/`VÉHICULES`/
/// `ÉQUIPEMENTS SPÉCIAUX` bands — carrying no per-column cell of its own: a caller draws it as a
/// whole row in its own right, however it draws a band (a coloured `pw.TableRow`, a bolded XLSX
/// row).
class OcptShootingPlanElementsGridCategoryBand extends OcptShootingPlanElementsGridRow {
  /// The category's own already-resolved display label.
  final String label;

  /// Class constructor
  const OcptShootingPlanElementsGridCategoryBand({required this.label});

  /// Get a string representation of the object, useful for debugging and logging.
  @override
  String toString() => "OcptShootingPlanElementsGridCategoryBand(label: $label)";

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [label];
}

/// One element's own row: its `<code> · <name>` label — the same shape
/// `OcptSchedulePlanSnapshot.elementsToBringOnDay`'s own printed line already carries on a named
/// call sheet — and its already-resolved cells, one per [OcptShootingPlanGrids.dayColumns] entry,
/// in the same order: the caller's own presence mark when the element is needed that day, or the
/// empty string otherwise — **never a quantity summed across that day's own scenes**, see
/// [OcptShootingPlanGrids]'s own doc comment.
class OcptShootingPlanElementsGridElementRow extends OcptShootingPlanElementsGridRow {
  /// This row's own leading label.
  final String label;

  /// This row's own resolved value at every one of [OcptShootingPlanGrids.dayColumns], in order.
  final List<String> cells;

  /// Class constructor
  const OcptShootingPlanElementsGridElementRow({required this.label, required this.cells});

  /// Get a string representation of the object, useful for debugging and logging.
  @override
  String toString() =>
      "OcptShootingPlanElementsGridElementRow(label: $label, cells: ${cells.length})";

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [label, cells];
}
