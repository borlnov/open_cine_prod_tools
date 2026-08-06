// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_roles_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shooting_slots_table.dart';

/// Which role is convoked during a slot.
///
/// **An actor has three times, not two.** The reference call sheets print `ARRIVÉE 16:45` and
/// `PAT 17:30 – 22:15` side by side, and the gap between them is the make-up chair: collapsing them
/// would either call an actor two hours before they are needed or lose their preparation entirely.
/// [arrivalMinute] is a personal fact and exists only per row; [castCallMinute]/[castWrapMinute]
/// override the slot's own default *PAT* band, which every row may or may not need to.
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

  /// When this role's actor is expected to arrive (for hair, make-up, costume, rehearsal), or null
  /// while unset. Per row only — see the class doc comment. May exceed 1440 — see
  /// `ocpt_shooting_slots_table.dart`.
  IntColumn get arrivalMinute => integer().nullable()();

  /// This role's own start of the *PAT* band, overriding `shooting_slots.castCallMinute`, or null
  /// to use the slot's own. May exceed 1440 — see `ocpt_shooting_slots_table.dart`.
  IntColumn get castCallMinute => integer().nullable()();

  /// This role's own end of the *PAT* band, overriding `shooting_slots.castWrapMinute`, or null to
  /// use the slot's own. May exceed 1440 — see `ocpt_shooting_slots_table.dart`.
  IntColumn get castWrapMinute => integer().nullable()();

  /// Free-form notes about this convocation.
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
