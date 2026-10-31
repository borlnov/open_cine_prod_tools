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
import 'package:open_cine_prod_tools/models/rules/ocpt_floor_plan_unlink_counts.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_responsive.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_export_document.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_package_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_export_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_export_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_canvas_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_canvas_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_placements_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_placements_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_sets_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_sets_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_inspector_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_inspector_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_storyboard_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_storyboard_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_character_name_picker_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_copy_blocking_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_scenario_coverage_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_inspector_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_centre.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_floor_plan_centre.dart'
    show OcptShotListFloorPlanCentre;
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_placements_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_right_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_sequence_body.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_sequence_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_status_bar.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_metadata_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_storyboard_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_storyboard_panels_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_version_create_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_versions_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock_layout_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_read_only_banner.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_shell.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_event.dart';
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

  /// Creates the shot list mode.
  const OcptShotListMode({super.key, this.revealRequest});

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

  @override
  void dispose() {
    _dockLayoutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiBlocListener(
    listeners: [
      BlocListener<OcptShotListExportBloc, OcptShotListExportState>(
        listener: _onExportStateChanged,
      ),
      BlocListener<OcptShotListStoryboardBloc, OcptShotListStoryboardState>(
        listener: _onStoryboardStateChanged,
      ),
      BlocListener<OcptShotListInspectorBloc, OcptShotListInspectorState>(
        listener: _onInspectorStateChanged,
      ),
      BlocListener<OcptShotListFloorPlanSetsBloc, OcptShotListFloorPlanSetsState>(
        listener: _onFloorPlanSetsStateChanged,
      ),
      BlocListener<OcptShotListFloorPlanCanvasBloc, OcptShotListFloorPlanCanvasState>(
        listener: _onFloorPlanCanvasStateChanged,
      ),
      BlocListener<OcptShotListFloorPlanPlacementsBloc, OcptShotListFloorPlanPlacementsState>(
        listener: _onFloorPlanPlacementsStateChanged,
      ),
    ],
    child: _buildMode(context),
  );

  /// Builds the mode itself, listening to the mode bloc.
  Widget _buildMode(BuildContext context) => BlocConsumer<OcptShotListBloc, OcptShotListState>(
    listener: _onStateChanged,
    builder: (context, state) {
      if (state.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }

      final workspaceState = context.watch<OcptWorkspaceBloc>().state;
      final storyboardState = context.watch<OcptShotListStoryboardBloc>().state;

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
            overflowEntries: _buildOverflowEntries(context),
            isLeftDockOpen: state.isSequencePanelVisible,
            onToggleLeftDock: () =>
                context.read<OcptShotListBloc>().add(const OcptShotListSequencePanelToggledEvent()),
            isRightDockOpen: state.rightDockTab != null,
            onToggleRightDock: () =>
                context.read<OcptShotListBloc>().add(const OcptShotListRightDockToggledEvent()),
            onProjectSettingsRequested: state.isPreviewingVersion
                ? null
                : () => _requestProjectSettings(context),
            banner: _buildReadOnlyBanner(context, state),
            leftPanel: _buildSequencePanel(context, state),
            rightPanel: _buildRightDock(context, state, isCompact),
            centre: OcptShotListCentre(
              state: state,
              isCompact: isCompact,
              onRoleDeleteRequested: (roleId) =>
                  unawaited(_handleRoleDeleteRequested(context, state, roleId)),
              onRoleMergeRequested: (sourceRoleId, targetRoleId) =>
                  unawaited(_handleRoleMergeRequested(context, state, sourceRoleId, targetRoleId)),
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
            statusBar: OcptShotListStatusBar(
              sequenceCount: state.sequenceCount,
              shotCount: state.totalShotCount,
              filmedShotCount: state.filmedShotCount,
              shotsToCheckCount: state.shotsToCheckCount,
              hint: _statusBarHint(context, state, storyboardState, isCompact),
            ),
            dockLayoutController: _dockLayoutController,
            onDockFractionsChanged: (fractions) => context.read<OcptShotListBloc>().add(
              OcptShotListDockFractionsChangedEvent(left: fractions.left, right: fractions.right),
            ),
          );
        },
      );
    },
  );

  /// Builds the mode's `⋮` overflow menu entries: resetting the panel layout, alone — the two
  /// exports moved to the toolbar's own `Export` button and its panel (see [_requestExport]), and
  /// this is the only entry the shot list mode has left to offer. A `⋮` holding one entry is thin,
  /// but honest: moving it somewhere else is a separate question this doesn't answer.
  List<PopupMenuEntry<void>> _buildOverflowEntries(BuildContext context) => [
    PopupMenuItem<void>(
      onTap: () => context.read<OcptShotListBloc>().add(const OcptShotListDockLayoutResetEvent()),
      child: Text(Tr.of(context).shotListResetPanelLayoutAction),
    ),
  ];

  /// Builds the four entries the toolbar's `Export` button offers: the shot list workbook and the
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

  /// Opens the export panel, then dispatches the picked document's own request: the XLSX export
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

  /// Dispatches the XLSX export request, resolving here — the last place with a [BuildContext] —
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

  /// Shows the scenario coverage export options dialog, then dispatches the export request if the
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

  /// Shows the storyboard export options dialog, then dispatches the export request if the user
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

  /// Dispatches the floor plans export request, resolving here — the last place with a
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

  /// The selected episode's own tag (`ep. 2`), or null while the open project holds one episode or
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

  /// Opens the project settings page, then re-reads the page setup if the user changed anything
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

  /// Builds the sequence tree, the shell's `leftPanel`, or null while it's hidden.
  ///
  /// `+ Shot` is wired only when the selected sequence is a real screenplay scene: the orphan
  /// group is where shots land when their scene disappears, never where new ones are authored.
  /// Neither it nor the orphan group's delete buttons are wired at all while a version is being
  /// previewed: the tree is then a way of reading that version, not of changing it.
  Widget? _buildSequencePanel(BuildContext context, OcptShotListState state) {
    if (!state.isSequencePanelVisible) {
      return null;
    }

    return OcptShotListSequencePanel(
      sequences: state.sequences,
      totalShotCount: state.totalShotCount,
      selectedSequenceId: state.selectedSequenceId,
      selectedShotId: state.selectedShotId,
      onSequenceSelected: (sequenceId) => context.read<OcptShotListBloc>().add(
        OcptShotListSequenceSelectedEvent(sequenceId: sequenceId),
      ),
      onShotSelected: (shotId) =>
          context.read<OcptShotListBloc>().add(OcptShotListShotSelectedEvent(shotId: shotId)),
      onShotCreated: state.selectedSequence is OcptSceneShotSequence && !state.isPreviewingVersion
          ? () =>
                context.read<OcptShotListBloc>().add(const OcptShotListShotCreationRequestedEvent())
          : null,
      onOrphanedShotDeleted: state.isPreviewingVersion
          ? null
          : (shotId) => _handleOrphanedShotDeletion(context, state, shotId),
    );
  }

  /// Confirms and dispatches the deletion of the orphaned shot [shotId], the left dock's own delete
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

  /// The display name of role [roleId] among [state]'s whole cast, or [roleId] itself as a last
  /// resort — the role merge confirmation names both roles, and a role gone from the cast between
  /// the click and the dialog opening is the only way this fallback is ever seen.
  String _roleNameOf(OcptShotListState state, String roleId) =>
      state.roles.firstWhereOrNull((role) => role.id == roleId)?.name ?? roleId;

  /// Shows the delete confirmation dialog, then dispatches the orphaned role's deletion if the user
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

  /// Shows the merge confirmation dialog, naming both roles, then dispatches the merge if the user
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

  /// Opens `OcptFloorPlanCopyBlockingDialog` over the sequence's own other shots, then dispatches
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

  /// Shows the unlink confirmation dialog — naming what leaves the view, its own unlink counts,
  /// when the sequence has anything placed on the set —
  /// then dispatches the set's unlinking if the user confirmed it — a tab's own close action,
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
      message: _unlinkSetConfirmMessageOf(tr, state, setId),
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

  /// The unlink dialog's own message: `The set's plan is kept.` alone, or followed by what leaves
  /// the view — the cameras, characters and props this sequence placed on [setId], joined
  /// naturally, when there is at least one.
  String _unlinkSetConfirmMessageOf(Tr tr, OcptShotListState state, String setId) {
    final sequence = state.selectedSequence;
    final floorPlanSet = state.setsOfSelectedSequence
        .where((candidate) => candidate.id == setId)
        .firstOrNull;
    if (sequence is! OcptSceneShotSequence || floorPlanSet == null) {
      return tr.shotListFloorPlanDeleteSetConfirmMessage;
    }

    final counts = ocptFloorPlanUnlinkCountsOf(
      floorPlanSet: floorPlanSet,
      sceneId: sequence.sceneId,
      shotIdsOfScene: sequence.shots.map((shot) => shot.id).toSet(),
    );
    final total = counts.cameras + counts.characters + counts.props;
    if (total <= 0) {
      return tr.shotListFloorPlanDeleteSetConfirmMessage;
    }

    final parts = [
      if (counts.cameras > 0) tr.shotListFloorPlanUnlinkCountCamerasPart(counts.cameras),
      if (counts.characters > 0) tr.shotListFloorPlanUnlinkCountCharactersPart(counts.characters),
      if (counts.props > 0) tr.shotListFloorPlanUnlinkCountPropsPart(counts.props),
    ];
    final list = _naturalJoin(parts, tr.shotListFloorPlanUnlinkCountConjunction);

    return "${tr.shotListFloorPlanDeleteSetConfirmMessage} "
        "${tr.shotListFloorPlanUnlinkCountMessage(total, list)}";
  }

  /// Joins [parts] the way a natural sentence would: the word alone for one, `A {conjunction} B`
  /// for two, `A, B {conjunction} C` for three or more (no comma before the last part — the
  /// convention French and English share here) — a plain helper rather than an ICU message, since
  /// ICU has no construct for joining however many non-zero parts a caller hands in.
  String _naturalJoin(List<String> parts, String conjunction) {
    if (parts.isEmpty) {
      return "";
    }
    if (parts.length == 1) {
      return parts.single;
    }
    final allButLast = parts.sublist(0, parts.length - 1).join(", ");
    return "$allButLast $conjunction ${parts.last}";
  }

  /// Opens `OcptFloorPlanCharacterNamePickerDialog` for the character symbol [symbolId] the bloc
  /// just placed, pre-filled with its own already-assigned
  /// default label ([OcptShotListFloorPlanCentre.symbolLabelValueOf]) and offering the selected shot's own characters as
  /// one-click picks. Writes the name picked through the very same pending-edit path the inline
  /// label editor rides — but flushed immediately (`OcptShotListFloorPlanPlacementsFieldEditFlushRequestedEvent`)
  /// rather than left to the 2 s debounce, since picking a name from a dialog is already a
  /// deliberate, discrete action. Dismissing the dialog leaves the placement's own default label
  /// untouched.
  Future<void> _askCharacterName(
    BuildContext context,
    OcptShotListState state,
    String symbolId,
  ) async {
    final currentLabel = OcptShotListFloorPlanCentre.symbolLabelValueOf(
      state,
      context.read<OcptShotListFloorPlanPlacementsBloc>().state,
      symbolId,
    );
    final suggestedNames = [
      for (final name in state.selectedShot?.characters ?? const <String>[])
        if (name.isNotEmpty) name,
    ];

    final picked = await OcptFloorPlanCharacterNamePickerDialog.show(
      context,
      initialValue: currentLabel,
      suggestedNames: suggestedNames,
    );
    if (picked == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    final placementsBloc = context.read<OcptShotListFloorPlanPlacementsBloc>();
    placementsBloc.add(
      OcptShotListFloorPlanSymbolLabelChangedEvent(symbolId: symbolId, rawValue: picked),
    );
    placementsBloc.add(const OcptShotListFloorPlanPlacementsFieldEditFlushRequestedEvent());
  }

  /// Shows the delete confirmation dialog, then dispatches the symbol's deletion if the user
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
    final multiSequence = _multiSequenceDeleteTargetOf(state, symbolId);

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

    final multiShot = _multiShotDeleteTargetOf(state, symbolId);
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

  /// Whether [symbolId] names a **set-scope** symbol (or a scene-scope override of one) whose own
  /// set is linked to two or more sequences — the condition under which deleting it asks the
  /// sequence-level extended three-button dialog — or null while it doesn't (a scene-/shot-scope
  /// symbol, or a set-scope one on a single-sequence set), in which case [_multiShotDeleteTargetOf]
  /// or the plain two-button dialog applies instead.
  ({int otherSequenceCount, String focusedSequenceCode, String targetSceneId})?
  _multiSequenceDeleteTargetOf(OcptShotListState state, String symbolId) {
    final selectedSet = state.selectedSet;
    if (selectedSet == null) {
      return null;
    }
    final symbol = selectedSet.symbols.firstWhereOrNull((candidate) => candidate.id == symbolId);
    if (symbol == null) {
      return null;
    }
    if (symbol.shotId != null) {
      return null; // shot-scope: never a candidate.
    }
    if (symbol.overridesSymbolId == null && symbol.sceneId != null) {
      return null; // a plain scene-scope symbol (a prop): never a candidate either.
    }

    final sequenceCount = state.floorPlanSnapshot?.sequenceCountOfSet(selectedSet.id) ?? 0;
    if (sequenceCount < 2) {
      return null;
    }

    // The sequence to mask it for: the override's own sceneId when [symbolId] already names one,
    // the focused sequence's own scene id when it names the original instead.
    final targetSceneId = symbol.sceneId ?? state.selectedSequenceId;
    if (targetSceneId == null) {
      return null;
    }
    final targetSequence = state.sequences.firstWhereOrNull(
      (sequence) => sequence.id == targetSceneId,
    );

    return (
      otherSequenceCount: sequenceCount - 1,
      focusedSequenceCode: ocptShotSequenceDisplayNumberOf(targetSequence),
      targetSceneId: targetSceneId,
    );
  }

  /// Whether [symbolId] names a **scene-scope** symbol (a prop, the sequence's own furniture, or
  /// itself a sequence-scope override — or a shot-scope override of one) of a sequence holding two
  /// or more shots — the condition under which deleting it asks the shot-level extended
  /// three-button dialog — or null while it doesn't
  /// (a set-scope symbol, already handled by [_multiSequenceDeleteTargetOf], or a single-shot
  /// sequence's own scene-scope symbol), in which case the plain two-button dialog applies.
  ({int otherShotCount, String focusedShotCode, String targetShotId})? _multiShotDeleteTargetOf(
    OcptShotListState state,
    String symbolId,
  ) {
    final selectedSet = state.selectedSet;
    if (selectedSet == null) {
      return null;
    }
    final symbol = selectedSet.symbols.firstWhereOrNull((candidate) => candidate.id == symbolId);
    if (symbol == null || (symbol.sceneId == null && symbol.shotId == null)) {
      return null; // set-scope: never a candidate here.
    }

    final sequence = state.selectedSequence;
    if (sequence is! OcptSceneShotSequence || sequence.shots.length < 2) {
      return null;
    }

    // The shot to mask it for: the override's own shotId when [symbolId] already names one, the
    // focused shot's own id when it names the scene-scope symbol instead.
    final targetShotId = symbol.shotId ?? state.selectedShotId;
    if (targetShotId == null) {
      return null;
    }
    final targetShot = sequence.shots.firstWhereOrNull((shot) => shot.id == targetShotId);

    return (
      otherShotCount: sequence.shots.length - 1,
      focusedShotCode: targetShot?.code ?? "",
      targetShotId: targetShotId,
    );
  }

  /// Shows the delete confirmation dialog, then dispatches the arrow's deletion if the user
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

  /// Shows the delete confirmation dialog, then dispatches the underlay's clearing if the user
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

  /// Shows the delete confirmation dialog, then dispatches the panel's deletion if the user
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

  /// Shows the delete confirmation dialog, then dispatches the mark's deletion if the user
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

  /// The status bar's own trailing hint for the active centre view: the board's `Panel 2 of 3
  /// selected · drag to reorder` while it is shown and a panel is selected, the floor plans'
  /// `Kitchen · 5 cameras on 4 shots · 12/5 has no camera yet` (the last segment only while a shot
  /// of the sequence still has none) while a set is selected, or null otherwise (the table, and
  /// either view with nothing of its own selected, have nothing to add).
  String? _statusBarHint(
    BuildContext context,
    OcptShotListState state,
    OcptShotListStoryboardState storyboardState,
    bool isCompact,
  ) {
    final isBoardShown = !isCompact && state.centreView == OcptShotListCentreView.board;
    final isFloorPlansShown = !isCompact && state.centreView == OcptShotListCentreView.floorPlans;

    if (isFloorPlansShown) {
      final selectedSet = state.selectedSet;
      final sequence = state.selectedSequence;
      if (selectedSet == null || sequence == null) {
        return null;
      }

      final cameraCount = selectedSet.symbols
          .where((symbol) => symbol.layer == OcptFloorPlanLayer.cameras)
          .length;
      final shotIdsWithCamera = {
        for (final symbol in selectedSet.symbols)
          if (symbol.layer == OcptFloorPlanLayer.cameras && symbol.shotId != null) symbol.shotId!,
      };
      final shotCountWithCamera = sequence.shots
          .where((shot) => shotIdsWithCamera.contains(shot.id))
          .length;
      final unplacedShot = sequence.shots.firstWhereOrNull(
        (shot) => !shotIdsWithCamera.contains(shot.id),
      );

      final base = Tr.of(
        context,
      ).shotListFloorPlanCameraStatusHint(selectedSet.name, cameraCount, shotCountWithCamera);
      return unplacedShot == null
          ? base
          : "$base · "
                "${Tr.of(context).shotListFloorPlanCameraStatusUnplacedHint(unplacedShot.code)}";
    }

    if (!isBoardShown) {
      return null;
    }

    final panels = state.panelsOfSelectedShot;
    final selectedPanel = storyboardState.selectedPanelIn(state);
    if (selectedPanel == null || panels.isEmpty) {
      return null;
    }

    final rank = panels.indexWhere((panel) => panel.id == selectedPanel.id) + 1;
    return Tr.of(context).shotListBoardPanelSelectedHint(rank, panels.length);
  }

  /// Builds the tabbed right dock, the shell's `rightPanel`, or null while the dock is closed.
  ///
  /// The inspector's `leadingGroup` follows the active centre view exactly as the centre itself
  /// does: `OcptStoryboardPanelsGroup` while the board is shown, null on the table — a compact
  /// width forces the table regardless of `state.centreView`, so [isCompact] is read the same way
  /// here as it is by `_buildSequenceBody`.
  Widget? _buildRightDock(BuildContext context, OcptShotListState state, bool isCompact) {
    final rightDockTab = state.rightDockTab;
    if (rightDockTab == null) {
      return null;
    }

    final selectedShot = state.selectedShot;
    final selectedSequence = state.selectedSequence;
    final sequenceDisplayNumber = ocptShotSequenceDisplayNumberOf(selectedSequence);
    final sequenceHeading = ocptShotSequenceHeadingOf(selectedSequence, selectedShot);
    final isBoardShown = !isCompact && state.centreView == OcptShotListCentreView.board;
    final isFloorPlansShown = !isCompact && state.centreView == OcptShotListCentreView.floorPlans;

    return OcptShotListRightDock(
      activeTab: rightDockTab,
      inspectorChild: OcptShotInspectorView(
        leadingGroup: isBoardShown
            ? OcptStoryboardPanelsView(
                onPanelDeleteRequested: (panelId) =>
                    unawaited(_handlePanelDeleteRequested(context, panelId)),
                onAnnotationDeleteRequested: (annotationId) =>
                    unawaited(_handleAnnotationDeleteRequested(context, annotationId)),
              )
            : isFloorPlansShown && selectedShot != null && state.selectedSet != null
            ? OcptShotListPlacementsView(
                state: state,
                onSymbolDeleteRequested: (symbolId) =>
                    unawaited(_handleSymbolDeleteRequested(context, state, symbolId)),
                onArrowDeleteRequested: (arrowId) =>
                    unawaited(_handleArrowDeleteRequested(context, arrowId)),
              )
            : null,
        onDeleteRequested: (shot) => unawaited(_handleDeleteRequested(context, shot)),
      ),
      metadataChild: OcptShotMetadataPanel(
        shot: selectedShot,
        sequenceDisplayNumber: sequenceDisplayNumber,
        sequenceHeading: sequenceHeading,
        placements: selectedShot == null
            ? const []
            : state.snapshot?.placementsByShotId[selectedShot.id] ?? const [],
      ),
      versionsChild: _buildVersionsPanel(context, state),
      onTabSelected: (tab) =>
          context.read<OcptShotListBloc>().add(OcptShotListRightDockTabSelectedEvent(tab: tab)),
      onClose: () => context.read<OcptShotListBloc>().add(const OcptShotListRightDockClosedEvent()),
    );
  }

  /// Builds the band naming the version being previewed, the shell's `banner`, or null while the
  /// working copy is on screen.
  ///
  /// Null too — the banner is simply not drawn — in the narrow window where the previewed version
  /// isn't in the list the panel was drawn from any more: the refresh ending every version handler
  /// resolves it on its own, and a band that named nothing would say less than no band at all.
  Widget? _buildReadOnlyBanner(BuildContext context, OcptShotListState state) {
    final previewedVersion = state.previewedVersion;
    if (previewedVersion == null) {
      return null;
    }

    final tr = Tr.of(context);

    return OcptWorkspaceReadOnlyBanner(
      version: previewedVersion,
      // `Start from this version` is a plain restore of the version being previewed:
      // `OcptProjectsManager.restoreProjectVersion` leaves the preview on its own before writing
      // anything, so the handler needs nothing beyond the same event a version's own card
      // dispatches.
      onForkRequested: () => context.read<OcptShotListBloc>().add(
        OcptProjectVersionRestoreConfirmedEvent(
          versionId: previewedVersion.id,
          safetyVersionName: tr.projectVersionRestoreSafetyName(previewedVersion.name),
        ),
      ),
      onExitPreview: () =>
          context.read<OcptShotListBloc>().add(const OcptProjectVersionPreviewExitRequestedEvent()),
    );
  }

  /// Builds the right dock's `Versions` tab: the working copy's own card and the project's named
  /// versions, the same panel the screenplay mode's dock hosts, wired to the events
  /// `MixinOcptProjectVersionsBloc` handles.
  Widget _buildVersionsPanel(BuildContext context, OcptShotListState state) =>
      OcptProjectVersionsPanel(
        versions: state.projectVersions,
        previewedVersionId: state.previewedVersionId,
        workingCopy: state.workingCopy,
        versionPendingDeletionId: state.versionPendingDeletionId,
        versionPendingRestoreId: state.versionPendingRestoreId,
        versionPendingRenameId: state.versionPendingRenameId,
        onCreateRequested: () => _requestVersionCreation(context),
        onPreviewRequested: (versionId) => context.read<OcptShotListBloc>().add(
          OcptProjectVersionPreviewRequestedEvent(versionId: versionId),
        ),
        onPreviewExitRequested: () => context.read<OcptShotListBloc>().add(
          const OcptProjectVersionPreviewExitRequestedEvent(),
        ),
        onRestoreRequested: (versionId) => context.read<OcptShotListBloc>().add(
          OcptProjectVersionRestoreRequestedEvent(versionId: versionId),
        ),
        onRestoreCancelled: () =>
            context.read<OcptShotListBloc>().add(const OcptProjectVersionRestoreCancelledEvent()),
        onRestoreConfirmed: (version) => context.read<OcptShotListBloc>().add(
          OcptProjectVersionRestoreConfirmedEvent(
            versionId: version.id,
            safetyVersionName: Tr.of(context).projectVersionRestoreSafetyName(version.name),
          ),
        ),
        onDeleteRequested: (versionId) => context.read<OcptShotListBloc>().add(
          OcptProjectVersionDeletionRequestedEvent(versionId: versionId),
        ),
        onDeleteCancelled: () =>
            context.read<OcptShotListBloc>().add(const OcptProjectVersionDeletionCancelledEvent()),
        onDeleteConfirmed: (versionId) => context.read<OcptShotListBloc>().add(
          OcptProjectVersionDeletionConfirmedEvent(versionId: versionId),
        ),
        onRenameRequested: (versionId) => context.read<OcptShotListBloc>().add(
          OcptProjectVersionRenameRequestedEvent(versionId: versionId),
        ),
        onRenameCancelled: () =>
            context.read<OcptShotListBloc>().add(const OcptProjectVersionRenameCancelledEvent()),
        onRenameConfirmed: (versionId, name, note) => context.read<OcptShotListBloc>().add(
          OcptProjectVersionRenameConfirmedEvent(versionId: versionId, name: name, note: note),
        ),
      );

  /// Shows the version creation dialog, then dispatches the capture if the user confirmed it.
  Future<void> _requestVersionCreation(BuildContext context) async {
    final bloc = context.read<OcptShotListBloc>();
    final fields = await OcptProjectVersionCreateDialog.show(context);
    if (fields == null) {
      return;
    }

    bloc.add(OcptProjectVersionCreationRequestedEvent(name: fields.name, note: fields.note));
  }

  /// Shows the delete confirmation dialog, then dispatches the deletion request if the user
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

  /// Applies bloc-driven effects onto the page: the live dock fractions, and the transient write
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

  /// Shows the transient write error the board raised as a SnackBar, then dismisses it.
  void _onStoryboardStateChanged(BuildContext context, OcptShotListStoryboardState state) {
    if (!state.hasWriteError) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(Tr.of(context).shotListWriteError)));
    context.read<OcptShotListStoryboardBloc>().add(
      const OcptShotListStoryboardWriteErrorDismissedEvent(),
    );
  }

  /// Shows the transient write error the inspector raised as a SnackBar, then dismisses it.
  void _onInspectorStateChanged(BuildContext context, OcptShotListInspectorState state) {
    if (!state.hasWriteError) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(Tr.of(context).shotListWriteError)));
    context.read<OcptShotListInspectorBloc>().add(
      const OcptShotListInspectorWriteErrorDismissedEvent(),
    );
  }

  /// Shows the transient write error the floor plan sets bloc raised as a SnackBar, then dismisses
  /// it.
  void _onFloorPlanSetsStateChanged(BuildContext context, OcptShotListFloorPlanSetsState state) {
    if (!state.hasWriteError) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(Tr.of(context).shotListWriteError)));
    context.read<OcptShotListFloorPlanSetsBloc>().add(
      const OcptShotListFloorPlanSetsWriteErrorDismissedEvent(),
    );
  }

  /// Shows the transient write error the placements bloc raised as a SnackBar, then dismisses it.
  void _onFloorPlanPlacementsStateChanged(
    BuildContext context,
    OcptShotListFloorPlanPlacementsState state,
  ) {
    if (!state.hasWriteError) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(Tr.of(context).shotListWriteError)));
    context.read<OcptShotListFloorPlanPlacementsBloc>().add(
      const OcptShotListFloorPlanPlacementsWriteErrorDismissedEvent(),
    );
  }

  /// Shows the transient write error the floor plan canvas raised as a SnackBar, then dismisses
  /// it, and opens the character name prompt a freshly placed character symbol asks for.
  void _onFloorPlanCanvasStateChanged(
    BuildContext context,
    OcptShotListFloorPlanCanvasState state,
  ) {
    if (state.hasWriteError) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(Tr.of(context).shotListWriteError)));
      context.read<OcptShotListFloorPlanCanvasBloc>().add(
        const OcptShotListFloorPlanCanvasWriteErrorDismissedEvent(),
      );
    }

    final pendingCharacterNamePromptSymbolId = state.pendingCharacterNamePromptSymbolId;
    if (pendingCharacterNamePromptSymbolId != null) {
      context.read<OcptShotListFloorPlanCanvasBloc>().add(
        const OcptShotListFloorPlanCharacterNamePromptDismissedEvent(),
      );
      unawaited(
        _askCharacterName(
          context,
          context.read<OcptShotListBloc>().state,
          pendingCharacterNamePromptSymbolId,
        ),
      );
    }
  }

  /// Shows the outcome of an export as a SnackBar, then dismisses it.
  void _onExportStateChanged(BuildContext context, OcptShotListExportState state) {
    final ioNotice = state.ioNotice;
    if (ioNotice == null) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(_ioNoticeMessage(context, ioNotice))));
    context.read<OcptShotListExportBloc>().add(const OcptShotListIoNoticeDismissedEvent());
  }

  /// Dispatches the project package export, resolving here — the last place with a
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

  /// Asks whether to write the package even though some referenced files are gone, then dispatches
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

  /// Maps [notice] to its localized, user-facing message.
  ///
  /// A succeeded kind degrades to the generic "shared" message on mobile
  /// ([OcptShotListIoNotice.wasShared]): there is no path to name, the export having been handed to
  /// the OS share sheet rather than written to a location the user picked.
  String _ioNoticeMessage(BuildContext context, OcptShotListIoNotice notice) {
    final tr = Tr.of(context);

    return switch (notice.kind) {
      OcptShotListIoNoticeKind.xlsxExportSucceeded =>
        notice.wasShared
            ? tr.exportSharedMessage
            : tr.shotListExportXlsxSuccessMessage(notice.path ?? ""),
      OcptShotListIoNoticeKind.xlsxExportFailed => tr.shotListExportXlsxError,
      OcptShotListIoNoticeKind.scenarioCoverageExportSucceeded =>
        notice.wasShared
            ? tr.exportSharedMessage
            : tr.shotListExportCoverageSuccessMessage(notice.path ?? ""),
      OcptShotListIoNoticeKind.scenarioCoverageExportFailed => tr.shotListExportCoverageError,
      OcptShotListIoNoticeKind.storyboardExportSucceeded =>
        notice.wasShared
            ? tr.exportSharedMessage
            : tr.shotListExportStoryboardSuccessMessage(notice.path ?? ""),
      OcptShotListIoNoticeKind.storyboardExportFailed => tr.shotListExportStoryboardError,
      OcptShotListIoNoticeKind.floorPlansExportSucceeded =>
        notice.wasShared
            ? tr.exportSharedMessage
            : tr.shotListExportFloorPlansSuccessMessage(notice.path ?? ""),
      OcptShotListIoNoticeKind.floorPlansExportFailed => tr.shotListExportFloorPlansError,
    };
  }
}
