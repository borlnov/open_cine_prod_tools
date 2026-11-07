// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/models/ocpt_episode.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_element_sheet_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_list_panel_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_location_sheet_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_person_sheet_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_role_sheet_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_role_alert_compact_banner.dart';

/// The resources mode's centre, the shell's `centre`: the compact role alert banner, then whichever
/// tab is active, filling the rest of the row.
///
/// The banner sits above everything else and stays whichever tab is active: it reports the whole
/// cast, not something about the tab currently being looked at — mirroring how the shot list's own
/// full role alert banners sit above its sequence content. It is withheld while the whole cast is
/// in order or a project version is being previewed read-only. Tapping a line selects that role,
/// landing on its sheet where the full `OcptRoleAlertBanner` already lives.
///
/// Every irreversible action a sheet offers is only *asked*, through the `on…Requested` callbacks:
/// the mode owns the confirmation dialogs.
class OcptResourcesCentre extends StatelessWidget {
  /// The mode's state, which the active tab and the selected records are read from.
  final OcptResourcesState state;

  /// The project's episodes, handed to the roles tab (see [OcptResourcesListPanelView.episodes]).
  final List<OcptEpisode> episodes;

  /// Called when the user asked to delete the selected person.
  final VoidCallback onPersonDeleteRequested;

  /// Called when the user asked to delete the selected role.
  final VoidCallback onRoleDeleteRequested;

  /// Called with the id of the candidacy the user asked to remove from the selected role.
  final ValueChanged<String> onCandidateRemoveRequested;

  /// Called with the source and the target role ids when the user asked to merge two roles.
  final void Function(String sourceRoleId, String targetRoleId) onRoleMergeRequested;

  /// Called when the user asked to delete the selected location.
  final VoidCallback onLocationDeleteRequested;

  /// Called when the user asked to delete the selected element.
  final VoidCallback onElementDeleteRequested;

  /// Class constructor
  const OcptResourcesCentre({
    super.key,
    required this.state,
    required this.episodes,
    required this.onPersonDeleteRequested,
    required this.onRoleDeleteRequested,
    required this.onCandidateRemoveRequested,
    required this.onRoleMergeRequested,
    required this.onLocationDeleteRequested,
    required this.onElementDeleteRequested,
  });

  /// Build the resources centre as a [Column].
  @override
  Widget build(BuildContext context) {
    final orphanedAlerts = state.orphanedRoleAlerts;
    final collisionAlerts = state.roleCollisionAlerts;
    final body = switch (state.activeTab) {
      OcptResourcesTab.people => OcptResourcesPersonSheetView(
        state: state,
        onDeleteRequested: onPersonDeleteRequested,
      ),
      OcptResourcesTab.roles => OcptResourcesRoleSheetView(
        state: state,
        episodes: episodes,
        onDeleteRequested: onRoleDeleteRequested,
        onCandidateRemoveRequested: onCandidateRemoveRequested,
        onMergeRequested: onRoleMergeRequested,
      ),
      OcptResourcesTab.locations => OcptResourcesLocationSheetView(
        state: state,
        onDeleteRequested: onLocationDeleteRequested,
      ),
      OcptResourcesTab.elements => OcptResourcesElementSheetView(
        state: state,
        onDeleteRequested: onElementDeleteRequested,
      ),
    };
    if (state.isPreviewingVersion || (orphanedAlerts.isEmpty && collisionAlerts.isEmpty)) {
      return body;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
          child: OcptRoleAlertCompactBanner(
            orphanedAlerts: orphanedAlerts,
            collisionAlerts: collisionAlerts,
            onRoleTapped: (roleId) => context.read<OcptResourcesBloc>().add(
              OcptResourcesRoleSelectedEvent(roleId: roleId),
            ),
          ),
        ),
        Expanded(child: body),
      ],
    );
  }
}
