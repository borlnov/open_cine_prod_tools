// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_crew_position_ref.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_candidate.dart';
import 'package:open_cine_prod_tools/models/ocpt_set.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_slot_timeline.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_slot_anchor_control.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_slot_cast_column.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_slot_crew_section.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_slot_guest_band.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_slot_note_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_slot_people.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_timetable.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_schedule_labels.dart';

/// The value the "no location" entry of the location picker menu carries, distinct from every
/// location id — a [PopupMenuButton] cannot carry a null value for an entry that must still be
/// selectable.
const String _noLocationOption = "";

/// The header width under which a linked anchor reads as `⛓ <slot>` rather than as the whole
/// sentence — the inspector opening beside the day view is what usually takes a card below it.
const double _compactHeaderWidth = 460;

/// One slot's own card in the day view: its `▲`/`▼` reorder pair, its label, its location and set,
/// its own note below them — what this slot alone needs saying, the day's own note to the crew
/// being a different thing — its own **anchored edge** — the one hour a slot is pinned by, with the
/// computed opposite edge read out under it — then the whole of **who is on this slot**
/// ([OcptScheduleSlotPeople]) — and, below it, this slot's **own** [OcptScheduleTimetable]: a day
/// used to carry one timetable shared by every slot; now each card draws its own, over its own
/// [blocks] alone, chained by its own [timeline].
///
/// **The three kinds of person sit under one foldable section**, `Assigner des personnes`: a row of
/// two halves, `Équipe technique` (grouped by department — see [OcptScheduleSlotCrewSection]) and
/// `Comédiens`, then a full-width `Invités` band under them, each ending on its own
/// `+ Crew member`/`+ Cast`/`+ Guest` footer opening a person or role picker right there on the
/// card, with no duplicate list anywhere in the right dock. **Only the section's own title folds**,
/// and it folds all three at once: a settled crew, cast and guest list are entered once and then
/// read past for the rest of the shoot, and the point of the fold is to get to the timetable — so
/// one gesture answers for the three rather than each of them needing its own, the three subsection
/// titles being plain read-outs. Neither of the two people halves is ever handed more than half the
/// card's own body width, and every crew or cast card within its own half wraps at a
/// fixed width (shrunk to fit when that half is narrower), so a wide day view flows several
/// cards per row instead of leaving the sides empty — the guest band wraps the same cards over the
/// card's **whole** width instead, not being split into halves.
///
/// **A crew or cast row says only who is convoked and in what function** (ADR 0018): a convocation
/// is a fact about a person on a **day**, joined across every slot they sit on, so it cannot be
/// read from one slot's card in isolation — the computed arrival/PAT/departure that used to sit
/// here move to the day's own convocations panel instead. A guest card carries **no clock at all**
/// either, for the same reason. The one editable clock on the whole card is the slot's own anchor
/// ([onAnchorChanged]).
///
/// **The guest band is always drawn**, empty hint and all, exactly as the two people halves are: a
/// slot's guests are one of the three answers to "who is on this unit", and a band that had to be
/// revealed from the `⋮` menu before it could be filled hid the very affordance somebody looking
/// for it was after.
///
/// **No candidate band sits beside them**, and deliberately: somebody seen for a part is expected
/// at twenty past ten rather than "on this unit today", so they are named on the **audition block**
/// that sees them, in this card's own timetable, and nowhere else (ADR 0024). A band saying
/// otherwise, beside the row that says it precisely, would be one band too many.
///
/// **The anchor control is a flat menu on the edge label** (`Début à heure fixe`, `Fin à heure
/// fixe`, then one entry per other slot of the day, in both directions), with the typed hour beside
/// it and the computed opposite edge under it. An entry that would close a circle of anchors is
/// shown **disabled with its reason** rather than left out — in a menu this short, a missing entry
/// reads as a bug — and picking a fixed-hour entry while the edge is linked **freezes the hour it
/// was reading at that moment**, rather than emptying the field or resurrecting a stale value. A
/// linked edge's button carries the whole sentence, falling back to `⛓ <slot>` with the sentence in
/// its tooltip once the card narrows.
///
/// Every writing affordance is a nullable callback, withheld while a project version is being
/// previewed (`isReadOnly`): the label field, the location/set pickers, the note field below them,
/// the anchor menu and its own minute field, the `▲`/`▼` controls moving the card in its day's
/// list, every
/// crew/cast row's own position picker and remove control, every guest row's own remove control and
/// its own reason/notes fields, every audition row's own candidacy chips and picker, all three `+`
/// footers, and every writing affordance of the timetable itself, its own hold row's sequence
/// picker included (see [OcptScheduleTimetable]'s own doc comment). Nothing here reads a
/// `pendingFieldEdits` map itself — [labelValue] is already resolved by the caller, exactly as
/// every other mode's own sheet fields are.
class OcptScheduleSlotCard extends StatelessWidget {
  /// The slot this card shows.
  final OcptShootingSlot slot;

