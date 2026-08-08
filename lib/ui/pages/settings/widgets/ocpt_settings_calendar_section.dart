// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_first_weekday.dart';

/// The settings page's "Calendar" section card: which day a week starts on.
///
/// A card of its own rather than a row of the language one: the week's first day is a calendar
/// convention, not a translation — a production can want a French interface and American weeks —
/// and the schedule mode's own display preferences will land beside it rather than under a heading
/// naming something else.
class OcptSettingsCalendarSection extends StatelessWidget {
  /// The day a week currently starts on.
  final OcptFirstWeekday firstWeekday;

  /// Called when the user picks a different first day.
  final ValueChanged<OcptFirstWeekday> onFirstWeekdayChanged;

  /// Class constructor
  const OcptSettingsCalendarSection({
    required this.firstWeekday,
    required this.onFirstWeekdayChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr.settingsCalendarSectionTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text(tr.settingsFirstWeekdayLabel)),
                DropdownButton<OcptFirstWeekday>(
                  value: firstWeekday,
                  onChanged: (value) => value == null ? null : onFirstWeekdayChanged(value),
                  mouseCursor: ocptClickableCursor,
                  items: [
                    DropdownMenuItem(
                      value: OcptFirstWeekday.monday,
                      child: Text(tr.settingsFirstWeekdayMondayOption),
                    ),
                    DropdownMenuItem(
                      value: OcptFirstWeekday.sunday,
                      child: Text(tr.settingsFirstWeekdaySundayOption),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
