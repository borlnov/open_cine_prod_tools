// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_day_minute.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_day_timeline.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_slot_timeline.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_minute_field.dart';

/// The label of the day's own slot [slotId], as [otherSlots] carries it, or the unnamed-slot
/// wording when it has none (or names no slot of this day any more).
String _labelOfSlot(BuildContext context, List<(String, String)> otherSlots, String slotId) {
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

/// One choice of the slot card's own anchor menu: which edge is being pinned, and — for a link —
/// the slot whose **opposite** edge it reads. A null [_AnchorChoice.sourceSlotId] is the fixed-hour
/// entry of that edge.
class _AnchorChoice {
  /// The edge this entry pins.
  final OcptShootingSlotAnchorEdge edge;

  /// The slot this entry reads the opposite edge of, or null for a typed hour.
  final String? sourceSlotId;

  /// Class constructor
  const _AnchorChoice(this.edge, this.sourceSlotId);
}

/// One row of the anchor menu before it is drawn: a divider when [choice] is null, an entry
/// otherwise.
class _AnchorMenuRow {
  /// What picking the entry reports, or null for the divider.
  final _AnchorChoice? choice;

  /// The entry's wording.
  final String label;

  /// Whether the entry is the anchor in force.
  final bool isSelected;

  /// Why the entry is disabled, or null while it can be picked.
  final String? disabledReason;

  /// Class constructor
  const _AnchorMenuRow({
    this.choice,
    this.label = "",
    this.isSelected = false,
    this.disabledReason,
  });
}

/// The slot card header's own anchor control, right-aligned: the pinned edge on top — a menu
/// picking which edge that is and where its hour comes from, then either the typed hour or the
/// computed one — and the **opposite**, always-computed edge read out under it in the muted colour.
///
/// [isCompact] is the card's own header width falling under its compact threshold (the inspector
/// opening beside it, most often): a linked edge then reads as `⛓ <slot>` rather than the whole
/// sentence, which moves to the button's tooltip.
class OcptScheduleSlotAnchorControl extends StatelessWidget {
  /// The slot whose anchor is shown.
  final OcptShootingSlot slot;

  /// [slot]'s own computed timeline, or null while it has nothing placed yet.
  final OcptShootingSlotTimeline? timeline;

  /// The day's own other live slots, by id and by raw label.
  final List<(String, String)> otherSlots;

  /// Every live slot of the day mapped to the id its own anchor currently reads, or null when that
  /// anchor is a typed hour — what the menu greys a circular entry out with.
  final Map<String, String?> anchorSourceBySlotId;

  /// Whether the header is narrow enough for a linked edge to read in its short form.
  final bool isCompact;

  /// Called with the slot's own new anchor once picked or committed, or null while withheld.
  final void Function(OcptShootingSlotAnchorEdge edge, int? minute, String? sourceSlotId)?
  onAnchorChanged;

  /// Class constructor
  const OcptScheduleSlotAnchorControl({
    super.key,
    required this.slot,
    required this.timeline,
    required this.otherSlots,
    required this.anchorSourceBySlotId,
    required this.isCompact,
    required this.onAnchorChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    final isEndAnchored = slot.anchorEdge == OcptShootingSlotAnchorEdge.end;
    final resolvedStartMinute = timeline?.startMinute;
    // A slot with nothing placed in it ends where it starts.
    final resolvedEndMinute = timeline?.endMinute ?? resolvedStartMinute;
    final anchoredMinute = isEndAnchored ? resolvedEndMinute : resolvedStartMinute;
    final oppositeMinute = isEndAnchored ? resolvedStartMinute : resolvedEndMinute;
    final oppositeLabel = isEndAnchored ? tr.scheduleSlotStartLabel : tr.scheduleSlotEndLabel;
    final sourceLabel = slot.anchorSlotId == null
        ? null
        : _labelOfSlot(context, otherSlots, slot.anchorSlotId!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AnchorButton(
              slot: slot,
              timeline: timeline,
              otherSlots: otherSlots,
              anchorSourceBySlotId: anchorSourceBySlotId,
              isCompact: isCompact,
              sourceLabel: sourceLabel,
              anchoredMinute: anchoredMinute,
              onAnchorChanged: onAnchorChanged,
            ),
            const SizedBox(width: 4),
            // A linked edge's hour is computed like every other, so its field carries no callback
            // and renders as plain text — the same way every computed time in this mode is read
            // out.
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
}

/// The anchor control's own edge button: the flat menu when the card may be written to, the same
/// wording as plain text when it may not.
class _AnchorButton extends StatelessWidget {
  /// The slot whose anchor is shown.
  final OcptShootingSlot slot;

  /// [slot]'s own computed timeline, or null while it has nothing placed yet.
  final OcptShootingSlotTimeline? timeline;

  /// The day's own other live slots, by id and by raw label.
  final List<(String, String)> otherSlots;

  /// Every live slot of the day mapped to the id its own anchor currently reads.
  final Map<String, String?> anchorSourceBySlotId;

  /// Whether a linked edge reads in its short form.
  final bool isCompact;

  /// The label of the slot the anchor reads, or null for a typed hour.
  final String? sourceLabel;

  /// The hour the anchored edge currently sits at, or null while nothing places it.
  final int? anchoredMinute;

  /// Called with the slot's own new anchor once picked, or null while withheld.
  final void Function(OcptShootingSlotAnchorEdge edge, int? minute, String? sourceSlotId)?
  onAnchorChanged;

  /// Class constructor
  const _AnchorButton({
    required this.slot,
    required this.timeline,
    required this.otherSlots,
    required this.anchorSourceBySlotId,
    required this.isCompact,
    required this.sourceLabel,
    required this.anchoredMinute,
    required this.onAnchorChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final isEndAnchored = slot.anchorEdge == OcptShootingSlotAnchorEdge.end;

    final sentence = sourceLabel == null
        ? (isEndAnchored ? tr.scheduleSlotEndLabel : tr.scheduleSlotStartLabel)
        : (isEndAnchored
              ? tr.scheduleSlotAnchorEndFromSlot(sourceLabel!)
              : tr.scheduleSlotAnchorStartFromSlot(sourceLabel!));
    final shown = sourceLabel != null && isCompact
        ? tr.scheduleSlotAnchorLinkedShort(sourceLabel!)
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

    return PopupMenuButton<_AnchorChoice>(
      tooltip: sourceLabel == null ? tr.scheduleSlotAnchorTooltip : sentence,
      onSelected: _onChoicePicked,
      itemBuilder: _buildMenu,
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
  ///
  /// An entry that would close a circle is shown **disabled with its reason** rather than left out,
  /// a `✓` marking the anchor in force.
  List<PopupMenuEntry<_AnchorChoice>> _buildMenu(BuildContext context) {
    final tr = Tr.of(context);
    final isLinked = slot.anchorSlotId != null;

    final rows = [
      _AnchorMenuRow(
        choice: const _AnchorChoice(OcptShootingSlotAnchorEdge.start, null),
        label: tr.scheduleSlotAnchorStartFixed,
        isSelected: !isLinked && slot.anchorEdge == OcptShootingSlotAnchorEdge.start,
      ),
      _AnchorMenuRow(
        choice: const _AnchorChoice(OcptShootingSlotAnchorEdge.end, null),
        label: tr.scheduleSlotAnchorEndFixed,
        isSelected: !isLinked && slot.anchorEdge == OcptShootingSlotAnchorEdge.end,
      ),
      if (otherSlots.isNotEmpty) const _AnchorMenuRow(),
      for (final (sourceId, rawLabel) in otherSlots)
        for (final edge in OcptShootingSlotAnchorEdge.values)
          _AnchorMenuRow(
            choice: _AnchorChoice(edge, sourceId),
            label: edge == OcptShootingSlotAnchorEdge.start
                ? tr.scheduleSlotAnchorStartFromSlot(_labelOf(context, rawLabel))
                : tr.scheduleSlotAnchorEndFromSlot(_labelOf(context, rawLabel)),
            isSelected: slot.anchorSlotId == sourceId && slot.anchorEdge == edge,
            disabledReason:
                ocptSlotAnchorWouldCycle(
                  anchorSourceBySlotId: anchorSourceBySlotId,
                  slotId: slot.id,
                  sourceSlotId: sourceId,
                )
                ? tr.scheduleSlotAnchorCycleReason
                : null,
          ),
    ];

    return [
      for (final row in rows)
        if (row.choice == null)
          const PopupMenuDivider()
        else
          PopupMenuItem<_AnchorChoice>(
            value: row.choice,
            enabled: row.disabledReason == null,
            child: _AnchorMenuItemContent(
              label: row.label,
              isSelected: row.isSelected,
              disabledReason: row.disabledReason,
            ),
          ),
    ];
  }

  /// Reports [choice] to [onAnchorChanged], **freezing the hour the edge was reading** when it goes
  /// back to a typed one: switching away from a link pre-fills the field with what it was showing
  /// at that moment, rather than emptying it or resurrecting whatever was typed before the link.
  void _onChoicePicked(_AnchorChoice choice) {
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
}

/// The content of one anchor menu entry: its wording, a `✓` when it is the anchor in force and —
/// when it would close a circle — its own reason under it, greyed rather than left out.
class _AnchorMenuItemContent extends StatelessWidget {
  /// The entry's wording.
  final String label;

  /// Whether the entry is the anchor in force.
  final bool isSelected;

  /// Why the entry is disabled, or null while it can be picked.
  final String? disabledReason;

  /// Class constructor
  const _AnchorMenuItemContent({
    required this.label,
    required this.isSelected,
    required this.disabledReason,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              if (disabledReason != null)
                Text(
                  disabledReason!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        if (isSelected) const Icon(Icons.check, size: 14),
      ],
    );
  }
}
