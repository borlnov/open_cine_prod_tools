// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_report.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_export_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_export_pick.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_reveal_request.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_responsive.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_export_document.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_package_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_export_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_canvas_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_placements_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_sets_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_inspector_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state_delete_targets.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_storyboard_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_copy_blocking_candidate.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_copy_blocking_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_scenario_coverage_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_centre.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_inspector_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_read_only_banner.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_sequence_body.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_sequence_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_status_bar_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_view_effects.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_storyboard_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock_layout_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_shell.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_event.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_floor_plan_unlink_message.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_project_package_missing_files_confirm.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_project_package_notice_message.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_project_version_notice_message.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_shot_list_labels.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_workspace_episode_export_tag.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_confirm_dialog.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_confirm_dialog_result.dart';

/// The shot list (découpage technique) production mode: the sequence tree on the left, the
/// selected sequence's shot table in the centre, and the tabbed shot inspector on the right.
///
/// While a project version is being previewed, the mode shows that version's shot list instead of
/// the working copy's, and shows it read-only: everything that would write — `+ Shot`, the orphan
/// group's delete buttons, every inspector control, the deleted-character banners' two ways out —
/// is withheld, and the shell carries the band naming the version. Browsing the sequences, reading
/// a shot and exporting the workbook all stay available: none of them touches the project.
class OcptShotListMode extends StatelessWidget {
  /// What this mode should open on, handed over by the mode that sent the user here — today the
  /// Resources location sheet's own `Open in shot list` — or null to open on the mode's own
  /// default.
  ///
  /// It reaches [OcptShotListBloc] through its constructor rather than as an event, so the centre
  /// view, the sequence and the set are part of the very first loaded state, exactly as
  /// `OcptResourcesMode.revealRequest` reaches `OcptResourcesBloc`.
  final OcptShotListRevealRequest? revealRequest;

  /// Create the shot list mode.
  const OcptShotListMode({super.key, this.revealRequest});

  /// Build the shot list mode as a [MultiBlocProvider].
  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (context) => OcptShotListBloc(
          selectedEpisodeId: context.read<OcptWorkspaceBloc>().state.selectedEpisodeId,
          revealRequest: revealRequest,
        ),
      ),
      // Built with the mode rather than on first read: a view bloc registers itself with the mode
      // bloc when it is built, and one that is not there yet cannot be asked to write what it holds.
      BlocProvider(
        lazy: false,
        create: (context) => OcptShotListExportBloc(modeBloc: context.read<OcptShotListBloc>()),
      ),
      BlocProvider(
        lazy: false,
        create: (context) => OcptShotListStoryboardBloc(modeBloc: context.read<OcptShotListBloc>()),
      ),
      BlocProvider(
        lazy: false,
        create: (context) => OcptShotListInspectorBloc(modeBloc: context.read<OcptShotListBloc>()),
      ),
      BlocProvider(
        lazy: false,
        create: (context) =>
            OcptShotListFloorPlanSetsBloc(modeBloc: context.read<OcptShotListBloc>()),
      ),
      BlocProvider(
        lazy: false,
        create: (context) =>
            OcptShotListFloorPlanCanvasBloc(modeBloc: context.read<OcptShotListBloc>()),
      ),
      BlocProvider(
        lazy: false,
        create: (context) =>
            OcptShotListFloorPlanPlacementsBloc(modeBloc: context.read<OcptShotListBloc>()),
      ),
    ],
    child: _ShotListView(hasRevealRequest: revealRequest != null),
  );
}

/// The content of [OcptShotListMode], separated from it so [OcptShotListMode] only wires the
/// [OcptShotListBloc] and its view blocs up.
///
/// This is a StatefulWidget (the documented exception) because it owns the dock layout
/// controller: the live dock fractions must survive a rebuild and be mutated imperatively while a
/// divider is being dragged, without emitting a bloc state per frame.
class _ShotListView extends StatefulWidget {
  /// Whether the bloc this view was mounted with was handed a reveal request, and the workspace
  /// therefore still holds one to clear.
  final bool hasRevealRequest;

  /// Class constructor
  const _ShotListView({required this.hasRevealRequest});

  /// Create the [_ShotListViewState] holding the state of the shot list view.
  @override
  State<_ShotListView> createState() => _ShotListViewState();
}

/// The state of [_ShotListView]: owns the dock layout controller and keeps it in sync with the
/// fractions the bloc persisted.
class _ShotListViewState extends State<_ShotListView> {
  /// The live source of truth for the two dock fractions while dragging a divider. Initialized
  /// with the defaults; synced to the bloc's persisted values once the load (or a reset)
  /// resolves, in [_onStateChanged].
  final OcptWorkspaceDockLayoutController _dockLayoutController = OcptWorkspaceDockLayoutController(
    leftFraction: OcptWorkspaceDock.leftDefaultFraction,
    rightFraction: OcptWorkspaceDock.rightDefaultFraction,
  );