  /// [slot]'s own location, or null while none is chosen.
  final OcptLocation? location;

  /// [slot]'s own set, or null while none is chosen.
  final OcptSet? set;

  /// The whole location catalogue (with their sets) — what the location/set pickers offer.
  final List<OcptLocation> locations;

  /// The whole address book, keyed by id — what a crew row's own name is read off.
  final Map<String, OcptPerson> personById;

  /// Every live candidacy of the project, keyed by id — what this card's timetable's own audition
  /// rows name a person and a part through.
  final Map<String, OcptRoleCandidate> roleCandidateById;

  /// The whole cast, keyed by id — what a cast row's own name is read off.
  final Map<String, OcptRole> roleById;

  /// The whole address book, in display order — what the `+ Crew member` picker offers.
  final List<OcptPerson> people;

  /// The whole cast, in display order — what the timetable's audition rows read a part's name off
  /// and group their candidate picker by, and what the `+ Cast` picker offers once the roles [slot]
  /// already convokes are left out of it.
  ///
  /// Kept whole rather than pre-filtered for the `+ Cast` picker: an audition for a part the slot
  /// also convokes must still offer that part's candidates.
  final List<OcptRole> roles;

  /// [slot]'s own label, as currently held (a pending edit, or its stored value).
  final String labelValue;

  /// Called with the label's raw text on every keystroke, or null while withheld.
  final ValueChanged<String>? onLabelChanged;

  /// [slot]'s own notes, as currently held (a pending edit, or its stored value).
  final String notesValue;

  /// Called with the note's raw text on every keystroke, or null while withheld.
  final ValueChanged<String>? onNotesChanged;

  /// Called with the location and set just picked, or null while withheld.
  final void Function(String? locationId, String? setId)? onPlaceChanged;

  /// Called with the slot's own new anchor once picked or committed, or null while withheld:
  /// which edge is pinned, and then **exactly one** of the typed hour and the slot whose opposite
  /// edge it reads — the discriminator `OcptShootingSlotsTable` declares.
  final void Function(OcptShootingSlotAnchorEdge edge, int? minute, String? sourceSlotId)?
  onAnchorChanged;

  /// Every live slot of this slot's own day mapped to the id its own anchor currently reads, or
  /// null when that anchor is a typed hour — what the anchor menu greys a circular entry out with
  /// (`ocptSlotAnchorWouldCycle`).
  final Map<String, String?> anchorSourceBySlotId;

  /// Called when the card's own `▲` control is clicked, or null when this slot cannot move up (it
  /// is its day's first) or the affordance is withheld. **The pair is drawn as soon as either of
  /// the two is non-null**, the one that is null reading as a disabled control rather than
  /// disappearing: a column of cards whose arrows shift about from one card to the next is harder
  /// to aim at than one greyed arrow.
  final VoidCallback? onMovedUp;

