// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_shot_list_labels.dart';

/// The status pill shown next to the inspector header's `Shot 1/3`: the control itself, not just
/// a read-out. Clicking it opens a menu of the three [OcptShotStatus] values, the active one
/// ticked; picking another one reports it through [onStatusSelected].
///
/// Built on [MenuAnchor], like the shot table's own `Columns ▾` menu, rather than a
/// [PopupMenuButton]: the trigger is a bespoke pill shape a popup button's own icon-shaped trigger
/// could not be.
class OcptShotStatusPill extends StatelessWidget {
  /// The status currently shown.
  final OcptShotStatus status;

  /// Called with the status picked from the menu.
  final ValueChanged<OcptShotStatus> onStatusSelected;

  /// Class constructor
  const OcptShotStatusPill({super.key, required this.status, required this.onStatusSelected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final color = ocptShotStatusColor(context, status);

    return MenuAnchor(
      menuChildren: [
        for (final candidate in OcptShotStatus.values)
          MenuItemButton(
            onPressed: () => onStatusSelected(candidate),
            leadingIcon: candidate == status
                ? const Icon(Icons.check, size: 16)
                : const SizedBox(width: 16),
            child: Text(ocptShotStatusLabel(tr, candidate)),
          ),
      ],
      builder: (context, controller, child) => InkWell(
        borderRadius: BorderRadius.circular(ocptRadiusLarge),
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: ocptSelectedStateAlpha),
            borderRadius: BorderRadius.circular(ocptRadiusLarge),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                ocptShotStatusLabel(tr, status),
                style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
              ),
              Icon(Icons.arrow_drop_down, size: 14, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
