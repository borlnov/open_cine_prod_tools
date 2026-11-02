// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_convocation_audition.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_day_convocation.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_convocations.dart';

/// One slot of a day, already resolved by the caller (`OcptScheduleState`, never this file, which
/// knows nothing of drift, of `shots`/`shot_characters`/`roles`, or of `ocpt_shooting_day_timeline
/// .dart`'s own types) into exactly what [ocptComputeDayConvocations] needs: who is linked to it,
/// and where its own chain of blocks starts, ends and shoots.
///
/// A person is convoked by being **linked to a slot** (ADR 0018) — there is no lead time, no group
/// and no per-block role resolution left in this file: whoever [personIds]/[uncastRoleIds]/
/// [guestPersonIds]/[guestFreeNames] names is convoked by this slot, for the
/// whole of it, and every clock a convocation carries is read off [startMinute]/[endMinute]/
/// [shootingStartMinute]/[shootingEndMinute]/[filmingStartMinute]/[filmingEndMinute] alone.
///
/// **A candidate is the one exception, and is not named here at all**: somebody seen for a part is
/// linked to the audition block that sees them rather than to the unit
/// ([OcptConvocationAudition], ADR 0024).
class OcptConvocationSlot extends Equatable {
  /// The slot's own id (`shooting_slots.id`), echoed back on every [OcptDayConvocation.slotIds]
  /// that includes it.
  final String id;

  /// The slot's own `startMinute` — where its chain of blocks starts, whether or not it carries any
  /// yet.
  final int startMinute;

  /// The slot's own last block end (`OcptShootingSlotTimeline.endMinute`), or null while it carries
  /// no block at all — a slot with nothing placed on it yet still convokes whoever is linked to it,
  /// just with nothing to say "the end" of (see [ocptComputeDayConvocations]'s own doc comment).
  final int? endMinute;

  /// The earliest start over this slot's own **shooting** blocks — `shot`, `hold`, `audition` and
  /// `rehearsal`, `OcptShootingBlockKind.isShootingTime`'s own answer (ADR 0018) — or null when it
  /// carries none of them. Null exactly when [shootingEndMinute] is: both are built from the same
  /// walk over the same blocks.
  final int? shootingStartMinute;

  /// The latest end over the same blocks, or null under the same condition as
  /// [shootingStartMinute].
  final int? shootingEndMinute;

  /// The earliest start over this slot's own **filming** blocks alone — `shot` and `hold`,
  /// `OcptShootingBlockKind.isFilming`'s own answer — or null when it carries none. Null exactly
  /// when [filmingEndMinute] is.
  ///
  /// This is what a PAT (*prêt à tourner*) band is read off: that word is the hour a performer must
  /// be ready for a take, so an audition or a rehearsal in the same slot, being no take, neither
  /// opens nor closes it — they are still working time, and still covered by the person's arrival
  /// and departure.
  final int? filmingStartMinute;

  /// The latest end over the same filming blocks, or null under the same condition as
  /// [filmingStartMinute].
  final int? filmingEndMinute;

  /// Every person linked to this slot as a human: its crew rows' own people, plus the actors of its
  /// cast roles that are cast — resolving a role's actor is the caller's job, this file knowing
  /// nothing of `roles.personId`.
  final Set<String> personIds;

  /// The cast roles of this slot nobody is cast in yet — each its own convocation, named by the
  /// role rather than by nobody.
  final Set<String> uncastRoleIds;

  /// The address-book guests attending this slot — the first half of `shooting_slot_guests`' own
  /// discriminator, resolving a guest's own `personId` being the caller's job, this file knowing
  /// nothing of that table.
  final Set<String> guestPersonIds;

  /// The free-named guests attending this slot — the discriminator's other half, each entry the
  /// guest's own verbatim `freeName`.
  final Set<String> guestFreeNames;

  /// Build a slot to feed to [ocptComputeDayConvocations].
  const OcptConvocationSlot({
    required this.id,
    required this.startMinute,
    required this.endMinute,
    required this.shootingStartMinute,
    required this.shootingEndMinute,
    required this.filmingStartMinute,
    required this.filmingEndMinute,
    required this.personIds,
    required this.uncastRoleIds,
    required this.guestPersonIds,
    required this.guestFreeNames,
  });

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [
    id,
    startMinute,
    endMinute,
    shootingStartMinute,
    shootingEndMinute,
    filmingStartMinute,
    filmingEndMinute,
    personIds,
    uncastRoleIds,
    guestPersonIds,
    guestFreeNames,
  ];
}
