// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/models/ocpt_call_sheet_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_call_sheet_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_day_out_of_days_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_day_out_of_days_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_one_line_schedule_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_one_line_schedule_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_xlsx_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_sides_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_sides_labels.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_agenda_color_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_agenda_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';

/// The events handled by `OcptScheduleBloc`.
sealed class OcptScheduleEvent extends BlocEventForMixin {
  /// Class constructor
  const OcptScheduleEvent();
}

/// Requests loading the current project's whole schedule read: the days with their slots, crew,
/// cast and blocks, the shot list (for the shots still to place and every placed block's own
/// label) and the resources catalogues (locations, roles, people) the inspector and the slot/cast
/// pickers read.
///
/// Dispatched once by the bloc's own constructor; it isn't meant to be sent by a widget.
class OcptScheduleLoadRequestedEvent extends OcptScheduleEvent {
  /// Class constructor
  const OcptScheduleLoadRequestedEvent();
}

/// Requests leaving the workspace: closes the current project and navigates back to the home page.
class OcptScheduleBackRequestedEvent extends OcptScheduleEvent {
  /// Class constructor
  const OcptScheduleBackRequestedEvent();
}

/// Toggles the left (days) dock's visibility.
class OcptScheduleLeftPanelToggledEvent extends OcptScheduleEvent {
  /// Class constructor
  const OcptScheduleLeftPanelToggledEvent();
}

/// Selects a tab of the right dock (the already-active tab closes the dock, any other one opens or
/// switches to it).
class OcptScheduleRightDockTabSelectedEvent extends OcptScheduleEvent {
  /// The tab to select.
  final OcptScheduleRightDockTab tab;

  /// Class constructor
  const OcptScheduleRightDockTabSelectedEvent({required this.tab});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, tab];
}

/// Toggles the right dock from the workspace toolbar: an open dock closes, a closed one reopens on
/// its last tab.
class OcptScheduleRightDockToggledEvent extends OcptScheduleEvent {
  /// Class constructor
  const OcptScheduleRightDockToggledEvent();
}

/// Closes the right dock via its own × close button.
class OcptScheduleRightDockClosedEvent extends OcptScheduleEvent {
  /// Class constructor
  const OcptScheduleRightDockClosedEvent();
}

/// Applies whichever dock fraction the ended drag gesture reports.
///
/// Only one of [left]/[right] is ever non-null per event, mirroring how the shell's own
/// `onDockFractionsChanged` callback is shaped. Unlike the other three modes' own version of this
/// event, the fraction is **not persisted**: `OcptPropertiesManager` is out of this milestone's
/// scope (see `OcptScheduleBloc`'s own doc comment), so the width only survives for the life of the
/// mode.
class OcptScheduleDockFractionsChangedEvent extends OcptScheduleEvent {
  /// The left dock's new fraction, or null when the drag was on the right divider.
  final double? left;

  /// The right dock's new fraction, or null when the drag was on the left divider.
  final double? right;

  /// Class constructor
  const OcptScheduleDockFractionsChangedEvent({required this.left, required this.right});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, left, right];
}

/// Restores both dock fractions to their defaults.
class OcptScheduleDockLayoutResetEvent extends OcptScheduleEvent {
  /// Class constructor
  const OcptScheduleDockLayoutResetEvent();
}

/// Selects day [dayId] in the left dock's own list, or on a strip/week/month cell, showing its own
/// read-out in the inspector. Clears both the selected block and the selected shot: a day selected
/// on its own has neither, and the day's own read-out is what the inspector must fall back to when
/// the user goes looking at a day — leaving a shot selected would silently keep it on screen
/// instead.
class OcptScheduleDaySelectedEvent extends OcptScheduleEvent {
  /// The id of the day to select.
  final String dayId;

  /// Class constructor
  const OcptScheduleDaySelectedEvent({required this.dayId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, dayId];
}

/// Selects block [blockId] — a placed shot's own strip chip, or one of a slot card's own timetable
/// rows — showing its own read-out in the inspector. Also selects [dayId], the block's own day, so
/// the left dock and the inspector stay in step, and clears the selected shot
/// (`OcptScheduleShotSelectedEvent`'s own doc comment): the two selections are mutually exclusive.
class OcptScheduleBlockSelectedEvent extends OcptScheduleEvent {
  /// The id of the block to select.
  final String blockId;