  /// Called when the card's own `▼` control is clicked, or null when this slot cannot move down (it
  /// is its day's last) or the affordance is withheld — see [onMovedUp].
  final VoidCallback? onMovedDown;

  /// Called when the `Delete this slot…` action is picked, or null while withheld.
  final VoidCallback? onDeletionRequested;

  /// Called with the id of the person picked by the `+ Crew member` footer, or null while withheld.
  final ValueChanged<String>? onCrewMemberAdded;

  /// Called with a crew assignment's id and the position just picked — a declared one promoted by
  /// [OcptScheduleSlotCrewSection] or a catalogue entry — or null while withheld.
  final void Function(String crewMemberId, OcptCrewPositionRef position)?
  onCrewMemberPositionChanged;

  /// Called with a crew assignment's id when its row's remove control is clicked, or null while
  /// withheld.
  final ValueChanged<String>? onCrewMemberRemoved;

  /// Called with the id of the role picked by the `+ Cast` footer, or null while withheld.
  final ValueChanged<String>? onCastRoleAdded;

  /// Called with a cast convocation's id when its row's remove control is clicked, or null while
  /// withheld.
  final ValueChanged<String>? onCastRoleRemoved;

  /// Called with the id of the person picked by the guest band's own `+ Guest` footer, or null
  /// while withheld — also what gates the `⋮` menu's own `Add a guest` entry (see the class doc
  /// comment).
  final ValueChanged<String>? onGuestAdded;

  /// Called with a guest attendance's id when its row's remove control is clicked, or null while
  /// withheld.
  final ValueChanged<String>? onGuestRemoved;

  /// Resolves a guest attendance's id to its own reason, as currently held (a pending edit, or its
  /// stored value).
  final String Function(String guestId) guestReasonValueOf;

  /// Called with a guest attendance's id and its raw reason text on every keystroke, or null while
  /// withheld.
  final void Function(String guestId, String rawValue)? onGuestReasonChanged;

  /// Resolves a guest attendance's id to its own notes, as currently held (a pending edit, or its
  /// stored value).
  final String Function(String guestId) guestNotesValueOf;

  /// Called with a guest attendance's id and its raw note text on every keystroke, or null while
  /// withheld.
  final void Function(String guestId, String rawValue)? onGuestNotesChanged;

  /// [slot]'s own **day**'s live blocks, across every slot, in `sortKey` order — this card filters
  /// them down to [slot]'s own before handing them to its own [OcptScheduleTimetable], so a caller
  /// never has to pre-slice the day's blocks itself.
  final List<OcptShootingDayBlock> blocks;

  /// [slot]'s own computed timeline, or null while it has nothing placed yet.
  final OcptShootingSlotTimeline? timeline;

  /// Resolves a shot id to the shot it names.
  final OcptShot? Function(String shotId) shotOf;

  /// The id of the currently selected block, or null while none is.
  final String? selectedBlockId;

  /// Every real scene of the screenplay's shot list — what a **hold** row's own timetable sequence
  /// picker offers. See [OcptScheduleTimetable.sequences].
  final List<OcptSceneShotSequence> sequences;

  /// The day's own other live slots, by id and by raw label — see
  /// [OcptScheduleTimetable.otherSlots].
  final List<(String, String)> otherSlots;

  /// Called with a block's id when its row is clicked.
  final ValueChanged<String> onBlockSelected;

  /// Called with a block's id and its 0-based new position once a drag-to-reorder gesture ends
  /// within this slot, or null while withheld.
  final void Function(String blockId, int newPosition)? onBlockReordered;

  /// Called with a block's id and its own new duration once a `±` control is tapped, or null while
  /// withheld.
  final void Function(String blockId, int durationMinutes)? onBlockDurationChanged;

  /// Called with a block's id and its own new anchor once the pin is toggled, or null while
  /// withheld.
  final void Function(String blockId, int? anchorMinute)? onBlockAnchorChanged;

