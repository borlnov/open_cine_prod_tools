// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_roles_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_screenplays_table.dart';

/// Which episodes a role is named in: the link between a `roles` row and a `screenplays` one.
///
/// `docs/adr/0019-one-project-several-episodes.md` is the record this table exists for. A role
/// belongs to the **production**, not to a script — a character speaking in three episodes is one
/// casting, one set of casting notes, one identity in `shooting_slot_cast`, not three — and this
/// table is what says where a role speaks, once `roles.screenplayId` no longer can.
/// `OcptRoleIndexService.reconcile` is handed one screenplay at a time, on the same save path
/// `OcptSceneIndexService` already runs on, and only ever writes **this episode's own links**: it
/// matches by name across every live, from-screenplay role of the whole project, ensuring a link
/// where a speaking character is found and tombstoning one where it no longer is — a role losing
/// its last live link is what orphans it, not losing this one.
///
/// No `sortKey`: a role's episodes are an unordered set of answers rather than a list the user
/// reorders — the same reasoning `OcptSceneSetsTable`'s own doc comment gives for a scene's sets,
/// and for the same shape of question ("which of these am I linked to?" rather than "in what order
/// do I read them?"). The order they read back in is the episodes' own `sortKey`, not a key of
/// their own.
@DataClassName('OcptRoleEpisodeRow')
class OcptRoleEpisodesTable extends Table {
  /// {@macro open_cine_prod_tools.OcptRoleEpisodesTable}
  @override
  String get tableName => 'role_episodes';

  /// The stable, unique id of this link (a UUID).
  TextColumn get id => text()();

  /// The role named in the episode.
  TextColumn get roleId => text().references(OcptRolesTable, #id)();

  /// The episode (a `screenplays` row) the role is named in.
  TextColumn get screenplayId => text().references(OcptScreenplaysTable, #id)();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
