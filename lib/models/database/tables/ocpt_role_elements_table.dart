// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_elements_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_roles_table.dart';

/// What a role wears, carries and is made up with: the link between a `roles` row and an `elements`
/// one.
///
/// `breakdown_tags` links a *passage* of the screenplay to a role or to an element, never a role to
/// an element, so "whose costume is this?" had no answer anywhere before this table. It is
/// `OcptSceneElementsTable`'s sibling — the same catalogue, linked from the other side of the
/// production — and it carries the same kind of per-link note: "manteau taché à partir de la
/// séquence 12" is a fact about this role's use of that coat, not about the coat.
///
/// **No category restriction, on purpose.** Nothing here says an element must be a costume, a prop
/// or a make-up item: a character's car, their dog and their stunt harness are facts about them
/// exactly as their coat is. The role sheet's own card groups the links by
/// [OcptElementsTable.category] for reading, and that grouping is read-time UI work over a flat
/// table, exactly as the elements list's own is — a restriction written into the schema would be
/// paid for with a migration the day it gets in the way.
///
/// No `sortKey`: a role's things are a set the user adds to and removes from, not a list they
/// reorder — the same reasoning `OcptSceneElementsTable`'s own doc comment gives.
@DataClassName('OcptRoleElementRow')
class OcptRoleElementsTable extends Table {
  /// {@macro open_cine_prod_tools.OcptRoleElementsTable}
  @override
  String get tableName => 'role_elements';

  /// The stable, unique id of this link (a UUID).
  TextColumn get id => text()();

  /// The role needing the element.
  TextColumn get roleId => text().references(OcptRolesTable, #id)();

  /// The element the role needs.
  TextColumn get elementId => text().references(OcptElementsTable, #id)();

  /// Free-form notes about this role's use of the element.
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
