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
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_set.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_cast_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_crew_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_crew_department.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_minute_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_timetable.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_schedule_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_day_timeline.dart';

/// The value the "no location" entry of the location picker menu carries, distinct from every
/// location id — a [PopupMenuButton] cannot carry a null value for an entry that must still be
/// selectable.
const String _noLocationOption = "";

/// The width every crew or cast card of a slot's own people sections claims when there is room for
/// it. [OcptScheduleSlotCard.build] never hands a card more than half its own body width, though: a
/// half narrower than this shrinks every card of that half down to fit instead of overflowing it.
const double _personCardWidth = 230;

/// One slot's own card in the day view: its label, its location and set, its own note below
/// them — what this slot alone needs saying, the day's own note to the crew being a different
/// thing — its own **start**
/// minute — the one clock left on a slot — then a row of two halves, `Équipe technique` (grouped by
/// department, foldable — see [_OcptScheduleCrewSection]) and `Comédiens`, each ending on its own
/// `+ Crew member`/`+ Cast` footer opening a person or role picker right there on the card, with no
/// duplicate list anywhere in the right dock — and, below both, this slot's **own**
/// [OcptScheduleTimetable]: a day used to carry one timetable shared by every slot; now each card
/// draws its own, over its own [blocks] alone, chained by its own [timeline]. Neither half is ever
/// handed more than half the card's own body width, and every crew or cast card within its own half
/// wraps at [_personCardWidth] (shrunk to fit when that half is narrower), so a wide day view flows
/// several cards per row instead of leaving the sides empty.
///
/// **A crew or cast row says only who is convoked and in what function** (ADR 0018): a convocation
/// is a fact about a person on a **day**, joined across every slot they sit on, so it cannot be read
/// from one slot's card in isolation — the computed arrival/PAT/departure that used to sit here move
/// to the day's own convocations panel instead. The one editable clock on the whole card is the
/// slot's own start ([onStartChanged]).
///
/// Every writing affordance is a nullable callback, withheld while a project version is being
/// previewed (`isReadOnly`): the label field, the location/set pickers, the note field below them,
/// the start field, the `▲`/`▼` controls moving the card in its day's list, every
/// crew/cast row's own position picker and remove control, both `+`
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

  /// Called with the slot's own new start minute once committed, or null while withheld.
  final ValueChanged<int>? onStartChanged;

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

  /// Called with a crew assignment's id and the catalogue position just picked, or null while
  /// withheld.
  final void Function(String crewMemberId, String positionId)? onCrewMemberPositionChanged;

  /// Called with a crew assignment's id when its row's remove control is clicked, or null while
  /// withheld.
  final ValueChanged<String>? onCrewMemberRemoved;

  /// Called with the id of the role picked by the `+ Cast` footer, or null while withheld.
  final ValueChanged<String>? onCastRoleAdded;

  /// Called with a cast convocation's id when its row's remove control is clicked, or null while
  /// withheld.
  final ValueChanged<String>? onCastRoleRemoved;

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
    required this.onStartChanged,
    required this.onMovedUp,
    required this.onMovedDown,
    required this.onDeletionRequested,
    required this.onCrewMemberAdded,
    required this.onCrewMemberPositionChanged,
    required this.onCrewMemberRemoved,
    required this.onCastRoleAdded,
    required this.onCastRoleRemoved,
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  constraints: const BoxConstraints(minHeight: 30),
                  decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 11),
                Expanded(child: _buildHeaderFields(context)),
                const SizedBox(width: 11),
                _buildStartField(context),
                if (onMovedUp != null || onMovedDown != null) _buildMoveControls(context),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
            child: _OcptScheduleSlotPeople(
              crewBuilder: ({required isExpanded, required onFoldToggled, required cardWidth}) =>
                  _OcptScheduleCrewSection(
                crew: slot.crew,
                personById: personById,
                people: people,
                cardWidth: cardWidth,
                isExpanded: isExpanded,
                onFoldToggled: onFoldToggled,
                onCrewMemberAdded: onCrewMemberAdded,
                onCrewMemberPositionChanged: onCrewMemberPositionChanged,
                onCrewMemberRemoved: onCrewMemberRemoved,
              ),
              castBuilder: ({required isExpanded, required onFoldToggled, required cardWidth}) =>
                  _buildCastColumn(
                    context,
                    cardWidth: cardWidth,
                    isExpanded: isExpanded,
                    onFoldToggled: onFoldToggled,
                  ),
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

  /// The header's own start field — the one clock a slot still carries, right-aligned.
  Widget _buildStartField(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("${tr.scheduleSlotStartLabel} ", style: theme.textTheme.labelSmall),
        OcptScheduleMinuteField(
          minute: slot.startMinute,
          isClearable: false,
          emptyHint: "—",
          onChanged: onStartChanged == null
              ? null
              : (value) => onStartChanged!(value ?? slot.startMinute),
        ),
      ],
    );
  }

  /// The `Comédiens` half: [slot]'s own convoked roles wrapped at [cardWidth] each, then the
  /// `+ Cast` footer — both hidden while [isExpanded] is false, its title then standing for the
  /// whole half. That fold is [_OcptScheduleSlotPeople]'s own, shared with the crew half:
  /// [onFoldToggled] folds and unfolds **both**.
  Widget _buildCastColumn(
    BuildContext context, {
    required double cardWidth,
    required bool isExpanded,
    required VoidCallback onFoldToggled,
  }) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPeopleSectionTitle(
          context,
          title: tr.scheduleSlotCastColumnTitle,
          count: slot.cast.length,
          isExpanded: isExpanded,
          onFoldToggled: onFoldToggled,
        ),
        if (isExpanded) ...[
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
      ],
    );
  }
}