  /// Tell the workspace that a reveal request was taken into account, so it applies only once.
  @override
  void initState() {
    super.initState();

    if (widget.hasRevealRequest) {
      // The bloc already has the request — it was handed it at construction, above — so all that
      // is left is telling the workspace it has been taken into account, exactly as
      // `_ResourcesViewState.initState` does for `OcptResourcesRevealRequest`. Dispatched here
      // rather than during the build that reads it, since emitting a state while the tree is being
      // built is not allowed.
      context.read<OcptWorkspaceBloc>().add(const OcptWorkspaceRevealRequestConsumedEvent());
    }
  }

  /// Flush the pending field edits of the bloc before the view leaves the tree.
  @override
  void deactivate() {
    // `deactivate()` runs before `dispose()` for every removal from the tree (a mode switch swaps
    // this whole subtree out, and so does the workspace's own back navigation), so flushing here
    // — rather than in `dispose()`, or waiting out the field-edit debounce — is what guarantees
    // the last couple of seconds of typing in an inspector field survive it: by the time
    // `dispose()` runs (and the `BlocProvider` above this widget closes the bloc along with it),
    // there may be nothing left to flush into. See `OcptStyledScreenplayEditor.deactivate()` for
    // the screenplay editor's own instance of the same reasoning.
    unawaited(context.read<OcptShotListBloc>().flushPendingFieldEdits());
    super.deactivate();
  }

