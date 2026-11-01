// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/models/ocpt_removed_role_alert.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_collision_alert.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_reveal_request.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_breakdown_scene_bars.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_workspace_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_tagging_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_tagging_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_header.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_recap_table.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_script_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_role_alert_compact_banner.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_event.dart';

/// The breakdown mode's centre, the shell's `centre`: the compact role alert banner (ADR 0030
/// decision 4), then the header band, then whichever of the script view or the recap table
/// [OcptBreakdownState.centreView] currently names, filling the rest of the row.
///
/// The banner sits above everything else and stays whichever scene or target is selected: it
/// reports the whole cast, not something about the sheet currently being looked at.
class OcptBreakdownCentre extends StatelessWidget {
  /// The mode's state, which the scenes, the targets and the screenplay are read from.
  final OcptBreakdownState state;

  /// Class constructor
  const OcptBreakdownCentre({super.key, required this.state});

  /// The compact role alert banner, or null while the whole cast is in order or a project version
  /// is being previewed read-only.
  Widget? _bannerOf(OcptBreakdownState state) {
    final orphanedAlerts = state.orphanedRoleAlerts;
    final collisionAlerts = state.roleCollisionAlerts;
    if (state.isPreviewingVersion || (orphanedAlerts.isEmpty && collisionAlerts.isEmpty)) {
      return null;
    }

    return _RoleAlertBanner(orphanedAlerts: orphanedAlerts, collisionAlerts: collisionAlerts);
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<OcptBreakdownBloc>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_bannerOf(state) case final banner?)
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: banner),
        OcptBreakdownHeader(
          centreView: state.centreView,
          onCentreViewSelected: (view) =>
              bloc.add(OcptBreakdownCentreViewSelectedEvent(view: view)),
          searchQuery: state.searchQuery,
          onSearchQueryChanged: (query) =>
              bloc.add(OcptBreakdownSearchQueryChangedEvent(query: query)),
          taggedTargetCount: state.taggedTargetCount,
          doneSceneCount: state.doneSceneCount,
          sceneCount: state.scenes.length,
        ),
        Expanded(
          child: state.centreView == OcptBreakdownCentreView.script
              ? _ScriptCentre(state: state)
              : _RecapCentre(state: state),
        ),
      ],
    );
  }
}

/// The compact role alert banner: the roles the screenplay no longer names and the hand-added ones
/// sharing a screenplay role's name.
///
/// Having no role sheet of its own, tapping a line opens the role in the resources mode instead,
/// through the very same workspace reveal request `Open in Resources` already uses.
class _RoleAlertBanner extends StatelessWidget {
  /// The roles the screenplay no longer names.
  final List<OcptRemovedRoleAlert> orphanedAlerts;

  /// The hand-added roles sharing a screenplay role's name.
  final List<OcptRoleCollisionAlert> collisionAlerts;

  /// Class constructor
  const _RoleAlertBanner({required this.orphanedAlerts, required this.collisionAlerts});

  @override
  Widget build(BuildContext context) => OcptRoleAlertCompactBanner(
    orphanedAlerts: orphanedAlerts,
    collisionAlerts: collisionAlerts,
    onRoleTapped: (roleId) => context.read<OcptWorkspaceBloc>().add(
      OcptWorkspaceModeSelectedEvent(
        mode: OcptWorkspaceMode.resources,
        revealRequest: OcptResourcesRevealRequest(tab: OcptResourcesTab.roles, recordId: roleId),
      ),
    ),
  );
}

/// The recap view: the target × scene cross-table, filtered by the header's own search field. A
/// row's click reports the same event a tagged word's click in the script view already does,
/// passing the target's own first scene id, so the left dock and the sheet stay in step.
class _RecapCentre extends StatelessWidget {
  /// The mode's state, which the scenes, the targets and the search are read from.
  final OcptBreakdownState state;

  /// Class constructor
  const _RecapCentre({required this.state});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<OcptBreakdownBloc>();

