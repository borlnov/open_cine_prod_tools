// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_budget_postes_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_elements_table.dart';

/// One quoted line of the budget: a quantity of something, at a unit price, inside a poste.
///
/// **The money is three columns, never reconstructed** — ADR 0025 is the
/// argument this table implements, and `lib/utils/ocpt_budget_vat.dart` is the only place in the
/// repository allowed to convert between the two tax bases:
///
/// - [unitAmountCents] is the figure exactly as typed, in cents. A conversion between tax bases is
///   computed for display and never written back, so somebody who types the 12.50 € printed on a
///   till receipt reads 12.50 € back everywhere, forever;
/// - [isTaxInclusive] says whether that figure already includes tax — a till receipt does, a
///   supplier quote usually does not, and a real budget mixes both, so no basis is imposed;
/// - [vatRateBasisPoints] is the rate that figure carries. Its own nullability is the override:
///   **null means "inherit the project's rate"** (`OcptProjectInfoTable.defaultVatRateBasisPoints`),
///   not "nobody has said" — a silent line follows the project and moves with it when the project's
///   rate changes, an explicit **0** is wages or a copyright assignment stating plainly that no VAT
///   applies, and the two are different facts with different totals: an excluding-tax total counts
///   a `0`-rated line, never a silent one.
///
/// [quantityMilli] is an integer in **thousandths**, for the reason cents are cents: 1.5 day is
/// 1500, 1,484 km is 1484000, and a total computed from it (`lib/utils/ocpt_budget_totals.dart`) is
/// exact rather than accumulating a rounding a floating-point quantity would.
@DataClassName('OcptBudgetLineRow')
class OcptBudgetLinesTable extends Table {
  /// {@macro open_cine_prod_tools.OcptBudgetLinesTable}
  @override
  String get tableName => 'budget_lines';

  /// The stable, unique id of this line (a UUID).
  TextColumn get id => text()();

  /// {@macro open_cine_prod_tools.sortKey}
  TextColumn get sortKey => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// The poste this line belongs to. → [OcptBudgetPostesTable]
  TextColumn get posteId => text().references(OcptBudgetPostesTable, #id)();

  /// This line's display name, e.g. "First assistant camera".
  TextColumn get label => text()();

  /// The quantity this line prices, in thousandths — see this table's own doc comment.
  ///
  /// Defaults to `1000` (a plain quantity of one) rather than to zero: a freshly created line prices
  /// one of something until the user says otherwise, which is the reading that keeps a fresh line's
  /// total equal to its unit price rather than silently zero.
  IntColumn get quantityMilli => integer().withDefault(const Constant(1000))();

  /// The unit [quantityMilli] is counted in, free text (e.g. "day", "km", "unit").
  TextColumn get unit => text().withDefault(const Constant(''))();

  /// The unit price, exactly as typed, in cents — see this table's own doc comment.
  IntColumn get unitAmountCents => integer().withDefault(const Constant(0))();

  /// Whether [unitAmountCents] already includes tax — see this table's own doc comment.
  ///
  /// **Non-nullable, `true` by default**: a real budget mixes tax-inclusive and tax-exclusive
  /// figures, but the common case a person types by hand off a receipt or an invoice total already
  /// includes tax, so a freshly created line reads that way until corrected.
  BoolColumn get isTaxInclusive => boolean().withDefault(const Constant(true))();

  /// The VAT rate this line's [unitAmountCents] carries, in basis points (550 for 5.5 %), or null —
  /// see this table's own doc comment for the two facts a null and an explicit `0` state
  /// differently.
  IntColumn get vatRateBasisPoints => integer().nullable()();

  /// The breakdown element this line prices, or null. → [OcptElementsTable]
  ///
  /// Declared from this milestone on but read by no service before M3: a quote line and a
  /// breakdown element are captured independently until the cost-tracking view can cross them
  /// (`elements.cost` seeding a fresh line's unit price, an unpriced element surfacing as a need).
  TextColumn get elementId => text().nullable().references(OcptElementsTable, #id)();

  /// What wrote this line, or null while a human typed it.
  ///
  /// A **stable key naming the thing provisioned** rather than a foreign key — `regie:meal`,
  /// `regie:snack`, `allowance:travel` and so on: the régie view provisions *one line per nature*,
  /// summing across every defrayal of that nature and every shooting day, so there is no single row
  /// on the other end for a foreign key to point at. Reprovisioning finds the line carrying the
  /// same key on the same poste and updates it, instead of stacking a second one beside it.
  ///
  /// Null is the ordinary case and means nobody provisioned this line — a line typed by hand is not
  /// a lesser line, and the provisioning leaves every one of them alone.
  TextColumn get provisionKey => text().nullable()();

  /// What the provisioning last wrote into this line, or null while it never wrote it.
  ///
  /// Holds `[label, quantityMilli, unitAmountCents]` as JSON, exactly as those three stood when
  /// the provisioning last set them. **It is how a hand edit is told from a stale figure**: on the
  /// next provision, a line whose current three still match this is the app's own to update, and a
  /// line whose do not has been retouched by somebody and is reported rather than overwritten. The
  /// user is never silently corrected, which is the same promise `OcptBudgetQuoteService` keeps
  /// everywhere else — an amount is what was typed.
  TextColumn get provisionDigest => text().nullable()();

  /// Free-form notes about this line.
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