  /// The id of the day the block belongs to.
  final String dayId;

  /// Class constructor
  const OcptScheduleBlockSelectedEvent({required this.blockId, required this.dayId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, blockId, dayId];
}

/// Selects which of the two centre views (agenda or day) the mode shows, dispatched by the
/// header's own `Agenda`/`Day` switch.
class OcptScheduleCentreViewSelectedEvent extends OcptScheduleEvent {
  /// The view to select.
  final OcptScheduleCentreView view;

  /// Class constructor
  const OcptScheduleCentreViewSelectedEvent({required this.view});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, view];
}

/// Selects which of the three agenda presentations is shown, dispatched by the header's own
/// segmented control.
class OcptScheduleAgendaModeSelectedEvent extends OcptScheduleEvent {
  /// The presentation to select.
  final OcptScheduleAgendaMode mode;

  /// Class constructor
  const OcptScheduleAgendaModeSelectedEvent({required this.mode});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, mode];
}

/// Selects what fact the agenda tints a day with, dispatched by the header's own "Colour by"
/// segmented control.
class OcptScheduleAgendaColorModeSelectedEvent extends OcptScheduleEvent {
  /// The colour mode to select.
  final OcptScheduleAgendaColorMode mode;

  /// Class constructor
  const OcptScheduleAgendaColorModeSelectedEvent({required this.mode});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, mode];
}

/// Pages the week/month agenda to [date], dispatched by the week/month presentation's own
/// previous/next/today controls, once built. The new anchor date only, since it is the week or the
/// month **containing** [date] that is shown next — resolving that from the current
/// `OcptScheduleAgendaMode` is the widget's own job, not this event's.
class OcptScheduleAgendaAnchorDateChangedEvent extends OcptScheduleEvent {
  /// The date the week/month agenda now anchors on.
  final DateTime date;

  /// Class constructor
  const OcptScheduleAgendaAnchorDateChangedEvent({required this.date});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, date];
}

/// Creates a new shooting day dated [date], appended at the end of the schedule.
class OcptScheduleDayCreatedEvent extends OcptScheduleEvent {
  /// The new day's date.
  final DateTime date;

  /// Class constructor
  const OcptScheduleDayCreatedEvent({required this.date});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, date];
}

/// Writes a new date onto day [dayId] immediately, dispatched by the day inspector's own date
/// field.
class OcptScheduleDayDateChangedEvent extends OcptScheduleEvent {
  /// The id of the day being redated.
  final String dayId;

  /// The date just picked.
  final DateTime date;

  /// Class constructor
  const OcptScheduleDayDateChangedEvent({required this.dayId, required this.date});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, dayId, date];
}

/// Writes [kind] onto day [dayId], dispatched by the day inspector's own `Kind` picker.
///
/// Nothing else moves with it: the day keeps its slots, its blocks, its convocations and its
/// events, and its number is recounted — in the series it has just joined — by the reload that
/// follows, three separate series being what makes `J3` keep counting shooting days alone.
class OcptScheduleDayKindChangedEvent extends OcptScheduleEvent {
  /// The id of the day whose kind changed.
  final String dayId;

  /// The kind just picked.
  final OcptShootingDayKind kind;

  /// Class constructor
  const OcptScheduleDayKindChangedEvent({required this.dayId, required this.kind});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, dayId, kind];
}

/// Writes a new status onto day [dayId] immediately, dispatched by the day inspector's own status
/// control.
class OcptScheduleDayStatusChangedEvent extends OcptScheduleEvent {
  /// The id of the day whose status changed.
  final String dayId;

  /// The status just picked.
  final OcptShootingDayStatus status;

  /// Class constructor
  const OcptScheduleDayStatusChangedEvent({required this.dayId, required this.status});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, dayId, status];
}

