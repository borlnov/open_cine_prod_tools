// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/events/schedule_base_event.dart';

/// The events about a day's slots and what a slot convokes.
sealed class OcptScheduleSlotsEvent extends OcptScheduleEvent {
  /// Class constructor
  const OcptScheduleSlotsEvent();
}

/// Creates a new slot inside day [dayId], appended at the end of its current slots, dispatched by
/// the day view's own `+ Créneau` control, once built.
class OcptScheduleSlotCreatedEvent extends OcptScheduleSlotsEvent {
  /// The id of the day the new slot belongs to.
  final String dayId;

  /// Class constructor
  const OcptScheduleSlotCreatedEvent({required this.dayId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, dayId];
}

/// Writes a new location/set onto slot [slotId] immediately, dispatched by the slot card's own
/// location and set pickers, once built. Picking a location clears the set (a set belongs to one
/// location); [setId] is passed alongside [locationId] rather than derived from it, since only the
/// widget knows which of the two pickers was just answered.
class OcptScheduleSlotPlaceChangedEvent extends OcptScheduleSlotsEvent {
  /// The id of the slot being placed.
  final String slotId;

  /// The location just picked, or null to clear it.
  final String? locationId;

  /// The set just picked, or null to clear it.
  final String? setId;

  /// Class constructor
  const OcptScheduleSlotPlaceChangedEvent({
    required this.slotId,
    required this.locationId,
    required this.setId,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, slotId, locationId, setId];
}

/// Pins slot [slotId]'s own [edge] immediately, dispatched by the slot card's own anchor menu and
/// by the minute field beside it — the one hour a slot carries, everything else a call sheet prints
/// for it being computed off that (ADR 0015, amended a second time).
///
/// **Exactly one of [minute] and [sourceSlotId] is non-null**, the discriminator
/// `OcptShootingSlotsTable` declares: a typed hour, or the slot whose **opposite** edge this one
/// reads. `OcptScheduleService.setSlotAnchor` writes nothing at all for anything else, and for a
/// link that isn't a live slot of the same day or would close a circle of anchors.
class OcptScheduleSlotAnchorChangedEvent extends OcptScheduleSlotsEvent {
  /// The id of the slot being edited.
  final String slotId;

  /// Which of the slot's two edges is now the pinned one.
  final OcptShootingSlotAnchorEdge edge;

  /// The hour [edge] is pinned to, or null when [sourceSlotId] is given instead.
  final int? minute;

  /// The slot whose opposite edge [edge] now reads, or null when [minute] is given instead.
  final String? sourceSlotId;

  /// Class constructor
  const OcptScheduleSlotAnchorChangedEvent({
    required this.slotId,
    required this.edge,
    required this.minute,
    required this.sourceSlotId,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, slotId, edge, minute, sourceSlotId];
}

/// Moves slot [slotId] to [newPosition] (0-based) within its own day, dispatched by a slot-reorder
/// gesture, once built.
class OcptScheduleSlotReorderedEvent extends OcptScheduleSlotsEvent {
  /// The id of the day the slot belongs to.
  final String dayId;

  /// The id of the slot to reorder.
  final String slotId;

  /// The 0-based position the slot is moved to.
  final int newPosition;

  /// Class constructor
  const OcptScheduleSlotReorderedEvent({
    required this.dayId,
    required this.slotId,
    required this.newPosition,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, dayId, slotId, newPosition];
}

/// Deletes slot [slotId] for good, dispatched by the mode once its `OcptConfirmDialog` has already
/// been answered. A block sitting in the slot only loses its `slotId`
/// (`OcptScheduleService.deleteSlot`'s own rule) and keeps its place in the day.
class OcptScheduleSlotDeletionConfirmedEvent extends OcptScheduleSlotsEvent {
  /// The id of the slot to delete.
  final String slotId;

  /// Class constructor
  const OcptScheduleSlotDeletionConfirmedEvent({required this.slotId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, slotId];
}

/// Adds [personId] to slot [slotId]'s own crew, dispatched by the slot card's own `+ Crew member`
/// footer. The position is not carried here: `OcptScheduleService.addSlotCrewMember` pre-fills it
/// from what [personId] declared in the address book, and
/// `OcptScheduleSlotCrewMemberPositionChangedEvent` is what corrects it afterwards.
class OcptScheduleSlotCrewMemberAddedEvent extends OcptScheduleSlotsEvent {
  /// The id of the slot the crew member is added to.
  final String slotId;

  /// The id of the person added.
  final String personId;

  /// Class constructor
  const OcptScheduleSlotCrewMemberAddedEvent({required this.slotId, required this.personId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, slotId, personId];
}

/// Writes a new position onto crew assignment [crewMemberId] immediately, dispatched by the slot
/// card's own position picker.
class OcptScheduleSlotCrewMemberPositionChangedEvent extends OcptScheduleSlotsEvent {
  /// The id of the crew assignment being edited.
  final String crewMemberId;

  /// The `ocptCrewPositions` id just picked, or the empty string when [customLabel] is set
  /// instead — exactly one of the two, the discriminator `shooting_slot_crew` already models.
  final String positionId;

  /// The free-text label just picked (a person's own declared free-label position), or the empty
  /// string when [positionId] is set instead.
  final String customLabel;

  /// Class constructor
  const OcptScheduleSlotCrewMemberPositionChangedEvent({
    required this.crewMemberId,
    required this.positionId,
    required this.customLabel,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, crewMemberId, positionId, customLabel];
}

/// Removes crew assignment [crewMemberId] for good, dispatched by its own row's dismissal.
class OcptScheduleSlotCrewMemberRemovedEvent extends OcptScheduleSlotsEvent {
  /// The id of the crew assignment to remove.
  final String crewMemberId;

  /// Class constructor
  const OcptScheduleSlotCrewMemberRemovedEvent({required this.crewMemberId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, crewMemberId];
}

/// Convokes role [roleId] during slot [slotId], dispatched by the slot card's own `+ Cast` footer.
class OcptScheduleSlotCastRoleAddedEvent extends OcptScheduleSlotsEvent {
  /// The id of the slot the role is convoked to.
  final String slotId;

  /// The id of the role convoked.
  final String roleId;

  /// Class constructor
  const OcptScheduleSlotCastRoleAddedEvent({required this.slotId, required this.roleId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, slotId, roleId];
}

/// Removes cast convocation [castRoleId] for good, dispatched by its own row's dismissal.
class OcptScheduleSlotCastRoleRemovedEvent extends OcptScheduleSlotsEvent {
  /// The id of the cast convocation to remove.
  final String castRoleId;

  /// Class constructor
  const OcptScheduleSlotCastRoleRemovedEvent({required this.castRoleId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, castRoleId];
}

/// Adds [personId] to slot [slotId]'s own guests, dispatched by the guest band's own `+ Guest`
/// footer — the address book alone, per Benoit's own decision: nobody is created from this mode, so
/// there is no free-named counterpart of this event.
class OcptScheduleSlotGuestAddedEvent extends OcptScheduleSlotsEvent {
  /// The id of the slot the guest is added to.
  final String slotId;

  /// The id of the person added.
  final String personId;

  /// Class constructor
  const OcptScheduleSlotGuestAddedEvent({required this.slotId, required this.personId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, slotId, personId];
}

/// Removes guest attendance [guestId] for good, dispatched by its own row's dismissal.
class OcptScheduleSlotGuestRemovedEvent extends OcptScheduleSlotsEvent {
  /// The id of the guest attendance to remove.
  final String guestId;

  /// Class constructor
  const OcptScheduleSlotGuestRemovedEvent({required this.guestId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, guestId];
}
