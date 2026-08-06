// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_cast_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_crew_member.dart';

/// A convocation window inside a `OcptShootingDay` — the *créneau* the reference call sheets print
/// — joined with its live [crew] and [cast], both in `sortKey` order, exactly as
/// `OcptLocation.sets` nests a location's live sets.
///
/// **[startMinute] may exceed 1440.** See `OcptShootingSlotsTable`'s own doc comment: it is this
/// slot's one typed clock, and every other convocation time is computed off it, never stored here —
/// `lib/utils/ocpt_shooting_day_timeline.dart` (ADR 0015) and
/// `lib/utils/ocpt_shooting_convocations.dart` (ADR 0017).
class OcptShootingSlot extends Equatable {
  /// The stable, unique id of this slot (a UUID).
  final String id;

  /// The day this slot belongs to.
  final String shootingDayId;

  /// This slot's own label ("Matin", "Nuit"), free text.
  final String label;

  /// The location this slot is shot at, or null while none is chosen.
  final String? locationId;

  /// The set (décor) this slot is shot at, or null while none is chosen.
  final String? setId;

  /// The minute, from the day's own midnight, this slot's own chain of blocks starts at.
  final int startMinute;

  /// Free-form notes about this slot.
  final String notes;

  /// The live crew members convoked during this slot, in `sortKey` order.
  final List<OcptShootingSlotCrewMember> crew;

  /// The live roles convoked during this slot, in `sortKey` order.
  final List<OcptShootingSlotCastMember> cast;

  /// Class constructor
  const OcptShootingSlot({
    required this.id,
    required this.shootingDayId,
    required this.label,
    required this.locationId,
    required this.setId,
    required this.startMinute,
    required this.notes,
    required this.crew,
    required this.cast,
  });

  /// Builds an [OcptShootingSlot] from its stored [row] and its already-ordered [crew] and [cast].
  factory OcptShootingSlot.fromRow({
    required OcptShootingSlotRow row,
    required List<OcptShootingSlotCrewMember> crew,
    required List<OcptShootingSlotCastMember> cast,
  }) => OcptShootingSlot(
    id: row.id,
    shootingDayId: row.shootingDayId,
    label: row.label,
    locationId: row.locationId,
    setId: row.setId,
    startMinute: row.startMinute,
    notes: row.notes,
    crew: crew,
    cast: cast,
  );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptShootingSlot(id: $id, shootingDayId: $shootingDayId, label: $label)";

  /// Object properties
  @override
  List<Object?> get props => [
    id,
    shootingDayId,
    label,
    locationId,
    setId,
    startMinute,
    notes,
    crew,
    cast,
  ];
}
