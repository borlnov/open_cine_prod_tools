// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';

/// A per-kilometre reimbursement rate the production names for itself, e.g. "Car", "Production
/// van", "Motorbike" — never the app's own.
///
/// **This table exists because the app ships in more than one country and states no regulatory
/// figure of its own**: a mileage scale is a legal figure that differs by country and by vehicle,
/// and this app cannot carry one as a constant without advancing a rate nobody here validated —
/// exactly the argument `OcptProjectInfoTable.minimumRestMinutes` already settled for a single
/// column, generalised here to a whole table. Nothing is seeded: a fresh project's
/// `budget_mileage_rates` is empty, and `OcptBudgetFinancingService` never writes a row into it
/// that the user didn't ask for — see that service's own doc comment.
///
/// [ratePerKmMilliCents] is a **money-per-distance figure**, not an amount typed once: `people`
/// (`commuteKmMilli`) and the catering-and-travel pass cross it with a distance to compute a total,
/// so it lives here rather than beside a single line.
@DataClassName('OcptBudgetMileageRateRow')
class OcptBudgetMileageRatesTable extends Table {
  /// {@macro open_cine_prod_tools.OcptBudgetMileageRatesTable}
  @override
  String get tableName => 'budget_mileage_rates';

  /// The stable, unique id of this rate (a UUID).
  TextColumn get id => text()();

  /// {@macro open_cine_prod_tools.sortKey}
  TextColumn get sortKey => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// This rate's display name, e.g. "Voiture personnelle".
  TextColumn get label => text()();

  /// The reimbursement rate, in **thousandths of a cent per kilometre** — `0.529 €/km` is `52900`.
  ///
  /// A deliberate deviation from the `ratePerKmCents` `docs/plans/budget-mode.md` names, taken with
  /// the plan owner's agreement: a real mileage scale is quoted to **three decimals** — 0.529,
  /// 0.601, 0.395 — and a whole-cent column simply cannot state the figure the user has in front of
  /// them. This is the money rule `docs/architecture/budget.md` already states for every other
  /// amount in this mode, applied to a per-kilometre rate rather than to a lump sum: an amount is
  /// stored exactly as it was typed, and never reconstructed.
  IntColumn get ratePerKmMilliCents => integer().withDefault(const Constant(0))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
