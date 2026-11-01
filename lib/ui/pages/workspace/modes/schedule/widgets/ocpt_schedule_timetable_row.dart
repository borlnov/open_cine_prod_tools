// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_candidate.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_day_minute.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_timeline_entry.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_dragged_block.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_minute_field.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_schedule_labels.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_shot_list_labels.dart';

/// The grid [_ocptStepDurationUp]/[_ocptStepDurationDown] snap a duration onto — five minutes,
/// matching the shot list's own estimate granularity.
const int _ocptDurationStepGridMinutes = 5;

/// The value the "no sequence yet" entry of a hold row's own sequence picker menu carries, distinct
/// from every scene id — a [PopupMenuButton] cannot carry a null value for an entry that must still
/// be selectable, the same convention `OcptScheduleSlotCard`'s own `_noLocationOption`/
/// `_noGroupOption` already use.
const String _noSequenceOption = "";

/// One block's own row of the timetable.
class OcptScheduleTimetableRow extends StatelessWidget {
  /// The block this row shows.
  final OcptShootingDayBlock block;

  /// This block's own computed timeline entry, or null while the slot has no timeline yet.
  final OcptShootingTimelineEntry? entry;

  /// Whether this block's own pinned anchor could not be honoured (ADR 0015 rule 4).
  final bool isOverrun;

  /// The shot [block] places, when [block]'s own kind is [OcptShootingBlockKind.shot].
  final OcptShot? shot;

  /// The whole cast — only read when [block]'s own kind is [OcptShootingBlockKind.audition], to
  /// name and to group the parts its candidacies are seen for.
  final List<OcptRole> roles;

  /// Every live candidacy of the project, keyed by id — see
  /// the timetable's own `roleCandidateById`.
  final Map<String, OcptRoleCandidate> roleCandidateById;

  /// Whether this is the currently selected block.
  final bool isSelected;

  /// This row's own index, when it sits inside a [ReorderableListView] (`onReordered` is not
  /// withheld) — [ReorderableListView] requires every child to carry one.
  final int? reorderIndex;

  /// Every real scene of the screenplay's shot list — see the timetable's own `sequences`. Only
  /// read when [block]'s own kind names a sequence — see [_namesASequence].
  final List<OcptSceneShotSequence> sequences;

  /// The day's own other live slots, by id and by raw label — see
  /// the timetable's own `otherSlots`.
  final List<(String, String)> otherSlots;

  /// Called when this row is clicked.
  final VoidCallback onSelected;

  /// Called with the new duration once a `±` control is tapped, or null while withheld (which also
  /// hides the controls).
  final ValueChanged<int>? onDurationChanged;

  /// Called with the new anchor once the pin is toggled or the pinned minute is retyped, or null
  /// while withheld (which also hides both).
  final ValueChanged<int?>? onAnchorChanged;

  /// Called with the status just picked, or null while withheld or this isn't a shot block.
  final ValueChanged<OcptShotStatus>? onShotStatusChanged;

  /// Called with the scene just picked from this row's own sequence picker (null for "no sequence
  /// yet"), or null while withheld or [block]'s own kind names no sequence — see [_namesASequence].
  final ValueChanged<String?>? onSequenceChanged;

  /// Called with the id of the candidacy just picked from this row's own `+` picker, or null while
  /// withheld or [block] isn't an [OcptShootingBlockKind.audition].
  final ValueChanged<String>? onCandidateAdded;

  /// Called with a candidacy convocation's own id when its chip's remove control is clicked, or
  /// null under the same conditions as [onCandidateAdded].
  final ValueChanged<String>? onCandidateRemoved;

  /// Called when this row's own remove control is clicked, or null while withheld.
  final VoidCallback? onDeletionRequested;

  /// Called with the id of the slot picked from this row's own `Move to…` menu, or null while
  /// withheld — which also makes this row undraggable, [otherSlots] having nowhere left to matter.
  final ValueChanged<String>? onMovedToSlot;

  /// Whether this row's own block names a sequence through `shooting_day_blocks.sceneId` — a hold
  /// reserving one's time, or a rehearsal working it — which is what draws the sequence picker.
  bool get _namesASequence =>
      block.kind == OcptShootingBlockKind.hold || block.kind == OcptShootingBlockKind.rehearsal;