/// Duplicates day [sourceDayId] into a new day dated [date], dispatched by the day card's own `⋮`
/// menu once its date picker resolved. Copies the source day's slots, crew and cast; copies
/// neither its placed shots nor its crew note (`OcptScheduleService.duplicateDay`'s own rule).
class OcptScheduleDayDuplicationRequestedEvent extends OcptScheduleEvent {
  /// The id of the day to duplicate.
  final String sourceDayId;

  /// The new day's date.
  final DateTime date;

  /// Class constructor
  const OcptScheduleDayDuplicationRequestedEvent({required this.sourceDayId, required this.date});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, sourceDayId, date];
}

/// Deletes day [dayId] for good — its slots, their crew and cast, and its blocks along with it —
/// dispatched by the mode once its `OcptConfirmDialog` (opened by the day card's own `⋮` menu) has
/// already been answered.
class OcptScheduleDayDeletionConfirmedEvent extends OcptScheduleEvent {
  /// The id of the day to delete.
  final String dayId;

  /// Class constructor
  const OcptScheduleDayDeletionConfirmedEvent({required this.dayId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, dayId];
}

/// Creates a new slot inside day [dayId], appended at the end of its current slots, dispatched by
/// the day view's own `+ Créneau` control, once built.
class OcptScheduleSlotCreatedEvent extends OcptScheduleEvent {
  /// The id of the day the new slot belongs to.
  final String dayId;

  /// Class constructor
  const OcptScheduleSlotCreatedEvent({required this.dayId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, dayId];
}

/// Writes a new location/set onto slot [slotId] immediately, dispatched by the slot card's own
/// location and set pickers, once built. Picking a location clears the set (a set belongs to one
/// location); [setId] is passed alongside [locationId] rather than derived from it, since only the
/// widget knows which of the two pickers was just answered.
class OcptScheduleSlotPlaceChangedEvent extends OcptScheduleEvent {
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

  /// Object properties
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
class OcptScheduleSlotAnchorChangedEvent extends OcptScheduleEvent {
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

  /// Object properties
  @override
  List<Object?> get props => [...super.props, slotId, edge, minute, sourceSlotId];
}

/// Moves slot [slotId] to [newPosition] (0-based) within its own day, dispatched by a slot-reorder
/// gesture, once built.
class OcptScheduleSlotReorderedEvent extends OcptScheduleEvent {
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

  /// Object properties
  @override
  List<Object?> get props => [...super.props, dayId, slotId, newPosition];
}

/// Deletes slot [slotId] for good, dispatched by the mode once its `OcptConfirmDialog` has already
/// been answered. A block sitting in the slot only loses its `slotId`
/// (`OcptScheduleService.deleteSlot`'s own rule) and keeps its place in the day.
class OcptScheduleSlotDeletionConfirmedEvent extends OcptScheduleEvent {
  /// The id of the slot to delete.
  final String slotId;

  /// Class constructor
  const OcptScheduleSlotDeletionConfirmedEvent({required this.slotId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, slotId];
}

/// Adds [personId] to slot [slotId]'s own crew, dispatched by the slot card's own `+ Crew member`
/// footer. The position is not carried here: `OcptScheduleService.addSlotCrewMember` pre-fills it
/// from what [personId] declared in the address book, and
/// `OcptScheduleSlotCrewMemberPositionChangedEvent` is what corrects it afterwards.
class OcptScheduleSlotCrewMemberAddedEvent extends OcptScheduleEvent {
  /// The id of the slot the crew member is added to.
  final String slotId;

  /// The id of the person added.
  final String personId;

  /// Class constructor
  const OcptScheduleSlotCrewMemberAddedEvent({required this.slotId, required this.personId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, slotId, personId];
}

/// Writes a new position onto crew assignment [crewMemberId] immediately, dispatched by the slot
/// card's own position picker.
class OcptScheduleSlotCrewMemberPositionChangedEvent extends OcptScheduleEvent {
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

  /// Object properties
  @override
  List<Object?> get props => [...super.props, crewMemberId, positionId, customLabel];
}

/// Removes crew assignment [crewMemberId] for good, dispatched by its own row's dismissal.
class OcptScheduleSlotCrewMemberRemovedEvent extends OcptScheduleEvent {
  /// The id of the crew assignment to remove.
  final String crewMemberId;