  /// Called with a shot block's own shot id and the status just picked, or null while withheld.
  final void Function(String shotId, OcptShotStatus status)? onShotStatusChanged;

  /// Called with a **hold** block's id and the scene just picked from its own timetable row's
  /// sequence picker, or null while withheld — see [OcptScheduleTimetable.onHoldSequenceChanged].
  final void Function(String blockId, String? sceneId)? onBlockSequenceChanged;

  /// Called with an **audition** block's id and the id of the candidacy just picked from its own
  /// timetable row's `+` picker, or null while withheld — see
  /// [OcptScheduleTimetable.onCandidateAdded].
  final void Function(String blockId, String roleCandidateId)? onBlockCandidateAdded;

  /// Called with a candidacy convocation's own id when its chip's remove control is clicked, or
  /// null while withheld — see [OcptScheduleTimetable.onCandidateRemoved].
  final ValueChanged<String>? onBlockCandidateRemoved;

  /// Called with a block's id when its own remove control is clicked, or null while withheld.
  final ValueChanged<String>? onBlockDeletionRequested;

  /// Called with the kind just picked from the timetable's own `+ Block` menu — the new block lands
  /// in **this** slot — or null while withheld.
  final ValueChanged<OcptShootingBlockKind>? onBlockAdded;

  /// Called when the timetable's own `+ Block` menu's `Shot` entry is picked, or null while
  /// withheld — see [OcptScheduleTimetable.onShotBlockRequested].
  final VoidCallback? onShotBlockRequested;

  /// Called with a block's id and the id of the slot it is moved to, or null while withheld — see
  /// [OcptScheduleTimetable.onBlockMovedToSlot].
  final void Function(String blockId, String targetSlotId)? onBlockMovedToSlot;