  /// Class constructor
  const OcptScheduleTimetableRow({
    super.key,
    required this.block,
    required this.entry,
    required this.isOverrun,
    required this.shot,
    required this.roles,
    required this.roleCandidateById,
    required this.isSelected,
    required this.reorderIndex,
    required this.sequences,
    required this.otherSlots,
    required this.onSelected,
    required this.onDurationChanged,
    required this.onAnchorChanged,
    required this.onShotStatusChanged,
    required this.onSequenceChanged,
    required this.onCandidateAdded,
    required this.onCandidateRemoved,
    required this.onDeletionRequested,
    required this.onMovedToSlot,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final entry = this.entry;
    final isShot = block.kind == OcptShootingBlockKind.shot;
    final shot = this.shot;
    final timeColor = isOverrun ? theme.colorScheme.error : theme.colorScheme.onSurface;
    final title = isShot
        ? (shot == null ? "" : "${shot.code} · ${shot.shotSize}")
        : (block.label.isEmpty ? ocptShootingBlockKindLabel(tr, block.kind) : block.label);
    final canMove = onMovedToSlot != null && otherSlots.isNotEmpty;

    // Everything but the drag handle below: kept as its own widget so it — and only it — can be
    // wrapped in a cross-slot [Draggable] without that drag ever competing with the handle's own
    // [ReorderableDragStartListener] for the same pointer. The two sit on disjoint areas of the
    // row, so the gesture arena never has to arbitrate between them.
    final rowTail = Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(
            entry == null
                ? "—"
                : "${ocptFormatDayMinute(entry.startMinute)} → "
                      "${ocptFormatDayMinute(entry.endMinute)}",
            style: theme.textTheme.labelSmall?.copyWith(
              color: timeColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Icon(
          ocptShootingBlockKindIcon(block.kind),
          size: 14,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        if (_namesASequence)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _OcptScheduleSequencePicker(
              block: block,
              sequences: sequences,
              onSequenceChanged: onSequenceChanged,
            ),
          ),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ),
        // A pinned block's own minute is typed here rather than only captured from the chain:
        // the moments an anchor exists for — a meal break's legal start, a flight, a location
        // lost at dusk (ADR 0015) — are named times, and pinning a block wherever the chain
        // happened to put it could never express one of them.
        if (block.anchorMinute != null && onAnchorChanged != null)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: OcptScheduleMinuteField(
              minute: block.anchorMinute,
              isClearable: false,
              emptyHint: "—",
              onChanged: onAnchorChanged,
            ),
          ),
        if (onAnchorChanged != null)
          IconButton(
            icon: Icon(
              block.anchorMinute != null ? Icons.push_pin : Icons.push_pin_outlined,
              size: 15,
            ),
            tooltip: tr.scheduleAnchorPinTooltip,
            visualDensity: VisualDensity.compact,
            color: block.anchorMinute != null ? theme.colorScheme.primary : null,
            onPressed: () =>
                onAnchorChanged!(block.anchorMinute != null ? null : entry?.startMinute),
          ),
        if (isShot && shot != null && onShotStatusChanged != null)
          PopupMenuButton<OcptShotStatus>(
            tooltip: "",
            onSelected: onShotStatusChanged,
            itemBuilder: (context) => [
              for (final status in OcptShotStatus.values)
                PopupMenuItem<OcptShotStatus>(
                  value: status,
                  child: Text(ocptShotStatusLabel(tr, status)),
                ),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ocptShotStatusLabel(tr, shot.status),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: ocptShotStatusColor(context, shot.status),
                  ),
                ),
                const Icon(Icons.arrow_drop_down, size: 14),
              ],
            ),
          )
        else if (isShot && shot != null)
          Text(
            ocptShotStatusLabel(tr, shot.status),
            style: theme.textTheme.labelSmall?.copyWith(
              color: ocptShotStatusColor(context, shot.status),
            ),
          ),
        if (onDurationChanged != null && entry != null) ...[
          const SizedBox(width: 4),
          _OcptScheduleDurationStepper(
            durationMinutes: entry.durationMinutes,
            onChanged: onDurationChanged!,
          ),
        ] else if (entry != null) ...[
          const SizedBox(width: 4),
          Text(ocptFormatMinuteDuration(entry.durationMinutes), style: theme.textTheme.labelSmall),
        ],
        if (canMove) _OcptScheduleMoveToMenu(otherSlots: otherSlots, onMovedToSlot: onMovedToSlot),
        if (onDeletionRequested != null)
          IconButton(
            icon: const Icon(Icons.close, size: 15),
            tooltip: tr.scheduleRemoveBlockTooltip,
            visualDensity: VisualDensity.compact,
            onPressed: onDeletionRequested,
          ),
      ],
    );

    final rowBody = canMove
        ? Draggable<OcptScheduleDraggedBlock>(
            data: OcptScheduleDraggedBlock(blockId: block.id, sourceSlotId: block.slotId),
            feedback: _OcptScheduleDragFeedback(title: title),
            childWhenDragging: Opacity(opacity: 0.35, child: rowTail),
            child: rowTail,
          )
        : rowTail;

    // On a line of its own under the row, never inside it: a strip that wraps cannot share a line
    // with controls that must stay put, and it is left outside the [Draggable] so its own chips
    // keep their gestures rather than starting a cross-slot drag.
    final candidateStrip = block.kind == OcptShootingBlockKind.audition
        ? _OcptScheduleCandidateStrip(
            block: block,
            roles: roles,
            roleCandidateById: roleCandidateById,
            onCandidateAdded: onCandidateAdded,
            onCandidateRemoved: onCandidateRemoved,
          )
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onSelected,
        mouseCursor: ocpt_theme.ocptClickableCursor,
        borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusMedium),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: ocpt_theme.ocptSelectedStateAlpha)
                : theme.colorScheme.surfaceContainer,
            border: Border.all(
              color: isOverrun
                  ? theme.colorScheme.error
                  : (isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant),
            ),
            borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusMedium),
          ),
          child: Row(
            children: [
              if (reorderIndex != null)
                ReorderableDragStartListener(
                  index: reorderIndex!,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.drag_indicator,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              Expanded(
                child: candidateStrip == null
                    ? rowBody
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [rowBody, const SizedBox(height: 6), candidateStrip],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The floating preview shown while a row is being dragged onto another slot's own timetable —
/// just its own title, since a drop target only cares about which block it received.
class _OcptScheduleDragFeedback extends StatelessWidget {
  /// The title of the row being dragged.
  final String title;

  /// Class constructor
  const _OcptScheduleDragFeedback({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusMedium),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
      ),
    );
  }
}

/// A **hold** or **rehearsal** row's own sequence picker: [block]'s own `sceneId` read out as
/// [Tr.scheduleUnplacedSequenceLabel] (the same "SEQ 4A" tag the left dock's own unplaced-shots
/// list already prints) or [Tr.scheduleHoldSequencePickerNoSequenceOption] while it names none,
/// opening onto every one of [sequences] plus that same "no sequence" entry when
/// [onSequenceChanged] is given, or plain read-only text while it is withheld.
///
/// A `sceneId` naming a scene [sequences] no longer carries — deleted from the screenplay since
/// it was picked — reads the same as "no sequence yet" rather than crashing on a lookup that
/// found nothing: the picker still lets the user pick a live one in its place.
class _OcptScheduleSequencePicker extends StatelessWidget {
  /// The block whose `sceneId` is read out.
  final OcptShootingDayBlock block;

  /// Every real scene of the screenplay's shot list the picker offers.
  final List<OcptSceneShotSequence> sequences;

  /// Called with the scene just picked (null for "no sequence yet"), or null while withheld, which
  /// turns the picker into plain read-only text.
  final ValueChanged<String?>? onSequenceChanged;

  /// Class constructor
  const _OcptScheduleSequencePicker({
    required this.block,
    required this.sequences,
    required this.onSequenceChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final onSequenceChanged = this.onSequenceChanged;
    final sceneId = block.sceneId;
    OcptSceneShotSequence? currentSequence;
    for (final sequence in sequences) {
      if (sequence.sceneId == sceneId) {
        currentSequence = sequence;
        break;
      }
    }
    final currentLabel = currentSequence == null
        ? tr.scheduleHoldSequencePickerNoSequenceOption
        : tr.scheduleUnplacedSequenceLabel(currentSequence.displaySceneNumber);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );

    if (onSequenceChanged == null) {
      return Text(currentLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: labelStyle);
    }

    return PopupMenuButton<String>(
      tooltip: "",
      padding: EdgeInsets.zero,
      onSelected: (value) => onSequenceChanged(value == _noSequenceOption ? null : value),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: _noSequenceOption,
          child: Text(tr.scheduleHoldSequencePickerNoSequenceOption),
        ),
        const PopupMenuDivider(),
        for (final sequence in sequences)
          PopupMenuItem<String>(
            value: sequence.sceneId,
            child: Text(
              "${tr.scheduleUnplacedSequenceLabel(sequence.displaySceneNumber)} · "
              "${sequence.heading}",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(currentLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: labelStyle),
          Icon(Icons.arrow_drop_down, size: 14, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

/// An **audition** row's own candidacy strip: one chip per `shooting_block_candidates` row the
/// block names — who is being seen, and for which part — then the `+` picker offering every
/// candidacy of the project this block does not already name, grouped by role.
///
/// A [Wrap] rather than a [Row]: a block reading two actors of two different parts together names
/// two candidacies, and a timetable narrowed by a side dock has no width to promise them. The
/// picker is a [PopupMenuButton] and the chips are plain containers, so nothing here puts a
/// [MenuItemButton] inside that [Wrap] — see `OcptResourcesColorSwatches` for what that costs.
///
/// A chip whose candidacy [roleCandidateById] no longer holds is **left out**: the link points at
/// nobody, and drawing a nameless chip would be worse than drawing nothing. Nothing cascades it
/// away either — see `OcptShootingBlockCandidatesTable`.
///
/// A block naming nobody yet reads out [Tr.scheduleAuditionNoCandidateHint] beside its picker,
/// exactly as a hold with no sequence reads its own "no sequence yet": an ordinary state said
/// plainly rather than an empty strip nobody can tell from a bug.
class _OcptScheduleCandidateStrip extends StatelessWidget {
  /// The audition block whose candidacies are drawn.
  final OcptShootingDayBlock block;

  /// The whole cast, naming and grouping the parts the candidacies are seen for.
  final List<OcptRole> roles;

  /// Every live candidacy of the project, keyed by id.
  final Map<String, OcptRoleCandidate> roleCandidateById;

  /// Called with the id of the candidacy just picked, or null while withheld, which hides the `+`
  /// picker.
  final ValueChanged<String>? onCandidateAdded;

  /// Called with a candidacy convocation's own id when its chip's remove control is clicked, or
  /// null while withheld.
  final ValueChanged<String>? onCandidateRemoved;

  /// Class constructor
  const _OcptScheduleCandidateStrip({
    required this.block,
    required this.roles,
    required this.roleCandidateById,
    required this.onCandidateAdded,
    required this.onCandidateRemoved,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final onCandidateRemoved = this.onCandidateRemoved;
    final onCandidateAdded = this.onCandidateAdded;

    final named = <(String, OcptRoleCandidate)>[];
    final namedCandidacyIds = <String>{};
    for (final link in block.candidates) {
      namedCandidacyIds.add(link.roleCandidateId);
      final candidate = roleCandidateById[link.roleCandidateId];
      if (candidate != null) {
        named.add((link.id, candidate));
      }
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (named.isEmpty)
          Text(
            tr.scheduleAuditionNoCandidateHint,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        for (final (linkId, candidate) in named)
          _OcptScheduleAuditionCandidateChip(
            key: ValueKey(linkId),
            label: _ocptCandidacyLabelOf(tr, roles, candidate),
            onRemoved: onCandidateRemoved == null ? null : () => onCandidateRemoved(linkId),
          ),
        if (onCandidateAdded != null)
          _OcptScheduleCandidatePicker(
            roles: roles,
            roleCandidateById: roleCandidateById,
            namedCandidacyIds: namedCandidacyIds,
            onPicked: onCandidateAdded,
          ),
      ],
    );
  }
}

/// The `+` half of the candidacy strip: every candidacy of the project the block does not already
/// name, **grouped by the part it is for** — a disabled heading per role, then its own
/// candidacies — since a casting director looks for "who else was seen for Marie" rather than for
/// a name in one long list.
///
/// It offers what already exists and never creates: a candidate is recorded on the role sheet,
/// where the casting is decided. With nothing left to offer, the menu says why rather than
/// opening empty — a menu with no entry does not open at all, which reads as a dead button: the
/// project holds no candidacy yet ([Tr.scheduleAuditionPickerNoCandidacyHint]), or this block
/// already names every one ([Tr.scheduleAuditionCandidateAlreadyNamedHint]).
class _OcptScheduleCandidatePicker extends StatelessWidget {
  /// The whole cast, ordering the groups and naming their headings.
  final List<OcptRole> roles;

  /// Every live candidacy of the project, keyed by id.
  final Map<String, OcptRoleCandidate> roleCandidateById;

  /// The ids of the candidacies the block already names, left out of the menu.
  final Set<String> namedCandidacyIds;

  /// Called with the id of the candidacy just picked.
  final ValueChanged<String> onPicked;

  /// Class constructor
  const _OcptScheduleCandidatePicker({
    required this.roles,
    required this.roleCandidateById,
    required this.namedCandidacyIds,
    required this.onPicked,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final offerableByRoleId = <String, List<OcptRoleCandidate>>{};
    for (final candidate in roleCandidateById.values) {
      if (namedCandidacyIds.contains(candidate.id)) {
        continue;
      }
      (offerableByRoleId[candidate.roleId] ??= <OcptRoleCandidate>[]).add(candidate);
    }
    for (final group in offerableByRoleId.values) {
      group.sort((left, right) => left.person.displayName.compareTo(right.person.displayName));
    }

    // The groups in [roles]' own order — the very order the roles tab lists the cast in — rather
    // than in whatever order the candidacies happened to arrive. A group whose part [roles] does
    // not hold comes last, under the unnamed-role heading, rather than being dropped from the menu.
    final orderedRoleIds = [
      for (final role in roles)
        if (offerableByRoleId.containsKey(role.id)) role.id,
      for (final roleId in offerableByRoleId.keys)
        if (!roles.any((role) => role.id == roleId)) roleId,
    ];

    return PopupMenuButton<String>(
      tooltip: tr.scheduleAddAuditionCandidateAction,
      padding: EdgeInsets.zero,
      onSelected: onPicked,
      itemBuilder: (context) => [
        if (offerableByRoleId.isEmpty)
          PopupMenuItem<String>(
            enabled: false,
            child: Text(
              roleCandidateById.isEmpty
                  ? tr.scheduleAuditionPickerNoCandidacyHint
                  : tr.scheduleAuditionCandidateAlreadyNamedHint,
            ),
          ),
        for (final roleId in orderedRoleIds) ...[
          PopupMenuItem<String>(enabled: false, child: Text(_ocptRoleNameOf(tr, roles, roleId))),
          for (final candidate in offerableByRoleId[roleId]!)
            PopupMenuItem<String>(
              value: candidate.id,
              child: Text(
                candidate.person.displayName.isEmpty
                    ? tr.resourcesUnnamedPerson
                    : candidate.person.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 2),
          Text(
            tr.scheduleAddAuditionCandidateAction,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary),
          ),
        ],
      ),
    );
  }
}

/// One candidacy's own wording — who, and for which part — the pair every reading of a candidacy
/// in this app carries, since two candidacies of one person are two different things and a name
/// alone could not tell them apart.
///
/// The part is read through the candidacy's own `roleId` against [roles], defensively: a role
/// deleted under it falls back on the cast's own "unnamed" reading rather than emptying the chip.
String _ocptCandidacyLabelOf(Tr tr, List<OcptRole> roles, OcptRoleCandidate candidate) =>
    tr.scheduleAuditionBlockLabel(
      candidate.person.displayName.isEmpty
          ? tr.resourcesUnnamedPerson
          : candidate.person.displayName,
      _ocptRoleNameOf(tr, roles, candidate.roleId),
    );

/// The name of the part [roleId] names in [roles], or the cast's own "unnamed" reading when it
/// has none or [roles] does not hold it.
String _ocptRoleNameOf(Tr tr, List<OcptRole> roles, String roleId) {
  for (final role in roles) {
    if (role.id == roleId) {
      return role.name.isEmpty ? tr.resourcesRoleUnnamed : role.name;
    }
  }

  return tr.resourcesRoleUnnamed;
}

/// A row's own `Move to…` menu — every one of [otherSlots], by label (an empty one read out as
/// [Tr.scheduleInspectorUnnamedSlot]) — the keyboard/no-pointer path onto [onMovedToSlot], beside
/// the row's own cross-slot drag.
class _OcptScheduleMoveToMenu extends StatelessWidget {
  /// The day's own other live slots, by id and by raw label.
  final List<(String, String)> otherSlots;

  /// Called with the id of the slot picked.
  final ValueChanged<String>? onMovedToSlot;

  /// Class constructor
  const _OcptScheduleMoveToMenu({required this.otherSlots, required this.onMovedToSlot});

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return PopupMenuButton<String>(
      tooltip: tr.scheduleMoveBlockTooltip,
      icon: const Icon(Icons.drive_file_move_outline, size: 15),
      padding: EdgeInsets.zero,
      onSelected: onMovedToSlot,
      itemBuilder: (context) => [
        PopupMenuItem<String>(enabled: false, child: Text(tr.scheduleMoveBlockMenuTitle)),
        for (final (id, label) in otherSlots)
          PopupMenuItem<String>(
            value: id,
            child: Text(label.isEmpty ? tr.scheduleInspectorUnnamedSlot : label),
          ),
      ],
    );
  }
}

/// One candidacy an audition row names, drawn as a chip: who is being seen and for which part, plus
/// its own remove control while one is given.
///
/// A chip rather than a card, unlike every convocation on the slot above it, because this is a
/// reading of one line of a running order rather than a directory of the unit: a block regularly
/// names two of these, and two cards would push the timetable's own hours off the row they belong
/// to.
class _OcptScheduleAuditionCandidateChip extends StatelessWidget {
  /// Who is being seen, and for which part — already resolved by the row, this widget resolving
  /// nothing itself.
  final String label;

  /// Called when this chip's own remove control is clicked, or null while withheld — which hides
  /// the control rather than disabling it.
  final VoidCallback? onRemoved;

  /// Class constructor
  const _OcptScheduleAuditionCandidateChip({
    super.key,
    required this.label,
    required this.onRemoved,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Container(
      padding: EdgeInsets.only(left: 8, right: onRemoved == null ? 8 : 2, top: 2, bottom: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          if (onRemoved != null)
            IconButton(
              icon: const Icon(Icons.close, size: 13),
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(3),
              tooltip: tr.scheduleRemoveAuditionCandidateTooltip,
              onPressed: onRemoved,
            ),
        ],
      ),
    );
  }
}

/// The `±` duration controls, over the block's own currently resolved duration.
class _OcptScheduleDurationStepper extends StatelessWidget {
  /// The block's own currently resolved duration, in minutes.
  final int durationMinutes;

  /// Called with the new duration once `±` is tapped.
  final ValueChanged<int> onChanged;

  /// Class constructor
  const _OcptScheduleDurationStepper({required this.durationMinutes, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove, size: 13),
          visualDensity: VisualDensity.compact,
          onPressed: () => onChanged(_ocptStepDurationDown(durationMinutes)),
        ),
        SizedBox(
          width: 48,
          child: Text(
            ocptFormatMinuteDuration(durationMinutes),
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add, size: 13),
          visualDensity: VisualDensity.compact,
          onPressed: () => onChanged(_ocptStepDurationUp(durationMinutes)),
        ),
      ],
    );
  }
}

/// The smallest multiple of [_ocptDurationStepGridMinutes] strictly greater than [durationMinutes]
/// — what the stepper's `+` control reports. An off-grid duration snaps onto the grid rather than
/// merely growing past it (12 → 15, not 17); a duration already on the grid still moves by exactly
/// [_ocptDurationStepGridMinutes] (15 → 20).
int _ocptStepDurationUp(int durationMinutes) =>
    ((durationMinutes ~/ _ocptDurationStepGridMinutes) + 1) * _ocptDurationStepGridMinutes;

/// The largest multiple of [_ocptDurationStepGridMinutes] strictly smaller than [durationMinutes],
/// floored at zero — what the stepper's `−` control reports, mirroring [_ocptStepDurationUp]'s own
/// snap-to-grid rule (12 → 10, 15 → 10, and a duration under the grid's own first step → 0 rather
/// than a negative one).
int _ocptStepDurationDown(int durationMinutes) {
  final steppedDown =
      ((durationMinutes - 1) ~/ _ocptDurationStepGridMinutes) * _ocptDurationStepGridMinutes;
  return steppedDown < 0 ? 0 : steppedDown;
}
