// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_assets_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_people_table.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';

/// Converts a [OcptElementCategory] to and from the text stored in the `elements.category` column.
class OcptElementCategoryConverter extends TypeConverter<OcptElementCategory, String> {
  /// Class constructor
  const OcptElementCategoryConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptElementCategory fromSql(String fromDb) => OcptElementCategory.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptElementCategory value) => value.name;
}

/// Converts a [OcptElementSourceKind] to and from the text stored in the `elements.sourceKind`
/// column.
class OcptElementSourceKindConverter extends TypeConverter<OcptElementSourceKind, String> {
  /// Class constructor
  const OcptElementSourceKindConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptElementSourceKind fromSql(String fromDb) => OcptElementSourceKind.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptElementSourceKind value) => value.name;
}

/// Converts a [OcptElementStatus] to and from the text stored in the `elements.status` column.
class OcptElementStatusConverter extends TypeConverter<OcptElementStatus, String> {
  /// Class constructor
  const OcptElementStatusConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptElementStatus fromSql(String fromDb) => OcptElementStatus.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptElementStatus value) => value.name;
}

/// Anything that must be present on a given shooting day and is not a person: props, set dressing,
/// costumes, vehicles, animals, special equipment, generators, even a block of extras.
///
/// One table rather than one per department, deliberately (decision 8 of the plan this table ships
/// under): both reference spreadsheets already keep every kind of item in one sheet with a category
/// column, because the tracking columns below — owner, who brings it, ready, returned — are
/// identical whatever the item is.
@DataClassName('OcptElementRow')
class OcptElementsTable extends Table {
  /// {@macro open_cine_prod_tools.OcptElementsTable}
  @override
  String get tableName => 'elements';

  /// The stable, unique id of this element (a UUID).
  TextColumn get id => text()();

  /// {@macro open_cine_prod_tools.sortKey}
  TextColumn get sortKey => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// The top-level category this element belongs to, aligned with standard breakdown practice.
  TextColumn get category => text().map(const OcptElementCategoryConverter())();

  /// A production's own finer grouping within [category], free text.
  TextColumn get subCategory => text().withDefault(const Constant(''))();

  /// The element's display name.
  TextColumn get name => text()();

  /// The short label a breakdown margin has room for, free text — the element's equivalent of a
  /// shot's `abbreviation`.
  TextColumn get code => text().withDefault(const Constant(''))();

  /// How many of this element are needed: a decimal number, or empty while nobody has counted.
  ///
  /// **Stored as text although the field only accepts a number** (`OcptDecimalTextInputFormatter`):
  /// the column predates the restriction and holds whatever earlier builds wrote into it, and
  /// turning it into a `real` is not the additive migration ADR 0007 allows. Read it with
  /// `double.tryParse` and treat what does not parse as no quantity — never as zero.
  TextColumn get quantity => text().withDefault(const Constant(''))();

  /// Where this element comes from, or is going to.
  TextColumn get sourceKind => text().map(const OcptElementSourceKindConverter())();

  /// Who owns this element, when they are in the address book (e.g. "M. et Mme Schmit"). Null when
  /// the owner is an organisation rather than a person — see [ownerNotes].
  TextColumn get ownerPersonId => text().nullable().references(OcptPeopleTable, #id)();

  /// Who owns this element, free text — used when the owner is an organisation ("Asso",
  /// "Rétro-Loc") rather than someone in the address book, or to add detail beside
  /// [ownerPersonId].
  TextColumn get ownerNotes => text().withDefault(const Constant(''))();

  /// Who brings this element to set: the reference sheets' "Qui l'apporte ?" — a different question
  /// from who owns it, and the one that actually fails on the day.
  TextColumn get broughtByPersonId => text().nullable().references(OcptPeopleTable, #id)();

  /// Where this element is stored until the shoot (e.g. "sous l'abri, déjà sur place"), free text.
  TextColumn get storageNotes => text().withDefault(const Constant(''))();

  /// How far this element is towards being ready for the shoot: to find, reserved, being made or
  /// confirmed — the breakdown pass's own tracking, which the three booleans below cannot express
  /// (neither *reserved* nor *being made* is any of "on the truck", "ready" or "returned").
  // The stored literal below must match `OcptElementStatus.toFind.name` exactly, for the same
  // reason `shots.status`'s default does: an enum's `.name` getter isn't a compile-time constant
  // expression, so it can't be written as `Constant(OcptElementStatus.toFind)`.
  TextColumn get status =>
      text().map(const OcptElementStatusConverter()).withDefault(const Constant('toFind'))();

  /// Whether this element is secured (owned, borrowed, rented or bought — the first of the three
  /// checkboxes both reference spreadsheets share, in the order they use: got it, ready, returned).
  BoolColumn get isSecured => boolean().withDefault(const Constant(false))();

  /// Whether this element is ready for the shoot (e.g. loaded on the truck).
  BoolColumn get isReadyForShoot => boolean().withDefault(const Constant(false))();

  /// Whether this element has been returned (to its owner, its rental house) after the shoot.
  BoolColumn get isReturned => boolean().withDefault(const Constant(false))();

  /// The cost of this element, in cents, or null while unknown. Read by the budget mode later;
  /// written here because this is where the information exists.
  IntColumn get cost => integer().nullable()();

  /// Why this element is needed, free text — the reference sheets' "Pourquoi ?".
  TextColumn get purposeNotes => text().withDefault(const Constant(''))();

  /// Free-form notes about this element.
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// This element's photo, or null while there is none. → [OcptAssetsTable]
  TextColumn get photoAssetId => text().nullable().references(OcptAssetsTable, #id)();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
