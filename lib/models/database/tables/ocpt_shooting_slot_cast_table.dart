// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_roles_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shooting_slots_table.dart';

/// Which role is convoked during a slot.
///
/// **An actor has three times, not two, and all three are computed** — see
/// `lib/utils/ocpt_shooting_convocations.dart` (ADR 0018): a role is convoked by being linked to a
/// slot, and every figure about it (arrival, PAT band, departure) is read off every live slot of
/// the day this row's own [slotId] is one of, joined with every other slot the same role is linked
/// to — the PAT (*prêt à tourner*) band, in particular, comes from the blocks of those slots naming
/// this role (a shot block through its `shot_characters`, a hold block through the sequence it
/// reserves). Nothing here says "how long before" any more — a production that wants an actor in
/// the make-up chair earlier creates the slot that says so and links the role to it, rather than
/// typing a lead time beside an ordinary convocation.
///
/// **The role is convoked, not the person**: the actor is read through `roles.personId`, so
/// recasting a role never rewrites the schedule, and an uncast role convoked anyway is a
/// legitimate state (reported by an M3 alert, not refused here). One actor playing two roles in one
/// night is two rows collapsing into one person on the printed sheet. Extras are ordinary `extra`
/// roles, created by hand in the resources mode exactly as any other role is — a nameless crowd is
/// a sentence in the day's `shooting_days.crewNote`, not a row here.
@DataClassName('OcptShootingSlotCastRow')
class OcptShootingSlotCastTable extends Table {
  /// {@macro open_cine_prod_tools.OcptShootingSlotCastTable}
  @override
  String get tableName => 'shooting_slot_cast';

  /// The stable, unique id of this convocation (a UUID).
  TextColumn get id => text()();

  /// The slot this convocation is for.
  TextColumn get slotId => text().references(OcptShootingSlotsTable, #id)();

  /// The role convoked during the slot.
  TextColumn get roleId => text().references(OcptRolesTable, #id)();

  /// {@macro open_cine_prod_tools.sortKey}
  TextColumn get sortKey => text().withDefault(const Constant(''))();

  /// Free-form notes about this convocation.
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
