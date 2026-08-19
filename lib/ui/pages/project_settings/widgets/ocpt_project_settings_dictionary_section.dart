// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';

/// The project settings page's "Project dictionary" section card: how many words the writer has
/// taught the spell checker so far — through "Add to the project's dictionary" in the styled
/// editor's right-click menu, or through `OcptProjectDictionaryDialog`'s own add field — and an
/// `Edit…` button opening that dialog to read, filter, add to and unlearn them
/// (`docs/plans/screenplay-spell-check.md` §4.6).
///
/// Placed right after `OcptProjectSettingsScreenplayLanguageSection`: this lexicon exists only
/// because a screenplay language is checked against it, so it sits directly under the section that
/// picks one. Like every other section on this page it only asks — [onEditRequested] opens the
/// dialog, and the *page* applies whatever that dialog reports through
/// `OcptProjectDictionaryService`, the same reporting shape `OcptEditorTitlePageDialog` already
/// uses for its own six fields.
class OcptProjectSettingsDictionarySection extends StatelessWidget {
  /// The project's currently learned words, live (tombstones already filtered out by
  /// `OcptProjectDictionaryService.loadWords`). Only their count is shown here — the words
  /// themselves are read, filtered and edited in the dialog [onEditRequested] opens.
  final List<String> words;

  /// Called when `Edit…` is tapped. This widget only ever asks: the page owns opening the dialog
  /// and dispatching whatever it reports.
  final VoidCallback onEditRequested;

  /// Class constructor
  const OcptProjectSettingsDictionarySection({
    required this.words,
    required this.onEditRequested,
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
            Text(tr.projectSettingsDictionarySectionTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              tr.projectSettingsDictionaryHint,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    words.isEmpty
                        ? tr.projectSettingsDictionaryEmpty
                        : tr.projectSettingsDictionaryWordCount(words.length),
                  ),
                ),
                OutlinedButton(
                  onPressed: onEditRequested,
                  child: Text(tr.projectSettingsDictionaryEditAction),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
