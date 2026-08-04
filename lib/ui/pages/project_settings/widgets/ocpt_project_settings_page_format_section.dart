// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';

/// The project settings page's "Page format" section card: a single dropdown over every
/// [OcptPageFormat].
///
/// The margins that pair with this format to make a full page setup are an app-wide preference
/// rather than a project one, so they stay in `OcptEditorPageSetupDialog`, the screenplay editor's
/// own page-setup dialog, rather than moving here.
class OcptProjectSettingsPageFormatSection extends StatelessWidget {
  /// The page format currently selected.
  final OcptPageFormat pageFormat;

  /// Called when the user picks a different page format.
  final ValueChanged<OcptPageFormat> onPageFormatChanged;

  /// Class constructor
  const OcptProjectSettingsPageFormatSection({
    required this.pageFormat,
    required this.onPageFormatChanged,
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
            Text(
              tr.projectSettingsPageFormatSectionTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text(tr.projectSettingsPageFormatLabel)),
                DropdownButton<OcptPageFormat>(
                  value: pageFormat,
                  onChanged: (value) {
                    if (value != null) {
                      onPageFormatChanged(value);
                    }
                  },
                  mouseCursor: ocptClickableCursor,
                  items: [
                    for (final format in OcptPageFormat.values)
                      DropdownMenuItem(value: format, child: Text(_formatLabel(tr, format))),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// The localized label of [format], the same wording `OcptEditorPageSetupDialog` uses.
  String _formatLabel(Tr tr, OcptPageFormat format) => switch (format) {
    OcptPageFormat.usLetter => tr.editorPageSetupUsLetterOption,
    OcptPageFormat.a4 => tr.editorPageSetupA4Option,
  };
}
