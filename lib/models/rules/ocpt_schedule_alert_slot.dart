// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/rules/ocpt_schedule_alerts.dart';

/// One slot of a day, already resolved by the caller (`OcptSchedulePlanSnapshot`, never this file,
/// which knows nothing of drift or of `shooting_slots`/`shooting_slot_crew`/`shooting_slot_cast`)
/// into exactly what the day-level rules need: its own resolved band, its location, and who is
/// convoked on it and how.
class OcptScheduleAlertSlot {
  /// The slot's own id (`shooting_slots.id`), echoed back on every alert that names it.
  final String id;

  /// The slot's own resolved start (`OcptShootingSlotTimeline.startMinute`), never a stored column.
  final int startMinute;

  /// The slot's own resolved end (`OcptShootingSlotTimeline.endMinute`), or null while it carries
  /// no block at all — see [OcptSchedulePersonDoubleBookedAlert]'s own doc comment for what that
  /// means to rule 2; every other rule reads an empty band as `endMinute ?? startMinute`, exactly
  /// as `ocptComputeDayConvocations` reads a departure.
  final int? endMinute;

  /// The location this slot is booked at, or null while none is chosen — a slot naming none is
  /// skipped by the location-coverage rule, there being nothing to check.
  final String? locationId;

  /// Every person convoked on this slot as a human: its own crew rows' people, plus the actors of
  /// its cast roles that are cast — mirroring `OcptConvocationSlot.personIds`.
  final Set<String> personIds;

  /// Every role convoked on this slot, cast or not — `OcptShootingSlotCastMember.roleId` verbatim.
  /// Unlike [personIds], which only ever names a human, an entry here may point at a role nobody
  /// has cast yet.
  final Set<String> convokedRoleIds;

  /// Builds a slot to feed to [ocptComputeScheduleAlerts].
  const OcptScheduleAlertSlot({
    required this.id,
    required this.startMinute,
    required this.endMinute,
    required this.locationId,
    required this.personIds,
    required this.convokedRoleIds,
  });
}
