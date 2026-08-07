// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_schedule_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_convocations.dart';

/// The right dock's own `Convocations` tab: the selected day's whole call, one card per **person**
/// (crew and cast folded together — an actor is read through `roles.personId`, so the question this
/// panel answers is "when does this human arrive" rather than "who plays what") or per **uncast
/// role** — a convocation nobody has cast yet, still owed to the production. This is the reading
/// nobody could get from a single slot card any more, once a person may sit on several of a day's
/// slots at once (ADR 0018): a slot card only ever draws its own `startMinute`, and every other
/// clock about a person moved here.
///
/// Entirely **read-only**: every figure on a card is computed by `ocptComputeDayConvocations`
/// (through `OcptScheduleState.convocationsOfDay`), and the only way to change any of them is to
/// move a block or a slot elsewhere in the day view. Unlike every other panel of this mode, this
/// widget therefore takes no `isReadOnly` flag and gates no callback — it offers none to begin
/// with — and draws identically whether the working copy or a version preview is on screen.
class OcptScheduleConvocationsPanel extends StatelessWidget {
  /// The selected day's own whole call, in whatever order `ocptComputeDayConvocations` returned it
  /// (arrival, then id — see that function's own doc comment) — this widget re-sorts by arrival
  /// then by the resolved display title before drawing a single row, since the pure function knows
  /// neither a person's nor a role's own name to sort on. Null while no day is selected, which is
  /// the panel's whole scope: a convocation is a fact about a person on a **day**, joined across
  /// every slot they sit on, so there is nothing to show without one.
  final List<OcptDayConvocation>? convocations;

  /// The whole address book, keyed by id — a convocation's own [OcptDayConvocation.personId] is
  /// resolved to a display name through this map.
  final Map<String, OcptPerson> personById;

  /// The whole cast, keyed by id — an uncast convocation's own [OcptDayConvocation.roleId] is
  /// resolved to a name through this map.
  final Map<String, OcptRole> roleById;

  /// The selected day's own live slots, keyed by id — every entry of an
  /// [OcptDayConvocation.slotIds] is resolved to a label through this map.
  final Map<String, OcptShootingSlot> slotById;

  /// Class constructor
  const OcptScheduleConvocationsPanel({
    super.key,
    required this.convocations,
    required this.personById,
    required this.roleById,
    required this.slotById,
  });

  @override
  Widget build(BuildContext context) {
    final convocations = this.convocations;
    final tr = Tr.of(context);

    if (convocations == null) {
      return _buildHint(context, tr.scheduleConvocationsEmptyHint);
    }

    final rows = _sortedRows(tr);
    if (rows.isEmpty) {
      return _buildHint(context, tr.scheduleConvocationsNoConvocationHint);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final (convocation, title) = rows[index];
        return _OcptScheduleConvocationCard(
          title: title,
          bandLabel: ocptScheduleConvocationBandLabel(convocation),
          slotsLabel: ocptScheduleConvocationSlotsLabel(tr, convocation, slotById),
        );
      },
    );
  }

  /// Every entry of [convocations] paired with its resolved display title, sorted by arrival then
  /// by that title — the order people actually walk in, which `ocptComputeDayConvocations` itself
  /// cannot produce: it ties on id for want of a name, and resolving one is this state's own job,
  /// not that pure function's (see [OcptDayConvocation]'s own doc comment).
  List<(OcptDayConvocation, String)> _sortedRows(Tr tr) {
    final rows = [
      for (final convocation in convocations!)
        (convocation, ocptScheduleConvocationTitle(tr, convocation, personById, roleById)),
    ];

    rows.sort((left, right) {
      final byArrival = left.$1.arrivalMinute.compareTo(right.$1.arrivalMinute);
      if (byArrival != 0) {
        return byArrival;
      }
      return left.$2.compareTo(right.$2);
    });

    return rows;
  }

  /// The panel's own empty-state read-out — a centred, muted, small hint — the exact idiom
  /// `OcptScheduleInspector` already shows with nothing selected, reused rather than a second one
  /// invented for this panel.
  Widget _buildHint(BuildContext context, String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ),
  );
}

/// One card of [OcptScheduleConvocationsPanel]: the resolved [title] on its own line, then the
/// arrival → PAT band → departure line, then the slots the person or role is linked to — the
/// layout Benoit asked for, drawn from the studio's own card component theme
/// (`lib/constants/ocpt_theme.dart`) rather than a bespoke radius or fill.
class _OcptScheduleConvocationCard extends StatelessWidget {
  /// The card's own title line — a person's display name, or an uncast role's own name suffixed
  /// with the "not cast" marker (see [ocptScheduleConvocationTitle]'s own doc comment).
  final String title;

  /// The arrival → PAT band → departure line (see [ocptScheduleConvocationBandLabel]'s own doc
  /// comment).
  final String bandLabel;

  /// The slots this convocation is linked to, by label, joined with " · " (see
  /// [ocptScheduleConvocationSlotsLabel]'s own doc comment) — never empty, since a convocation
  /// always names at least the one slot it was built from.
  final String slotsLabel;

  /// Class constructor
  const _OcptScheduleConvocationCard({
    required this.title,
    required this.bandLabel,
    required this.slotsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(bandLabel, style: theme.textTheme.bodySmall),
            const SizedBox(height: 2),
            Text(
              slotsLabel,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