/// A people half's own title row, shared by [OcptScheduleSlotCard]'s cast half and
/// [_OcptScheduleCrewSection]: the fold chevron, the half's own name, and how many people it holds
/// — the count shown in both states, so a folded half never reads as an empty one and an unfolded
/// one still answers "how many" without counting cards.
///
/// Clicking it toggles **both** halves at once ([_OcptScheduleSlotPeople] owning the one fold they
/// share), which is why this is one widget rather than each half growing its own title.
Widget _buildPeopleSectionTitle(
  BuildContext context, {
  required String title,
  required int count,
  required bool isExpanded,
  required VoidCallback onFoldToggled,
}) {
  final theme = Theme.of(context);
  final titleStyle = theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

  return InkWell(
    mouseCursor: ocptClickableCursor,
    onTap: onFoldToggled,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isExpanded ? Icons.expand_less : Icons.expand_more,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 2),
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
    ),
  );
}

/// How [_OcptScheduleSlotPeople] asks the card for one of its two halves: the fold state the two
/// share, the control that toggles it, and the width one person card claims.
typedef _OcptScheduleSlotPeopleHalfBuilder =
    Widget Function({
      required bool isExpanded,
      required VoidCallback onFoldToggled,
      required double cardWidth,
    });

/// The two people halves of a slot card, side by side and **sharing one fold**: a click on either
/// title folds and unfolds them both, which is what Benoit asked for over an accordion where each
/// half answers only for itself.
///
/// It owns nothing but that fold — the halves themselves are built by the card, which is where
/// every row, callback and catalogue they need is already in scope, so this widget takes them as
/// builders rather than re-declaring a dozen fields it would only forward. The fold is per-view
/// [State], expanded by default: nothing is lost by it resetting the next time the card is built.
class _OcptScheduleSlotPeople extends StatefulWidget {
  /// Builds the crew half, given the shared fold state, the control toggling it, and the width one
  /// person card claims.
  final _OcptScheduleSlotPeopleHalfBuilder crewBuilder;

  /// Builds the cast half, from the same three.
  final _OcptScheduleSlotPeopleHalfBuilder castBuilder;

  /// Class constructor
  const _OcptScheduleSlotPeople({required this.crewBuilder, required this.castBuilder});

  @override
  State<_OcptScheduleSlotPeople> createState() => _OcptScheduleSlotPeopleState();
}

/// The state of [_OcptScheduleSlotPeople]: owns the fold the two halves share.
class _OcptScheduleSlotPeopleState extends State<_OcptScheduleSlotPeople> {
  /// Whether both halves show their own cards and footer.
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // Neither half is ever handed more than half the row's own width; a card's own fixed width
      // shrinks to fit when that half is narrower than it, so a narrow day view never overflows the
      // card the way two hard-coded column widths once could.
      final cardWidth = math.min(_personCardWidth, (constraints.maxWidth - 22) / 2);
      void onFoldToggled() => setState(() => _isExpanded = !_isExpanded);

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: widget.crewBuilder(
              isExpanded: _isExpanded,
              onFoldToggled: onFoldToggled,
              cardWidth: cardWidth,
            ),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: widget.castBuilder(
              isExpanded: _isExpanded,
              onFoldToggled: onFoldToggled,
              cardWidth: cardWidth,
            ),
          ),
        ],
      );
    },
  );
}