  /// Class constructor
  const OcptScheduleSlotCrewMemberRemovedEvent({required this.crewMemberId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, crewMemberId];
}

/// Convokes role [roleId] during slot [slotId], dispatched by the slot card's own `+ Cast` footer.
class OcptScheduleSlotCastRoleAddedEvent extends OcptScheduleEvent {
  /// The id of the slot the role is convoked to.
  final String slotId;

  /// The id of the role convoked.
  final String roleId;

  /// Class constructor
  const OcptScheduleSlotCastRoleAddedEvent({required this.slotId, required this.roleId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, slotId, roleId];
}

/// Removes cast convocation [castRoleId] for good, dispatched by its own row's dismissal.
class OcptScheduleSlotCastRoleRemovedEvent extends OcptScheduleEvent {
  /// The id of the cast convocation to remove.
  final String castRoleId;

  /// Class constructor
  const OcptScheduleSlotCastRoleRemovedEvent({required this.castRoleId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, castRoleId];
}

/// Convokes candidacy [roleCandidateId] on slot [slotId], dispatched by the candidates band's own
/// `+ Candidate` footer — the fourth kind of link a slot carries, and the one a casting day is
/// planned with (ADR 0018: you are convoked because you are linked to a slot).
///
/// It names a **candidacy**, never a person: the convocation is about somebody being seen *for a
/// part*, and one person seen for two parts on one day is two convocations.
class OcptScheduleSlotCandidateAddedEvent extends OcptScheduleEvent {
  /// The id of the slot the candidate is convoked on.
  final String slotId;

  /// The id of the candidacy convoked — who, for which part.
  final String roleCandidateId;

  /// Class constructor
  const OcptScheduleSlotCandidateAddedEvent({
    required this.slotId,
    required this.roleCandidateId,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, slotId, roleCandidateId];
}

/// Removes candidate convocation [slotCandidateId] for good, dispatched by its own row's dismissal.
///
/// **Touches no block**: an audition block naming that candidacy stays exactly where it is — see
/// `OcptScheduleService.removeSlotCandidate`.
class OcptScheduleSlotCandidateRemovedEvent extends OcptScheduleEvent {
  /// The id of the candidate convocation to remove.
  final String slotCandidateId;

  /// Class constructor
  const OcptScheduleSlotCandidateRemovedEvent({required this.slotCandidateId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, slotCandidateId];
}

/// Adds [personId] to slot [slotId]'s own guests, dispatched by the guest band's own `+ Guest`
/// footer — the address book alone, per Benoit's own decision: nobody is created from this mode, so
/// there is no free-named counterpart of this event.
class OcptScheduleSlotGuestAddedEvent extends OcptScheduleEvent {
  /// The id of the slot the guest is added to.
  final String slotId;

  /// The id of the person added.
  final String personId;

  /// Class constructor
  const OcptScheduleSlotGuestAddedEvent({required this.slotId, required this.personId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, slotId, personId];
}

/// Removes guest attendance [guestId] for good, dispatched by its own row's dismissal.
class OcptScheduleSlotGuestRemovedEvent extends OcptScheduleEvent {
  /// The id of the guest attendance to remove.
  final String guestId;

  /// Class constructor
  const OcptScheduleSlotGuestRemovedEvent({required this.guestId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, guestId];
}

/// Creates a new event on day [dayId] at [minute], dispatched by the day view's or the day
/// inspector's own `+ Event` footer (`OcptScheduleDayEventsList.onEventAdded`). [minute] is a
/// starting point the row's own minute field immediately corrects, never a claim about when
/// anything happens — see `OcptScheduleMode`'s own default-hour helper.
class OcptScheduleDayEventCreatedEvent extends OcptScheduleEvent {
  /// The id of the day the event is added to.
  final String dayId;

  /// The hour the event is first given.
  final int minute;

  /// Class constructor
  const OcptScheduleDayEventCreatedEvent({required this.dayId, required this.minute});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, dayId, minute];
}

/// Writes a new hour onto event [eventId], dispatched the moment its own minute field commits —
/// unlike every other event field, an event's hour is never typed into the field-edit debounce
/// (`OcptScheduleField` carries no minute entry), mirroring a slot's or a block's own anchor.
class OcptScheduleDayEventMinuteChangedEvent extends OcptScheduleEvent {
  /// The id of the event whose hour changed.
  final String eventId;

