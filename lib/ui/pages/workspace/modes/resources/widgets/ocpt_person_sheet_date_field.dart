// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';

/// One editable date field of the person sheet (a date of birth, an image rights date): a label
/// over a themed, tappable box reading the date out (or empty), opening the platform's own date
/// picker. `OcptRoleSheetCandidatesCard` uses it too, for a candidacy's own audition date — the
/// same "pick a date" gesture, whichever sheet asks it.
///
/// Built on [InputDecorator] rather than a real [TextField]: nothing here is ever typed
/// character by character, so a plain decorated, tappable surface is all a date field needs, and
/// it comes from the app's own `inputDecorationTheme` (`lib/constants/ocpt_theme.dart`) for free.
/// This is the smallest, most conventional use of [showDatePicker] the repository had no prior
/// convention for: it is called directly at the tap site, exactly as [showDialog] already is
/// elsewhere in the app, and its own internal dismissal (tapping outside it, or its Cancel/OK
/// buttons) is Flutter's, not a `Navigator` call this code makes itself.
class OcptPersonSheetDateField extends StatelessWidget {
  /// The field's label, upper-cased for display.
  final String label;

  /// The field's current value, or null while unset.
  final DateTime? value;

  /// Called with the newly picked date, or null while the field may not be written to (a project
  /// version being previewed read-only): the box then reads the date out with no reaction to a
  /// tap.
  final ValueChanged<DateTime?>? onChanged;

  /// Class constructor
  const OcptPersonSheetDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final onChanged = this.onChanged;
    final value = this.value;
    final formatted = value == null
        ? null
        : DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: onChanged == null ? null : () => _pickDate(context, onChanged),
          mouseCursor: ocptClickableCursor,
          borderRadius: BorderRadius.circular(ocptRadiusSmall),
          child: InputDecorator(
            decoration: InputDecoration(
              isDense: true,
              suffixIcon: onChanged == null
                  ? null
                  : (value == null
                        ? const Icon(Icons.calendar_today_outlined, size: 14)
                        : IconButton(
                            icon: const Icon(Icons.clear, size: 14),
                            tooltip: tr.resourcesClearDateAction,
                            onPressed: () => onChanged(null),
                          )),
            ),
            child: Text(formatted ?? "", style: theme.textTheme.bodySmall),
          ),
        ),
      ],
    );
  }

  /// Opens the platform date picker seeded with [value] (or today, while unset), reporting the
  /// pick to [onChanged]. Does nothing when the picker is dismissed with no pick.
  Future<void> _pickDate(BuildContext context, ValueChanged<DateTime?> onChanged) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? now,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 5),
    );

    if (picked != null) {
      onChanged(picked);
    }
  }
}
