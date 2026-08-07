// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';

/// One person holding one position during a `shooting_slots` window.
///
/// A person holding two positions in one slot is two [OcptShootingSlotCrewMember]s — see
/// `OcptShootingSlotCrewTable`'s own doc comment.
///
/// **This row's arrival and PAT band are computed, never typed** — see
/// `lib/utils/ocpt_shooting_convocations.dart` (ADR 0018): this row's [slotId] is one of possibly
/// several slots this person is linked to on the same day, and every figure about them is read off
/// every live slot they are on, joined together. Nothing here says how long before a moment they
/// are needed — a production wanting them there earlier links them to a slot that says so.
class OcptShootingSlotCrewMember extends Equatable {
  /// The stable, unique id of this assignment (a UUID).
  final String id;

  /// The slot this assignment is for.
  final String slotId;

  /// The person holding this position during the slot.
  final String personId;

  /// The stable code of the position, from `ocptCrewPositions`, or the empty string when
  /// [customLabel] is used instead.
  final String positionId;

  /// A free-text position label, used instead of [positionId] when the catalogue has nothing that
  /// fits. Empty when [positionId] is set.
  final String customLabel;

  /// Free-form notes about this assignment.
  final String notes;

  /// Class constructor
  const OcptShootingSlotCrewMember({
    required this.id,
    required this.slotId,
    required this.personId,
    required this.positionId,
    required this.customLabel,
    required this.notes,
  });

  /// Builds an [OcptShootingSlotCrewMember] from its stored [row].
  factory OcptShootingSlotCrewMember.fromRow(OcptShootingSlotCrewRow row) =>
      OcptShootingSlotCrewMember(
        id: row.id,
        slotId: row.slotId,
        personId: row.personId,
        positionId: row.positionId,
        customLabel: row.customLabel,
        notes: row.notes,
      );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptShootingSlotCrewMember(id: $id, slotId: $slotId, personId: $personId)";

  /// Object properties
  @override
  List<Object?> get props => [id, slotId, personId, positionId, customLabel, notes];
}