    return OcptBreakdownRecapTable(
      scenes: state.scenes,
      targets: state.targets,
      elements: state.elements,
      people: state.people,
      searchQuery: state.searchQuery,
      selectedTargetRef: state.selectedTargetRef,
      onTargetSelected: (targetKind, targetId, sceneId) => bloc.add(
        OcptBreakdownTargetSelectedEvent(
          targetKind: targetKind,
          targetId: targetId,
          sceneId: sceneId,
        ),
      ),
    );
  }
}

/// The script view: the whole screenplay typeset as a paper sheet, its words clickable.
///
/// It sits inside a [BlocBuilder] on [OcptBreakdownTaggingBloc], so opening an anchor or a popover
/// redraws the sheet and not the shell around it. `OcptBreakdownScriptView.onWordClicked` alone is
/// what withholds the whole range interaction while a version is being previewed: nulling it out is
/// enough, since no anchor can open and therefore no popover ever has a range to show.
class _ScriptCentre extends StatelessWidget {
  /// The mode's state, which the screenplay, the scenes and the selection are read from.
  final OcptBreakdownState state;

  /// Class constructor
  const _ScriptCentre({required this.state});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<OcptBreakdownBloc>();
    final taggingBloc = context.read<OcptBreakdownTaggingBloc>();
    final isReadOnly = state.isPreviewingVersion;

    return BlocBuilder<OcptBreakdownTaggingBloc, OcptBreakdownTaggingState>(
      builder: (context, taggingState) => OcptBreakdownScriptView(
        screenplayText: state.screenplayText,
        scenes: state.scenes,
        targetById: ocptBreakdownTargetsById(state.targets),
        pageSetup: state.pageSetup,
        selectedSceneId: state.selectedSceneId,
        onSceneSelected: (sceneId) =>
            bloc.add(OcptBreakdownSceneHeadingSelectedEvent(sceneId: sceneId)),
        hiddenLegendKeys: state.hiddenLegendKeys,
        selectedTargetRef: state.selectedTargetRef,
        locations: [for (final location in state.locations) (location.id, location.name)],
        onPopoverSetCreationRequested: (locationId, name) => taggingBloc.add(
          OcptBreakdownPopoverSetCreationRequestedEvent(locationId: locationId, name: name),
        ),
        onTargetSelected: (targetKind, targetId, sceneId) => bloc.add(
          OcptBreakdownTargetSelectedEvent(
            targetKind: targetKind,
            targetId: targetId,
            sceneId: sceneId,
          ),
        ),
        onWordClicked: isReadOnly
            ? null
            : (sceneId, wordStartOffset, wordEndOffset) => taggingBloc.add(
                OcptBreakdownWordClickedEvent(
                  sceneId: sceneId,
                  wordStartOffset: wordStartOffset,
                  wordEndOffset: wordEndOffset,
                ),
              ),
        pendingTagAnchor: taggingState.pendingTagAnchor,
        pendingTagRange: taggingState.pendingTagRange,
        candidates: state.searchCandidates,
        onSelectionCancelled: () => taggingBloc.add(const OcptBreakdownTagRangeCancelledEvent()),
        onPopoverCancelled: () => taggingBloc.add(const OcptBreakdownTagRangeCancelledEvent()),
        onPopoverTargetLinked: (targetKind, targetId) => taggingBloc.add(
          OcptBreakdownPopoverTargetLinkedEvent(targetKind: targetKind, targetId: targetId),
        ),
        onPopoverElementCreationRequested: (category, name) => taggingBloc.add(
          OcptBreakdownPopoverElementCreationRequestedEvent(category: category, name: name),
        ),
        onOpenInResourcesRequested: () => context.read<OcptWorkspaceBloc>().add(
          const OcptWorkspaceModeSelectedEvent(mode: OcptWorkspaceMode.resources),
        ),
      ),
    );
  }
}