  /// Class constructor
  const OcptScheduleSlotCard({
    super.key,
    required this.slot,
    required this.location,
    required this.set,
    required this.locations,
    required this.personById,
    required this.roleCandidateById,
    required this.roleById,
    required this.people,
    required this.roles,
    required this.labelValue,
    required this.onLabelChanged,
    required this.notesValue,
    required this.onNotesChanged,
    required this.onPlaceChanged,
    required this.onAnchorChanged,
    required this.anchorSourceBySlotId,
    required this.onMovedUp,
    required this.onMovedDown,
    required this.onDeletionRequested,
    required this.onCrewMemberAdded,
    required this.onCrewMemberPositionChanged,
    required this.onCrewMemberRemoved,
    required this.onCastRoleAdded,
    required this.onCastRoleRemoved,
    required this.onGuestAdded,
    required this.onGuestRemoved,
    required this.guestReasonValueOf,
    required this.onGuestReasonChanged,
    required this.guestNotesValueOf,
    required this.onGuestNotesChanged,
    required this.blocks,
    required this.timeline,
    required this.shotOf,
    required this.selectedBlockId,
    required this.sequences,
    required this.otherSlots,
    required this.onBlockSelected,
    required this.onBlockReordered,
    required this.onBlockDurationChanged,
    required this.onBlockAnchorChanged,
    required this.onShotStatusChanged,
    required this.onBlockSequenceChanged,
    required this.onBlockCandidateAdded,
    required this.onBlockCandidateRemoved,
    required this.onBlockDeletionRequested,
    required this.onBlockAdded,
    required this.onShotBlockRequested,
    required this.onBlockMovedToSlot,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final tint = ocptScheduleDayLocationTint(context, location);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusMedium),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: theme.colorScheme.surfaceContainer,
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
            child: LayoutBuilder(
              builder: (context, constraints) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (onMovedUp != null || onMovedDown != null)
                    _MoveControls(onMovedUp: onMovedUp, onMovedDown: onMovedDown),
                  Container(
                    width: 4,
                    constraints: const BoxConstraints(minHeight: 30),
                    decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: _HeaderFields(
                      slot: slot,
                      location: location,
                      set: set,
                      locations: locations,
                      labelValue: labelValue,
                      onLabelChanged: onLabelChanged,
                      notesValue: notesValue,
                      onNotesChanged: onNotesChanged,
                      onPlaceChanged: onPlaceChanged,
                    ),
                  ),
                  const SizedBox(width: 11),
                  OcptScheduleSlotAnchorControl(
                    slot: slot,
                    timeline: timeline,
                    otherSlots: otherSlots,
                    anchorSourceBySlotId: anchorSourceBySlotId,
                    isCompact: constraints.maxWidth < _compactHeaderWidth,
                    onAnchorChanged: onAnchorChanged,
                  ),
                  if (onDeletionRequested != null)
                    PopupMenuButton<VoidCallback>(
                      icon: const Icon(Icons.more_vert, size: 16),
                      tooltip: "",
                      padding: EdgeInsets.zero,
                      onSelected: (action) => action(),
                      itemBuilder: (context) => [
                        PopupMenuItem<VoidCallback>(
                          value: onDeletionRequested,
                          child: Text(tr.scheduleDeleteSlotAction),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
            child: OcptScheduleSlotPeople(
              peopleCount: slot.crew.length + slot.cast.length + slot.guests.length,
              crewBuilder: (cardWidth) => OcptScheduleSlotCrewSection(
                crew: slot.crew,
                personById: personById,
                people: people,
                cardWidth: cardWidth,
                onCrewMemberAdded: onCrewMemberAdded,
                onCrewMemberPositionChanged: onCrewMemberPositionChanged,
                onCrewMemberRemoved: onCrewMemberRemoved,
              ),
              castBuilder: (cardWidth) => OcptScheduleSlotCastColumn(
                cast: slot.cast,
                roles: roles,
                roleById: roleById,
                personById: personById,
                cardWidth: cardWidth,
                onCastRoleAdded: onCastRoleAdded,
                onCastRoleRemoved: onCastRoleRemoved,
              ),
              guestsBuilder: (cardWidth) => OcptScheduleSlotGuestBand(
                guests: slot.guests,
                personById: personById,
                people: people,
                cardWidth: cardWidth,
                onGuestAdded: onGuestAdded,
                onGuestRemoved: onGuestRemoved,
                guestReasonValueOf: guestReasonValueOf,
                onGuestReasonChanged: onGuestReasonChanged,
                guestNotesValueOf: guestNotesValueOf,
                onGuestNotesChanged: onGuestNotesChanged,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 0, 13, 11),
            child: _SlotTimetable(
              slot: slot,
              blocks: blocks,
              roles: roles,
              roleCandidateById: roleCandidateById,
              timeline: timeline,
              shotOf: shotOf,
              selectedBlockId: selectedBlockId,
              sequences: sequences,
              otherSlots: otherSlots,
              onBlockSelected: onBlockSelected,
              onBlockReordered: onBlockReordered,
              onBlockDurationChanged: onBlockDurationChanged,
              onBlockAnchorChanged: onBlockAnchorChanged,
              onShotStatusChanged: onShotStatusChanged,
              onBlockSequenceChanged: onBlockSequenceChanged,
              onBlockCandidateAdded: onBlockCandidateAdded,
              onBlockCandidateRemoved: onBlockCandidateRemoved,
              onBlockDeletionRequested: onBlockDeletionRequested,
              onBlockAdded: onBlockAdded,
              onShotBlockRequested: onShotBlockRequested,
              onBlockMovedToSlot: onBlockMovedToSlot,
            ),
          ),
        ],
      ),
    );
  }
}

/// A slot card's own timetable, below its crew and cast columns — see [OcptScheduleSlotCard]'s
/// class doc comment. Every field is forwarded as-is to [OcptScheduleTimetable], the card's own
/// [blocks] being filtered down to [slot]'s own here.
class _SlotTimetable extends StatelessWidget {
  /// The slot the timetable belongs to.
  final OcptShootingSlot slot;

