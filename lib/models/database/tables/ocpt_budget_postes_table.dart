// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';

/// A budget line's parent chapter, following the CNC nomenclature every French commission expects
/// (`lib/constants/ocpt_budget_cnc_postes.dart` seeds the ten of them), then renamed, reordered and
/// extended like any other record — the nomenclature is seeded, never frozen.
///
/// **This table carries no quoted amount.** A poste's total is the sum of its
/// `OcptBudgetLinesTable` rows, computed by `lib/utils/ocpt_budget_totals.dart`, never stored here:
/// a `quotedAmount` column would be a second copy of one truth, and the "frozen quote" the mockup
/// shows is already what a project version freezes.
@DataClassName('OcptBudgetPosteRow')
class OcptBudgetPostesTable extends Table {
  /// {@macro open_cine_prod_tools.OcptBudgetPostesTable}
  @override
  String get tableName => 'budget_postes';

  /// The stable, unique id of this poste (a UUID).
  ///
  /// The ten seeded postes carry a **constant** id, declared alongside them in
  /// `lib/constants/ocpt_budget_cnc_postes.dart`, so two replicas seeding the same project produce
  /// the same ten rows rather than twenty a merge would then have to reconcile.
  TextColumn get id => text()();

  /// {@macro open_cine_prod_tools.sortKey}
  TextColumn get sortKey => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// The CNC poste number as printed on a commission's own nomenclature (e.g. `2`, `4.1`), free
  /// text.
  ///
  /// Free text rather than an integer or an enum: the nomenclature is seeded and then editable, a
  /// poste the user adds of their own has no CNC number to carry, and a sub-poste's own number
  /// (`4.1`, `4.2`) is not an integer at all.
  TextColumn get code => text().withDefault(const Constant(''))();

  /// This poste's display name, e.g. "Personnel".
  TextColumn get label => text()();

  /// This poste's name in the mode's simplified header state, or null.
  ///
  /// **Null means "this poste has no simplified wording of its own"**, not "no name at all": the
  /// simplified display then falls back to [label], exactly the reading a nullable override always
  /// carries in this schema (`OcptBudgetLinesTable.vatRateBasisPoints` for a line's rate, or
  /// `OcptProjectInfoTable.minimumRestMinutes` for a figure nobody has recorded). The ten seeded
  /// postes each carry one, since the CNC's own wording ("Droits artistiques") is not what a
  /// five-person crew reads at a glance ("Scénario et musique") — a poste the user adds later is
  /// free to leave this null and read the same way in both header states.
  TextColumn get simpleLabel => text().nullable()();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
