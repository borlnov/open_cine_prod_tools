// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_roles_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shooting_day_groups_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shooting_slots_table.dart';

/// Which role is convoked during a slot.
///
/// **An actor has three times, not two, and all three are computed** — see
/// `lib/utils/ocpt_shooting_convocations.dart` (ADR 0017). The PAT (*prêt à tourner*) band comes
/// from the blocks of the slot naming this role (a shot block through its `shot_characters`, a
/// hold block through the scene it reserves time for), and the arrival is that band's start minus
/// this row's resolved lead time — the make-up chair, which is why the lead lives per role and per
/// day rather than once per film. [leadMinutes] is that figure; when null, this row inherits
/// [groupId]'s own `shooting_day_groups.leadMinutes` instead, and **this row's own figure wins over
/// its group's** when both are set.
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

  /// The `shooting_day_groups` row this convocation belongs to, or null while it belongs to none.
  /// See the class doc comment.
  TextColumn get groupId => text().nullable().references(OcptShootingDayGroupsTable, #id)();

  /// This convocation's own lead time, overriding [groupId]'s own figure, or null to use the
  /// group's — see the class doc comment.
  IntColumn get leadMinutes => integer().nullable()();

  /// Free-form notes about this convocation.
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