  /// The event's own new hour.
  final int minute;

  /// Class constructor
  const OcptScheduleDayEventMinuteChangedEvent({required this.eventId, required this.minute});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, eventId, minute];
}

/// Removes event [eventId] for good, dispatched once `OcptConfirmDialog` has confirmed it — named
/// for the confirmation it comes after, exactly as [OcptScheduleBlockDeletionConfirmedEvent] is.
class OcptScheduleDayEventDeletionConfirmedEvent extends OcptScheduleEvent {
  /// The id of the event to remove.
  final String eventId;

  /// Class constructor
  const OcptScheduleDayEventDeletionConfirmedEvent({required this.eventId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, eventId];
}

/// Selects shot [shotId] — a row of the left dock's own "shots still to place" list — showing its
/// own read-out in the inspector, and opens the right dock on the `Inspector` tab. Clears the
/// selected block: the two selections are mutually exclusive, so bringing a shot's own read-out up
/// would otherwise silently leave a stale block one showing underneath it. A [shotId] naming no live
/// shot is ignored, mirroring how `OcptScheduleBlockSelectedEvent` ignores an unknown day.
class OcptScheduleShotSelectedEvent extends OcptScheduleEvent {
  /// The id of the shot to select.
  final String shotId;

  /// Class constructor
  const OcptScheduleShotSelectedEvent({required this.shotId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, shotId];
}

/// Writes a new shooting status onto shot [shotId] immediately — the very column the shot list
/// mode's own inspector edits (`OcptShotListService.updateShot`'s `status`) — dispatched by that
/// shot's own block row's status control, in whichever slot card places it.
class OcptScheduleShotStatusChangedEvent extends OcptScheduleEvent {
  /// The id of the shot whose status changed.
  final String shotId;

  /// The status just picked.
  final OcptShotStatus status;

  /// Class constructor
  const OcptScheduleShotStatusChangedEvent({required this.shotId, required this.status});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, shotId, status];
}

/// Creates a new non-shot block (a milestone or a `hold`) inside slot [slotId], appended at the end
/// of that slot's own timetable, dispatched by that slot card's own `+ Block` control — the gesture
/// names the slot it sits on directly.
class OcptScheduleBlockCreatedEvent extends OcptScheduleEvent {
  /// The id of the slot the new block belongs to.
  final String slotId;

  /// The kind of block to create. Never [OcptShootingBlockKind.shot] — placing a shot goes through
  /// [OcptScheduleShotBlockCreatedEvent] instead, which is what carries its own `shotId`.
  final OcptShootingBlockKind kind;

  /// Class constructor
  const OcptScheduleBlockCreatedEvent({required this.slotId, required this.kind});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, slotId, kind];
}

/// Creates a new **shot** block inside slot [slotId], appended at the end of that slot's own
/// timetable, dispatched once the mode's own shot picker dialog — opened by that slot card's own
/// `+ Block` menu's `Shot` entry — resolves to a pick.
///
/// A **second event** rather than a `shotId` added to [OcptScheduleBlockCreatedEvent]: that event's
/// own [OcptScheduleBlockCreatedEvent.kind] can never be [OcptShootingBlockKind.shot] (see its own
/// doc comment), and giving it an optional `shotId` field that only ever accompanies that one kind
/// would let a caller build an event naming a kind and a shot id that disagree with each other — a
/// shape this event rules out by construction rather than one a handler would have to reject.
/// `OcptScheduleService.placeShot` always creates, never moves: a shot may legitimately be placed
/// more than once (interrupted by the meal break and resumed after it).
class OcptScheduleShotBlockCreatedEvent extends OcptScheduleEvent {
  /// The id of the slot the new block belongs to.
  final String slotId;

  /// The id of the shot being placed.
  final String shotId;

