// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';

/// One kind of person's own title row inside a slot card's people section, shared by its crew
/// section, its cast column and its guest band: the kind's own name and how many people it holds,
/// so a half answers "how many" without its cards being counted.
///
/// It is a **plain read-out, clickable by nothing**: the one fold on the card belongs to the people
/// section and answers for the three kinds at once, so a title that also folded its own kind would
/// be a second, narrower question asked in the same place as the first.
class OcptScheduleSlotPeopleSubsectionTitle extends StatelessWidget {
  /// The kind's own name, upper-cased on display.
  final String title;

  /// How many people the kind holds.
  final int count;

  /// Class constructor
  const OcptScheduleSlotPeopleSubsectionTitle({
    super.key,
    required this.title,
    required this.count,
  });

  /// Build the schedule slot people subsection title as a [Row].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

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
}
