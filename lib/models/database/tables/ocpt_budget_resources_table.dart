// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';

/// Converts a [OcptBudgetResourceGroupKind] to and from the text stored in the
/// `budget_resources.groupKind` column.
class OcptBudgetResourceGroupKindConverter extends TypeConverter<OcptBudgetResourceGroupKind, String> {
  /// Class constructor
  const OcptBudgetResourceGroupKindConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptBudgetResourceGroupKind fromSql(String fromDb) =>
      OcptBudgetResourceGroupKind.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptBudgetResourceGroupKind value) => value.name;
}

/// Converts a [OcptBudgetResourceStatus] to and from the text stored in the
/// `budget_resources.status` column.
class OcptBudgetResourceStatusConverter extends TypeConverter<OcptBudgetResourceStatus, String> {
  /// Class constructor
  const OcptBudgetResourceStatusConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptBudgetResourceStatus fromSql(String fromDb) => OcptBudgetResourceStatus.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptBudgetResourceStatus value) => value.name;
}

/// One line of the production's financing plan: a subsidy, a cash contribution or a contribution
/// in kind ([groupKind]), what it comes to and where it stands ([status]).
///
/// **No `receivedCents` column, even though `docs/plans/budget-mode.md` §4 lists one.** What has
/// actually been received against a resource is the sum of the `budget_entries` credits naming it
/// through `budget_entries.resourceId`, computed on every read rather than stored beside it — the
/// very same argument `docs/architecture/budget.md` already makes twice, in "A poste's quoted
/// amount is not stored" and in "A commitment settles by naming the entry that paid it": a stored
/// second copy of one truth has to be kept in step by a write nobody can guarantee never to forget.
/// A subsidy's own instalments are read exactly the way a poste's paid total already is — off the
/// journal, never off a duplicate counter.
///
/// **No money triple either — no `isTaxInclusive`, no `vatRateBasisPoints`.** A financing resource
/// is money coming *in*, and `docs/architecture/budget.md`'s own "Money that has moved is read
/// tax-inclusive, always" already settles that there is no second basis to read it in: a subsidy is
/// awarded, notified or paid at one figure, never a figure that needs converting between an
/// excluding-tax and an including-tax reading the way a quoted line does.
@DataClassName('OcptBudgetResourceRow')
class OcptBudgetResourcesTable extends Table {
  /// {@macro open_cine_prod_tools.OcptBudgetResourcesTable}
  @override
  String get tableName => 'budget_resources';

  /// The stable, unique id of this resource (a UUID).
  TextColumn get id => text()();

  /// {@macro open_cine_prod_tools.sortKey}
  TextColumn get sortKey => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// What kind of financing this resource is.
  // The stored literal below must match `OcptBudgetResourceGroupKind.subsidy.name` exactly, for the
  // same reason `budget_commitments.status`'s default does: an enum's `.name` getter isn't a
  // compile-time constant expression, so it can't be written as `Constant(…)`.
  TextColumn get groupKind => text()
      .map(const OcptBudgetResourceGroupKindConverter())
      .withDefault(const Constant('subsidy'))();

  /// This resource's free-text wording, e.g. "Région Île-de-France — aide à la production".
  TextColumn get label => text()();

  /// The amount this resource comes to, exactly as typed, in cents.
  IntColumn get amountCents => integer().withDefault(const Constant(0))();

  /// How far this resource has progressed towards actually financing the production.
  TextColumn get status => text()
      .map(const OcptBudgetResourceStatusConverter())
      .withDefault(const Constant('applied'))();

  /// Whether this resource has to be repaid before the revenue sharing splits what is left —
  /// `docs/plans/budget-mode.md`'s "reimbursable contributions repaid before anything is split".
  BoolColumn get isReimbursable => boolean().withDefault(const Constant(false))();

  /// Free-form notes about this resource.
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