/// The `Équipe technique` half of [OcptScheduleSlotCard]'s own body: [crew] grouped by department,
/// each department's own cards wrapped at [cardWidth], then the `+ Crew member` footer — all of it
/// hidden while [isExpanded] is false, its title then standing for the whole half.
///
/// The fold itself belongs to [_OcptScheduleSlotPeople], which the cast half shares: [onFoldToggled]
/// folds and unfolds **both**.
class _OcptScheduleCrewSection extends StatelessWidget {
  /// The slot's own crew assignments, in `sortKey` order.
  final List<OcptShootingSlotCrewMember> crew;

  /// The whole address book, keyed by id — what a crew row's own name is read off.
  final Map<String, OcptPerson> personById;

  /// The whole address book, in display order — what the `+ Crew member` picker offers.
  final List<OcptPerson> people;

  /// The width every crew card of this half claims — see [_personCardWidth]'s own doc comment.
  final double cardWidth;

  /// Whether this half shows its own cards and footer, or its title alone.
  final bool isExpanded;

  /// Toggles the fold both halves share.
  final VoidCallback onFoldToggled;

  /// Called with the id of the person picked by the `+ Crew member` footer, or null while withheld.
  final ValueChanged<String>? onCrewMemberAdded;

  /// Called with a crew assignment's id and the catalogue position just picked, or null while
  /// withheld.
  final void Function(String crewMemberId, String positionId)? onCrewMemberPositionChanged;

  /// Called with a crew assignment's id when its row's remove control is clicked, or null while
  /// withheld.
  final ValueChanged<String>? onCrewMemberRemoved;

  /// Class constructor
  const _OcptScheduleCrewSection({
    required this.crew,
    required this.personById,
    required this.people,
    required this.cardWidth,
    required this.isExpanded,
    required this.onFoldToggled,
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
        _buildPeopleSectionTitle(
          context,
          title: tr.scheduleSlotCrewColumnTitle,
          count: crew.length,
          isExpanded: isExpanded,
          onFoldToggled: onFoldToggled,
        ),
        if (isExpanded) ...[
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
                            child: _OcptScheduleCrewMemberRow(
                              key: ValueKey(member.id),
                              member: member,
                              person: personById[member.personId],
                              onPositionChanged: onCrewMemberPositionChanged == null
                                  ? null
                                  : (positionId) =>
                                      onCrewMemberPositionChanged!(member.id, positionId),
                              onRemoved: onCrewMemberRemoved == null
                                  ? null
                                  : () => onCrewMemberRemoved!(member.id),
                            ),
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
      ],
    );
  }
}

/// One crew card of [OcptScheduleSlotCard]'s own `Équipe technique` column, built exactly like
/// [_OcptScheduleCastRoleRow]'s own card (see [_buildSlotPersonCard]): the position picker and the
/// remove control on the first line, the person's own name underneath.
class _OcptScheduleCrewMemberRow extends StatelessWidget {
  /// The crew assignment this row shows.
  final OcptShootingSlotCrewMember member;

  /// The person [member] names, or null while not yet loaded.
  final OcptPerson? person;

  /// Called with the catalogue position just picked, or null while withheld.
  final ValueChanged<String>? onPositionChanged;

  /// Called when this row's remove control is clicked, or null while withheld.
  final VoidCallback? onRemoved;

  /// Class constructor
  const _OcptScheduleCrewMemberRow({
    super.key,
    required this.member,
    required this.person,
    required this.onPositionChanged,
    required this.onRemoved,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final positionLabel = member.positionId.isEmpty
        ? (member.customLabel.isEmpty ? tr.resourcesPositionScopePlaceholder : member.customLabel)
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
                    : PopupMenuButton<String>(
                        tooltip: "",
                        onSelected: onPositionChanged,
                        itemBuilder: (context) => [
                          for (final position in ocptCrewPositions)
                            PopupMenuItem<String>(
                              value: position.id,
                              child: Text(ocptCrewPositionLabel(tr, position.id)),
                            ),
                        ],
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
