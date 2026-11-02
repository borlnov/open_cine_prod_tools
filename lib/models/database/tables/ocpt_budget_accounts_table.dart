// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';

/// A budget line's parent chapter, following the CNC nomenclature every French commission expects
/// (`lib/constants/ocpt_budget_cnc_accounts.dart` seeds the ten of them), then renamed, reordered
/// and extended like any other record — the nomenclature is seeded, never frozen.
///
/// **This table carries no quoted amount.** An account's total is the sum of its
/// `OcptBudgetLinesTable` rows, computed by `lib/models/rules/ocpt_budget_totals.dart`, never
/// stored here: a `quotedAmount` column would be a second copy of one truth, and the "frozen quote"
/// the mockup shows is already what a project version freezes.
///
/// [estimateToCompleteCents] is not a counter-example: the quote is *derivable* from the lines it
/// sums, so storing it would duplicate a truth the lines already state, but what is still expected
/// to be spent is a human's judgement about the future, derivable from nothing this table or its
/// lines already hold — its own doc comment says why its null reads "nobody has judged", not zero.
@DataClassName('OcptBudgetAccountRow')
class OcptBudgetAccountsTable extends Table {
  /// {@macro open_cine_prod_tools.OcptBudgetAccountsTable}
  @override
  String get tableName => 'budget_postes';

  /// Get the stable, unique id of this account (a UUID).
  ///
  /// The ten seeded accounts carry a **constant** id, declared alongside them in
  /// `lib/constants/ocpt_budget_cnc_accounts.dart`, so two replicas seeding the same project
  /// produce the same ten rows rather than twenty a merge would then have to reconcile.
  TextColumn get id => text()();

  /// {@macro open_cine_prod_tools.sortKey}
  TextColumn get sortKey => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// Get the CNC account number as printed on a commission's own nomenclature (e.g. `2`, `4.1`),
  /// free text.
  ///
  /// Free text rather than an integer or an enum: the nomenclature is seeded and then editable, an
  /// account the user adds of their own has no CNC number to carry, and a sub-account's own number
  /// (`4.1`, `4.2`) is not an integer at all.
  TextColumn get code => text().withDefault(const Constant(''))();

  /// Get this account's display name, e.g. "Personnel".
  TextColumn get label => text()();

  /// Get this account's name in the mode's simplified header state, or null.
  ///
  /// **Null means "this poste has no simplified wording of its own"**, not "no name at all": the
  /// simplified display then falls back to [label], exactly the reading a nullable override always
  /// carries in this schema (`OcptBudgetLinesTable.vatRateBasisPoints` for a line's rate, or
  /// `OcptProjectInfoTable.minimumRestMinutes` for a figure nobody has recorded). The ten seeded
  /// accounts each carry one, since the CNC's own wording ("Droits artistiques") is not what a
  /// five-person crew reads at a glance ("Scénario et musique") — an account the user adds later is
  /// free to leave this null and read the same way in both header states.
  TextColumn get simpleLabel => text().nullable()();

  /// Get what is still expected to be spent on this account beyond what has already been paid and
  /// committed against it, in cents, or null.
  ///
  /// **Null means "derive it", not "zero"**: `lib/models/rules/ocpt_budget_totals.dart`'s
  /// `ocptBudgetEstimateToCompleteCents` reads a null here as "nobody has judged this yet" and
  /// answers `max(0, quote − paid − committed)` in its place — the same reading a nullable override
  /// carries elsewhere in this schema ([simpleLabel] above, or
  /// `OcptBudgetLinesTable.vatRateBasisPoints` for a line's rate), except that those two fall back
  /// to another **stored** fact (a label, a project-wide rate) while this one falls back to a
  /// **computed** one, since nothing this table holds could ever record what a human has not yet
  /// judged. A typed value, by contrast, is never second-guessed: it is a real cost report's own
  /// adjustment, not a restatement of the quote.
  IntColumn get estimateToCompleteCents => integer().nullable()();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
