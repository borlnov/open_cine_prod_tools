// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_picked_value_button.dart';

/// The window a row falls back to the first time it is switched to [OcptDayPartSlot.custom]: an
/// ordinary working day, so the user narrows a plausible window rather than building one from
/// midnight.
const int ocptDefaultWindowStartMinute = 9 * 60;

/// The end of the window described by [ocptDefaultWindowStartMinute].
const int ocptDefaultWindowEndMinute = 18 * 60;

/// The `09:00 → 18:00` pair of time buttons of a window whose slot is [OcptDayPartSlot.custom].
class OcptTimeWindowControl extends StatelessWidget {
  /// The window's start in minutes from midnight, or null while it has none of its own — the
  /// default window is then shown, which is what switching to a custom slot would seed.
  final int? startMinute;

  /// The window's end in minutes from midnight, or null. See [startMinute].
  final int? endMinute;

  /// Called when the start is clicked, or null while it may not be changed.
  final VoidCallback? onStartPressed;

  /// Called when the end is clicked, or null while it may not be changed.
  final VoidCallback? onEndPressed;

  /// Class constructor
  const OcptTimeWindowControl({
    super.key,
    required this.startMinute,
    required this.endMinute,
    required this.onStartPressed,
    required this.onEndPressed,
  });

  /// Build the time window control as a [Row].
  @override
  Widget build(BuildContext context) => Row(
    children: [
      OcptPickedValueButton(
        label: _formatMinute(context, startMinute ?? ocptDefaultWindowStartMinute),
        onPressed: onStartPressed,
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text("→", style: Theme.of(context).textTheme.labelSmall),
      ),
      OcptPickedValueButton(
        label: _formatMinute(context, endMinute ?? ocptDefaultWindowEndMinute),
        onPressed: onEndPressed,
      ),
    ],
  );

  /// Get [minute], counted from midnight, as the platform's own time of day.
  String _formatMinute(BuildContext context, int minute) => MaterialLocalizations.of(
    context,
  ).formatTimeOfDay(TimeOfDay(hour: minute ~/ 60, minute: minute % 60));
}
