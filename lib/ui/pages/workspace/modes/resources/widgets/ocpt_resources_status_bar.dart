// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_status_bar.dart';

/// The resources mode's status band: `N people · N roles · N positions · N locations · N
/// elements`, straight from the mock-up.
///
/// Built on the shell's own [OcptWorkspaceStatusBar], exactly as the shot list's status line is:
/// on a narrow window the summary degrades from the right, dropping roles, then positions, then
/// locations, while the people count — the address book's own size, the figure every other count
/// here is measured against — never is.
class OcptResourcesStatusBar extends StatelessWidget {
  /// The number of people in the address book.
  final int peopleCount;

  /// The number of roles in the cast.
  final int roleCount;

  /// The total number of crew position assignments across every person.
  final int positionCount;

  /// The number of locations.
  final int locationCount;

  /// The number of elements in the catalogue.
  final int elementCount;

  /// Class constructor
  const OcptResourcesStatusBar({
    super.key,
    required this.peopleCount,
    required this.roleCount,
    required this.positionCount,
    required this.locationCount,
    required this.elementCount,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final elementsText = tr.resourcesStatsElements(elementCount);

    return OcptWorkspaceStatusBar(
      counters: [
        tr.resourcesStatsPeople(peopleCount),
        tr.resourcesStatsRoles(roleCount),
        tr.resourcesStatsPositions(positionCount),
        tr.resourcesStatsLocations(locationCount),
      ],
      nonDroppableCount: 1,
      trailingText: elementsText,
      trailing: Text(elementsText, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}
