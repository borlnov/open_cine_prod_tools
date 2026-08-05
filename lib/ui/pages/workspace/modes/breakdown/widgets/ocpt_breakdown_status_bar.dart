// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_status_bar.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_warning_color.dart';

/// The breakdown mode's status band: `N tagged · N categories · N to find · N to check`, mirroring
/// `OcptResourcesStatusBar` for its leading counters and `OcptShotListStatusBar` for its own
/// trailing "to check" figure.
///
/// Built on the shell's own [OcptWorkspaceStatusBar]: on a narrow window the summary degrades from
/// the right, dropping the category count before the tagged-target count, which — the pass's own
/// headline figure — never is. [toFindCount] and [needsCheckTagCount] both sit in the band's own
/// trailing slot, never dropped, [needsCheckTagCount] wearing the warning colour — the same one the
/// scene panel's ⚠ does — while there is anything left to check, exactly as
/// `OcptShotListStatusBar.shotsToCheckCount` does for its own flagged shots.
class OcptBreakdownStatusBar extends StatelessWidget {
  /// The number of distinct targets tagged across the whole screenplay.
  final int taggedTargetCount;

  /// The number of distinct palette entries (an element category, or the role/set kinds) among the
  /// tagged targets.
  final int usedCategoryCount;

  /// The number of tagged elements still marked as `toFind`.
  final int toFindCount;

  /// The number of live tags, across the whole screenplay, a save could not re-anchor
  /// (`OcptBreakdownTag.needsCheck`).
  final int needsCheckTagCount;

  /// Class constructor
  const OcptBreakdownStatusBar({
    super.key,
    required this.taggedTargetCount,
    required this.usedCategoryCount,
    required this.toFindCount,
    required this.needsCheckTagCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final toFindText = tr.breakdownStatsToFind(toFindCount);
    final needsCheckText = tr.breakdownStatsToCheck(needsCheckTagCount);

    return OcptWorkspaceStatusBar(
      counters: [
        tr.breakdownStatsTagged(taggedTargetCount),
        tr.breakdownStatsCategories(usedCategoryCount),
      ],
      nonDroppableCount: 1,
      trailingText: "$toFindText · $needsCheckText",
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(toFindText, style: theme.textTheme.labelSmall),
          Text(" · ", style: theme.textTheme.labelSmall),
          Text(
            needsCheckText,
            style: theme.textTheme.labelSmall?.copyWith(
              color: needsCheckTagCount == 0 ? null : ocptWarningColor(context),
            ),
          ),
        ],
      ),
    );
  }
}
