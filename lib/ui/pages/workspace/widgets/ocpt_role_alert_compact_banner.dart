// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_removed_role_alert.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_collision_alert.dart';

/// The compact, mode-level summary of every role needing attention — ADR 0030 decision 4, refined
/// by the M4 step of `docs/plans/shot-characters-are-roles.md`: a role's trouble must be visible the
/// moment a mode is entered, not only once its own record is opened.
///
/// Shown at the top of the resources mode and the breakdown mode alike, above everything else those
/// modes show: one line per role needing attention, built straight from [OcptRemovedRoleAlert] and
/// [OcptRoleCollisionAlert] over the whole cast — [orphanedAlerts] contributes one line each, and
/// [collisionAlerts] contributes **two**, one for the screenplay role and one for the hand-added
/// role a collision alert names, since it is a role's own trouble this reports, not a collision's.
/// Each line names the role by its trouble's own name (the orphaned name, or the name the two roles
/// share) and, tapped, calls [onRoleTapped] with that role's id — the resources mode selects it
/// (switching to the roles tab), landing on the sheet where the full `OcptRoleAlertBanner` already
/// lives; the breakdown mode, which has no role sheet of its own, opens it in the resources mode
/// instead, through the workspace reveal request it already uses for `Open in Resources`. This
/// widget itself knows nothing about either mode's own way of getting there — it only ever asks,
/// through [onRoleTapped].
///
/// Renders nothing at all — clears itself — the moment neither list holds anything, and [isReadOnly]
/// withholds it outright: a project version being previewed read-only has no fix to point the way
/// to. Does **not** change `OcptRoleAlertBanner`'s own, full-size banner, which keeps living in the
/// resources mode's role sheet and the shot list.
class OcptRoleAlertCompactBanner extends StatelessWidget {
  /// Every orphaned-role alert of the whole cast, one line each.
  final List<OcptRemovedRoleAlert> orphanedAlerts;

  /// Every name-collision alert of the whole cast, two lines each — one per role it names.
  final List<OcptRoleCollisionAlert> collisionAlerts;

  /// Called with a role's id when its own line is tapped.
  final ValueChanged<String> onRoleTapped;

  /// Whether what the mode shows is a project version being previewed read-only, which withholds
  /// this banner outright.
  final bool isReadOnly;

  /// Class constructor
  const OcptRoleAlertCompactBanner({
    super.key,
    required this.orphanedAlerts,
    required this.collisionAlerts,
    required this.onRoleTapped,
    this.isReadOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isReadOnly || (orphanedAlerts.isEmpty && collisionAlerts.isEmpty)) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final color = theme.colorScheme.error;

    final lines = <Widget>[
      for (final alert in orphanedAlerts)
        _buildLine(
          theme: theme,
          color: color,
          roleId: alert.roleId,
          text: tr.roleAlertCompactOrphanedLine(alert.characterName),
        ),
      for (final alert in collisionAlerts) ...[
        _buildLine(
          theme: theme,
          color: color,
          roleId: alert.screenplayRoleId,
          text: tr.roleAlertCompactCollisionLine(alert.name),
        ),
        _buildLine(
          theme: theme,
          color: color,
          roleId: alert.handAddedRoleId,
          text: tr.roleAlertCompactCollisionLine(alert.name),
        ),
      ],
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: ocptSelectedStateAlpha),
        borderRadius: BorderRadius.circular(ocptRadiusMedium),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: lines),
    );
  }

  /// One line: [text], tappable onto [roleId].
  Widget _buildLine({
    required ThemeData theme,
    required Color color,
    required String roleId,
    required String text,
  }) => InkWell(
    onTap: () => onRoleTapped(roleId),
    mouseCursor: ocptClickableCursor,
    borderRadius: BorderRadius.circular(ocptRadiusMedium),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.person_off_outlined, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall?.copyWith(color: color))),
          Icon(Icons.chevron_right, size: 16, color: color),
        ],
      ),
    ),
  );
}
