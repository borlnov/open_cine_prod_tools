// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_removed_role_alert.dart';

/// The alert shown above the roles table for a role the screenplay no longer names as a speaking
/// character, but whose casting and notes are kept.
///
/// One banner per [OcptRemovedRoleAlert], built file for file like
/// `OcptShotListRemovedCharacterBanner` — the error colour, the same icon family, one banner per
/// alert — but offering the two ways out `OcptRoleIndexService.reconcile` actually leaves open:
/// delete the role for good, or keep it as a hand-added silent role. Nothing dismisses it by hand:
/// the banner disappears on its own once the role it names is gone or is no longer orphaned.
///
/// [isReadOnly] keeps the report and drops both ways out of it: a project version being previewed
/// states the mismatch it was captured with — which is part of what that version was — without
/// offering to resolve it in a project the user isn't looking at.
class OcptRemovedRoleBanner extends StatelessWidget {
  /// The alert this banner reports.
  final OcptRemovedRoleAlert alert;

  /// Called when `Delete this role` is clicked.
  final VoidCallback onDeleteRequested;

  /// Called when `Keep as a silent role` is clicked.
  final VoidCallback onKeepRequested;

  /// Whether what the mode shows is a project version being previewed read-only, which neither
  /// action may write to.
  final bool isReadOnly;

  /// Class constructor
  const OcptRemovedRoleBanner({
    super.key,
    required this.alert,
    required this.onDeleteRequested,
    required this.onKeepRequested,
    this.isReadOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final color = theme.colorScheme.error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: ocptSelectedStateAlpha),
        borderRadius: BorderRadius.circular(ocptRadiusMedium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.person_off_outlined, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr.resourcesRemovedRoleBanner(alert.characterName),
                  style: theme.textTheme.bodySmall?.copyWith(color: color),
                ),
                if (!isReadOnly) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      TextButton(
                        onPressed: onDeleteRequested,
                        style: TextButton.styleFrom(foregroundColor: color),
                        child: Text(tr.resourcesRemovedRoleDeleteAction),
                      ),
                      TextButton(
                        onPressed: onKeepRequested,
                        style: TextButton.styleFrom(foregroundColor: color),
                        child: Text(tr.resourcesRemovedRoleKeepAction),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
