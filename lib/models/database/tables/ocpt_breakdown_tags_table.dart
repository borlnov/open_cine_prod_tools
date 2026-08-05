// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_elements_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_roles_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_scenes_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_sets_table.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';

/// Converts a [OcptBreakdownTargetKind] to and from the text stored in the
/// `breakdown_tags.targetKind` column.
class OcptBreakdownTargetKindConverter extends TypeConverter<OcptBreakdownTargetKind, String> {
  /// Class constructor
  const OcptBreakdownTargetKindConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptBreakdownTargetKind fromSql(String fromDb) => OcptBreakdownTargetKind.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptBreakdownTargetKind value) => value.name;
}

/// A passage of the screenplay tagged during the breakdown pass, anchoring it to the catalogue row
/// it calls for.
///
/// Three nullable foreign keys plus a discriminator ([targetKind]), rather than one untyped
/// `targetId`: the schema declares `PRAGMA foreign_keys` and enforces it, so a real column per
/// target keeps referential integrity, and lets a tombstoned target keep its tags pointing
/// somewhere valid rather than at a dangling id — `elements.ownerPersonId`/`broughtByPersonId`
/// already do exactly this. Exactly one of [elementId]/[roleId]/[setId] is non-null: the one
/// [targetKind] names.
///
/// [startOffset]/[endOffset] are **scene-relative**, exactly as `shot_coverages`, and for the same
/// reason: a scene that moves because a scene above it grew keeps every tag it had, with no
/// rewriting at all.
///
/// [taggedText] stores the passage **verbatim**, where the neighbouring `shot_coverages` stores
/// only a digest — a deliberate departure. A tag is a few words, so storing them costs nothing, and
/// it buys two things a digest cannot: a shifted tag can be re-anchored by searching the scene for
/// the stored text, and the other occurrences of the same words can be found and offered as
/// suggestions. A digest can do neither.
///
/// No `sortKey`: a scene's tags are ordered by [startOffset], which is the order they are read in.
@DataClassName('OcptBreakdownTagRow')
class OcptBreakdownTagsTable extends Table {
  /// {@macro open_cine_prod_tools.OcptBreakdownTagsTable}
  @override
  String get tableName => 'breakdown_tags';

  /// The stable, unique id of this tag (a UUID).
  TextColumn get id => text()();

  /// The scene the tagged passage is in. [startOffset]/[endOffset] are relative to this scene's
  /// `charStart`.
  TextColumn get sceneId => text().references(OcptScenesTable, #id)();

  /// Which of [elementId]/[roleId]/[setId] this tag points at.
  TextColumn get targetKind => text().map(const OcptBreakdownTargetKindConverter())();

  /// The element this tag points at, non-null iff [targetKind] is
  /// [OcptBreakdownTargetKind.element].
  TextColumn get elementId => text().nullable().references(OcptElementsTable, #id)();

  /// The role this tag points at, non-null iff [targetKind] is [OcptBreakdownTargetKind.role].
  TextColumn get roleId => text().nullable().references(OcptRolesTable, #id)();

  /// The set this tag points at, non-null iff [targetKind] is [OcptBreakdownTargetKind.set].
  TextColumn get setId => text().nullable().references(OcptSetsTable, #id)();

  /// The character offset, relative to the scene's `charStart`, at which the tagged passage
  /// starts.
  IntColumn get startOffset => integer()();

  /// The character offset, relative to the scene's `charStart`, one past the last character of the
  /// tagged passage.
  IntColumn get endOffset => integer()();

  /// The tagged passage, verbatim, as it read when this tag was last written or re-anchored.
  TextColumn get taggedText => text()();

  /// Whether the passage at [startOffset]/[endOffset] no longer matches [taggedText] and could not
  /// be re-anchored by searching the scene for it.
  BoolColumn get needsCheck => boolean().withDefault(const Constant(false))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
