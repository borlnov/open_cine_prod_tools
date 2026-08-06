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
class OcptShootingSlotCastMember extends Equatable {
  /// The stable, unique id of this convocation (a UUID).
  final String id;

  /// The slot this convocation is for.
  final String slotId;

  /// The role convoked during the slot.
  final String roleId;

  /// When this role's actor is expected to arrive (for hair, make-up, costume, rehearsal), or null
  /// while unset. May exceed 1440 — see `OcptShootingSlotsTable`'s own doc comment.
  final int? arrivalMinute;

  /// This role's own start of the *PAT* band, overriding the slot's own `castCallMinute`, or null
  /// to use the slot's own. May exceed 1440 — see `OcptShootingSlotsTable`'s own doc comment.
  final int? castCallMinute;

  /// This role's own end of the *PAT* band, overriding the slot's own `castWrapMinute`, or null to
  /// use the slot's own. May exceed 1440 — see `OcptShootingSlotsTable`'s own doc comment.
  final int? castWrapMinute;

  /// Free-form notes about this convocation.
  final String notes;

  /// Class constructor
  const OcptShootingSlotCastMember({
    required this.id,
    required this.slotId,
    required this.roleId,
    required this.arrivalMinute,
    required this.castCallMinute,
    required this.castWrapMinute,
    required this.notes,
  });

  /// Builds an [OcptShootingSlotCastMember] from its stored [row].
  factory OcptShootingSlotCastMember.fromRow(OcptShootingSlotCastRow row) =>
      OcptShootingSlotCastMember(
        id: row.id,
        slotId: row.slotId,
        roleId: row.roleId,
        arrivalMinute: row.arrivalMinute,
        castCallMinute: row.castCallMinute,
        castWrapMinute: row.castWrapMinute,
        notes: row.notes,
      );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptShootingSlotCastMember(id: $id, slotId: $slotId, roleId: $roleId)";

  /// Object properties
  @override
  List<Object?> get props => [
    id,
    slotId,
    roleId,
    arrivalMinute,
    castCallMinute,
    castWrapMinute,
    notes,
  ];
}
