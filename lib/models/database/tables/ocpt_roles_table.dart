// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_people_table.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';

/// Converts a [OcptRoleKind] to and from the text stored in the `roles.kind` column.
class OcptRoleKindConverter extends TypeConverter<OcptRoleKind, String> {
  /// Class constructor
  const OcptRoleKindConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptRoleKind fromSql(String fromDb) => OcptRoleKind.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptRoleKind value) => value.name;
}

/// A character of the film and the person cast to play them, if any.
///
/// A role belongs to the **production**, not to any one screenplay
/// (`docs/adr/0019-one-project-several-episodes.md`): a character speaking in several episodes is
/// one casting, not one per episode, and `role_episodes` (`OcptRoleEpisodesTable`) is what records
/// which episodes name it. A speaking role is **reconciled from the screenplay**, not typed from
/// nothing (`OcptRoleIndexService`, on the same save path `OcptSceneIndexService` already runs),
/// mirroring the way `shots.orphanedHeading` survives a scene's disappearance: a role's casting and
/// notes outlive the character being renamed or cut in any one episode. A role for a non-speaking
/// part or a group of extras is added by hand instead — see [kind].
@DataClassName('OcptRoleRow')
class OcptRolesTable extends Table {
  /// {@macro open_cine_prod_tools.OcptRolesTable}
  @override
  String get tableName => 'roles';

  /// The stable, unique id of this role (a UUID).
  TextColumn get id => text()();

  /// The character's name.
  TextColumn get name => text()();

  /// {@macro open_cine_prod_tools.sortKey}
  TextColumn get sortKey => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// The person cast in this role, or null while it is uncast.
  TextColumn get personId => text().nullable().references(OcptPeopleTable, #id)();

  /// Whether this is a speaking role (reconciled from the screenplay), a silent role or an extra —
  /// the two latter kinds are always added by hand, since the screenplay never names them as a cue.
  TextColumn get kind => text().map(const OcptRoleKindConverter())();

  /// Whether [name] is owned by the screenplay reconciliation (`OcptRoleIndexService`) rather than
  /// typed by the user: true for a role created from a speaking character, false for one added by
  /// hand. A row the user created is never touched by reconciliation, whatever character names
  /// later appear or disappear.
  BoolColumn get isFromScreenplay => boolean().withDefault(const Constant(false))();

  /// The name this character had in the screenplay when it stopped being found there, or null while
  /// it is still present. Mirrors `shots.orphanedHeading`: the role, its casting and its notes
  /// survive, and the mode shows a removed-role banner offering to delete it or keep it as a silent
  /// role.
  TextColumn get orphanedName => text().nullable()();

  /// Casting notes for this role, free text.
  TextColumn get castingNotes => text().withDefault(const Constant(''))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
