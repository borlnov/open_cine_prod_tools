// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';

/// Somebody attending a `shooting_slots` window who is neither crew nor cast.
///
/// **Exactly one of [personId]/[freeName] says who this is** — see
/// `OcptShootingSlotGuestsTable`'s own doc comment.
///
/// **This row's arrival and departure are computed, never typed** — see
/// `lib/utils/ocpt_shooting_convocations.dart` (ADR 0018): this row's [slotId] is one of possibly
/// several slots this guest is linked to on the same day, and every figure about them is read off
/// every live slot they are on, joined together. A guest never carries a PAT band, whatever
/// shooting blocks the slot holds — they are not there to shoot.
class OcptShootingSlotGuest extends Equatable {
  /// The stable, unique id of this attendance (a UUID).
  final String id;

  /// The slot this guest attends.
  final String slotId;

  /// The address-book person this guest is, or null when [freeName] is used instead.
  final String? personId;

  /// A free-text name, used instead of [personId] when the guest is not, and will never be, a row
  /// of `people`. Empty when [personId] is set.
  final String freeName;

  /// Why this guest is on set.
  final String reason;

  /// Free-form notes about this attendance.
  final String notes;

  /// Class constructor
  const OcptShootingSlotGuest({
    required this.id,
    required this.slotId,
    required this.personId,
    required this.freeName,
    required this.reason,
    required this.notes,
  });

  /// Builds an [OcptShootingSlotGuest] from its stored [row].
  factory OcptShootingSlotGuest.fromRow(OcptShootingSlotGuestRow row) => OcptShootingSlotGuest(
    id: row.id,
    slotId: row.slotId,
    personId: row.personId,
    freeName: row.freeName,
    reason: row.reason,
    notes: row.notes,
  );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptShootingSlotGuest(id: $id, slotId: $slotId, personId: $personId, freeName: $freeName)";

  /// Object properties
  @override
  List<Object?> get props => [id, slotId, personId, freeName, reason, notes];
}
