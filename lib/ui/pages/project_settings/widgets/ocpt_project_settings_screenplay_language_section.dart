// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_language.dart';

/// The project settings page's "Screenplay language" section card: a single dropdown over every
/// [OcptScreenplayLanguage], plus a "None" entry carrying null.
///
/// Placed right after `OcptProjectSettingsPageFormatSection`: it is a screenplay concern, matching
/// the page format that already sits there, and the project's future dictionary of learned words
/// hangs under this very section. Unlike the page format, which is never null, "None" here is a
/// real, honest answer — a screenplay written in a language this app carries no dictionary for —
/// not a state the dropdown merely tolerates.
class OcptProjectSettingsScreenplayLanguageSection extends StatelessWidget {
  /// The screenplay language currently selected, or null while nobody has recorded one.
  final OcptScreenplayLanguage? screenplayLanguage;

  /// Called when the user picks a different screenplay language, including null for "None".
  final ValueChanged<OcptScreenplayLanguage?> onScreenplayLanguageChanged;

  /// Class constructor
  const OcptProjectSettingsScreenplayLanguageSection({
    required this.screenplayLanguage,
    required this.onScreenplayLanguageChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr.projectSettingsScreenplayLanguageSectionTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text(tr.projectSettingsScreenplayLanguageLabel)),
                DropdownButton<OcptScreenplayLanguage?>(
                  value: screenplayLanguage,
                  // Unlike `OcptProjectSettingsPageFormatSection`'s `onChanged`, a null value is
                  // reported rather than dropped: picking "None" is a real gesture (turning the
                  // checker off for this screenplay), not an incomplete selection to guard against.
                  onChanged: onScreenplayLanguageChanged,
                  mouseCursor: ocptClickableCursor,
                  items: [
                    DropdownMenuItem(
                      child: Text(tr.projectSettingsScreenplayLanguageNoneOption),
                    ),
                    for (final language in OcptScreenplayLanguage.values)
                      DropdownMenuItem(
                        value: language,
                        child: Text(_languageLabel(tr, language)),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              tr.projectSettingsScreenplayLanguageHint,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  /// The localized label of [language].
  String _languageLabel(Tr tr, OcptScreenplayLanguage language) => switch (language) {
    OcptScreenplayLanguage.fr => tr.projectSettingsScreenplayLanguageFrenchOption,
    OcptScreenplayLanguage.enGb => tr.projectSettingsScreenplayLanguageEnglishOption,
  };
}
