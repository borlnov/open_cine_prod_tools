// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_candidate.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_schedule_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_day_timeline.dart';

/// One slot's **compact** rendering in the day view: its resolved hours, the single audition it
/// holds — who is seen, for which part — and the control opening it back into its full
/// `OcptScheduleSlotCard`.
///
/// **A rendering, not a second model.** Convoking twelve candidates at twenty-minute intervals
/// costs twelve slots — that follows from ADR 0018, a convocation *being* the slot you are linked
/// to — and twelve full cards is a lot of surface for twelve twenty-minute auditions. This row is
/// the answer to that, and only to that: a slot whose whole content is one audition block draws as
/// one line, and the day view falls back to the full card the moment it carries anything more. The
/// file says exactly what it said before; only the reading is shorter.
///
/// It is **read-only by construction**: nothing here writes, and everything a user might want to do
/// to the slot — its hour, its place, its people, its block's own duration — is one click away
/// behind [onExpandRequested]. That is deliberate rather than a shortcut: a row that carried half
/// the card's affordances would be a second, poorer card, and choosing which half to keep is a
/// decision nobody made.
class OcptScheduleCompactSlotRow extends StatelessWidget {
  /// The slot this row stands for.
  final OcptShootingSlot slot;

  /// The single audition block [slot] holds — what this row reads its title off.
  final OcptShootingDayBlock auditionBlock;

  /// [slot]'s own computed timeline, or null while it has nothing chained yet — the hours printed
  /// on the left are the **resolved** ones, exactly as every other surface of this mode reads them.
  final OcptShootingSlotTimeline? timeline;

  /// The whole cast, keyed by id — what the part somebody is seen for is named through.
  final Map<String, OcptRole> roleById;

  /// Every live candidacy, keyed by id — what the person being seen is named through.
  final Map<String, OcptRoleCandidate> roleCandidateById;

  /// Called when the row's own control is clicked, opening this slot back into its full card. Never
  /// null: the row would otherwise be a dead end.
  final VoidCallback onExpandRequested;

  /// Class constructor
  const OcptScheduleCompactSlotRow({
    super.key,
    required this.slot,
    required this.auditionBlock,
    required this.timeline,
    required this.roleById,
    required this.roleCandidateById,
    required this.onExpandRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final mutedStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return InkWell(
      onTap: onExpandRequested,
      mouseCursor: ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(ocptRadiusSmall),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 106,
              child: Text(
                _hoursLabel(),
                style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Icon(
              ocptShootingBlockKindIcon(auditionBlock.kind),
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _auditionTitleOf(tr),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
            if (slot.label.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(slot.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: mutedStyle),
            ],
            IconButton(
              icon: const Icon(Icons.unfold_more, size: 15),
              visualDensity: VisualDensity.compact,
              tooltip: tr.scheduleExpandSlotTooltip,
              onPressed: onExpandRequested,
            ),
          ],
        ),
      ),
    );
  }

  /// The row's own hours: the slot's resolved start and the end of its single block, or an em dash
  /// while nothing is chained yet — never a stored column, an end-anchored slot starting wherever
  /// its own blocks put it. Read through [ocptScheduleDayMinuteRangeLabel], the same reading every
  /// other surface of this mode gives a pair of resolved minutes.
  String _hoursLabel() =>
      ocptScheduleDayMinuteRangeLabel(timeline?.startMinute, timeline?.endMinute);

  /// Who is seen, and for which part — the very reading an audition's own timetable row gives, and
  /// read just as defensively: a candidacy removed, or a part deleted, under a plan that still holds
  /// the block leaves the row naming the address book's own fallbacks rather than going blank.
  String _auditionTitleOf(Tr tr) {
    final candidate = roleCandidateById[auditionBlock.roleCandidateId];
    final role = roleById[auditionBlock.roleId];

    return tr.scheduleAuditionBlockLabel(
      candidate == null || candidate.person.displayName.isEmpty
          ? tr.resourcesUnnamedPerson
          : candidate.person.displayName,
      role == null || role.name.isEmpty ? tr.resourcesRoleUnnamed : role.name,
    );
  }
}
