// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_crew_positions.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_person_position.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_set.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_cast_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_crew_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_guest.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_crew_department.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_minute_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_timetable.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_schedule_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_crew_position_prefill.dart';
import 'package:open_cine_prod_tools/utils/ocpt_day_minute.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_day_timeline.dart';

/// The value the "no location" entry of the location picker menu carries, distinct from every
/// location id — a [PopupMenuButton] cannot carry a null value for an entry that must still be
/// selectable.
const String _noLocationOption = "";

/// The header width under which a linked anchor reads as `⛓ <slot>` rather than as the whole
/// sentence — the inspector opening beside the day view is what usually takes a card below it.
const double _compactHeaderWidth = 460;

/// One choice of the slot card's own anchor menu: which edge is being pinned, and — for a link —
/// the slot whose **opposite** edge it reads. A null [_OcptScheduleSlotAnchorChoice.sourceSlotId]
/// is the fixed-hour entry of that edge.
class _OcptScheduleSlotAnchorChoice {
  /// The edge this entry pins.
  final OcptShootingSlotAnchorEdge edge;

  /// The slot this entry reads the opposite edge of, or null for a typed hour.
  final String? sourceSlotId;

  /// Class constructor
  const _OcptScheduleSlotAnchorChoice(this.edge, this.sourceSlotId);
}

/// The width every crew or cast card of a slot's own people sections claims when there is room for
/// it. [OcptScheduleSlotCard.build] never hands a card more than half its own body width, though: a
/// half narrower than this shrinks every card of that half down to fit instead of overflowing it.
const double _personCardWidth = 230;

