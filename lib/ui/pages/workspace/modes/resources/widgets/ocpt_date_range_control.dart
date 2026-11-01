// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_picked_value_button.dart';

/// The `from … to …` pair of date buttons of a dated window, shared by the two sheets that hold
/// one: a person's unavailabilities and a location's availability windows.
///
/// Both ends are always shown, even when they hold the same date: a one-day window is the same
/// shape as any other, and hiding the second end until it differs would hide the very affordance
/// that makes a range.
class OcptDateRangeControl extends StatelessWidget {
  /// The first date the window covers.
  final DateTime startDate;

  /// The last date the window covers, inclusive.
  final DateTime endDate;

  /// Called when the first date is clicked, or null while it may not be changed.
  final VoidCallback? onStartPressed;

  /// Called when the last date is clicked, or null while it may not be changed.
  final VoidCallback? onEndPressed;

  /// Class constructor
  const OcptDateRangeControl({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onStartPressed,
    required this.onEndPressed,
  });

  /// Build the date range control as a [Wrap].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(tr.resourcesUnavailabilityFromLabel, style: labelStyle),
        OcptPickedValueButton(
          label: DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(startDate),
          onPressed: onStartPressed,
        ),
        Text(tr.resourcesUnavailabilityToLabel, style: labelStyle),
        OcptPickedValueButton(
          label: DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(endDate),
          onPressed: onEndPressed,
        ),
      ],
    );
  }
}