  /// Build the shot list view as an [OcptShotListViewEffects].
  @override
  Widget build(BuildContext context) => OcptShotListViewEffects(
    child: BlocConsumer<OcptShotListBloc, OcptShotListState>(
      listener: _onStateChanged,
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final workspaceState = context.watch<OcptWorkspaceBloc>().state;

        return LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = ocptIsCompactWidth(constraints.maxWidth);

            return OcptWorkspaceShell(
              title: state.title,
              isDirty: false,
              isReadOnly: state.isPreviewingVersion,
              onBack: () =>
                  context.read<OcptShotListBloc>().add(const OcptShotListBackRequestedEvent()),
              episodes: workspaceState.episodes,
              selectedEpisodeId: workspaceState.selectedEpisodeId,
              onEpisodeSelected: (episodeId) => context.read<OcptWorkspaceBloc>().add(
                OcptWorkspaceEpisodeSelectedEvent(episodeId: episodeId),
              ),
              modeLabel: Tr.of(context).workspaceModeLabelShotList,
              onExportRequested: (anchor) => unawaited(_requestExport(context, state, anchor)),
              // The mode's `⋮` overflow menu: resetting the panel layout, alone — the exports are the
              // toolbar's own `Export` button and its panel (see [_requestExport]). A `⋮` holding one
              // entry is thin, but honest: moving it somewhere else is a separate question.
              overflowEntries: [
                PopupMenuItem<void>(
                  onTap: () => context.read<OcptShotListBloc>().add(
                    const OcptShotListDockLayoutResetEvent(),
                  ),
                  child: Text(Tr.of(context).shotListResetPanelLayoutAction),
                ),
              ],
              isLeftDockOpen: state.isSequencePanelVisible,
              onToggleLeftDock: () => context.read<OcptShotListBloc>().add(
                const OcptShotListSequencePanelToggledEvent(),
              ),
              isRightDockOpen: state.rightDockTab != null,
              onToggleRightDock: () =>
                  context.read<OcptShotListBloc>().add(const OcptShotListRightDockToggledEvent()),
              onProjectSettingsRequested: state.isPreviewingVersion
                  ? null
                  : () => _requestProjectSettings(context),
              banner: state.previewedVersion == null
                  ? null
                  : OcptShotListReadOnlyBanner(previewedVersion: state.previewedVersion!),
              leftPanel: !state.isSequencePanelVisible
                  ? null
                  : OcptShotListSequenceDock(
                      state: state,
                      onOrphanedShotDeleteRequested: (shotId) =>
                          unawaited(_handleOrphanedShotDeletion(context, state, shotId)),
                    ),
              rightPanel: state.rightDockTab == null
                  ? null
                  : OcptShotListInspectorDock(
                      state: state,
                      isCompact: isCompact,
                      onPanelDeleteRequested: (panelId) =>
                          unawaited(_handlePanelDeleteRequested(context, panelId)),
                      onAnnotationDeleteRequested: (annotationId) =>
                          unawaited(_handleAnnotationDeleteRequested(context, annotationId)),
                      onSymbolDeleteRequested: (symbolId) =>
                          unawaited(_handleSymbolDeleteRequested(context, state, symbolId)),
                      onArrowDeleteRequested: (arrowId) =>
                          unawaited(_handleArrowDeleteRequested(context, arrowId)),
                      onShotDeleteRequested: (shot) =>
                          unawaited(_handleDeleteRequested(context, shot)),
                    ),
              centre: OcptShotListCentre(
                state: state,
                isCompact: isCompact,
                onRoleDeleteRequested: (roleId) =>
                    unawaited(_handleRoleDeleteRequested(context, state, roleId)),
                onRoleMergeRequested: (sourceRoleId, targetRoleId) => unawaited(
                  _handleRoleMergeRequested(context, state, sourceRoleId, targetRoleId),
                ),
                child: OcptShotListSequenceBody(
                  state: state,
                  isCompact: isCompact,
                  onPanelDeleteRequested: (panelId) =>
                      unawaited(_handlePanelDeleteRequested(context, panelId)),
                  onSymbolDeleteRequested: (symbolId) =>
                      unawaited(_handleSymbolDeleteRequested(context, state, symbolId)),
                  onUnderlayClearRequested: (setId) =>
                      unawaited(_handleUnderlayClearRequested(context, setId)),
                  onCopyBlockingRequested: (setId) =>
                      unawaited(_handleCopyBlockingRequested(context, state, setId)),
                  onSetDeleteRequested: (setId) =>
                      unawaited(_handleSetDeleteRequested(context, state, setId)),
                  onXlsxExportRequested: (anchor) => _requestXlsxExport(context, state, anchor),
                ),
              ),
              statusBar: OcptShotListStatusBarView(state: state, isCompact: isCompact),
              dockLayoutController: _dockLayoutController,
              onDockFractionsChanged: (fractions) => context.read<OcptShotListBloc>().add(
                OcptShotListDockFractionsChangedEvent(left: fractions.left, right: fractions.right),
              ),
            );
          },
        );
      },
    ),
  );

  /// Build the four entries the toolbar's `Export` button offers: the shot list workbook and the
  /// scenario coverage PDF, unavailable while the shot list holds no shot at all — there would be
  /// nothing in the workbook but its header row, and nothing to annotate the screenplay with — and
  /// the storyboard PDF and the floor plans PDF, each unavailable for its own, narrower reason:
  /// a shot list can hold shots without holding a single panel,
  /// or without a single camera placed on any of its floor plans.
  List<OcptWorkspaceExportEntry<OcptShotListExportDocument>> _buildExportEntries(
    BuildContext context,
    OcptShotListState state,
  ) {
    final tr = Tr.of(context);
    final unavailableReason = state.totalShotCount > 0 ? null : tr.shotListExportUnavailableReason;

    return [
      OcptWorkspaceExportEntry<OcptShotListExportDocument>(
        value: OcptShotListExportDocument.xlsx,
        title: tr.shotListExportXlsxTitle,
        description: tr.shotListExportXlsxDescription,
        formatLabel: "XLSX",
        unavailableReason: unavailableReason,
      ),
      OcptWorkspaceExportEntry<OcptShotListExportDocument>(
        value: OcptShotListExportDocument.coverage,
        title: tr.shotListExportCoverageTitle,
        description: tr.shotListExportCoverageDescription,
        formatLabel: "PDF",
        unavailableReason: unavailableReason,
      ),
      OcptWorkspaceExportEntry<OcptShotListExportDocument>(
        value: OcptShotListExportDocument.storyboard,
        title: tr.shotListExportStoryboardTitle,
        description: tr.shotListExportStoryboardDescription,
        formatLabel: "PDF",
        unavailableReason: state.hasAnyStoryboardPanel
            ? null
            : tr.shotListExportStoryboardUnavailableReason,
      ),
      OcptWorkspaceExportEntry<OcptShotListExportDocument>(
        value: OcptShotListExportDocument.floorPlans,
        title: tr.shotListExportFloorPlansTitle,
        description: tr.shotListExportFloorPlansDescription,
        formatLabel: "PDF",
        unavailableReason: state.hasAnyFloorPlanCamera
            ? null
            : tr.shotListExportFloorPlansUnavailableReason,
      ),
    ];
  }

  /// Open the export panel, then dispatch the picked document's own request: the XLSX export
  /// event and the floor plans export event directly (neither opens an options dialog of its own —
  /// the table's own `Export XLSX` button mirrors the first, the workbook mirrors the second), or
  /// [_requestScenarioCoverageExport]/[_requestStoryboardExport], which each open their own export
  /// options dialog first.
  Future<void> _requestExport(
    BuildContext context,
    OcptShotListState state,
    Rect? shareAnchor,
  ) async {
    final tr = Tr.of(context);
    final picked = await OcptWorkspaceExportDialog.show<OcptShotListExportDocument>(
      context,
      title: tr.shotListExportPanelTitle,
      message: tr.shotListExportPanelMessage,
      entries: _buildExportEntries(context, state),
      isPreviewingVersion: state.isPreviewingVersion,
    );
    if (picked == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    switch (picked) {
      case OcptWorkspaceExportDocumentPick<OcptShotListExportDocument>(:final document):
        switch (document) {
          case OcptShotListExportDocument.xlsx:
            _requestXlsxExport(context, state, shareAnchor);
          case OcptShotListExportDocument.coverage:
            await _requestScenarioCoverageExport(context, state, shareAnchor);
          case OcptShotListExportDocument.storyboard:
            await _requestStoryboardExport(context, state, shareAnchor);
          case OcptShotListExportDocument.floorPlans:
            _requestFloorPlansExport(context, state, shareAnchor);
        }
      case OcptWorkspaceExportProjectPackagePick<OcptShotListExportDocument>():
        _requestProjectPackageExport(context);
    }
  }

  /// Dispatch the XLSX export request, resolving here — the last place with a [BuildContext] —
  /// every localized string the workbook and the native save dialog carry.
  void _requestXlsxExport(BuildContext context, OcptShotListState state, Rect? shareAnchor) {
    final tr = Tr.of(context);

    context.read<OcptShotListExportBloc>().add(
      OcptShotListXlsxExportRequestedEvent(
        labels: ocptShotListXlsxLabelsOf(tr, state.sequences),
        fileTypeLabel: tr.shotListExportXlsxFileTypeLabel,
        episodeTag: _episodeExportTag(context),
        shareAnchor: shareAnchor,
      ),
    );
  }

  /// Show the scenario coverage export options dialog, then dispatch the export request if the
  /// user applied it, resolving here — the last place with a [BuildContext] — every localized
  /// string the exported document and the native save dialog carry.
  Future<void> _requestScenarioCoverageExport(
    BuildContext context,
    OcptShotListState state,
    Rect? shareAnchor,
  ) async {
    final bloc = context.read<OcptShotListExportBloc>();
    final options = await OcptScenarioCoverageExportDialog.show(context, current: state.pageSetup);
    if (options == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    final tr = Tr.of(context);
    bloc.add(
      OcptShotListScenarioCoverageExportRequestedEvent(
        options: options,
        labels: ocptScenarioCoverageLabelsOf(tr, state.sequences),
        fileTypeLabel: tr.shotListExportCoverageFileTypeLabel,
        episodeTag: _episodeExportTag(context),
        shareAnchor: shareAnchor,
      ),
    );
  }

  /// Show the storyboard export options dialog, then dispatch the export request if the user
  /// applied it, resolving here — the last place with a [BuildContext] — every localized string
  /// the exported document (and, when its toggle is on, the appended floor plan sheets) and the
  /// native save dialog carry.
  Future<void> _requestStoryboardExport(
    BuildContext context,
    OcptShotListState state,
    Rect? shareAnchor,
  ) async {
    final bloc = context.read<OcptShotListExportBloc>();
    final options = await OcptStoryboardExportDialog.show(context, current: state.pageSetup);
    if (options == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    final tr = Tr.of(context);
    bloc.add(
      OcptShotListStoryboardExportRequestedEvent(
        options: options,
        labels: ocptStoryboardLabelsOf(tr, state.sequences),
        floorPlanLabels: ocptFloorPlanLabelsOf(tr, state.sequences),
        fileTypeLabel: tr.shotListExportStoryboardFileTypeLabel,
        episodeTag: _episodeExportTag(context),
        shareAnchor: shareAnchor,
      ),
    );
  }

  /// Dispatch the floor plans export request, resolving here — the last place with a
  /// [BuildContext] — every localized string the exported document and the native save dialog
  /// carry. Opens no options dialog of its own, mirroring the table's own `Export XLSX` button.
  void _requestFloorPlansExport(BuildContext context, OcptShotListState state, Rect? shareAnchor) {
    final tr = Tr.of(context);

    context.read<OcptShotListExportBloc>().add(
      OcptShotListFloorPlansExportRequestedEvent(
        labels: ocptFloorPlanLabelsOf(tr, state.sequences),
        fileTypeLabel: tr.shotListExportFloorPlansFileTypeLabel,
        episodeTag: _episodeExportTag(context),
        shareAnchor: shareAnchor,
      ),
    );
  }

  /// Get the selected episode's own tag (`ep. 2`), or null while the open project holds one episode
  /// or
  /// none — read here, the last place with a [BuildContext] before an export event is dispatched,
  /// exactly as every other localized export payload already is.
  String? _episodeExportTag(BuildContext context) {
    final workspaceState = context.read<OcptWorkspaceBloc>().state;
    return ocptWorkspaceEpisodeExportTagOf(
      context: context,
      episodes: workspaceState.episodes,
      selectedEpisodeId: workspaceState.selectedEpisodeId,
    );
  }

  /// Open the project settings page, then re-read the page setup if the user changed anything
  /// there.
  ///
  /// Also tells `OcptWorkspaceBloc` to reload its episodes: the settings page's own `Episodes`
  /// card can add or delete one, which the workspace bloc otherwise only learns about from
  /// `OcptProjectsManager.currentProjectStream`, an event the episode CRUD does not fire.
  Future<void> _requestProjectSettings(BuildContext context) async {
    final bloc = context.read<OcptShotListBloc>();
    final workspaceBloc = context.read<OcptWorkspaceBloc>();
    final hasChanged = await globalGetIt().get<OcptRouterManager>().push<bool>(
      OcptRoute.projectSettings,
    );
    if (hasChanged != true) {
      return;
    }

    bloc.add(const OcptShotListProjectSettingsChangedEvent());
    workspaceBloc.add(const OcptWorkspaceEpisodesReloadRequestedEvent());
  }

  /// Confirm and dispatch the deletion of the orphaned shot [shotId], the left dock's own delete
  /// button, going through the same confirmation dialog and the same event as the inspector's
  /// `Delete shot` action. Ignores a click on a shot the snapshot no longer holds.
  Future<void> _handleOrphanedShotDeletion(
    BuildContext context,
    OcptShotListState state,
    String shotId,
  ) async {
    final shot = state.snapshot?.shotsById[shotId];
    if (shot == null) {
      return;
    }

    await _handleDeleteRequested(context, shot);
  }

  /// Get the display name of role [roleId] among [state]'s whole cast, or [roleId] itself as a last
  /// resort — the role merge confirmation names both roles, and a role gone from the cast between
  /// the click and the dialog opening is the only way this fallback is ever seen.
  String _roleNameOf(OcptShotListState state, String roleId) =>
      state.roles.firstWhereOrNull((role) => role.id == roleId)?.name ?? roleId;

  /// Show the delete confirmation dialog, then dispatch the orphaned role's deletion if the user
  /// confirmed it — the shared role alert banner's `Delete the role` action.
  Future<void> _handleRoleDeleteRequested(
    BuildContext context,
    OcptShotListState state,
    String roleId,
  ) async {
    final inspectorBloc = context.read<OcptShotListInspectorBloc>();
    final tr = Tr.of(context);
    final confirmed = await OcptConfirmDialog.show(
      context,
      title: tr.resourcesRoleDeleteConfirmTitle,
      message: tr.resourcesRoleDeleteConfirmMessage,
      cancelLabel: tr.shotListDeleteConfirmCancelAction,
      confirmLabel: tr.shotListDeleteConfirmDeleteAction,
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    inspectorBloc.add(OcptShotListOrphanedRoleDeleteRequestedEvent(roleId: roleId));
  }

  /// Show the merge confirmation dialog, naming both roles, then dispatch the merge if the user
  /// confirmed it — the shared role alert banner's merge affordance, either variant.
  Future<void> _handleRoleMergeRequested(
    BuildContext context,
    OcptShotListState state,
    String sourceRoleId,
    String targetRoleId,
  ) async {
    final inspectorBloc = context.read<OcptShotListInspectorBloc>();
    final tr = Tr.of(context);
    final confirmed = await OcptConfirmDialog.show(
      context,
      title: tr.roleAlertMergeConfirmTitle,
      message: tr.roleAlertMergeConfirmMessage(
        _roleNameOf(state, sourceRoleId),
        _roleNameOf(state, targetRoleId),
      ),
      cancelLabel: tr.shotListDeleteConfirmCancelAction,
      confirmLabel: tr.roleAlertMergeConfirmAction,
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    inspectorBloc.add(
      OcptShotListRoleMergeRequestedEvent(sourceRoleId: sourceRoleId, targetRoleId: targetRoleId),
    );
  }

  /// Open `OcptFloorPlanCopyBlockingDialog` over the sequence's own other shots, then dispatch
  /// the copy once one is picked — the set tabs' own `＋ Set` menu `Copy blocking from another
  /// shot` entry, which only asks which shot to copy from.
  Future<void> _handleCopyBlockingRequested(
    BuildContext context,
    OcptShotListState state,
    String setId,
  ) async {
    final sequence = state.selectedSequence;
    final destinationShotId = state.selectedShotId;
    if (sequence is! OcptSceneShotSequence || destinationShotId == null) {
      return;
    }

    final candidates = [
      for (final shot in sequence.shots)
        if (shot.id != destinationShotId)
          OcptFloorPlanCopyBlockingCandidate(shotId: shot.id, shotCode: shot.code),
    ];
    if (candidates.isEmpty) {
      return;
    }

    final sourceShotId = await OcptFloorPlanCopyBlockingDialog.show(
      context,
      candidates: candidates,
    );
    if (sourceShotId == null || !context.mounted) {
      return;
    }

    context.read<OcptShotListFloorPlanSetsBloc>().add(
      OcptShotListFloorPlanBlockingCopyRequestedEvent(setId: setId, sourceShotId: sourceShotId),
    );
  }

  /// Show the unlink confirmation dialog — naming what leaves the view, its own unlink counts, when
  /// the sequence has anything placed on the set — then dispatch the set's unlinking if the user
  /// confirmed it — a tab's own close action,
  /// which only asks. Not destructive (`isDestructive: false`): the plan itself is kept, only the
  /// sequence link goes.
  Future<void> _handleSetDeleteRequested(
    BuildContext context,
    OcptShotListState state,
    String setId,
  ) async {
    final setsBloc = context.read<OcptShotListFloorPlanSetsBloc>();
    final tr = Tr.of(context);
    final confirmed = await OcptConfirmDialog.show(
      context,
      title: tr.shotListFloorPlanDeleteSetConfirmTitle,
      message: ocptFloorPlanUnlinkSetMessageOf(
        tr,
        sequence: state.selectedSequence,
        floorPlanSet: state.setsOfSelectedSequence
            .where((candidate) => candidate.id == setId)
            .firstOrNull,
      ),
      cancelLabel: tr.shotListDeleteConfirmCancelAction,
      confirmLabel: tr.shotListFloorPlanUnlinkSetConfirmAction,
      isDestructive: false,
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    setsBloc.add(OcptShotListSetDeletionRequestedEvent(setId: setId));
  }

  /// Show the delete confirmation dialog, then dispatch the symbol's deletion if the user
  /// confirmed it — the canvas's own delete handle and the Placements group's own remove action,
  /// which only ask.
  ///
  /// **Two extended, three-button dialogs**, checked in
  /// order — a symbol never qualifies for both, but a plain scene-scope override of a set element
  /// could in principle sit at the boundary, and the broader "shared with other sequences" scope
  /// takes priority when it does:
  /// - While [symbolId] (or, when it is a scene-scope override, the set-scope original it
  ///   overrides) is a **set-scope** symbol whose own set is linked to two or more sequences:
  ///   `Cancel` / `Remove from sequence <n>` (masks it for [state]'s own focused sequence alone,
  ///   restorable) / `Delete everywhere` (destructive, tombstones the original and every override
  ///   of it, in every sequence).
  /// - Otherwise, while it (or, when it is a shot-scope override, the scene-scope symbol it
  ///   overrides) is a **scene-scope** symbol of a sequence holding two or more shots: `Cancel` /
  ///   `Remove from shot <n>` (masks it for [state]'s own focused shot alone, restorable) /
  ///   `Delete from the sequence` (destructive, tombstones the scene-scope symbol and every shot
  ///   override of it — `OcptFloorPlanService.deleteSymbol`'s own cascade — never reaching the
  ///   set-scope original it may itself override).
  ///
  /// Every other symbol (a shot-scope camera/character/light, or either scope on a
  /// single-sequence/single-shot one) keeps the plain two-button confirmation.
  Future<void> _handleSymbolDeleteRequested(
    BuildContext context,
    OcptShotListState state,
    String symbolId,
  ) async {
    final placementsBloc = context.read<OcptShotListFloorPlanPlacementsBloc>();
    final tr = Tr.of(context);
    final multiSequence = state.multiSequenceDeleteTargetOf(symbolId);

    if (multiSequence != null) {
      final result = await OcptConfirmDialog.showWithAlternative(
        context,
        title: tr.shotListFloorPlanDeleteSymbolConfirmTitle,
        message: tr.shotListFloorPlanDeleteSetElementMultiSequenceMessage(
          multiSequence.otherSequenceCount,
        ),
        cancelLabel: tr.shotListDeleteConfirmCancelAction,
        alternativeLabel: tr.shotListFloorPlanRemoveFromSequenceAction(
          multiSequence.focusedSequenceCode,
        ),
        confirmLabel: tr.shotListFloorPlanDeleteEverywhereAction,
      );
      if (!context.mounted) {
        return;
      }

      switch (result) {
        case OcptConfirmDialogResult.cancelled:
          return;
        case OcptConfirmDialogResult.confirmed:
          placementsBloc.add(
            OcptShotListFloorPlanSymbolDeleteEverywhereRequestedEvent(symbolId: symbolId),
          );
        case OcptConfirmDialogResult.alternative:
          placementsBloc.add(
            OcptShotListFloorPlanSymbolHideRequestedEvent(
              symbolId: symbolId,
              targetSceneId: multiSequence.targetSceneId,
            ),
          );
      }
      return;
    }

    final multiShot = state.multiShotDeleteTargetOf(symbolId);
    if (multiShot != null) {
      final result = await OcptConfirmDialog.showWithAlternative(
        context,
        title: tr.shotListFloorPlanDeleteSymbolConfirmTitle,
        message: tr.shotListFloorPlanDeleteSceneElementMultiShotMessage(multiShot.otherShotCount),
        cancelLabel: tr.shotListDeleteConfirmCancelAction,
        alternativeLabel: tr.shotListFloorPlanRemoveFromShotAction(multiShot.focusedShotCode),
        confirmLabel: tr.shotListFloorPlanDeleteFromSequenceAction,
      );
      if (!context.mounted) {
        return;
      }

      switch (result) {
        case OcptConfirmDialogResult.cancelled:
          return;
        case OcptConfirmDialogResult.confirmed:
          // A shot override resolves to its scene-scope original first (mirrors
          // `deleteSymbolEverywhere`'s own one-level resolution) — `deleteSymbol` already
          // cascades every shot override of whichever id ends up deleted.
          final selected = state.selectedSet?.symbols.firstWhereOrNull(
            (candidate) => candidate.id == symbolId,
          );
          final resolvedId = selected != null && selected.shotId != null
              ? (selected.overridesSymbolId ?? symbolId)
              : symbolId;
          placementsBloc.add(
            OcptShotListFloorPlanSymbolDeletionRequestedEvent(symbolId: resolvedId),
          );
        case OcptConfirmDialogResult.alternative:
          placementsBloc.add(
            OcptShotListFloorPlanSymbolHideForShotRequestedEvent(
              symbolId: symbolId,
              targetShotId: multiShot.targetShotId,
            ),
          );
      }
      return;
    }

    final confirmed = await OcptConfirmDialog.show(
      context,
      title: tr.shotListFloorPlanDeleteSymbolConfirmTitle,
      message: tr.shotListFloorPlanDeleteSymbolConfirmMessage,
      cancelLabel: tr.shotListDeleteConfirmCancelAction,
      confirmLabel: tr.shotListDeleteConfirmDeleteAction,
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    placementsBloc.add(OcptShotListFloorPlanSymbolDeletionRequestedEvent(symbolId: symbolId));
  }

  /// Show the delete confirmation dialog, then dispatch the arrow's deletion if the user
  /// confirmed it — the Placements group's own remove action, which only asks.
  Future<void> _handleArrowDeleteRequested(BuildContext context, String arrowId) async {
    final placementsBloc = context.read<OcptShotListFloorPlanPlacementsBloc>();
    final tr = Tr.of(context);
    final confirmed = await OcptConfirmDialog.show(
      context,
      title: tr.shotListFloorPlanDeleteArrowConfirmTitle,
      message: tr.shotListFloorPlanDeleteArrowConfirmMessage,
      cancelLabel: tr.shotListDeleteConfirmCancelAction,
      confirmLabel: tr.shotListDeleteConfirmDeleteAction,
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    placementsBloc.add(OcptShotListFloorPlanArrowDeletionRequestedEvent(arrowId: arrowId));
  }

  /// Show the delete confirmation dialog, then dispatch the underlay's clearing if the user
  /// confirmed it — the tray's own `Clear underlay` action, which only asks.
  Future<void> _handleUnderlayClearRequested(BuildContext context, String setId) async {
    final setsBloc = context.read<OcptShotListFloorPlanSetsBloc>();
    final tr = Tr.of(context);
    final confirmed = await OcptConfirmDialog.show(
      context,
      title: tr.shotListFloorPlanClearUnderlayConfirmTitle,
      message: tr.shotListFloorPlanClearUnderlayConfirmMessage,
      cancelLabel: tr.shotListDeleteConfirmCancelAction,
      confirmLabel: tr.shotListDeleteConfirmDeleteAction,
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    setsBloc.add(OcptShotListFloorPlanUnderlayClearRequestedEvent(setId: setId));
  }

  /// Show the delete confirmation dialog, then dispatch the panel's deletion if the user
  /// confirmed it — the inspector's Panels group's own `Delete panel` action, which only asks.
  Future<void> _handlePanelDeleteRequested(BuildContext context, String panelId) async {
    final storyboardBloc = context.read<OcptShotListStoryboardBloc>();
    final tr = Tr.of(context);
    final confirmed = await OcptConfirmDialog.show(
      context,
      title: tr.shotListBoardDeletePanelConfirmTitle,
      message: tr.shotListBoardDeletePanelConfirmMessage,
      cancelLabel: tr.shotListDeleteConfirmCancelAction,
      confirmLabel: tr.shotListDeleteConfirmDeleteAction,
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    storyboardBloc.add(OcptShotListPanelDeletionRequestedEvent(panelId: panelId));
  }

  /// Show the delete confirmation dialog, then dispatch the mark's deletion if the user
  /// confirmed it — the annotation section's own remove action, which only asks.
  Future<void> _handleAnnotationDeleteRequested(BuildContext context, String annotationId) async {
    final storyboardBloc = context.read<OcptShotListStoryboardBloc>();
    final tr = Tr.of(context);
    final confirmed = await OcptConfirmDialog.show(
      context,
      title: tr.shotListBoardDeleteAnnotationConfirmTitle,
      message: tr.shotListBoardDeleteAnnotationConfirmMessage,
      cancelLabel: tr.shotListDeleteConfirmCancelAction,
      confirmLabel: tr.shotListDeleteConfirmDeleteAction,
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    storyboardBloc.add(OcptShotListAnnotationDeletionRequestedEvent(annotationId: annotationId));
  }

  /// Show the delete confirmation dialog, then dispatch the deletion request if the user
  /// confirmed it.
  Future<void> _handleDeleteRequested(BuildContext context, OcptShot shot) async {
    final bloc = context.read<OcptShotListBloc>();
    final tr = Tr.of(context);
    final confirmed = await OcptConfirmDialog.show(
      context,
      title: tr.shotListDeleteConfirmTitle,
      message: tr.shotListDeleteConfirmMessage(shot.code),
      cancelLabel: tr.shotListDeleteConfirmCancelAction,
      confirmLabel: tr.shotListDeleteConfirmDeleteAction,
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(OcptShotListShotDeletionRequestedEvent(shotId: shot.id));
  }

  /// Apply bloc-driven effects onto the page: the live dock fractions, and the transient write
  /// error SnackBar.
  void _onStateChanged(BuildContext context, OcptShotListState state) {
    // Pushes the bloc's persisted fractions (the initial load, or "Reset panel layout") onto the
    // live controller; a no-op once a drag's own end-of-gesture event brings the bloc back in
    // sync with the value the controller already holds.
    _dockLayoutController.syncFromPersisted(
      leftFraction: state.leftDockFraction,
      rightFraction: state.rightDockFraction,
    );

    if (state.hasWriteError) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(Tr.of(context).shotListWriteError)));
      context.read<OcptShotListBloc>().add(const OcptShotListWriteErrorDismissedEvent());
    }

    final versionNotice = state.projectVersionNotice;
    if (versionNotice != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(ocptProjectVersionNoticeMessage(context, versionNotice))),
        );
      context.read<OcptShotListBloc>().add(const OcptProjectVersionNoticeDismissedEvent());
    }

    final packagePendingExport = state.projectPackagePendingExport;
    if (packagePendingExport != null) {
      context.read<OcptShotListBloc>().add(const OcptProjectPackageMissingFilesAskDismissedEvent());
      unawaited(_askAboutMissingPackagedFiles(context, packagePendingExport));
    }

    final packageNotice = state.projectPackageNotice;
    if (packageNotice != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(ocptProjectPackageNoticeMessage(context, packageNotice))),
        );
      context.read<OcptShotListBloc>().add(const OcptProjectPackageNoticeDismissedEvent());
    }
  }

  /// Dispatch the project package export, resolving here — the last place with a
  /// [BuildContext] — the label the native save dialog carries.
  ///
  /// What happens next depends on what the project references: everything being there, the save
  /// dialog opens straight away; anything missing, the bloc asks back through its own state and
  /// [_askAboutMissingPackagedFiles] is what puts that question on screen.
  void _requestProjectPackageExport(BuildContext context) {
    context.read<OcptShotListBloc>().add(
      OcptProjectPackageExportRequestedEvent(
        fileTypeLabel: Tr.of(context).projectPackageFileTypeLabel,
      ),
    );
  }

  /// Ask whether to write the package even though some referenced files are gone, then dispatch
  /// the export if the user said to go on.
  ///
  /// Opened from the bloc's state rather than from the panel's own click, since only the bloc can
  /// read the project file the pre-flight scanned. The question is cleared from that state the
  /// moment this opens, so a later emission never stacks a second dialog behind this one.
  Future<void> _askAboutMissingPackagedFiles(
    BuildContext context,
    OcptProjectPackagePreflight preflight,
  ) async {
    final bloc = context.read<OcptShotListBloc>();
    final confirmed = await ocptAskAboutMissingPackagedFiles(context, preflight);
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(
      OcptProjectPackageExportConfirmedEvent(
        fileTypeLabel: Tr.of(context).projectPackageFileTypeLabel,
      ),
    );
  }

  /// Dispose [_dockLayoutController].
  @override
  void dispose() {
    _dockLayoutController.dispose();
    super.dispose();
  }
}