  /// Class constructor
  const OcptScheduleShotBlockCreatedEvent({required this.slotId, required this.shotId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, slotId, shotId];
}

/// Creates a new **audition** block inside slot [slotId], appended at the end of that slot's own
/// timetable, dispatched once the mode's own candidate picker dialog — opened by that slot card's
/// own `+ Block` menu's `Audition` entry — resolves to a pick.
///
/// A **third** event beside [OcptScheduleBlockCreatedEvent] and [OcptScheduleShotBlockCreatedEvent],
/// and for that second one's own reason: an audition names a candidacy and the part it is for, and
/// a kind that only ever accompanies those two ids is a shape better ruled out by construction than
/// rejected in a handler.
///
/// It carries the **candidacy** alone: the part is that candidacy's own `roleId`, and asking the
/// user for it twice — or letting an event name a pair that disagrees with itself — would be the
/// same mistake one step further on.
class OcptScheduleAuditionBlockCreatedEvent extends OcptScheduleEvent {
  /// The id of the slot the new block belongs to.
  final String slotId;

  /// The id of the candidacy being seen — who, for which part.
  final String roleCandidateId;

  /// Class constructor
  const OcptScheduleAuditionBlockCreatedEvent({
    required this.slotId,
    required this.roleCandidateId,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, slotId, roleCandidateId];
}

/// Writes a new duration onto block [blockId] immediately, dispatched by its own slot card's own ±
/// duration controls.
class OcptScheduleBlockDurationChangedEvent extends OcptScheduleEvent {
  /// The id of the block being edited.
  final String blockId;

  /// The block's own new duration, in minutes, or null to fall back to a shot's own estimate (or
  /// the mode's own default).
  final int? durationMinutes;

  /// Class constructor
  const OcptScheduleBlockDurationChangedEvent({required this.blockId, required this.durationMinutes});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, blockId, durationMinutes];
}

/// Writes a new anchor onto block [blockId] immediately, dispatched by its own slot card's own
/// anchor pin.
class OcptScheduleBlockAnchorChangedEvent extends OcptScheduleEvent {
  /// The id of the block being edited.
  final String blockId;

  /// The minute, from the day's own midnight, the block is now pinned to, or null to unpin it.
  final int? anchorMinute;

  /// Class constructor
  const OcptScheduleBlockAnchorChangedEvent({required this.blockId, required this.anchorMinute});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, blockId, anchorMinute];
}

/// Writes a new sequence onto **hold** block [blockId] immediately, dispatched by its own timetable
/// row's sequence picker — the control that finally fills `shooting_day_blocks.sceneId`, which says
/// which roles a held sequence calls for (its free-text label never could).
class OcptScheduleBlockSequenceChangedEvent extends OcptScheduleEvent {
  /// The id of the hold block being edited.
  final String blockId;

  /// The id of the scene just picked, or null to clear it back to "no sequence yet".
  final String? sceneId;

  /// Class constructor
  const OcptScheduleBlockSequenceChangedEvent({required this.blockId, required this.sceneId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, blockId, sceneId];
}

/// Moves block [blockId] to [newPosition] (0-based) within its own slot's timetable, dispatched by
/// a drag-to-reorder gesture on that slot card's own timetable. The block's own slot is read off
/// its own row (`OcptScheduleService.reorderBlock`), so no slot or day id travels with this event.
class OcptScheduleBlockReorderedEvent extends OcptScheduleEvent {
  /// The id of the block to reorder.
  final String blockId;

  /// The 0-based position the block is moved to.
  final int newPosition;

  /// Class constructor
  const OcptScheduleBlockReorderedEvent({required this.blockId, required this.newPosition});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, blockId, newPosition];
}

/// Moves block [blockId] to slot [targetSlotId], appended at the end of that slot's own timetable,
/// dispatched either by dragging a row out of one slot card's own timetable onto another's, or by
/// picking an entry of the block's own `Move to…` menu (M2').
class OcptScheduleBlockMovedToSlotEvent extends OcptScheduleEvent {
  /// The id of the block to move.
  final String blockId;

  /// The id of the slot it is moved to.
  final String targetSlotId;