/// One slot's own card in the day view: its `▲`/`▼` reorder pair, its label, its location and set,
/// its own note below them — what this slot alone needs saying, the day's own note to the crew
/// being a different thing — its own **anchored edge** — the one hour a slot is pinned by, with the
/// computed opposite edge read out under it — then the whole of **who is on this slot**
/// ([_OcptScheduleSlotPeople]) — and, below it, this slot's **own** [OcptScheduleTimetable]: a day
/// used to carry one timetable shared by every slot; now each card draws its own, over its own
/// [blocks] alone, chained by its own [timeline].
///
/// **The three kinds of person sit under one foldable section**, `Assigner des personnes`: a row of
/// two halves, `Équipe technique` (grouped by department — see [_OcptScheduleCrewSection]) and
/// `Comédiens`, then a full-width `Invités` band under them, each ending on its own
/// `+ Crew member`/`+ Cast`/`+ Guest` footer opening a person or role picker right there on the
/// card, with no duplicate list anywhere in the right dock. **Only the section's own title folds**,
/// and it folds all three at once: a settled crew, cast and guest list are entered once and then
/// read past for the rest of the shoot, and the point of the fold is to get to the timetable — so
/// one gesture answers for the three rather than each of them needing its own, the three subsection
/// titles being plain read-outs. Neither of the two people halves is ever handed more than half the
/// card's own body width, and every crew or cast card within its own half wraps at
/// [_personCardWidth] (shrunk to fit when that half is narrower), so a wide day view flows several
/// cards per row instead of leaving the sides empty — the guest band wraps the same cards over the
/// card's **whole** width instead, not being split into halves.
///
/// **A crew or cast row says only who is convoked and in what function** (ADR 0018): a convocation
/// is a fact about a person on a **day**, joined across every slot they sit on, so it cannot be read
/// from one slot's card in isolation — the computed arrival/PAT/departure that used to sit here move
/// to the day's own convocations panel instead. A guest card carries **no clock at all** either, for
/// the same reason. The one editable clock on the whole card is the slot's own anchor
/// ([onAnchorChanged]).
///
/// **The guest band is always drawn**, empty hint and all, exactly as the two people halves are: a
/// slot's guests are one of the three answers to "who is on this unit", and a band that had to be
/// revealed from the `⋮` menu before it could be filled hid the very affordance somebody looking for
/// it was after.
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
/// its own reason/notes fields, all three `+`
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

  /// The whole cast, keyed by id — what a cast row's own name is read off.
  final Map<String, OcptRole> roleById;

  /// The whole address book, in display order — what the `+ Crew member` picker offers.
  final List<OcptPerson> people;

  /// The whole cast, in display order — what the `+ Cast` picker offers, already excluding the
  /// roles [slot] already convokes.
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
  /// [_OcptScheduleCrewSection] or a catalogue entry — or null while withheld.
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

  /// Called with the id of the person picked by the guest band's own `+ Guest` footer, or null while
  /// withheld — also what gates the `⋮` menu's own `Add a guest` entry (see the class doc comment).
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
        borderRadius: BorderRadius.circular(ocptRadiusMedium),
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
                  if (onMovedUp != null || onMovedDown != null) _buildMoveControls(context),
                  Container(
                    width: 4,
                    constraints: const BoxConstraints(minHeight: 30),
                    decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 11),
                  Expanded(child: _buildHeaderFields(context)),
                  const SizedBox(width: 11),
                  _buildAnchorControl(
                    context,
                    isCompact: constraints.maxWidth < _compactHeaderWidth,
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
            child: _OcptScheduleSlotPeople(
              peopleCount: slot.crew.length + slot.cast.length + slot.guests.length,
              crewBuilder: (cardWidth) => _OcptScheduleCrewSection(
                crew: slot.crew,
                personById: personById,
                people: people,
                cardWidth: cardWidth,
                onCrewMemberAdded: onCrewMemberAdded,
                onCrewMemberPositionChanged: onCrewMemberPositionChanged,
                onCrewMemberRemoved: onCrewMemberRemoved,
              ),
              castBuilder: (cardWidth) => _buildCastColumn(context, cardWidth: cardWidth),
              guestsBuilder: () => _buildGuestBand(context),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 0, 13, 11),
            child: _buildTimetable(context),
          ),
        ],
      ),
    );
  }

  /// This slot's own timetable, below its crew and cast columns — see the class doc comment.
  Widget _buildTimetable(BuildContext context) {
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
          onDeletionRequested: onBlockDeletionRequested,
          onBlockAdded: onBlockAdded,
          onShotBlockRequested: onShotBlockRequested,
          onBlockMovedToSlot: onBlockMovedToSlot,
        ),
      ],
    );
  }

  /// The header's own label field and location/set pickers.
  Widget _buildHeaderFields(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final onLabelChanged = this.onLabelChanged;
    final onPlaceChanged = this.onPlaceChanged;

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
              : _OcptScheduleSlotLabelField(
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
                  ? _buildPlaceName(context, location?.name ?? tr.scheduleDayNoLocation)
                  : PopupMenuButton<String>(
                      tooltip: "",
                      onSelected: (value) => onPlaceChanged(
                        value == _noLocationOption ? null : value,
                        null,
                      ),
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
                            child: _buildPlaceName(
                              context,
                              location?.name ?? tr.scheduleDayNoLocation,
                            ),
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
                    ? _buildPlaceName(context, set?.name ?? tr.scheduleInspectorNoSets)
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
                              child: _buildPlaceName(
                                context,
                                set?.name ?? tr.scheduleInspectorNoSets,
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, size: 16),
                          ],
                        ),
                      ),
              ),
            ],
          ],
        ),
        ..._buildNoteField(context),
      ],
    );
  }

  /// The header's own note, below the location · set line — what this slot alone needs saying
  /// ("parking derrière l'église"), as opposed to the day's own note to the crew.
  ///
  /// Read-only, an empty note draws **nothing** rather than a dash: the line would then only add
  /// noise under a place that already reads fully.
  List<Widget> _buildNoteField(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final onNotesChanged = this.onNotesChanged;

    if (onNotesChanged == null) {
      if (notesValue.isEmpty) {
        return const [];
      }

      return [
        const SizedBox(height: 3),
        Text(notesValue, style: theme.textTheme.bodySmall),
      ];
    }

    return [
      const SizedBox(height: 3),
      _OcptScheduleSlotNoteField(
        key: ValueKey(slot.id),
        value: notesValue,
        hintText: tr.scheduleSlotNotesHint,
        onChanged: onNotesChanged,
      ),
    ];
  }

  /// The header's own pair of `▲`/`▼` controls, moving this card one place up or down its day's
  /// list — the pointer-light path onto the same reorder a `sortKey` states, shown as soon as one
  /// of the two is available (see [onMovedUp]).
  Widget _buildMoveControls(BuildContext context) {
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

  /// One name of the header's own location · set line, ellipsized on a single line.
  Widget _buildPlaceName(BuildContext context, String name) => Text(
    name,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: Theme.of(context).textTheme.bodySmall,
  );

  /// The header's own anchor control, right-aligned: the pinned edge on top — a menu picking which
  /// edge that is and where its hour comes from, then either the typed hour or the computed one —
  /// and the **opposite**, always-computed edge read out under it in the muted colour.
  ///
  /// [isCompact] is the card's own header width falling under [_compactHeaderWidth] (the inspector
  /// opening beside it, most often): a linked edge then reads as `⛓ <slot>` rather than the whole
  /// sentence, which moves to the button's tooltip.
  Widget _buildAnchorControl(BuildContext context, {required bool isCompact}) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    final isEndAnchored = slot.anchorEdge == OcptShootingSlotAnchorEdge.end;
    final resolvedStartMinute = timeline?.startMinute;
    // ADR 0015's rule 5: a slot with nothing placed in it ends where it starts.
    final resolvedEndMinute = timeline?.endMinute ?? resolvedStartMinute;
    final anchoredMinute = isEndAnchored ? resolvedEndMinute : resolvedStartMinute;
    final oppositeMinute = isEndAnchored ? resolvedStartMinute : resolvedEndMinute;
    final oppositeLabel = isEndAnchored ? tr.scheduleSlotStartLabel : tr.scheduleSlotEndLabel;
    final sourceLabel = slot.anchorSlotId == null ? null : _labelOfSlot(context, slot.anchorSlotId!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAnchorButton(
              context,
              isCompact: isCompact,
              sourceLabel: sourceLabel,
              anchoredMinute: anchoredMinute,
            ),
            const SizedBox(width: 4),
            // A linked edge's hour is computed like every other, so its field carries no callback
            // and renders as plain text — the same way every computed time in this mode is read out.
            OcptScheduleMinuteField(
              minute: sourceLabel == null ? slot.anchorMinute : anchoredMinute,
              isClearable: false,
              emptyHint: "—",
              onChanged: onAnchorChanged == null || sourceLabel != null
                  ? null
                  : (value) => onAnchorChanged!(
                      slot.anchorEdge,
                      value ?? slot.anchorMinute ?? anchoredMinute ?? 0,
                      null,
                    ),
            ),
          ],
        ),
        Text(
          "$oppositeLabel ${oppositeMinute == null ? "—" : ocptFormatDayMinute(oppositeMinute)}",
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  /// The anchor control's own edge button: the flat menu when this card may be written to, the same
  /// wording as plain text when it may not.
  Widget _buildAnchorButton(
    BuildContext context, {
    required bool isCompact,
    required String? sourceLabel,
    required int? anchoredMinute,
  }) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final isEndAnchored = slot.anchorEdge == OcptShootingSlotAnchorEdge.end;

    final sentence = sourceLabel == null
        ? (isEndAnchored ? tr.scheduleSlotEndLabel : tr.scheduleSlotStartLabel)
        : (isEndAnchored
              ? tr.scheduleSlotAnchorEndFromSlot(sourceLabel)
              : tr.scheduleSlotAnchorStartFromSlot(sourceLabel));
    final shown = sourceLabel != null && isCompact
        ? tr.scheduleSlotAnchorLinkedShort(sourceLabel)
        : sentence;
    final label = Text(
      shown,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.labelSmall,
    );

    if (onAnchorChanged == null) {
      return Tooltip(message: sentence, child: label);
    }

    return PopupMenuButton<_OcptScheduleSlotAnchorChoice>(
      tooltip: sourceLabel == null ? tr.scheduleSlotAnchorTooltip : sentence,
      onSelected: (choice) => _onAnchorChoicePicked(choice, anchoredMinute),
      itemBuilder: _buildAnchorMenu,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: label),
          const Icon(Icons.arrow_drop_down, size: 14),
        ],
      ),
    );
  }

  /// The anchor menu's own entries: the two fixed-hour ones, then, per other live slot of the day,
  /// the two directions a link can read it in. Every entry carries a **non-null** value, a
  /// [PopupMenuButton] reading null as "the menu was dismissed" and never calling `onSelected` for
  /// it — the trap `ocptNewLocationMenuValue` already documents.
  List<PopupMenuEntry<_OcptScheduleSlotAnchorChoice>> _buildAnchorMenu(BuildContext context) {
    final tr = Tr.of(context);
    final isLinked = slot.anchorSlotId != null;

    return [
      _buildAnchorMenuItem(
        context,
        choice: const _OcptScheduleSlotAnchorChoice(OcptShootingSlotAnchorEdge.start, null),
        label: tr.scheduleSlotAnchorStartFixed,
        isSelected: !isLinked && slot.anchorEdge == OcptShootingSlotAnchorEdge.start,
      ),
      _buildAnchorMenuItem(
        context,
        choice: const _OcptScheduleSlotAnchorChoice(OcptShootingSlotAnchorEdge.end, null),
        label: tr.scheduleSlotAnchorEndFixed,
        isSelected: !isLinked && slot.anchorEdge == OcptShootingSlotAnchorEdge.end,
      ),
      if (otherSlots.isNotEmpty) const PopupMenuDivider(),
      for (final (sourceId, rawLabel) in otherSlots)
        for (final edge in OcptShootingSlotAnchorEdge.values)
          _buildAnchorMenuItem(
            context,
            choice: _OcptScheduleSlotAnchorChoice(edge, sourceId),
            label: edge == OcptShootingSlotAnchorEdge.start
                ? tr.scheduleSlotAnchorStartFromSlot(_labelOf(context, rawLabel))
                : tr.scheduleSlotAnchorEndFromSlot(_labelOf(context, rawLabel)),
            isSelected: slot.anchorSlotId == sourceId && slot.anchorEdge == edge,
            disabledReason: ocptSlotAnchorWouldCycle(
              anchorSourceBySlotId: anchorSourceBySlotId,
              slotId: slot.id,
              sourceSlotId: sourceId,
            )
                ? tr.scheduleSlotAnchorCycleReason
                : null,
          ),
    ];
  }

  /// One entry of the anchor menu: its wording, a `✓` when it is the anchor in force, and — when it
  /// would close a circle — its own reason under it, greyed rather than left out.
  PopupMenuEntry<_OcptScheduleSlotAnchorChoice> _buildAnchorMenuItem(
    BuildContext context, {
    required _OcptScheduleSlotAnchorChoice choice,
    required String label,
    required bool isSelected,
    String? disabledReason,
  }) {
    final theme = Theme.of(context);

    return PopupMenuItem<_OcptScheduleSlotAnchorChoice>(
      value: choice,
      enabled: disabledReason == null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label),
                if (disabledReason != null)
                  Text(
                    disabledReason,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (isSelected) const Icon(Icons.check, size: 14),
        ],
      ),
    );
  }

  /// Reports [choice] to [onAnchorChanged], **freezing the hour the edge was reading** when it goes
  /// back to a typed one: switching away from a link pre-fills the field with what it was showing
  /// at that moment, rather than emptying it or resurrecting whatever was typed before the link.
  void _onAnchorChoicePicked(_OcptScheduleSlotAnchorChoice choice, int? anchoredMinute) {
    final onAnchorChanged = this.onAnchorChanged;
    if (onAnchorChanged == null) {
      return;
    }

    if (choice.sourceSlotId != null) {
      onAnchorChanged(choice.edge, null, choice.sourceSlotId);
      return;
    }

    final resolvedStartMinute = timeline?.startMinute;
    final frozen = choice.edge == OcptShootingSlotAnchorEdge.end
        ? (timeline?.endMinute ?? resolvedStartMinute)
        : resolvedStartMinute;
    onAnchorChanged(choice.edge, frozen ?? anchoredMinute ?? slot.anchorMinute ?? 0, null);
  }

  /// The label of the day's own slot [slotId], as [otherSlots] carries it, or the unnamed-slot
  /// wording when it has none (or names no slot of this day any more).
  String _labelOfSlot(BuildContext context, String slotId) {
    for (final (id, rawLabel) in otherSlots) {
      if (id == slotId) {
        return _labelOf(context, rawLabel);
      }
    }

    return Tr.of(context).scheduleInspectorUnnamedSlot;
  }

  /// [rawLabel], or the unnamed-slot wording when it is empty.
  String _labelOf(BuildContext context, String rawLabel) =>
      rawLabel.isEmpty ? Tr.of(context).scheduleInspectorUnnamedSlot : rawLabel;

  /// The `Comédiens` half: [slot]'s own convoked roles wrapped at [cardWidth] each, then the
  /// `+ Cast` footer, under a title that is a plain read-out — the only fold on this card is
  /// [_OcptScheduleSlotPeople]'s own, over the three kinds of person at once.
  Widget _buildCastColumn(BuildContext context, {required double cardWidth}) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPeopleSubsectionTitle(
          context,
          title: tr.scheduleSlotCastColumnTitle,
          count: slot.cast.length,
        ),
        const SizedBox(height: 7),
        if (slot.cast.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              tr.scheduleSlotCastEmptyHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final member in slot.cast)
                  SizedBox(
                    width: cardWidth,
                    child: _OcptScheduleCastRoleRow(
                      key: ValueKey(member.id),
                      member: member,
                      role: roleById[member.roleId],
                      person: roleById[member.roleId]?.personId == null
                          ? null
                          : personById[roleById[member.roleId]!.personId],
                      onRemoved: onCastRoleRemoved == null
                          ? null
                          : () => onCastRoleRemoved!(member.id),
                    ),
                  ),
              ],
            ),
          ),
        if (onCastRoleAdded != null)
          PopupMenuButton<String>(
            tooltip: "",
            onSelected: onCastRoleAdded,
            itemBuilder: (context) => [
              for (final role in roles)
                PopupMenuItem<String>(value: role.id, child: Text(role.name)),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add, size: 14),
                const SizedBox(width: 4),
                Text(tr.scheduleAddCastAction, style: theme.textTheme.labelSmall),
              ],
            ),
          ),
      ],
    );
  }

  /// The guest band: [slot]'s own live guests wrapped at [_personCardWidth] over the card's **whole**
  /// width (shrunk to fit when that is narrower — unlike the crew and cast halves, this band is never
  /// split in two), then the `+ Guest` footer. It is drawn whether or not [slot] holds a guest, like
  /// the two halves above it; see the class doc comment.
  Widget _buildGuestBand(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPeopleSubsectionTitle(
          context,
          title: tr.scheduleSlotGuestsColumnTitle,
          count: slot.guests.length,
        ),
        const SizedBox(height: 7),
        if (slot.guests.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              tr.scheduleSlotGuestsEmptyHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final guest in slot.guests)
                    SizedBox(
                      width: math.min(_personCardWidth, constraints.maxWidth),
                      child: _OcptScheduleGuestRow(
                        key: ValueKey(guest.id),
                        guest: guest,
                        person: guest.personId == null ? null : personById[guest.personId],
                        reasonValue: guestReasonValueOf(guest.id),
                        onReasonChanged: onGuestReasonChanged == null
                            ? null
                            : (value) => onGuestReasonChanged!(guest.id, value),
                        notesValue: guestNotesValueOf(guest.id),
                        onNotesChanged: onGuestNotesChanged == null
                            ? null
                            : (value) => onGuestNotesChanged!(guest.id, value),
                        onRemoved: onGuestRemoved == null ? null : () => onGuestRemoved!(guest.id),
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (onGuestAdded != null)
          PopupMenuButton<String>(
            tooltip: "",
            onSelected: onGuestAdded,
            itemBuilder: (context) => [
              for (final person in people)
                PopupMenuItem<String>(
                  value: person.id,
                  child: Text(
                    person.displayName.isEmpty ? tr.resourcesUnnamedPerson : person.displayName,
                  ),
                ),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add, size: 14),
                const SizedBox(width: 4),
                Text(tr.scheduleAddGuestAction, style: theme.textTheme.labelSmall),
              ],
            ),
          ),
      ],
    );
  }
}