  /// The day's live blocks, across every slot.
  final List<OcptShootingDayBlock> blocks;

  /// The whole cast, in display order.
  final List<OcptRole> roles;

  /// Every live candidacy of the project, keyed by id.
  final Map<String, OcptRoleCandidate> roleCandidateById;

  /// [slot]'s own computed timeline, or null while it has nothing placed yet.
  final OcptShootingSlotTimeline? timeline;

  /// Resolves a shot id to the shot it names.
  final OcptShot? Function(String shotId) shotOf;

  /// The id of the currently selected block, or null while none is.
  final String? selectedBlockId;

  /// Every real scene of the screenplay's shot list.
  final List<OcptSceneShotSequence> sequences;

  /// The day's own other live slots, by id and by raw label.
  final List<(String, String)> otherSlots;

  /// Called with a block's id when its row is clicked.
  final ValueChanged<String> onBlockSelected;

  /// Called once a drag-to-reorder gesture ends, or null while withheld.
  final void Function(String blockId, int newPosition)? onBlockReordered;

  /// Called once a `±` control is tapped, or null while withheld.
  final void Function(String blockId, int durationMinutes)? onBlockDurationChanged;

  /// Called once a block's pin is toggled, or null while withheld.
  final void Function(String blockId, int? anchorMinute)? onBlockAnchorChanged;

  /// Called with a shot block's shot id and the status just picked, or null while withheld.
  final void Function(String shotId, OcptShotStatus status)? onShotStatusChanged;

  /// Called with a hold block's id and the scene just picked, or null while withheld.
  final void Function(String blockId, String? sceneId)? onBlockSequenceChanged;

  /// Called with an audition block's id and the candidacy just picked, or null while withheld.
  final void Function(String blockId, String roleCandidateId)? onBlockCandidateAdded;

  /// Called with a candidacy convocation's id when its chip is removed, or null while withheld.
  final ValueChanged<String>? onBlockCandidateRemoved;

  /// Called with a block's id when its remove control is clicked, or null while withheld.
  final ValueChanged<String>? onBlockDeletionRequested;

  /// Called with the kind just picked from the `+ Block` menu, or null while withheld.
  final ValueChanged<OcptShootingBlockKind>? onBlockAdded;

  /// Called when the `+ Block` menu's `Shot` entry is picked, or null while withheld.
  final VoidCallback? onShotBlockRequested;

  /// Called with a block's id and the slot it is moved to, or null while withheld.
  final void Function(String blockId, String targetSlotId)? onBlockMovedToSlot;

  /// Class constructor
  const _SlotTimetable({
    required this.slot,
    required this.blocks,
    required this.roles,
    required this.roleCandidateById,
    required this.timeline,
    required this.shotOf,
    required this.selectedBlockId,
    required this.sequences,
    required this.otherSlots,
    required this.onBlockSelected,
    required this.onBlockReordered,
    required this.onBlockDurationChanged,
    required this.onBlockAnchorChanged,
    required this.onShotStatusChanged,
    required this.onBlockSequenceChanged,
    required this.onBlockCandidateAdded,
    required this.onBlockCandidateRemoved,
    required this.onBlockDeletionRequested,
    required this.onBlockAdded,
    required this.onShotBlockRequested,
    required this.onBlockMovedToSlot,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr.scheduleTimetableTitle.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 7),
        OcptScheduleTimetable(
          slotId: slot.id,
          blocks: [
            for (final block in blocks)
              if (block.slotId == slot.id) block,
          ],
          roles: roles,
          roleCandidateById: roleCandidateById,
          timeline: timeline,
          shotOf: shotOf,
          selectedBlockId: selectedBlockId,
          sequences: sequences,
          otherSlots: otherSlots,
          onBlockSelected: onBlockSelected,
          onReordered: onBlockReordered,
          onDurationChanged: onBlockDurationChanged,
          onAnchorChanged: onBlockAnchorChanged,
          onShotStatusChanged: onShotStatusChanged,
          onHoldSequenceChanged: onBlockSequenceChanged,
          onCandidateAdded: onBlockCandidateAdded,
          onCandidateRemoved: onBlockCandidateRemoved,
          onDeletionRequested: onBlockDeletionRequested,
          onBlockAdded: onBlockAdded,
          onShotBlockRequested: onShotBlockRequested,
          onBlockMovedToSlot: onBlockMovedToSlot,
        ),
      ],
    );
  }
}