  /// Class constructor
  const OcptScheduleBlockMovedToSlotEvent({required this.blockId, required this.targetSlotId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, blockId, targetSlotId];
}

/// Deletes block [blockId] for good, whatever its kind, dispatched by the mode once its
/// `OcptConfirmDialog` has already been answered.
class OcptScheduleBlockDeletionConfirmedEvent extends OcptScheduleEvent {
  /// The id of the block to delete.
  final String blockId;

  /// Class constructor
  const OcptScheduleBlockDeletionConfirmedEvent({required this.blockId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, blockId];
}

/// Records the raw text just typed into [field] of entity [targetId] as a pending edit, dispatched
/// on every keystroke into a day/slot/block/crew/cast/group free-text field — rides
/// `OcptScheduleBloc`'s own 2 s field-edit debounce.
class OcptScheduleFieldChangedEvent extends OcptScheduleEvent {
  /// The id of the entity being edited (a day, a slot, a block, a crew assignment, a cast
  /// convocation or a group, according to [field]).
  final String targetId;

  /// Which field is being edited.
  final OcptScheduleField field;

  /// The field's raw text, as typed.
  final String rawValue;

  /// Class constructor
  const OcptScheduleFieldChangedEvent({
    required this.targetId,
    required this.field,
    required this.rawValue,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, targetId, field, rawValue];
}

/// Fired by the field-edit debounce timer once it elapses with no further typing: writes every
/// pending field edit. Not meant to be dispatched by a widget; the bloc dispatches it itself.
class OcptScheduleFieldEditFlushRequestedEvent extends OcptScheduleEvent {
  /// Class constructor
  const OcptScheduleFieldEditFlushRequestedEvent();
}

/// Re-reads the page setup after the project settings page changed something, so the three export
/// dialogs pre-fill from the page format actually in effect — mirrors `OcptShotListBloc`'s own
/// handler for the very same reason.
class OcptScheduleProjectSettingsChangedEvent extends OcptScheduleEvent {
  /// Class constructor
  const OcptScheduleProjectSettingsChangedEvent();
}

/// Requests exporting the general call sheets of [options]' own days, one PDF per day, into a
/// folder the user picks — dispatched once `OcptScheduleCallSheetsExportDialog` returns its result.
class OcptScheduleCallSheetsExportRequestedEvent extends OcptScheduleEvent {
  /// The one-off options the export runs with (the page format/margins and which days to print).
  final OcptCallSheetExportOptions options;

  /// Every localized string the exported documents carry.
  final OcptCallSheetLabels labels;

  /// The localized label of the native "choose a folder" dialog's own confirm button.
  final String confirmButtonText;

  /// Class constructor
  const OcptScheduleCallSheetsExportRequestedEvent({
    required this.options,
    required this.labels,
    required this.confirmButtonText,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, options, labels, confirmButtonText];
}

/// Requests exporting the named call sheets of [options]' own days, one PDF per (selected
/// convocation × day), into a folder the user picks — dispatched once
/// `OcptScheduleNamedCallSheetsExportDialog` returns its result.
class OcptScheduleNamedCallSheetsExportRequestedEvent extends OcptScheduleEvent {
  /// The one-off options the export runs with: the page format/margins, the days to print
  /// ([OcptCallSheetExportOptions.dayIds]) and which of their own convocations are printed —
  /// [OcptCallSheetExportOptions.selectedConvocationKeys] being the union over every day named here,
  /// so a key convoked on only one of them yields one file, not one per day.
  final OcptCallSheetExportOptions options;

  /// Every localized string the exported documents carry.
  final OcptCallSheetLabels labels;

  /// The localized label of the native "choose a folder" dialog's own confirm button.
  final String confirmButtonText;

  /// Class constructor
  const OcptScheduleNamedCallSheetsExportRequestedEvent({
    required this.options,
    required this.labels,
    required this.confirmButtonText,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, options, labels, confirmButtonText];
}

/// Requests exporting the whole-shoot shooting plan of [options]' own days as a single PDF, written
/// through the native save dialog — dispatched once `OcptScheduleShootingPlanExportDialog` returns
/// its result.
class OcptScheduleShootingPlanExportRequestedEvent extends OcptScheduleEvent {
  /// The one-off options the export runs with (the page format/margins, which days to print, and
  /// the title page/summary grid toggles).
  final OcptShootingPlanExportOptions options;