/// One kind of person's own title row inside [_OcptScheduleSlotPeople]'s section, shared by
/// [OcptScheduleSlotCard]'s cast half, its guest band and [_OcptScheduleCrewSection]: the kind's own
/// name and how many people it holds, so a half answers "how many" without its cards being counted.
///
/// It is a **plain read-out, clickable by nothing**: the one fold on this card belongs to
/// [_OcptScheduleSlotPeople] and answers for the three kinds at once, so a title that also folded
/// its own kind would be a second, narrower question asked in the same place as the first.
Widget _buildPeopleSubsectionTitle(
  BuildContext context, {
  required String title,
  required int count,
}) {
  final theme = Theme.of(context);
  final titleStyle = theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(
        child: Text(
          title.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: titleStyle,
        ),
      ),
      const SizedBox(width: 6),
      Text(
        Tr.of(context).scheduleSlotPeopleCount(count),
        style: titleStyle?.copyWith(fontStyle: FontStyle.italic),
      ),
    ],
  );
}

/// The whole `Assigner des personnes` section of a slot card: the two people halves side by side —
/// `Équipe technique` and `Comédiens`, each handed at most half the row's width — then the full-width
/// `Invités` band under them, all three behind **one fold** carried by the section's own title.
///
/// That is the one fold on the card, and it is deliberate: a settled crew, cast and guest list are
/// entered once and then read past for the rest of the shoot, so one gesture gets the reader to the
/// timetable rather than each kind needing its own. The three kinds' own titles are plain read-outs
/// ([_buildPeopleSubsectionTitle]), and the count on this one is the three of them together, so a
/// folded section never reads as an empty slot.
///
/// It owns nothing but that fold — the three parts themselves are built by the card, which is where
/// every row, callback and catalogue they need is already in scope, so this widget takes them as
/// builders rather than re-declaring a dozen fields it would only forward. The fold is per-view
/// [State], expanded by default: nothing is lost by it resetting the next time the card is built.
class _OcptScheduleSlotPeople extends StatefulWidget {
  /// How many people the section holds altogether, crew, cast and guests — what its own title reads
  /// out in both fold states.
  final int peopleCount;

