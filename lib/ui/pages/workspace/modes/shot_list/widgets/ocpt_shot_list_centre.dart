// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_inspector_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_role_alert_banner.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_floating_add_button.dart';

/// The shell's `centre` of the shot list mode: the shared role alert banners, then the [child] —
/// the selected sequence's header and its table, board or floor plans — under them, overlaid at a
/// compact width ([isCompact]) with the same floating `+ Shot` affordance the left dock's own
/// button already fires — see [OcptWorkspaceFloatingAddButton]'s own doc comment.
///
/// The floating button mirrors the sequence tree's own `onShotCreated` gating exactly: wired only
/// while the selected sequence is a real scene and no version is being previewed, withheld (a null
/// callback, never disabled) otherwise. Creating a shot already opens the right dock on its
/// inspector tab (`OcptShotListBloc._onShotCreationRequested`), which the compact width shows as an
/// edge drawer — nothing further to wire here for that.
///
/// The banners sit above everything else and stay whichever sequence is selected: they report a
/// mismatch about the whole cast, not something about the sequence currently being looked at.
/// Deleting an orphaned role and merging two roles are only *asked*, through
/// [onRoleDeleteRequested] and [onRoleMergeRequested]: the mode owns their confirmation dialogs.
class OcptShotListCentre extends StatelessWidget {
  /// The mode's state, which the role alerts and the selected sequence are read from.
  final OcptShotListState state;

  /// Whether the window is at a compact width, where the floating `+ Shot` button shows.
  final bool isCompact;

  /// Called with the id of the orphaned role the user asked to delete; the mode confirms it, then
  /// dispatches the deletion.
  final ValueChanged<String> onRoleDeleteRequested;

  /// Called with the ids of the source and the target role the user asked to merge; the mode
  /// confirms it, then dispatches the merge.
  final void Function(String sourceRoleId, String targetRoleId) onRoleMergeRequested;

  /// What the centre shows under the banners.
  final Widget child;

  /// Class constructor
  const OcptShotListCentre({
    super.key,
    required this.state,
    required this.isCompact,
    required this.onRoleDeleteRequested,
    required this.onRoleMergeRequested,
    required this.child,
  });

  /// Build the shot list centre as an [OcptWorkspaceFloatingAddButton].
  @override
  Widget build(BuildContext context) {
    final hasBanners = state.orphanedRoleAlerts.isNotEmpty || state.roleCollisionAlerts.isNotEmpty;

    final content = !hasBanners
        ? child
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                child: _RoleAlertBanners(
                  state: state,
                  onRoleDeleteRequested: onRoleDeleteRequested,
                  onRoleMergeRequested: onRoleMergeRequested,
                ),
              ),
              Expanded(child: child),
            ],
          );

    return OcptWorkspaceFloatingAddButton(
      isVisible: isCompact,
      label: Tr.of(context).shotListAddShotAction,
      onPressed: state.selectedSequence is OcptSceneShotSequence && !state.isPreviewingVersion
          ? () =>
                context.read<OcptShotListBloc>().add(const OcptShotListShotCreationRequestedEvent())
          : null,
      child: content,
    );
  }
}

/// One [OcptRoleAlertBanner] per orphaned role and per name collision the state derives
/// (ADR 0030, decision 4).
class _RoleAlertBanners extends StatelessWidget {
  /// The mode's state, which the alerts are derived from.
  final OcptShotListState state;

  /// See [OcptShotListCentre.onRoleDeleteRequested].
  final ValueChanged<String> onRoleDeleteRequested;

  /// See [OcptShotListCentre.onRoleMergeRequested].
  final void Function(String sourceRoleId, String targetRoleId) onRoleMergeRequested;

  /// Class constructor
  const _RoleAlertBanners({
    required this.state,
    required this.onRoleDeleteRequested,
    required this.onRoleMergeRequested,
  });

  /// Build the role alert banners as a [Column].
  @override
  Widget build(BuildContext context) {
    final inspectorBloc = context.read<OcptShotListInspectorBloc>();

    return Column(
      children: [
        for (final alert in state.orphanedRoleAlerts)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OcptRoleAlertBanner.orphaned(
              alert: alert,
              mergeTargets: state.mergeTargetsOf(alert),
              isReadOnly: state.isPreviewingVersion,
              onDeleteRequested: onRoleDeleteRequested,
              onKeepRequested: (roleId) =>
                  inspectorBloc.add(OcptShotListOrphanedRoleKeptEvent(roleId: roleId)),
              onMergeRequested: onRoleMergeRequested,
            ),
          ),
        for (final alert in state.roleCollisionAlerts)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OcptRoleAlertBanner.collision(
              alert: alert,
              isReadOnly: state.isPreviewingVersion,
              onMergeRequested: onRoleMergeRequested,
            ),
          ),
      ],
    );
  }
}
