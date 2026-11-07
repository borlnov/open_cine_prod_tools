// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/converters/ocpt_role_kind_converter.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_people_table.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';

/// A character of the film and the person cast to play them, if any.
///
/// A role belongs to the **production**, not to any one screenplay
/// (`docs/adr/0019-one-project-several-episodes.md`): a character speaking in several episodes is
/// one casting, not one per episode, and `role_episodes` (`OcptRoleEpisodesTable`) is what records
/// which episodes name it. A role is **reconciled from the screenplay**, not typed from nothing
/// (`OcptRoleIndexService`), on the same save path `OcptSceneIndexService` already runs, whenever a
/// character is cued in dialogue or only ever named in capitals in the action, mirroring the way
/// `shots.orphanedHeading` survives a scene's disappearance: a role's casting and notes outlive the
/// character being renamed or cut in any one episode. A role for a group of extras, or one the user
/// requalifies by hand, is typed from nothing instead — see [kind] and [isFromScreenplay].
@DataClassName('OcptRoleRow')
class OcptRolesTable extends Table {
  /// {@macro open_cine_prod_tools.OcptRolesTable}
  @override
  String get tableName => 'roles';

  /// Get the stable, unique id of this role (a UUID).
  TextColumn get id => text()();

  /// Get the character's name.
  TextColumn get name => text()();

  /// {@macro open_cine_prod_tools.sortKey}
  TextColumn get sortKey => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// Get the person cast in this role, or null while it is uncast.
  TextColumn get personId => text().nullable().references(OcptPeopleTable, #id)();

  /// Tell whether this is a speaking role, a silent role or an extra. [OcptRoleKind.speaking] is
  /// always
  /// reconciled from a dialogue cue; [OcptRoleKind.silent] is reconciled from a character's name
  /// standing in capitals in the action **or** added by hand — the two are told apart by
  /// [isFromScreenplay], not by this column alone (`ocptRoleIsActionDetected`, `lib/models/rules/`)
  /// — and [OcptRoleKind.extra] is always added by hand, since the screenplay has no convention
  /// naming a group of extras.
  TextColumn get kind => text().map(const OcptRoleKindConverter())();

  /// Tell whether [name] (and, for a non-speaking [kind], the row's very existence) is owned by the
  /// screenplay reconciliation (`OcptRoleIndexService`) rather than typed by the user: true for a
  /// role created from a cue or from a name standing in the action, false for one added by hand. A
  /// row the user created is never touched by reconciliation, whatever character names later appear
  /// or disappear.
  BoolColumn get isFromScreenplay => boolean().withDefault(const Constant(false))();

  /// Get the name this character had in the screenplay when it stopped being found there, or null
  /// while
  /// it is still present. Mirrors `shots.orphanedHeading`: the role, its casting and its notes
  /// survive, and the mode shows a removed-role banner offering to delete it or keep it as a silent
  /// role.
  TextColumn get orphanedName => text().nullable()();

  /// Get the casting notes for this role, free text.
  TextColumn get castingNotes => text().withDefault(const Constant(''))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