  /// Builds the crew half, given the width one person card claims.
  final Widget Function(double cardWidth) crewBuilder;

  /// Builds the cast half, from that same width.
  final Widget Function(double cardWidth) castBuilder;

  /// Builds the guest band, which spans the section's whole width and therefore takes none.
  final Widget Function() guestsBuilder;

  /// Class constructor
  const _OcptScheduleSlotPeople({
    required this.peopleCount,
    required this.crewBuilder,
    required this.castBuilder,
    required this.guestsBuilder,
  });

  @override
  State<_OcptScheduleSlotPeople> createState() => _OcptScheduleSlotPeopleState();
}

/// The state of [_OcptScheduleSlotPeople]: owns the fold its three parts share.
class _OcptScheduleSlotPeopleState extends State<_OcptScheduleSlotPeople> {
  /// Whether the section shows its three kinds of person, or its title alone.
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildSectionTitle(context),
      if (_isExpanded) ...[
        const SizedBox(height: 9),
        LayoutBuilder(
          builder: (context, constraints) {
            // Neither half is ever handed more than half the row's own width; a card's own fixed
            // width shrinks to fit when that half is narrower than it, so a narrow day view never
            // overflows the card the way two hard-coded column widths once could.
            final cardWidth = math.min(_personCardWidth, (constraints.maxWidth - 22) / 2);

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: widget.crewBuilder(cardWidth)),
                const SizedBox(width: 22),
                Expanded(child: widget.castBuilder(cardWidth)),
              ],
            );
          },
        ),
        const SizedBox(height: 11),
        widget.guestsBuilder(),
      ],
    ],
  );

  /// The section's own clickable title: the fold chevron, its name, and how many people the three
  /// kinds hold together.
  Widget _buildSectionTitle(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return InkWell(
      mouseCursor: ocptClickableCursor,
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isExpanded ? Icons.expand_less : Icons.expand_more,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 2),
          Flexible(
            child: Text(
              Tr.of(context).scheduleSlotPeopleSectionTitle.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: titleStyle?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            Tr.of(context).scheduleSlotPeopleCount(widget.peopleCount),
            style: titleStyle?.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

/// The `Équipe technique` half of [OcptScheduleSlotCard]'s own body: [crew] grouped by department,
/// each department's own cards wrapped at [cardWidth], then the `+ Crew member` footer, under a
/// title that is a plain read-out — the one fold on the card belongs to [_OcptScheduleSlotPeople]
/// and answers for the crew, the cast and the guests at once.
///
/// **This is where a crew row's picker learns what to promote and what to refuse** —
/// [_prefillFor] joins each member's own person's declared `person_positions` against every other
/// live crew row of [crew] naming that same person, through `ocptCrewPositionPrefillOf`
/// (`lib/utils/`): the promoted list and the taken set travel down to
/// [_OcptScheduleCrewMemberRow] rather than being recomputed inside its own menu builder.
class _OcptScheduleCrewSection extends StatelessWidget {
  /// The slot's own crew assignments, in `sortKey` order.
  final List<OcptShootingSlotCrewMember> crew;

  /// The whole address book, keyed by id — what a crew row's own name is read off.
  final Map<String, OcptPerson> personById;

  /// The whole address book, in display order — what the `+ Crew member` picker offers.
  final List<OcptPerson> people;

  /// The width every crew card of this half claims — see [_personCardWidth]'s own doc comment.
  final double cardWidth;

  /// Called with the id of the person picked by the `+ Crew member` footer, or null while withheld.
  final ValueChanged<String>? onCrewMemberAdded;

  /// Called with a crew assignment's id and the position just picked, or null while withheld.
  final void Function(String crewMemberId, OcptCrewPositionRef position)?
  onCrewMemberPositionChanged;

  /// Called with a crew assignment's id when its row's remove control is clicked, or null while
  /// withheld.
  final ValueChanged<String>? onCrewMemberRemoved;

  /// Class constructor
  const _OcptScheduleCrewSection({
    required this.crew,
    required this.personById,
    required this.people,
    required this.cardWidth,
    required this.onCrewMemberAdded,
    required this.onCrewMemberPositionChanged,
    required this.onCrewMemberRemoved,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final byDepartment = <OcptCrewDepartment?, List<OcptShootingSlotCrewMember>>{};
    for (final member in crew) {
      final department = ocptCrewPositionDepartmentOf(member.positionId);
      byDepartment.putIfAbsent(department, () => []).add(member);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPeopleSubsectionTitle(
          context,
          title: tr.scheduleSlotCrewColumnTitle,
          count: crew.length,
        ),
        const SizedBox(height: 7),
        if (crew.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              tr.scheduleSlotCrewEmptyHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          for (final department in byDepartment.keys)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    department == null
                        ? tr.scheduleSlotUnassignedDepartmentLabel
                        : ocptCrewDepartmentLabel(tr, department),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final member in byDepartment[department]!)
                        SizedBox(
                          width: cardWidth,
                          child: _buildCrewMemberRow(member),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        if (onCrewMemberAdded != null)
          PopupMenuButton<String>(
            tooltip: "",
            onSelected: onCrewMemberAdded,
            itemBuilder: (context) => [
              for (final person in people)
                PopupMenuItem<String>(
                  value: person.id,
                  child: Text(
                    person.displayName.isEmpty ? tr.resourcesUnnamedPerson : person.displayName,
                  ),
                ),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add, size: 14),
                const SizedBox(width: 4),
                Text(tr.scheduleAddCrewMemberAction, style: theme.textTheme.labelSmall),
              ],
            ),
          ),
      ],
    );
  }

  /// One crew card for [member], its picker's promoted and taken positions computed through
  /// [_prefillFor] so the row and the service that later refuses a duplicate can never disagree.
  Widget _buildCrewMemberRow(OcptShootingSlotCrewMember member) {
    final prefill = _prefillFor(member);

    return _OcptScheduleCrewMemberRow(
      key: ValueKey(member.id),
      member: member,
      person: personById[member.personId],
      promotedPositions: prefill.promotedPositions,
      takenPositions: prefill.takenPositions,
      onPositionChanged: onCrewMemberPositionChanged == null
          ? null
          : (position) => onCrewMemberPositionChanged!(member.id, position),
      onRemoved: onCrewMemberRemoved == null ? null : () => onCrewMemberRemoved!(member.id),
    );
  }

  /// Joins [member]'s own person's declared `person_positions` with every live crew row of [crew]
  /// naming that same person on this slot — [member]'s own row included, so its current position
  /// reads as taken rather than greyed — through `ocptCrewPositionPrefillOf`: what
  /// [_buildCrewMemberRow]'s picker promotes above the catalogue, and what it must never offer.
  OcptCrewPositionPrefill _prefillFor(OcptShootingSlotCrewMember member) =>
      ocptCrewPositionPrefillOf(
        declaredPositions: [
          for (final position
              in personById[member.personId]?.positions ?? const <OcptPersonPosition>[])
            OcptCrewPositionRef(positionId: position.positionId, customLabel: position.customLabel),
        ],
        heldOnSlot: [
          for (final other in crew)
            if (other.personId == member.personId)
              OcptCrewPositionRef(positionId: other.positionId, customLabel: other.customLabel),
        ],
      );
}

/// One crew card of [OcptScheduleSlotCard]'s own `Équipe technique` column, built exactly like
/// [_OcptScheduleCastRoleRow]'s own card (see [_buildSlotPersonCard]): the position picker and the
/// remove control on the first line, the person's own name underneath.
///
/// The picker promotes [promotedPositions] above the `ocptCrewPositions` catalogue and never
/// offers anything in [takenPositions] — the two lists [_OcptScheduleCrewSection] hands down,
/// join computed once rather than per menu build (see its own doc comment).
class _OcptScheduleCrewMemberRow extends StatelessWidget {
  /// The crew assignment this row shows.
  final OcptShootingSlotCrewMember member;

  /// The person [member] names, or null while not yet loaded.
  final OcptPerson? person;

  /// The person's declared positions not already held on this slot, in their declared order —
  /// shown at the top of the picker, above the catalogue, behind a divider. Computed once by
  /// [_OcptScheduleCrewSection._prefillFor] rather than recomputed on every menu build.
  final List<OcptCrewPositionRef> promotedPositions;

  /// Every position this person already holds on this slot, [member]'s own included — never
  /// offered by the picker, catalogue entries among them.
  final Set<OcptCrewPositionRef> takenPositions;

  /// Called with the position just picked — a promoted one or a catalogue entry — or null while
  /// withheld.
  final ValueChanged<OcptCrewPositionRef>? onPositionChanged;

  /// Called when this row's remove control is clicked, or null while withheld.
  final VoidCallback? onRemoved;

  /// Class constructor
  const _OcptScheduleCrewMemberRow({
    super.key,
    required this.member,
    required this.person,
    required this.promotedPositions,
    required this.takenPositions,
    required this.onPositionChanged,
    required this.onRemoved,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final positionLabel = member.positionId.isEmpty
        ? (member.customLabel.isEmpty
              ? tr.scheduleSlotCrewPositionPlaceholder
              : member.customLabel)
        : ocptCrewPositionLabel(tr, member.positionId);
    final personName = person?.displayName.isEmpty ?? true
        ? tr.resourcesUnnamedPerson
        : person!.displayName;

    return _buildSlotPersonCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: onPositionChanged == null
                    ? Text(positionLabel, style: theme.textTheme.bodySmall)
                    : PopupMenuButton<OcptCrewPositionRef>(
                        tooltip: "",
                        onSelected: onPositionChanged,
                        itemBuilder: (context) => _buildPositionMenuItems(context, tr),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                positionLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, size: 14),
                          ],
                        ),
                      ),
              ),
              if (onRemoved != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 14),
                  visualDensity: VisualDensity.compact,
                  tooltip: tr.scheduleRemoveCrewMemberTooltip,
                  onPressed: onRemoved,
                ),
            ],
          ),
          Text(
            personName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  /// Builds the position picker menu: [promotedPositions] first, then a divider (omitted when
  /// that list is empty), then the `ocptCrewPositions` catalogue grouped under a disabled
  /// department header each time the department changes — mirroring
  /// `_OcptPersonPositionRow._buildMenuItems` — with [takenPositions] filtered out of both blocks.
  List<PopupMenuEntry<OcptCrewPositionRef>> _buildPositionMenuItems(BuildContext context, Tr tr) {
    final theme = Theme.of(context);
    final items = <PopupMenuEntry<OcptCrewPositionRef>>[];

    for (final position in promotedPositions) {
      items.add(
        PopupMenuItem<OcptCrewPositionRef>(
          value: position,
          child: Text(_labelOf(tr, position)),
        ),
      );
    }
    if (items.isNotEmpty) {
      items.add(const PopupMenuDivider());
    }

    OcptCrewDepartment? lastDepartment;
    for (final position in ocptCrewPositions) {
      final ref = OcptCrewPositionRef(positionId: position.id, customLabel: "");
      if (takenPositions.contains(ref)) {
        continue;
      }
      if (position.department != lastDepartment) {
        items.add(
          PopupMenuItem<OcptCrewPositionRef>(
            enabled: false,
            height: 28,
            child: Text(
              ocptCrewDepartmentLabel(tr, position.department).toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        );
        lastDepartment = position.department;
      }
      items.add(
        PopupMenuItem<OcptCrewPositionRef>(
          value: ref,
          child: Text(ocptCrewPositionLabel(tr, position.id)),
        ),
      );
    }

    return items;
  }

  /// [position]'s own label: the catalogue's when it names one, [position].customLabel otherwise.
  String _labelOf(Tr tr, OcptCrewPositionRef position) =>
      position.positionId.isEmpty ? position.customLabel : ocptCrewPositionLabel(tr, position.positionId);
}

/// One cast card of [OcptScheduleSlotCard]'s own `Comédiens` column, its layout shared with
/// [_OcptScheduleCrewMemberRow]'s own card (see [_buildSlotPersonCard]): the role's own name and
/// remove control on the first line, the cast actor's own name underneath.
class _OcptScheduleCastRoleRow extends StatelessWidget {
  /// The cast convocation this row shows.
  final OcptShootingSlotCastMember member;

  /// The role [member] convokes, or null while not yet loaded.
  final OcptRole? role;

  /// The person cast in [role], or null while uncast (or not yet loaded).
  final OcptPerson? person;

  /// Called when this row's remove control is clicked, or null while withheld.
  final VoidCallback? onRemoved;

  /// Class constructor
  const _OcptScheduleCastRoleRow({
    super.key,
    required this.member,
    required this.role,
    required this.person,
    required this.onRemoved,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return _buildSlotPersonCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  role?.name ?? "",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              if (onRemoved != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 14),
                  visualDensity: VisualDensity.compact,
                  tooltip: tr.scheduleRemoveCastTooltip,
                  onPressed: onRemoved,
                ),
            ],
          ),
          Text(
            person == null ? tr.scheduleSlotCastUncastHint : person!.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: person == null ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// One guest card of [OcptScheduleSlotCard]'s own guest band, built in the same
/// [_buildSlotPersonCard] shell as [_OcptScheduleCrewMemberRow] and [_OcptScheduleCastRoleRow]: the
/// guest's own name and the remove control on the first line, then its reason, then its notes —
/// **no clock at all**, like every other convocation card (the hours are read in the `Convocations`
/// dock tab).
///
/// The name is a **read-out, never a picker**: a guest's identity is fixed the moment they are
/// added, exactly as a crew row's person and a cast row's role are. A row whose [guest]'s own
/// `personId` is null reads its `freeName` instead — defensively, since nothing in this app ever
/// mints a free-named guest (only the address book picker adds one), but a stored row is read back
/// as-is either way.
class _OcptScheduleGuestRow extends StatelessWidget {
  /// The guest attendance this row shows.
  final OcptShootingSlotGuest guest;

  /// The address-book person [guest] names, or null while [guest] is free-named instead (or not yet
  /// loaded).
  final OcptPerson? person;

  /// The reason field's current authoritative value (a pending edit, or its stored value).
  final String reasonValue;

  /// Called with the reason field's raw text on every keystroke, or null while withheld.
  final ValueChanged<String>? onReasonChanged;

  /// The notes field's current authoritative value (a pending edit, or its stored value).
  final String notesValue;

  /// Called with the notes field's raw text on every keystroke, or null while withheld.
  final ValueChanged<String>? onNotesChanged;

  /// Called when this row's remove control is clicked, or null while withheld.
  final VoidCallback? onRemoved;

  /// Class constructor
  const _OcptScheduleGuestRow({
    super.key,
    required this.guest,
    required this.person,
    required this.reasonValue,
    required this.onReasonChanged,
    required this.notesValue,
    required this.onNotesChanged,
    required this.onRemoved,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final name = guest.personId != null
        ? (person?.displayName.isEmpty ?? true ? tr.resourcesUnnamedPerson : person!.displayName)
        : (guest.freeName.isEmpty ? tr.resourcesUnnamedPerson : guest.freeName);

    return _buildSlotPersonCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              if (onRemoved != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 14),
                  visualDensity: VisualDensity.compact,
                  tooltip: tr.scheduleRemoveGuestTooltip,
                  onPressed: onRemoved,
                ),
            ],
          ),
          const SizedBox(height: 2),
          _buildTextLine(
            context,
            value: reasonValue,
            hintText: tr.scheduleSlotGuestReasonHint,
            onChanged: onReasonChanged,
            keySuffix: "reason",
          ),
          const SizedBox(height: 2),
          _buildTextLine(
            context,
            value: notesValue,
            hintText: tr.scheduleSlotGuestNotesHint,
            onChanged: onNotesChanged,
            keySuffix: "notes",
          ),
        ],
      ),
    );
  }

  /// One of this row's own two free-text lines (reason, notes): [_OcptScheduleSlotNoteField]'s own
  /// controller-sync field while [onChanged] is non-null, or plain read-only text — drawing
  /// **nothing at all** while empty, the same rule [OcptScheduleSlotCard._buildNoteField] already
  /// follows for the slot's own note.
  Widget _buildTextLine(
    BuildContext context, {
    required String value,
    required String hintText,
    required ValueChanged<String>? onChanged,
    required String keySuffix,
  }) {
    if (onChanged == null) {
      if (value.isEmpty) {
        return const SizedBox.shrink();
      }
      return Text(value, style: Theme.of(context).textTheme.bodySmall);
    }

    return _OcptScheduleSlotNoteField(
      key: ValueKey("${guest.id}-$keySuffix"),
      value: value,
      hintText: hintText,
      onChanged: onChanged,
    );
  }
}

