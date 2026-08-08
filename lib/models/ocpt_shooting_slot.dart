// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_cast_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_crew_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_guest.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';

/// A convocation window inside a `OcptShootingDay` — the *créneau* the reference call sheets print
/// — joined with its live [crew], [cast] and [guests], all three in `sortKey` order, exactly as
/// `OcptLocation.sets` nests a location's live sets.
///
/// **[anchorEdge] plus exactly one of [anchorMinute]/[anchorSlotId] is the whole of what this slot
/// says about time**, and a stored minute may exceed 1440. See `OcptShootingSlotsTable`'s own doc
/// comment: where this slot actually starts and ends is computed, never read off a column here —
/// `lib/utils/ocpt_shooting_day_timeline.dart` (ADR 0015, amended twice) and
/// `lib/utils/ocpt_shooting_convocations.dart` (ADR 0018). A widget that wants "the hour of this
/// slot" reads its resolved `OcptShootingSlotTimeline.startMinute`, not [anchorMinute], which is
/// null the moment the edge is linked and is the *end* whenever [anchorEdge] is
/// [OcptShootingSlotAnchorEdge.end].
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

  /// Which of this slot's two edges is the pinned one.
  final OcptShootingSlotAnchorEdge anchorEdge;

  /// The hour [anchorEdge] is pinned to, typed by hand — null exactly when [anchorSlotId] is set.
  final int? anchorMinute;

  /// The slot of the same day whose **opposite** edge [anchorEdge] reads its hour off — null
  /// exactly when [anchorMinute] is set.
  final String? anchorSlotId;

  /// Free-form notes about this slot.
  final String notes;

  /// The live crew members convoked during this slot, in `sortKey` order.
  final List<OcptShootingSlotCrewMember> crew;

  /// The live roles convoked during this slot, in `sortKey` order.
  final List<OcptShootingSlotCastMember> cast;

  /// The live guests attending this slot, in `sortKey` order.
  final List<OcptShootingSlotGuest> guests;

  /// Class constructor
  const OcptShootingSlot({
    required this.id,
    required this.shootingDayId,
    required this.label,
    required this.locationId,
    required this.setId,
    required this.anchorEdge,
    required this.anchorMinute,
    required this.anchorSlotId,
    required this.notes,
    required this.crew,
    required this.cast,
    required this.guests,
  });

  /// Builds an [OcptShootingSlot] from its stored [row] and its already-ordered [crew], [cast] and
  /// [guests].
  factory OcptShootingSlot.fromRow({
    required OcptShootingSlotRow row,
    required List<OcptShootingSlotCrewMember> crew,
    required List<OcptShootingSlotCastMember> cast,
    required List<OcptShootingSlotGuest> guests,
  }) => OcptShootingSlot(
    id: row.id,
    shootingDayId: row.shootingDayId,
    label: row.label,
    locationId: row.locationId,
    setId: row.setId,
    anchorEdge: row.anchorEdge,
    anchorMinute: row.anchorMinute,
    anchorSlotId: row.anchorSlotId,
    notes: row.notes,
    crew: crew,
    cast: cast,
    guests: guests,
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
    anchorEdge,
    anchorMinute,
    anchorSlotId,
    notes,
    crew,
    cast,
    guests,
  ];
}
