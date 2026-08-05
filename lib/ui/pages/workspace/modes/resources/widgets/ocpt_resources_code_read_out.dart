// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_field.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';

/// The padding the read-out sits in, matching the input decoration theme's own `contentPadding` so
/// a code lines up with the fields it stands beside rather than floating above them.
const EdgeInsets _readOutPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 10);

/// A record's code, read out rather than edited: an upper-cased label over the code itself, laid
/// out like [OcptResourcesSheetField] without being one.
///
/// A code belongs to the app, not to the user: `OcptElementsService.createElement` and
/// `OcptLocationsService.createSet` mint one at creation and a category change is the only thing
/// that ever rewrites one, so there is no field to type into and no writing callback to withhold —
/// which is why this reads the same in a previewed version as it does in the working copy.
///
/// It is deliberately not a read-only [OcptResourcesSheetField]: that shape is what a *previewed*
/// field looks like, a box that would normally accept typing and doesn't right now. This one never
/// will, and says so by not looking like an input at all. The value is still selectable, a code
/// being exactly the kind of thing that gets copied into a spreadsheet by hand.
class OcptResourcesCodeReadOut extends StatelessWidget {
  /// The label shown above the code, upper-cased for display.
  final String label;

  /// The code itself. An empty one — a set restored out of a project version captured before codes
  /// existed — reads as [ocptResourcesEmptyValue] rather than as a blank gap.
  final String code;

  /// Class constructor
  const OcptResourcesCodeReadOut({super.key, required this.label, required this.code});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trimmed = code.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: _readOutPadding,
          child: SelectableText(
            trimmed.isEmpty ? ocptResourcesEmptyValue : trimmed,
            maxLines: 1,
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