/// The header's own pair of `▲`/`▼` controls, moving the card one place up or down its day's
/// list — the pointer-light path onto the same reorder a `sortKey` states, shown as soon as one
/// of the two is available (see [OcptScheduleSlotCard.onMovedUp]).
class _MoveControls extends StatelessWidget {
  /// Called when the `▲` control is clicked, or null while it is disabled.
  final VoidCallback? onMovedUp;

  /// Called when the `▼` control is clicked, or null while it is disabled.
  final VoidCallback? onMovedDown;

  /// Class constructor
  const _MoveControls({required this.onMovedUp, required this.onMovedDown});

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_up, size: 15),
          tooltip: tr.scheduleMoveSlotUpTooltip,
          visualDensity: VisualDensity.compact,
          onPressed: onMovedUp,
        ),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, size: 15),
          tooltip: tr.scheduleMoveSlotDownTooltip,
          visualDensity: VisualDensity.compact,
          onPressed: onMovedDown,
        ),
      ],
    );
  }
}

/// The header's own label field, location/set pickers and note.
class _HeaderFields extends StatelessWidget {
  /// The slot the header shows.
  final OcptShootingSlot slot;

  /// [slot]'s own location, or null while none is chosen.
  final OcptLocation? location;

  /// [slot]'s own set, or null while none is chosen.
  final OcptSet? set;

  /// The whole location catalogue (with their sets).
  final List<OcptLocation> locations;

  /// [slot]'s own label, as currently held.
  final String labelValue;

  /// Called with the label's raw text on every keystroke, or null while withheld.
  final ValueChanged<String>? onLabelChanged;

  /// [slot]'s own notes, as currently held.
  final String notesValue;

  /// Called with the note's raw text on every keystroke, or null while withheld.
  final ValueChanged<String>? onNotesChanged;

  /// Called with the location and set just picked, or null while withheld.
  final void Function(String? locationId, String? setId)? onPlaceChanged;

