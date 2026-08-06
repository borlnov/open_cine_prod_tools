// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';

/// One role convoked during a `shooting_slots` window.
///
/// **The role is convoked, not the person** — see `OcptShootingSlotCastTable`'s own doc comment:
/// the actor is read through `roles.personId` at the point this is displayed, so recasting a role
/// never rewrites the schedule.
///
/// **This row's PAT band and arrival are computed, never typed** — see
/// `lib/utils/ocpt_shooting_convocations.dart` (ADR 0017). [leadMinutes] is a lead time typed
/// beside this role, and [groupId] the `OcptShootingDayGroup` this row belongs to when it belongs
/// to one; this row's own [leadMinutes] wins over its group's when both are set.
class OcptShootingSlotCastMember extends Equatable {
  /// The stable, unique id of this convocation (a UUID).
  final String id;

  /// The slot this convocation is for.
  final String slotId;

  /// The role convoked during the slot.
  final String roleId;

  /// The `OcptShootingDayGroup` this convocation belongs to, or null while it belongs to none.
  final String? groupId;

  /// This convocation's own lead time, overriding [groupId]'s own figure, or null to use the
  /// group's.
  final int? leadMinutes;

  /// Free-form notes about this convocation.
  final String notes;

  /// Class constructor
  const OcptShootingSlotCastMember({
    required this.id,
    required this.slotId,
    required this.roleId,
    required this.groupId,
    required this.leadMinutes,
    required this.notes,
  });

  /// Builds an [OcptShootingSlotCastMember] from its stored [row].
  factory OcptShootingSlotCastMember.fromRow(OcptShootingSlotCastRow row) =>
      OcptShootingSlotCastMember(
        id: row.id,
        slotId: row.slotId,
        roleId: row.roleId,
        groupId: row.groupId,
        leadMinutes: row.leadMinutes,
        notes: row.notes,
      );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptShootingSlotCastMember(id: $id, slotId: $slotId, roleId: $roleId)";

  /// Object properties
  @override
  List<Object?> get props => [id, slotId, roleId, groupId, leadMinutes, notes];
}
