// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_status_bar.dart';

/// The breakdown mode's status band: `N tagged · N categories · N to find`, mirroring
/// `OcptResourcesStatusBar`.
///
/// Built on the shell's own [OcptWorkspaceStatusBar]: on a narrow window the summary degrades from
/// the right, dropping the category count before the tagged-target count, which — the pass's own
/// headline figure — never is.
class OcptBreakdownStatusBar extends StatelessWidget {
  /// The number of distinct targets tagged across the whole screenplay.
  final int taggedTargetCount;

  /// The number of distinct palette entries (an element category, or the role/set kinds) among the
  /// tagged targets.
  final int usedCategoryCount;

  /// The number of tagged elements still marked as `toFind`.
  final int toFindCount;

  /// Class constructor
  const OcptBreakdownStatusBar({
    super.key,
    required this.taggedTargetCount,
    required this.usedCategoryCount,
    required this.toFindCount,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final toFindText = tr.breakdownStatsToFind(toFindCount);

    return OcptWorkspaceStatusBar(
      counters: [
        tr.breakdownStatsTagged(taggedTargetCount),
        tr.breakdownStatsCategories(usedCategoryCount),
      ],
      nonDroppableCount: 1,
      trailingText: toFindText,
      trailing: Text(toFindText, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}
