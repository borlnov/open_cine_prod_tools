// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_roles_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shots_table.dart';

/// The `roles` attached to a shot: its screenplay speaking characters, plus any character invented
/// in the shot list for a silent role or an extra.
///
/// A shot's characters are the production's `roles`
/// (`docs/adr/0030-a-shots-characters-are-the-productions-roles.md`): this table references
/// [OcptRolesTable] rather than storing a free name, so the découpage, the dépouillement and the
/// resources mode all read and write the one cast. This is what makes the shared role banner
/// meaningful in the shot list: a role removed from the screenplay still has its rows here until a
/// user explicitly detaches it, merges it or deletes it.
///
/// Schema version 3 reshaped this table from its original `{shotId, characterName}` key
/// (`OcptProjectDatabase`'s own migration history) — the first non-additive migration this project
/// ships, argued in the ADR above.
@DataClassName('OcptShotCharacterRow')
class OcptShotCharactersTable extends Table {
  /// {@macro open_cine_prod_tools.OcptShotCharactersTable}
  @override
  String get tableName => 'shot_characters';

  /// The shot this role is attached to.
  TextColumn get shotId => text().references(OcptShotsTable, #id)();

  /// The role attached to the shot.
  TextColumn get roleId => text().references(OcptRolesTable, #id)();

  /// {@macro open_cine_prod_tools.position}
  IntColumn get position => integer()();

  /// {@macro open_cine_prod_tools.sortKey}
  TextColumn get sortKey => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {shotId, roleId};
}