  /// Class constructor
  const _HeaderFields({
    required this.slot,
    required this.location,
    required this.set,
    required this.locations,
    required this.labelValue,
    required this.onLabelChanged,
    required this.notesValue,
    required this.onNotesChanged,
    required this.onPlaceChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final onLabelChanged = this.onLabelChanged;
    final onPlaceChanged = this.onPlaceChanged;
    final onNotesChanged = this.onNotesChanged;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 160,
          child: onLabelChanged == null
              ? Text(
                  labelValue.isEmpty ? tr.scheduleInspectorUnnamedSlot : labelValue,
                  style: theme.textTheme.titleSmall,
                )
              : _SlotLabelField(
                  key: ValueKey(slot.id),
                  value: labelValue,
                  hintText: tr.scheduleInspectorUnnamedSlot,
                  onChanged: onLabelChanged,
                ),
        ),
        const SizedBox(height: 6),
        // Every entry of this row is flexible and every name ellipsizes: the card narrows with the
        // centre whenever the inspector opens, and a location and a set named at full length would
        // otherwise push straight through the times column beside them.
        Row(
          children: [
            Flexible(
              child: onPlaceChanged == null
                  ? _PlaceName(name: location?.name ?? tr.scheduleDayNoLocation)
                  : PopupMenuButton<String>(
                      tooltip: "",
                      onSelected: (value) =>
                          onPlaceChanged(value == _noLocationOption ? null : value, null),
                      itemBuilder: (context) => [
                        PopupMenuItem<String>(
                          value: _noLocationOption,
                          child: Text(tr.scheduleDayNoLocation),
                        ),
                        const PopupMenuDivider(),
                        for (final candidate in locations)
                          PopupMenuItem<String>(value: candidate.id, child: Text(candidate.name)),
                      ],
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: _PlaceName(name: location?.name ?? tr.scheduleDayNoLocation),
                          ),
                          const Icon(Icons.arrow_drop_down, size: 16),
                        ],
                      ),
                    ),
            ),
            if (location != null) ...[
              const SizedBox(width: 6),
              Text("·", style: theme.textTheme.bodySmall),
              const SizedBox(width: 6),
              Flexible(
                child: onPlaceChanged == null
                    ? _PlaceName(name: set?.name ?? tr.scheduleInspectorNoSets)
                    : PopupMenuButton<String>(
                        tooltip: "",
                        onSelected: (value) =>
                            onPlaceChanged(location!.id, value == _noLocationOption ? null : value),
                        itemBuilder: (context) => [
                          PopupMenuItem<String>(
                            value: _noLocationOption,
                            child: Text(tr.scheduleInspectorNoSets),
                          ),
                          const PopupMenuDivider(),
                          for (final candidate in location!.sets)
                            PopupMenuItem<String>(value: candidate.id, child: Text(candidate.name)),
                        ],
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: _PlaceName(name: set?.name ?? tr.scheduleInspectorNoSets),
                            ),
                            const Icon(Icons.arrow_drop_down, size: 16),
                          ],
                        ),
                      ),
              ),
            ],
          ],
        ),
        // The slot's own note, below the location · set line — what this slot alone needs saying
        // ("parking derrière l'église"), as opposed to the day's own note to the crew. Read-only,
        // an empty note draws nothing rather than a dash: the line would then only add noise under
        // a place that already reads fully.
        if (onNotesChanged != null || notesValue.isNotEmpty) ...[
          const SizedBox(height: 3),
          if (onNotesChanged == null)
            Text(notesValue, style: theme.textTheme.bodySmall)
          else
            OcptScheduleSlotNoteField(
              key: ValueKey(slot.id),
              value: notesValue,
              hintText: tr.scheduleSlotNotesHint,
              onChanged: onNotesChanged,
            ),
        ],
      ],
    );
  }
}

/// One name of the header's own location · set line, ellipsized on a single line.
class _PlaceName extends StatelessWidget {
  /// The name shown.
  final String name;

  /// Class constructor
  const _PlaceName({required this.name});

  @override
  Widget build(BuildContext context) => Text(
    name,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: Theme.of(context).textTheme.bodySmall,
  );
}

/// The slot card's own single-line label field, following the same controller-sync idiom as
/// `OcptScheduleInspector`'s own note field: [value] is the field's current authoritative value,
/// and the internal controller is only reset to it when it genuinely differs from what the
/// controller already holds, so the caret never jumps mid-typing.
class _SlotLabelField extends StatefulWidget {
  /// The field's current authoritative value.
  final String value;

  /// The hint shown while [value] is empty.
  final String hintText;

  /// Called with the field's raw text on every keystroke.
  final ValueChanged<String> onChanged;

  /// Class constructor
  const _SlotLabelField({
    super.key,
    required this.value,
    required this.hintText,
    required this.onChanged,
  });

  @override
  State<_SlotLabelField> createState() => _SlotLabelFieldState();
}

/// The state of [_SlotLabelField]: owns the controller the class doc comment explains.
class _SlotLabelFieldState extends State<_SlotLabelField> {
  /// The field's own text editing controller, seeded from the widget's initial value and kept in
  /// sync with it afterward, see [didUpdateWidget].
  late final TextEditingController _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant _SlotLabelField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    onChanged: widget.onChanged,
    style: Theme.of(context).textTheme.titleSmall,
    decoration: InputDecoration(isDense: true, hintText: widget.hintText),
  );
}