  /// Every localized string the exported document carries.
  final OcptShootingPlanLabels labels;

  /// The localized label passed to the native save dialog's own type filter.
  final String fileTypeLabel;

  /// Class constructor
  const OcptScheduleShootingPlanExportRequestedEvent({
    required this.options,
    required this.labels,
    required this.fileTypeLabel,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, options, labels, fileTypeLabel];
}

/// Requests exporting the whole-shoot shooting plan's own **workbook** of [options]' own days as a
/// single XLSX file, written through the native save dialog — dispatched once
/// `OcptScheduleShootingPlanXlsxExportDialog` returns its result. The workbook sibling of
/// [OcptScheduleShootingPlanExportRequestedEvent].
class OcptScheduleShootingPlanXlsxExportRequestedEvent extends OcptScheduleEvent {
  /// The one-off options the export runs with — which days to print, and nothing else.
  final OcptShootingPlanXlsxExportOptions options;

  /// Every localized string the exported workbook carries.
  final OcptShootingPlanXlsxLabels labels;

  /// The localized label passed to the native save dialog's own type filter.
  final String fileTypeLabel;

  /// Class constructor
  const OcptScheduleShootingPlanXlsxExportRequestedEvent({
    required this.options,
    required this.labels,
    required this.fileTypeLabel,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, options, labels, fileTypeLabel];
}

/// Requests exporting the cast's own *Day Out of Days* over [options]' own days as a single PDF,
/// written through the native save dialog — dispatched once
/// `OcptScheduleDayOutOfDaysExportDialog` returns its result.
class OcptScheduleDayOutOfDaysExportRequestedEvent extends OcptScheduleEvent {
  /// The one-off options the export runs with (the page format/margins, which days the table
  /// crosses, and the title page toggle).
  final OcptDayOutOfDaysExportOptions options;

  /// Every localized string the exported document carries.
  final OcptDayOutOfDaysLabels labels;

  /// The localized label passed to the native save dialog's own type filter.
  final String fileTypeLabel;

  /// Class constructor
  const OcptScheduleDayOutOfDaysExportRequestedEvent({
    required this.options,
    required this.labels,
    required this.fileTypeLabel,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, options, labels, fileTypeLabel];
}

/// Requests exporting the one-line schedule over `options.dayIds` as a single PDF, written through
/// the native save dialog — dispatched once `OcptScheduleOneLineScheduleExportDialog` returns its
/// result.
class OcptScheduleOneLineScheduleExportRequestedEvent extends OcptScheduleEvent {
  /// The one-off options the export runs with (the page format/margins, which days to print, and
  /// the title page toggle).
  final OcptOneLineScheduleExportOptions options;

  /// Every localized string the exported document carries.
  final OcptOneLineScheduleLabels labels;

  /// The localized label passed to the native save dialog's own type filter.
  final String fileTypeLabel;

  /// Class constructor
  const OcptScheduleOneLineScheduleExportRequestedEvent({
    required this.options,
    required this.labels,
    required this.fileTypeLabel,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, options, labels, fileTypeLabel];
}

/// Requests exporting `options.dayId`'s own sides booklet as a single PDF, written through the
/// native save dialog — dispatched once `OcptScheduleSidesExportDialog` returns its result.
class OcptScheduleSidesExportRequestedEvent extends OcptScheduleEvent {
  /// The one-off options the export runs with (the page format/margins, the one day printed, the
  /// scene-numbers toggle and the presentation).
  final OcptSidesExportOptions options;

  /// Every localized string the exported booklet carries.
  final OcptSidesLabels labels;

  /// The localized label passed to the native save dialog's own type filter.
  final String fileTypeLabel;

  /// Class constructor
  const OcptScheduleSidesExportRequestedEvent({
    required this.options,
    required this.labels,
    required this.fileTypeLabel,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, options, labels, fileTypeLabel];
}

/// Clears the transient export notice currently shown, if any.
class OcptScheduleIoNoticeDismissedEvent extends OcptScheduleEvent {
  /// Class constructor
  const OcptScheduleIoNoticeDismissedEvent();
}
