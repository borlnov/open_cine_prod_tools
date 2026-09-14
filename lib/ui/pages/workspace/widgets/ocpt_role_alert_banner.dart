// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_removed_role_alert.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_collision_alert.dart';

/// The one banner a role needing attention is reported through, wherever it is
/// (`docs/adr/0030-a-shots-characters-are-the-productions-roles.md`, decision 4): the resources
/// mode's role sheet, and the shot list, above the table. Folds the two banners that used to answer
/// this separately — `OcptRemovedRoleBanner` and the shot list's own free-name
/// `OcptShotListRemovedCharacterBanner` — into one widget, built file for file like they were: the
/// error colour, the `person_off` icon, a message line, then the actions.
///
/// Two variants, built through the two named constructors:
/// - [OcptRoleAlertBanner.orphaned] reports an [OcptRemovedRoleAlert] — a role the screenplay no
///   longer names — and offers `Delete the role` / `Keep as silent`, then a `Merge with:` row of
///   `ActionChip`s over [mergeTargets] (the roles the screenplay still names).
/// - [OcptRoleAlertBanner.collision] reports an [OcptRoleCollisionAlert] — a hand-added role
///   sharing a name with a live screenplay role — advisory and persistent: no dismissal, a single
///   `Merge` action.
///
/// [onMergeRequested] is called with `(sourceRoleId, targetRoleId)` in both variants: for
/// [OcptRoleAlertBanner.orphaned], the alert's own role is always `sourceRoleId` and the clicked
/// target chip's id is `targetRoleId`; for [OcptRoleAlertBanner.collision], the hand-added role is
/// always `sourceRoleId` and the screenplay role `targetRoleId` (decision 2: the merge is always
/// anchored on the screenplay role). The merge itself, like the delete, is irreversible and is
/// confirmed by the caller through `OcptConfirmDialog` before it dispatches anything — this widget
/// only ever asks.
///
/// [isReadOnly] keeps the message and withholds every action: a project version being previewed
/// states the mismatch it was captured with, without offering to resolve it in a project the user
/// isn't looking at.
class OcptRoleAlertBanner extends StatelessWidget {
  /// The orphaned-role alert this banner reports, or null when it reports [collisionAlert] instead.
  final OcptRemovedRoleAlert? orphanedAlert;

  /// The name-collision alert this banner reports, or null when it reports [orphanedAlert] instead.
  final OcptRoleCollisionAlert? collisionAlert;

  /// The screenplay roles [orphanedAlert] can be merged into — every live, `isFromScreenplay` role
  /// that isn't itself orphaned, other than [orphanedAlert]'s own — offered as the `Merge with:`
  /// row's chips. Ignored for [collisionAlert], which offers no chips.
  final List<OcptRole> mergeTargets;

  /// Called with `(sourceRoleId, targetRoleId)` when a merge is requested. Null (or [isReadOnly])
  /// withholds every merge affordance.
  final void Function(String sourceRoleId, String targetRoleId)? onMergeRequested;

  /// Called with [orphanedAlert]'s role id when `Delete the role` is clicked. Ignored for
  /// [collisionAlert], which offers no delete.
  final ValueChanged<String>? onDeleteRequested;

  /// Called with [orphanedAlert]'s role id when `Keep as silent` is clicked. Ignored for
  /// [collisionAlert].
  final ValueChanged<String>? onKeepRequested;

  /// Whether what the mode shows is a project version being previewed read-only, which no callback
  /// of this banner may write through.
  final bool isReadOnly;

  /// Builds the orphaned variant, reporting [alert].
  const OcptRoleAlertBanner.orphaned({
    super.key,
    required OcptRemovedRoleAlert alert,
    required this.mergeTargets,
    required this.onDeleteRequested,
    required this.onKeepRequested,
    required this.onMergeRequested,
    this.isReadOnly = false,
  }) : orphanedAlert = alert,
       collisionAlert = null;

  /// Builds the collision variant, reporting [alert].
  const OcptRoleAlertBanner.collision({
    super.key,
    required OcptRoleCollisionAlert alert,
    required this.onMergeRequested,
    this.isReadOnly = false,
  }) : collisionAlert = alert,
       orphanedAlert = null,
       mergeTargets = const [],
       onDeleteRequested = null,
       onKeepRequested = null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final color = theme.colorScheme.error;
    final orphanedAlert = this.orphanedAlert;
    final collisionAlert = this.collisionAlert;

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
                  orphanedAlert != null
                      ? tr.roleAlertOrphanedMessage(orphanedAlert.characterName)
                      : tr.roleAlertCollisionMessage(collisionAlert!.name),
                  style: theme.textTheme.bodySmall?.copyWith(color: color),
                ),
                if (!isReadOnly) ...[
                  const SizedBox(height: 6),
                  if (orphanedAlert != null)
                    _buildOrphanedActions(context, tr, color, orphanedAlert)
                  else
                    _buildCollisionAction(tr, color, collisionAlert!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the orphaned variant's actions: `Delete the role`, `Keep as silent`, then the
  /// `Merge with:` row of target chips (hidden while [mergeTargets] is empty).
  Widget _buildOrphanedActions(
    BuildContext context,
    Tr tr,
    Color color,
    OcptRemovedRoleAlert alert,
  ) {
    final onMergeRequested = this.onMergeRequested;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            TextButton(
              onPressed: () => onDeleteRequested?.call(alert.roleId),
              style: TextButton.styleFrom(foregroundColor: color),
              child: Text(tr.roleAlertOrphanedDeleteAction),
            ),
            TextButton(
              onPressed: () => onKeepRequested?.call(alert.roleId),
              style: TextButton.styleFrom(foregroundColor: color),
              child: Text(tr.roleAlertOrphanedKeepAction),
            ),
          ],
        ),
        if (mergeTargets.isNotEmpty && onMergeRequested != null) ...[
          const SizedBox(height: 4),
          Text(
            tr.roleAlertMergeWithLabel,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final target in mergeTargets)
                ActionChip(
                  label: Text(target.name.isEmpty ? tr.resourcesRoleUnnamed : target.name),
                  onPressed: () => onMergeRequested(alert.roleId, target.id),
                ),
            ],
          ),
        ],
      ],
    );
  }

  /// Builds the collision variant's single action: `Merge`, anchored on the screenplay role
  /// (decision 2).
  Widget _buildCollisionAction(Tr tr, Color color, OcptRoleCollisionAlert alert) => TextButton(
    onPressed: () => onMergeRequested?.call(alert.handAddedRoleId, alert.screenplayRoleId),
    style: TextButton.styleFrom(foregroundColor: color),
    child: Text(tr.roleAlertMergeAction),
  );
}
