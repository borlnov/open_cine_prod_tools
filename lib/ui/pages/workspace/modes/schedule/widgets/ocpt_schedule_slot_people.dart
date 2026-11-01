// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';

/// The width every crew or cast card of a slot's own people sections claims when there is room for
/// it. [OcptScheduleSlotPeople] never hands a card more than half its own body width, though: a
/// half narrower than this shrinks every card of that half down to fit instead of overflowing it.
const double _personCardWidth = 230;

/// The whole `Assigner des personnes` section of a slot card: the two people halves side by side —
/// `Équipe technique` and `Comédiens`, each handed at most half the row's width — then the
/// full-width `Invités` band under them, all three behind **one fold** carried by the section's own
/// title.
///
/// That is the one fold on the card, and it is deliberate: a settled crew, cast and guest list are
/// entered once and then read past for the rest of the shoot, so one gesture gets the reader to the
/// timetable rather than each kind needing its own. The three kinds' own titles are plain read-outs
/// (see `OcptScheduleSlotPeopleSubsectionTitle`), and the count on this one is the three of them
/// together, so a folded section never reads as an empty slot.
///
/// It owns nothing but that fold — the three parts themselves are built by the card, which is where
/// every row, callback and catalogue they need is already in scope, so this widget takes them as
/// builders rather than re-declaring a dozen fields it would only forward. The fold is per-view
/// [State], expanded by default: nothing is lost by it resetting the next time the card is built.
class OcptScheduleSlotPeople extends StatefulWidget {
  /// How many people the section holds altogether, crew, cast and guests — what its own title reads
  /// out in both fold states.
  final int peopleCount;

  /// Builds the crew half, given the width one person card claims.
  final Widget Function(double cardWidth) crewBuilder;

  /// Builds the cast half, from that same width.
  final Widget Function(double cardWidth) castBuilder;

  /// Builds the guest band, the whole of the second row, from the width one person card claims
  /// there.
  final Widget Function(double cardWidth) guestsBuilder;

  /// Class constructor
  const OcptScheduleSlotPeople({
    super.key,
    required this.peopleCount,
    required this.crewBuilder,
    required this.castBuilder,
    required this.guestsBuilder,
  });

  @override
  State<OcptScheduleSlotPeople> createState() => _OcptScheduleSlotPeopleState();
}

/// The state of [OcptScheduleSlotPeople]: owns the fold its three parts share.
class _OcptScheduleSlotPeopleState extends State<OcptScheduleSlotPeople> {
  /// Whether the section shows its three kinds of person, or its title alone.
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SectionTitle(
        isExpanded: _isExpanded,
        peopleCount: widget.peopleCount,
        onToggled: () => setState(() => _isExpanded = !_isExpanded),
      ),
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
        LayoutBuilder(
          builder: (context, constraints) =>
              widget.guestsBuilder(math.min(_personCardWidth, constraints.maxWidth)),
        ),
      ],
    ],
  );
}

/// The section's own clickable title: the fold chevron, its name, and how many people the three
/// kinds hold together.
class _SectionTitle extends StatelessWidget {
  /// Whether the section is currently unfolded.
  final bool isExpanded;

  /// How many people the three kinds hold together.
  final int peopleCount;

  /// Called when the title is tapped, to flip the fold.
  final VoidCallback onToggled;

  /// Class constructor
  const _SectionTitle({
    required this.isExpanded,
    required this.peopleCount,
    required this.onToggled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return InkWell(
      mouseCursor: ocpt_theme.ocptClickableCursor,
      onTap: onToggled,
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
              Tr.of(context).scheduleSlotPeopleSectionTitle.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: titleStyle?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            Tr.of(context).scheduleSlotPeopleCount(peopleCount),
            style: titleStyle?.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