/// The slot card's own single-line label field, following the same controller-sync idiom as
/// `OcptScheduleInspector`'s own note field: [value] is the field's current authoritative value,
/// and the internal controller is only reset to it when it genuinely differs from what the
/// controller already holds, so the caret never jumps mid-typing.
class _OcptScheduleSlotLabelField extends StatefulWidget {
  /// The field's current authoritative value.
  final String value;

  /// The hint shown while [value] is empty.
  final String hintText;

  /// Called with the field's raw text on every keystroke.
  final ValueChanged<String> onChanged;

  /// Class constructor
  const _OcptScheduleSlotLabelField({
    super.key,
    required this.value,
    required this.hintText,
    required this.onChanged,
  });

  @override
  State<_OcptScheduleSlotLabelField> createState() => _OcptScheduleSlotLabelFieldState();
}

/// The state of [_OcptScheduleSlotLabelField]: owns the controller the class doc comment explains.
class _OcptScheduleSlotLabelFieldState extends State<_OcptScheduleSlotLabelField> {
  /// The field's own text editing controller, seeded from the widget's initial value and kept in
  /// sync with it afterward, see [didUpdateWidget].
  late final TextEditingController _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant _OcptScheduleSlotLabelField oldWidget) {
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

/// The slot card's own note field, below its location · set line — [_OcptScheduleSlotLabelField]'s
/// own controller-sync idiom, drawn as a body-sized field that grows with what is typed into it
/// rather than a single-line title.
class _OcptScheduleSlotNoteField extends StatefulWidget {
  /// The field's current authoritative value.
  final String value;

  /// The hint shown while [value] is empty.
  final String hintText;

  /// Called with the field's raw text on every keystroke.
  final ValueChanged<String> onChanged;

  /// Class constructor
  const _OcptScheduleSlotNoteField({
    super.key,
    required this.value,
    required this.hintText,
    required this.onChanged,
  });

  @override
  State<_OcptScheduleSlotNoteField> createState() => _OcptScheduleSlotNoteFieldState();
}

/// The state of [_OcptScheduleSlotNoteField]: owns the controller the class doc comment explains.
class _OcptScheduleSlotNoteFieldState extends State<_OcptScheduleSlotNoteField> {
  /// The field's own text editing controller, seeded from the widget's initial value and kept in
  /// sync with it afterward, see [didUpdateWidget].
  late final TextEditingController _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant _OcptScheduleSlotNoteField oldWidget) {
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
    maxLines: null,
    style: Theme.of(context).textTheme.bodySmall,
    decoration: InputDecoration(isDense: true, hintText: widget.hintText),
  );
}

/// The bordered card shell shared by [_OcptScheduleCrewMemberRow] and [_OcptScheduleCastRoleRow]:
/// the one place their common border, radius and padding are declared, so the two kinds of card
/// cannot drift from one another.
Widget _buildSlotPersonCard(BuildContext context, {required Widget child}) {
  final theme = Theme.of(context);

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
    decoration: BoxDecoration(
      border: Border.all(color: theme.colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
    ),
    child: child,
  );
}
