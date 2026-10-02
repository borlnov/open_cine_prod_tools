// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_status_bar.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_warning_color.dart';

/// The shot list's status band: how many sequences and shots the list holds, how many of them are
/// already filmed, and how many need checking.
///
/// Built on the shell's own [OcptWorkspaceStatusBar], exactly as the screenplay editor's status
/// line is, so the two modes' bands degrade identically on a narrow window: the filmed count is
/// dropped first, the sequence and shot counts never are. The shots-to-check count is the band's
/// trailing segment — it is the one figure asking for an action, so it keeps its place at the far
/// right whatever the width, and wears the warning colour (the same one the ⚠ of a shot needing
/// checking does) while there is anything left to check.
class OcptShotListStatusBar extends StatelessWidget {
  /// The number of sequences the shot list holds, orphan group included.
  final int sequenceCount;

  /// The total number of shots, across every sequence.
  final int shotCount;

  /// How many of [shotCount] are already filmed.
  final int filmedShotCount;

  /// How many shots are currently flagged as needing checking.
  final int shotsToCheckCount;

  /// A trailing hint the mode words per active centre view (the board's `Panel 2 of 3 selected ·
  /// drag to reorder`), or null while the active view has nothing of its own to add.
  final String? hint;

  /// Class constructor
  const OcptShotListStatusBar({
    super.key,
    required this.sequenceCount,
    required this.shotCount,
    required this.filmedShotCount,
    required this.shotsToCheckCount,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final hint = this.hint;
    final toCheckText = tr.shotListStatsToCheck(shotsToCheckCount);
    final toCheckWidget = Text(
      toCheckText,
      style: theme.textTheme.labelSmall?.copyWith(
        color: shotsToCheckCount == 0 ? null : ocptWarningColor(context),
      ),
    );

    return OcptWorkspaceStatusBar(
      counters: [
        tr.shotListStatsSequences(sequenceCount),
        tr.shotListShotsCount(shotCount),
        tr.shotListStatsFilmed(filmedShotCount),
      ],
      nonDroppableCount: 2,
      trailingText: hint == null ? toCheckText : "$hint · $toCheckText",
      trailing: hint == null
          ? toCheckWidget
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(hint, style: theme.textTheme.labelSmall),
                Text(" · ", style: theme.textTheme.labelSmall),
                toCheckWidget,
              ],
            ),
    );
  }
}
