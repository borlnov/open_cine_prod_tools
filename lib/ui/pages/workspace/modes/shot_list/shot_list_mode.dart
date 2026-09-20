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
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_set.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_report.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_annotation.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_export_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_export_pick.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_export_document.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_pending_edit_key.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_package_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_layer_tray.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_placements_group.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_set_tabs.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_scenario_coverage_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_coverage_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_inspector_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_centre_header.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_columns_menu.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_right_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_sequence_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_status_bar.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_table.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_metadata_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_storyboard_board.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_storyboard_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_storyboard_panel_size_menu.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_storyboard_panels_group.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_version_create_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_versions_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_role_alert_banner.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock_layout_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_floating_add_button.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_read_only_banner.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_shell.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_event.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_export_share_anchor.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_project_package_missing_files_confirm.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_project_package_notice_message.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_project_version_notice_message.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_shot_list_labels.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_workspace_episode_export_tag.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_confirm_dialog.dart';
import 'package:open_cine_prod_tools/utils/ocpt_responsive.dart';

/// The shot list (découpage technique) production mode: the sequence tree on the left, the
/// selected sequence's shot table in the centre, and the tabbed shot inspector on the right.
///
/// While a project version is being previewed, the mode shows that version's shot list instead of
/// the working copy's, and shows it read-only: everything that would write — `+ Shot`, the orphan
/// group's delete buttons, every inspector control, the deleted-character banners' two ways out —
/// is withheld, and the shell carries the band naming the version. Browsing the sequences, reading
/// a shot and exporting the workbook all stay available: none of them touches the project.
class OcptShotListMode extends StatelessWidget {
  /// Creates the shot list mode.
  const OcptShotListMode({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => OcptShotListBloc(
      selectedEpisodeId: context.read<OcptWorkspaceBloc>().state.selectedEpisodeId,
    ),
    child: const _ShotListView(),
  );
}

/// The content of [OcptShotListMode], separated from it so [OcptShotListMode] only wires the
/// [OcptShotListBloc] up (RFL3).
///
/// This is a StatefulWidget (the documented RFL1 exception) because it owns the dock layout
/// controller: the live dock fractions must survive a rebuild and be mutated imperatively while a
/// divider is being dragged, without emitting a bloc state per frame.
class _ShotListView extends StatefulWidget {
  /// Class constructor
  const _ShotListView();

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
  Widget build(BuildContext context) => BlocConsumer<OcptShotListBloc, OcptShotListState>(
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
            overflowEntries: _buildOverflowEntries(context),
            isLeftDockOpen: state.isSequencePanelVisible,
            onToggleLeftDock: () => context.read<OcptShotListBloc>().add(
              const OcptShotListSequencePanelToggledEvent(),
            ),
            isRightDockOpen: state.rightDockTab != null,
            onToggleRightDock: () => context.read<OcptShotListBloc>().add(
              const OcptShotListRightDockToggledEvent(),
            ),
            onProjectSettingsRequested: state.isPreviewingVersion
                ? null
                : () => _requestProjectSettings(context),
            banner: _buildReadOnlyBanner(context, state),
            leftPanel: _buildSequencePanel(context, state),
            rightPanel: _buildRightDock(context, state, isCompact),
            centre: _buildCentre(context, state, isCompact),
            statusBar: OcptShotListStatusBar(
              sequenceCount: state.sequenceCount,
              shotCount: state.totalShotCount,
              filmedShotCount: state.filmedShotCount,
              shotsToCheckCount: state.shotsToCheckCount,
              hint: _statusBarHint(context, state, isCompact),
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
  /// the storyboard PDF and the floor plans PDF, each unavailable for its own, narrower reason
  /// (`docs/plans/storyboard.md`, §5): a shot list can hold shots without holding a single panel,
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

    context.read<OcptShotListBloc>().add(
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
    final bloc = context.read<OcptShotListBloc>();
    final options = await OcptScenarioCoverageExportDialog.show(
      context,
      current: state.pageSetup,
    );
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
    final bloc = context.read<OcptShotListBloc>();
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

    context.read<OcptShotListBloc>().add(
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
      onShotSelected: (shotId) => context.read<OcptShotListBloc>().add(
        OcptShotListShotSelectedEvent(shotId: shotId),
      ),
      onShotCreated: state.selectedSequence is OcptSceneShotSequence && !state.isPreviewingVersion
          ? () => context.read<OcptShotListBloc>().add(
              const OcptShotListShotCreationRequestedEvent(),
            )
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

  /// Builds the shell's `centre`: the shared role alert banners, then the selected sequence's
  /// header, the `Columns ▾` menu, and the shot table under them, overlaid at a compact width
  /// ([isCompact]) with the same floating `+ Shot` affordance the left dock's own button already
  /// fires — see [OcptWorkspaceFloatingAddButton]'s own doc comment.
  ///
  /// The floating button mirrors [_buildSequencePanel]'s own `onShotCreated` gating exactly: wired
  /// only while the selected sequence is a real scene and no version is being previewed, withheld
  /// (a null callback, never disabled) otherwise. Creating a shot already opens the right dock on its
  /// inspector tab ([OcptShotListBloc._onShotCreationRequested]), which the compact width shows as an
  /// edge drawer — nothing further to wire here for that.
  ///
  /// The banners sit above everything else and stay whichever sequence is selected: they report a
  /// mismatch about the whole cast, not something about the sequence currently being looked at.
  Widget _buildCentre(BuildContext context, OcptShotListState state, bool isCompact) {
    final banners = _buildRoleAlertBanners(context, state);
    final body = _buildSequenceBody(context, state, isCompact);

    final content = banners.isEmpty
        ? body
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                child: Column(children: banners),
              ),
              Expanded(child: body),
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

  /// Builds one [OcptRoleAlertBanner] per orphaned role and per name collision the state derives
  /// (ADR 0030, decision 4), or an empty list when the whole cast is in order.
  List<Widget> _buildRoleAlertBanners(BuildContext context, OcptShotListState state) {
    final bloc = context.read<OcptShotListBloc>();

    return [
      for (final alert in state.orphanedRoleAlerts)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: OcptRoleAlertBanner.orphaned(
            alert: alert,
            mergeTargets: state.mergeTargetsOf(alert),
            isReadOnly: state.isPreviewingVersion,
            onDeleteRequested: (roleId) => _handleRoleDeleteRequested(context, state, roleId),
            onKeepRequested: (roleId) =>
                bloc.add(OcptShotListOrphanedRoleKeptEvent(roleId: roleId)),
            onMergeRequested: (sourceRoleId, targetRoleId) =>
                _handleRoleMergeRequested(context, state, sourceRoleId, targetRoleId),
          ),
        ),
      for (final alert in state.roleCollisionAlerts)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: OcptRoleAlertBanner.collision(
            alert: alert,
            isReadOnly: state.isPreviewingVersion,
            onMergeRequested: (sourceRoleId, targetRoleId) =>
                _handleRoleMergeRequested(context, state, sourceRoleId, targetRoleId),
          ),
        ),
    ];
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
    final bloc = context.read<OcptShotListBloc>();
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

    bloc.add(OcptShotListOrphanedRoleDeleteRequestedEvent(roleId: roleId));
  }

  /// Shows the merge confirmation dialog, naming both roles, then dispatches the merge if the user
  /// confirmed it — the shared role alert banner's merge affordance, either variant.
  Future<void> _handleRoleMergeRequested(
    BuildContext context,
    OcptShotListState state,
    String sourceRoleId,
    String targetRoleId,
  ) async {
    final bloc = context.read<OcptShotListBloc>();
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

    bloc.add(
      OcptShotListRoleMergeRequestedEvent(sourceRoleId: sourceRoleId, targetRoleId: targetRoleId),
    );
  }

  /// Builds what the centre shows under the banners: the header (the view switch, the sequence's
  /// own title/summary and whatever the active view needs), then the table, the board or the
  /// floor plans, or the empty state while no sequence is selected.
  ///
  /// A compact width shows the table regardless of `state.centreView`: the board and the floor
  /// plans are large-screen views in v1 (`docs/plans/storyboard.md`, §4.3), so the switch itself
  /// offers the table only and this stays in lock-step with it rather than reading a second
  /// predicate.
  Widget _buildSequenceBody(BuildContext context, OcptShotListState state, bool isCompact) {
    final tr = Tr.of(context);
    final sequence = state.selectedSequence;

    if (sequence == null) {
      return OcptWorkspaceEmptyMode(
        icon: Icons.movie_filter_outlined,
        message: tr.shotListNoSequenceSelectedHint,
      );
    }

    final isBoardShown = !isCompact && state.centreView == OcptShotListCentreView.board;
    final isFloorPlansShown = !isCompact && state.centreView == OcptShotListCentreView.floorPlans;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
          child: OcptShotListCentreHeader(
            sequence: sequence,
            centreView: state.centreView,
            isBoardAvailable: !isCompact,
            isFloorPlansAvailable: !isCompact,
            boardPanelCount: state.boardPanelCountOfSelectedSequence,
            onCentreViewSelected: (view) => context.read<OcptShotListBloc>().add(
              OcptShotListCentreViewSelectedEvent(view: view),
            ),
            trailing: switch ((isBoardShown, isFloorPlansShown)) {
              (true, _) => OcptStoryboardPanelSizeMenu(
                value: state.boardPanelSize,
                onChanged: (size) => context.read<OcptShotListBloc>().add(
                  OcptShotListPanelSizeChangedEvent(size: size),
                ),
              ),
              (_, true) => _buildSetTabs(context, state, sequence),
              _ => _buildTableTrailingControls(context, state),
            },
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
            child: switch ((isBoardShown, isFloorPlansShown)) {
              (true, _) => _buildBoard(context, state, sequence),
              (_, true) => _buildFloorPlanView(context, state, sequence),
              _ => OcptShotListTable(
                shots: sequence.shots,
                sequenceHeading: switch (sequence) {
                  OcptSceneShotSequence() => sequence.heading,
                  OcptOrphanShotSequence() => ocptShotListEmptyValue,
                },
                visibleColumns: state.visibleColumns,
                selectedShotId: state.selectedShotId,
                placementsByShotId: state.snapshot?.placementsByShotId ?? const {},
                onShotSelected: (shotId) => context.read<OcptShotListBloc>().add(
                  OcptShotListShotSelectedEvent(shotId: shotId),
                ),
              ),
            },
          ),
        ),
      ],
    );
  }

  /// The table view's own trailing controls, unchanged from what `_SequenceHeader`'s row used to
  /// build beside it: the `Columns ▾` menu and the `Export XLSX` button.
  Widget _buildTableTrailingControls(BuildContext context, OcptShotListState state) {
    final tr = Tr.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OcptShotListColumnsMenu(
          visibleColumns: state.visibleColumns,
          onColumnToggled: (column) => context.read<OcptShotListBloc>().add(
            OcptShotListColumnToggledEvent(column: column),
          ),
        ),
        const SizedBox(width: 8),
        // Exports the whole shot list, not the sequence this header names: the button sits here
        // because the mock-up puts it next to the columns menu, not because it is scoped to what
        // the table below currently shows. Wrapped in its own Builder so the anchor handed to the
        // export is this button's own screen Rect, not some ancestor's.
        Builder(
          builder: (buttonContext) => OutlinedButton.icon(
            onPressed: state.totalShotCount > 0
                ? () =>
                      _requestXlsxExport(context, state, ocptExportShareAnchorOf(buttonContext))
                : null,
            icon: const Icon(Icons.file_download_outlined, size: 16),
            label: Text(tr.shotListExportXlsxAction),
          ),
        ),
      ],
    );
  }

  /// Builds the board view: the selected sequence's shots as `OcptStoryboardShotRow`s, wired to
  /// every board write event, each withheld (a null callback) under a version preview.
  Widget _buildBoard(BuildContext context, OcptShotListState state, OcptShotSequence sequence) {
    final bloc = context.read<OcptShotListBloc>();
    final isReadOnly = state.isPreviewingVersion;
    final tr = Tr.of(context);

    return OcptStoryboardBoard(
      shots: sequence.shots,
      roles: state.roles,
      panelsByShotId: state.storyboardSnapshot?.panelsByShotId ?? const {},
      panelSize: state.boardPanelSize,
      selectedShotId: state.selectedShotId,
      selectedPanelId: state.selectedPanelId,
      isReadOnly: isReadOnly,
      onShotSelected: (shotId) => bloc.add(OcptShotListShotSelectedEvent(shotId: shotId)),
      onPanelSelected: (panelId) => bloc.add(OcptShotListPanelSelectedEvent(panelId: panelId)),
      onImportRequested: isReadOnly
          ? null
          : (shotId) => bloc.add(
              OcptShotListPanelImportRequestedEvent(
                shotId: shotId,
                fileTypeLabel: tr.shotListBoardImageFileTypeLabel,
              ),
            ),
      onReplaceRequested: isReadOnly
          ? null
          : (panelId) => bloc.add(
              OcptShotListPanelReplaceRequestedEvent(
                panelId: panelId,
                fileTypeLabel: tr.shotListBoardImageFileTypeLabel,
              ),
            ),
      onDeleteRequested: isReadOnly
          ? null
          : (panelId) => unawaited(_handlePanelDeleteRequested(context, panelId)),
      onPanelReordered: isReadOnly
          ? null
          : (shotId, panelId, newPosition) => bloc.add(
              OcptShotListPanelReorderedEvent(
                shotId: shotId,
                panelId: panelId,
                newPosition: newPosition,
              ),
            ),
      activeAnnotationTool: state.activeAnnotationTool,
      selectedAnnotationId: state.selectedAnnotationId,
      onAnnotationDrawn: isReadOnly
          ? null
          : (panelId, kind, x1, y1, x2, y2) => bloc.add(
              OcptShotListAnnotationDrawnEvent(
                panelId: panelId,
                kind: kind,
                x1: x1,
                y1: y1,
                x2: x2,
                y2: y2,
              ),
            ),
      onLabelPlaced: isReadOnly
          ? null
          : (panelId, x, y) =>
                bloc.add(OcptShotListAnnotationPlacedEvent(panelId: panelId, x1: x, y1: y)),
      onAnnotationSelected: (annotationId) =>
          bloc.add(OcptShotListAnnotationSelectedEvent(annotationId: annotationId)),
    );
  }

  /// Builds the floor plans view's own case tabs, the header's trailing slot while it is shown:
  /// `+ Case` is wired only when the selected sequence is a real screenplay scene (mirroring
  /// `_buildSequencePanel`'s own `onShotCreated` gating), and every write is withheld under a
  /// version preview.
  Widget _buildSetTabs(BuildContext context, OcptShotListState state, OcptShotSequence sequence) {
    final bloc = context.read<OcptShotListBloc>();
    final isReadOnly = state.isPreviewingVersion;
    final canCreateSet = sequence is OcptSceneShotSequence && !isReadOnly;

    return OcptFloorPlanSetTabs(
      sets: state.setsOfSelectedSequence,
      selectedSetId: state.selectedSetId,
      nameValueOf: (setId) => _setNameValueOf(state, setId),
      onSetSelected: (setId) => bloc.add(OcptShotListSetSelectedEvent(setId: setId)),
      onSetCreationRequested: canCreateSet
          ? () => bloc.add(const OcptShotListSetCreationRequestedEvent())
          : null,
      onSetNameChanged: isReadOnly
          ? null
          : (setId, rawValue) =>
                bloc.add(OcptShotListSetNameChangedEvent(setId: setId, rawValue: rawValue)),
      onSetReordered: isReadOnly
          ? null
          : (setId, newPosition) => bloc.add(
              OcptShotListSetReorderedEvent(setId: setId, newPosition: newPosition),
            ),
      onSetDeleteRequested: isReadOnly
          ? null
          : (setId) => unawaited(_handleSetDeleteRequested(context, state, setId)),
    );
  }

  /// [setId]'s current name: a pending edit still in the bloc's debounce, or the case's own
  /// stored value — the case tabs' equivalent of [_fieldValueOf]/[_panelCommentValueOf].
  String _setNameValueOf(OcptShotListState state, String setId) {
    final pending = state.pendingFieldEdits[OcptShotListSetNameEditKey(setId: setId)];
    if (pending != null) {
      return pending;
    }
    for (final floorPlanSet in state.setsOfSelectedSequence) {
      if (floorPlanSet.id == setId) {
        return floorPlanSet.name;
      }
    }
    return "";
  }

  /// Shows the delete confirmation dialog, then dispatches the case's deletion if the user
  /// confirmed it — a tab's own close action, which only asks.
  Future<void> _handleSetDeleteRequested(
    BuildContext context,
    OcptShotListState state,
    String setId,
  ) async {
    final bloc = context.read<OcptShotListBloc>();
    final tr = Tr.of(context);
    final confirmed = await OcptConfirmDialog.show(
      context,
      title: tr.shotListFloorPlanDeleteCaseConfirmTitle,
      message: tr.shotListFloorPlanDeleteCaseConfirmMessage,
      cancelLabel: tr.shotListDeleteConfirmCancelAction,
      confirmLabel: tr.shotListDeleteConfirmDeleteAction,
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(OcptShotListSetDeletionRequestedEvent(setId: setId));
  }

  /// Builds the floor plans view: the tray, the tool bar, the canvas and the focus strip, every
  /// write withheld (a null callback) under a version preview, reads (zoom, pan, layer visibility,
  /// symbol selection, focusing a shot) staying available throughout.
  ///
  /// **The focus is derived, never stored**: [OcptShotListState.isFloorPlanShotFocusActive] reads
  /// `selectedShotId == null ? sequence : that shot`, and `focusShotId` handed to the view below is
  /// simply `state.selectedShotId` — the very field the table's rows and the board already share.
  Widget _buildFloorPlanView(
    BuildContext context,
    OcptShotListState state,
    OcptShotSequence sequence,
  ) {
    final bloc = context.read<OcptShotListBloc>();
    final tr = Tr.of(context);
    final isReadOnly = state.isPreviewingVersion;
    final selectedSet = state.selectedSet;
    final selectedSetId = state.selectedSetId;
    final focusShotId = state.selectedShotId;

    final shotRankByShotId = <String, int>{
      for (var i = 0; i < sequence.shots.length; i++) sequence.shots[i].id: i + 1,
    };

    return OcptFloorPlanView(
      floorPlanSet: selectedSet,
      shots: sequence.shots,
      shotRankByShotId: shotRankByShotId,
      focusShotId: focusShotId,
      previousShotId: state.previousShotOfSelectedShot?.id,
      nextShotId: state.nextShotOfSelectedShot?.id,
      hasCameraOnSetOf: _hasCameraOnSetOf(sequence, selectedSet),
      sequenceCameras: _sequenceCamerasOf(selectedSet, shotRankByShotId),
      initialZoom: state.floorPlanZoom,
      hiddenLayers: state.floorPlanHiddenLayers,
      hiddenCameraSymbolIds: state.floorPlanHiddenCameraSymbolIds,
      isUnderlayHidden: state.isFloorPlanUnderlayHidden,
      isOnionSkinPreviousShown: state.isFloorPlanOnionSkinPreviousShown,
      isOnionSkinNextShown: state.isFloorPlanOnionSkinNextShown,
      onionSkinOpacity: state.floorPlanOnionSkinOpacity,
      isMetricsShown: state.isFloorPlanMetricsShown,
      selectedSymbolId: state.selectedFloorPlanSymbolId,
      pendingArrowAnchorSymbolId: state.pendingFloorPlanArrowAnchorSymbolId,
      activeTool: state.floorPlanActiveTool,
      activeLayer: state.floorPlanActiveLayer,
      isReadOnly: isReadOnly,
      symbolLabelValueOf: (symbolId) => _symbolLabelValueOf(state, symbolId),
      onToolSelected: (tool) => bloc.add(OcptShotListFloorPlanToolSelectedEvent(tool: tool)),
      onLayerVisibilityToggled: (layer) =>
          bloc.add(OcptShotListFloorPlanLayerVisibilityToggledEvent(layer: layer)),
      onActiveLayerChanged: (layer) =>
          bloc.add(OcptShotListFloorPlanActiveLayerChangedEvent(layer: layer)),
      onCameraVisibilityToggled: (symbolId) =>
          bloc.add(OcptShotListFloorPlanCameraVisibilityToggledEvent(symbolId: symbolId)),
      onOnionSkinToggled: (isPrevious) =>
          bloc.add(OcptShotListFloorPlanOnionSkinToggledEvent(isPrevious: isPrevious)),
      onOnionSkinOpacityChanged: (opacity) =>
          bloc.add(OcptShotListFloorPlanOnionSkinOpacityChangedEvent(opacity: opacity)),
      onMetricsToggled: () => bloc.add(const OcptShotListFloorPlanMetricsToggledEvent()),
      onUnderlayVisibilityToggled: () =>
          bloc.add(const OcptShotListFloorPlanUnderlayVisibilityToggledEvent()),
      onUnderlayImportRequested: isReadOnly || selectedSetId == null
          ? null
          : () => bloc.add(
              OcptShotListFloorPlanUnderlayImportRequestedEvent(
                setId: selectedSetId,
                fileTypeLabel: tr.shotListFloorPlanUnderlayFileTypeLabel,
              ),
            ),
      onUnderlayClearRequested:
          isReadOnly || selectedSetId == null || selectedSet?.underlayAssetId == null
          ? null
          : () => unawaited(_handleUnderlayClearRequested(context, selectedSetId)),
      onSymbolSelected: (symbolId) =>
          bloc.add(OcptShotListFloorPlanSymbolSelectedEvent(symbolId: symbolId)),
      onSymbolPlaced: isReadOnly || selectedSetId == null
          ? null
          : (layer, shotId, xM, yM) => bloc.add(
              OcptShotListFloorPlanSymbolPlacedEvent(
                setId: selectedSetId,
                layer: layer,
                shotId: shotId,
                xM: xM,
                yM: yM,
              ),
            ),
      onSymbolMoved: isReadOnly
          ? null
          : (symbolId, xM, yM) => bloc.add(
              OcptShotListFloorPlanSymbolMovedEvent(symbolId: symbolId, xM: xM, yM: yM),
            ),
      onSymbolResized: isReadOnly
          ? null
          : (symbolId, widthM, heightM) => bloc.add(
              OcptShotListFloorPlanSymbolResizedEvent(
                symbolId: symbolId,
                widthM: widthM,
                heightM: heightM,
              ),
            ),
      onSymbolRotated: isReadOnly
          ? null
          : (symbolId, rotationDeg) => bloc.add(
              OcptShotListFloorPlanSymbolRotatedEvent(
                symbolId: symbolId,
                rotationDeg: rotationDeg,
              ),
            ),
      onSymbolDeleteRequested: isReadOnly
          ? null
          : (symbolId) => unawaited(_handleSymbolDeleteRequested(context, symbolId)),
      onArrowSymbolTapped: isReadOnly || selectedSetId == null || focusShotId == null
          ? null
          : (symbolId) => bloc.add(OcptShotListFloorPlanArrowSymbolTappedEvent(symbolId: symbolId)),
      onArrowAnchorCancelled: isReadOnly
          ? null
          : () => bloc.add(const OcptShotListFloorPlanArrowAnchorCancelledEvent()),
      onGhostShotFocusRequested: (shotId) =>
          bloc.add(OcptShotListShotSelectedEvent(shotId: shotId)),
      onSymbolLabelChanged: isReadOnly
          ? null
          : (symbolId, rawValue) => bloc.add(
              OcptShotListFloorPlanSymbolLabelChangedEvent(symbolId: symbolId, rawValue: rawValue),
            ),
      onUnderlayTransformChanged: isReadOnly || selectedSetId == null
          ? null
          : (xM, yM, widthM, heightM) => bloc.add(
              OcptShotListFloorPlanUnderlayTransformChangedEvent(
                setId: selectedSetId,
                xM: xM,
                yM: yM,
                widthM: widthM,
                heightM: heightM,
              ),
            ),
      onZoomSettled: (zoom) => bloc.add(OcptShotListFloorPlanZoomChangedEvent(zoom: zoom)),
      onSequenceChipSelected: () => bloc.add(const OcptShotListShotDeselectedEvent()),
      onShotChipSelected: (shotId) => bloc.add(OcptShotListShotSelectedEvent(shotId: shotId)),
      onShotWalkRequested: (delta) =>
          bloc.add(OcptShotListFloorPlanShotWalkRequestedEvent(delta: delta)),
    );
  }

  /// Whether each of [sequence]'s own shots has a live camera symbol on [selectedSet], keyed by
  /// shot id — the focus strip's own filled/hollow dots.
  Map<String, bool> _hasCameraOnSetOf(
    OcptShotSequence sequence,
    OcptFloorPlanSet? selectedSet,
  ) {
    if (selectedSet == null) {
      return const {};
    }
    final shotIdsWithCamera = {
      for (final symbol in selectedSet.symbols)
        if (symbol.layer == OcptFloorPlanLayer.cameras && symbol.shotId != null) symbol.shotId!,
    };
    return {for (final shot in sequence.shots) shot.id: shotIdsWithCamera.contains(shot.id)};
  }

  /// Every live camera symbol of [selectedSet], numbered, for the tray's own expandable cameras
  /// row under the `Sequence` focus — built from the very same `OcptFloorPlanSheet.of` the canvas
  /// itself draws that focus from, so the tray's own labels can never disagree with the canvas.
  List<OcptFloorPlanTraySequenceCamera> _sequenceCamerasOf(
    OcptFloorPlanSet? selectedSet,
    Map<String, int> shotRankByShotId,
  ) {
    if (selectedSet == null) {
      return const [];
    }
    final sheet = OcptFloorPlanSheet.of(
      floorPlanSet: selectedSet,
      focusShotId: null,
      shotRankByShotId: shotRankByShotId,
    );
    return [
      for (final symbol in sheet.symbols)
        if (symbol.layer == OcptFloorPlanLayer.cameras)
          OcptFloorPlanTraySequenceCamera(
            symbolId: symbol.symbolId,
            label: symbol.cameraLabel ?? "?",
          ),
    ];
  }

  /// [symbolId]'s current label value: a pending edit still in the bloc's debounce, or the
  /// symbol's own stored label — the inline label editor's equivalent of [_fieldValueOf].
  String _symbolLabelValueOf(OcptShotListState state, String symbolId) {
    final pending = state.pendingFieldEdits[OcptShotListSymbolLabelEditKey(symbolId: symbolId)];
    if (pending != null) {
      return pending;
    }
    for (final floorPlanSet in state.setsOfSelectedSequence) {
      for (final symbol in floorPlanSet.symbols) {
        if (symbol.id == symbolId) {
          return symbol.label;
        }
      }
    }
    return "";
  }

  /// Shows the delete confirmation dialog, then dispatches the symbol's deletion if the user
  /// confirmed it — the canvas's own delete handle, which only asks.
  Future<void> _handleSymbolDeleteRequested(BuildContext context, String symbolId) async {
    final bloc = context.read<OcptShotListBloc>();
    final tr = Tr.of(context);
    final confirmed = await OcptConfirmDialog.show(
      context,
      title: tr.shotListFloorPlanDeleteSymbolConfirmTitle,
      message: tr.shotListFloorPlanDeleteSymbolConfirmMessage,
      cancelLabel: tr.shotListDeleteConfirmCancelAction,
      confirmLabel: tr.shotListDeleteConfirmDeleteAction,
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(OcptShotListFloorPlanSymbolDeletionRequestedEvent(symbolId: symbolId));
  }

  /// Shows the delete confirmation dialog, then dispatches the arrow's deletion if the user
  /// confirmed it — the Placements group's own remove action, which only asks.
  Future<void> _handleArrowDeleteRequested(BuildContext context, String arrowId) async {
    final bloc = context.read<OcptShotListBloc>();
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

    bloc.add(OcptShotListFloorPlanArrowDeletionRequestedEvent(arrowId: arrowId));
  }

  /// Builds the inspector's floor-plans-only `leadingGroup`: the selected shot's own placements on
  /// the selected case, and one line per other case of the sequence — null while no shot or no
  /// case is selected (the `Sequence` focus shows no single shot's own placements at all).
  Widget? _buildPlacementsGroup(BuildContext context, OcptShotListState state) {
    final selectedShot = state.selectedShot;
    final selectedSet = state.selectedSet;
    if (selectedShot == null || selectedSet == null) {
      return null;
    }

    final isReadOnly = state.isPreviewingVersion;

    final shotRankByShotId = <String, int>{
      for (final sequence in state.sequences)
        if (sequence is OcptSceneShotSequence)
          for (var i = 0; i < sequence.shots.length; i++) sequence.shots[i].id: i + 1,
    };
    final sheet = OcptFloorPlanSheet.of(
      floorPlanSet: selectedSet,
      focusShotId: selectedShot.id,
      shotRankByShotId: shotRankByShotId,
    );
    final ownSymbols = [
      for (final symbol in sheet.symbols)
        if (!symbol.isGhost && symbol.shotId == selectedShot.id) symbol,
    ];
    final ownArrows = [
      for (final arrow in sheet.arrows)
        if (!arrow.isGhost && arrow.shotId == selectedShot.id) arrow,
    ];

    final otherSets = [
      for (final otherSet in state.setsOfSelectedSequence)
        if (otherSet.id != selectedSet.id)
          OcptFloorPlanPlacementsOtherSet(
            setName: otherSet.name,
            cameraCount: otherSet.symbols
                .where(
                  (symbol) =>
                      symbol.layer == OcptFloorPlanLayer.cameras &&
                      symbol.shotId == selectedShot.id,
                )
                .length,
          ),
    ];

    return OcptFloorPlanPlacementsGroup(
      setName: selectedSet.name,
      cameras: ownSymbols.where((symbol) => symbol.layer == OcptFloorPlanLayer.cameras).toList(),
      characters: ownSymbols
          .where((symbol) => symbol.layer == OcptFloorPlanLayer.characters)
          .toList(),
      lights: ownSymbols.where((symbol) => symbol.layer == OcptFloorPlanLayer.lights).toList(),
      handProps: ownSymbols
          .where((symbol) => symbol.layer == OcptFloorPlanLayer.props)
          .toList(),
      arrows: ownArrows,
      otherSets: otherSets,
      isReadOnly: isReadOnly,
      onSymbolDeleteRequested: isReadOnly
          ? null
          : (symbolId) => unawaited(_handleSymbolDeleteRequested(context, symbolId)),
      onArrowDeleteRequested: isReadOnly
          ? null
          : (arrowId) => unawaited(_handleArrowDeleteRequested(context, arrowId)),
    );
  }

  /// Shows the delete confirmation dialog, then dispatches the underlay's clearing if the user
  /// confirmed it — the tray's own `Clear underlay` action, which only asks.
  Future<void> _handleUnderlayClearRequested(BuildContext context, String setId) async {
    final bloc = context.read<OcptShotListBloc>();
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

    bloc.add(OcptShotListFloorPlanUnderlayClearRequestedEvent(setId: setId));
  }

  /// [panelId]'s current comment value: a pending edit still in the bloc's debounce, or the
  /// panel's own stored value — the board's equivalent of [_fieldValueOf].
  String _panelCommentValueOf(OcptShotListState state, String panelId) {
    final pending = state.pendingFieldEdits[OcptShotListPanelCommentEditKey(panelId: panelId)];
    if (pending != null) {
      return pending;
    }

    for (final panel in state.panelsOfSelectedShot) {
      if (panel.id == panelId) {
        return panel.comment;
      }
    }
    return "";
  }

  /// [annotationId]'s current text value: a pending edit still in the bloc's debounce, or the
  /// mark's own stored text — the annotation section's equivalent of [_panelCommentValueOf].
  String _annotationTextValueOf(OcptShotListState state, String annotationId) {
    final pending =
        state.pendingFieldEdits[OcptShotListAnnotationTextEditKey(annotationId: annotationId)];
    if (pending != null) {
      return pending;
    }

    for (final annotation in state.selectedPanel?.annotations ?? const <OcptStoryboardAnnotation>[]) {
      if (annotation.id == annotationId) {
        return annotation.text;
      }
    }
    return "";
  }

  /// Shows the delete confirmation dialog, then dispatches the panel's deletion if the user
  /// confirmed it — the inspector's Panels group's own `Delete panel` action, which only asks.
  Future<void> _handlePanelDeleteRequested(BuildContext context, String panelId) async {
    final bloc = context.read<OcptShotListBloc>();
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

    bloc.add(OcptShotListPanelDeletionRequestedEvent(panelId: panelId));
  }

  /// Shows the delete confirmation dialog, then dispatches the mark's deletion if the user
  /// confirmed it — the annotation section's own remove action, which only asks.
  Future<void> _handleAnnotationDeleteRequested(BuildContext context, String annotationId) async {
    final bloc = context.read<OcptShotListBloc>();
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

    bloc.add(OcptShotListAnnotationDeletionRequestedEvent(annotationId: annotationId));
  }

  /// Builds the inspector's board-only `leadingGroup`: the selected shot's own panels, each with
  /// its comment field, the reorder affordance and a `Delete panel` action that only asks (see
  /// [_handlePanelDeleteRequested]), followed by the selected panel's own annotation section (the
  /// `Annotate` tool picker and its marks list).
  Widget _buildPanelsGroup(BuildContext context, OcptShotListState state) {
    final bloc = context.read<OcptShotListBloc>();
    final selectedShot = state.selectedShot;
    final isReadOnly = state.isPreviewingVersion;

    return OcptStoryboardPanelsGroup(
      panels: state.panelsOfSelectedShot,
      commentValueOf: (panelId) => _panelCommentValueOf(state, panelId),
      isReadOnly: isReadOnly,
      onCommentChanged: isReadOnly
          ? null
          : (panelId, rawValue) =>
                bloc.add(OcptShotListPanelCommentChangedEvent(panelId: panelId, rawValue: rawValue)),
      onReordered: isReadOnly || selectedShot == null
          ? null
          : (panelId, newPosition) => bloc.add(
              OcptShotListPanelReorderedEvent(
                shotId: selectedShot.id,
                panelId: panelId,
                newPosition: newPosition,
              ),
            ),
      onDeleteRequested: isReadOnly
          ? null
          : (panelId) => unawaited(_handlePanelDeleteRequested(context, panelId)),
      selectedPanelId: state.selectedPanelId,
      annotations: state.selectedPanel?.annotations ?? const <OcptStoryboardAnnotation>[],
      selectedAnnotationId: state.selectedAnnotationId,
      activeAnnotationTool: state.activeAnnotationTool,
      onToolChanged: isReadOnly
          ? null
          : (tool) => bloc.add(OcptShotListAnnotationToolSelectedEvent(tool: tool)),
      annotationTextValueOf: (annotationId) => _annotationTextValueOf(state, annotationId),
      onAnnotationSelected: (annotationId) =>
          bloc.add(OcptShotListAnnotationSelectedEvent(annotationId: annotationId)),
      onAnnotationTextChanged: isReadOnly
          ? null
          : (annotationId, rawValue) => bloc.add(
              OcptShotListAnnotationTextChangedEvent(
                annotationId: annotationId,
                rawValue: rawValue,
              ),
            ),
      onAnnotationDeleteRequested: isReadOnly
          ? null
          : (annotationId) => unawaited(_handleAnnotationDeleteRequested(context, annotationId)),
    );
  }

  /// The status bar's own trailing hint for the active centre view: the board's `Panel 2 of 3
  /// selected · drag to reorder` while it is shown and a panel is selected, the floor plans'
  /// `Kitchen · 5 cameras on 4 shots · 12/5 has no camera yet` (the last segment only while a shot
  /// of the sequence still has none) while a case is selected, or null otherwise (the table, and
  /// either view with nothing of its own selected, have nothing to add).
  String? _statusBarHint(BuildContext context, OcptShotListState state, bool isCompact) {
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
          if (symbol.layer == OcptFloorPlanLayer.cameras && symbol.shotId != null)
            symbol.shotId!,
      };
      final shotCountWithCamera = sequence.shots
          .where((shot) => shotIdsWithCamera.contains(shot.id))
          .length;
      final unplacedShot = sequence.shots.firstWhereOrNull(
        (shot) => !shotIdsWithCamera.contains(shot.id),
      );

      final base = Tr.of(context).shotListFloorPlanCameraStatusHint(
        selectedSet.name,
        cameraCount,
        shotCountWithCamera,
      );
      return unplacedShot == null
          ? base
          : "$base · ${Tr.of(context).shotListFloorPlanCameraStatusUnplacedHint(unplacedShot.code)}";
    }

    if (!isBoardShown) {
      return null;
    }

    final panels = state.panelsOfSelectedShot;
    final selectedPanel = state.selectedPanel;
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
    final sequenceDisplayNumber = _sequenceDisplayNumberFor(selectedSequence);
    final sequenceHeading = _sequenceHeadingFor(selectedSequence, selectedShot);
    final coverageLayout = state.buildSelectedCoverageLayout();
    final staleCoverageRangeIds = coverageLayout == null
        ? const <String>{}
        : state.staleCoverageRangeIdsOfSelectedShot(coverageLayout);
    final isBoardShown = !isCompact && state.centreView == OcptShotListCentreView.board;
    final isFloorPlansShown = !isCompact && state.centreView == OcptShotListCentreView.floorPlans;

    return OcptShotListRightDock(
      activeTab: rightDockTab,
      inspectorChild: OcptShotInspectorPanel(
        shot: selectedShot,
        sequenceHeading: sequenceHeading,
        leadingGroup: isBoardShown
            ? _buildPanelsGroup(context, state)
            : isFloorPlansShown
            ? _buildPlacementsGroup(context, state)
            : null,
        sequenceDisplayNumber: sequenceDisplayNumber,
        roles: state.roles,
        suggestions: state.suggestions,
        coverageLayout: coverageLayout,
        otherShotsCoverageRanges: state.otherShotsCoverageOfSelectedScene(),
        staleCoverageRangeIds: staleCoverageRangeIds,
        fieldValueOf: (field) => _fieldValueOf(state, selectedShot, field),
        onDifficultyChanged: (axis, value) => _dispatchIfShotSelected(
          context,
          selectedShot,
          (id) => OcptShotListShotDifficultyChangedEvent(shotId: id, axis: axis, value: value),
        ),
        onCharacterToggled: (roleId) => _dispatchIfShotSelected(
          context,
          selectedShot,
          (id) => OcptShotListShotCharacterToggledEvent(shotId: id, roleId: roleId),
        ),
        onCharacterAdded: (name) => _dispatchIfShotSelected(
          context,
          selectedShot,
          (id) => OcptShotListCharacterAddRequestedEvent(shotId: id, characterName: name),
        ),
        onFieldChanged: (field, value) => _dispatchIfShotSelected(
          context,
          selectedShot,
          (id) => OcptShotListShotFieldChangedEvent(shotId: id, field: field, rawValue: value),
        ),
        onSelectCoverageRequested: () => _handleCoverageSelectionRequested(context),
        onCoverageClearAll: () => _dispatchIfShotSelected(
          context,
          selectedShot,
          (id) => OcptShotListCoverageClearRequestedEvent(shotId: id),
        ),
        onMarkAsChecked: () => _dispatchIfShotSelected(
          context,
          selectedShot,
          (id) => OcptShotListShotMarkedAsCheckedEvent(shotId: id),
        ),
        onDeleteRequested: selectedShot == null
            ? null
            : () => _handleDeleteRequested(context, selectedShot),
        isReadOnly: state.isPreviewingVersion,
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
      onTabSelected: (tab) => context.read<OcptShotListBloc>().add(
        OcptShotListRightDockTabSelectedEvent(tab: tab),
      ),
      onClose: () =>
          context.read<OcptShotListBloc>().add(const OcptShotListRightDockClosedEvent()),
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
      onExitPreview: () => context.read<OcptShotListBloc>().add(
        const OcptProjectVersionPreviewExitRequestedEvent(),
      ),
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
        onRestoreCancelled: () => context.read<OcptShotListBloc>().add(
          const OcptProjectVersionRestoreCancelledEvent(),
        ),
        onRestoreConfirmed: (version) => context.read<OcptShotListBloc>().add(
          OcptProjectVersionRestoreConfirmedEvent(
            versionId: version.id,
            safetyVersionName: Tr.of(context).projectVersionRestoreSafetyName(version.name),
          ),
        ),
        onDeleteRequested: (versionId) => context.read<OcptShotListBloc>().add(
          OcptProjectVersionDeletionRequestedEvent(versionId: versionId),
        ),
        onDeleteCancelled: () => context.read<OcptShotListBloc>().add(
          const OcptProjectVersionDeletionCancelledEvent(),
        ),
        onDeleteConfirmed: (versionId) => context.read<OcptShotListBloc>().add(
          OcptProjectVersionDeletionConfirmedEvent(versionId: versionId),
        ),
        onRenameRequested: (versionId) => context.read<OcptShotListBloc>().add(
          OcptProjectVersionRenameRequestedEvent(versionId: versionId),
        ),
        onRenameCancelled: () => context.read<OcptShotListBloc>().add(
          const OcptProjectVersionRenameCancelledEvent(),
        ),
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

  /// The display number of [sequence]: a real scene's own `displaySceneNumber`, or the orphan
  /// placeholder for the orphan group or for no sequence at all.
  String _sequenceDisplayNumberFor(OcptShotSequence? sequence) => switch (sequence) {
    OcptSceneShotSequence() => sequence.displaySceneNumber,
    OcptOrphanShotSequence() || null => ocptShotListEmptyValue,
  };

  /// The heading shown for [sequence]: a real scene's own heading, or [shot]'s
  /// `OcptShot.orphanedHeading` while [sequence] is the orphan group.
  String _sequenceHeadingFor(OcptShotSequence? sequence, OcptShot? shot) => switch (sequence) {
    OcptSceneShotSequence() => sequence.heading,
    OcptOrphanShotSequence() => shot?.orphanedHeading ?? ocptShotListEmptyValue,
    null => ocptShotListEmptyValue,
  };

  /// [shot]'s current value for [field], for the inspector's editable fields: a pending edit
  /// still sitting in the bloc's debounce takes priority over the shot's own stored value, so
  /// typing is never overwritten by an unrelated reload. Formatted for an editable field (an
  /// empty string for a missing value, never [ocptShotListEmptyValue], which is the table and
  /// read-only fields' own placeholder).
  String _fieldValueOf(OcptShotListState state, OcptShot? shot, OcptShotListEditableField field) {
    if (shot == null) {
      return "";
    }

    final pending = state.pendingFieldEdits[
        OcptShotListShotFieldEditKey(shotId: shot.id, field: field)];
    if (pending != null) {
      return pending;
    }

    return switch (field) {
      OcptShotListEditableField.shotSize => shot.shotSize,
      OcptShotListEditableField.abbreviation => shot.abbreviation,
      OcptShotListEditableField.framing => shot.framing,
      OcptShotListEditableField.cameraMove => shot.cameraMove,
      OcptShotListEditableField.lens => shot.lens,
      OcptShotListEditableField.recordingFormat => shot.recordingFormat,
      OcptShotListEditableField.estimatedDuration => shot.estimatedDurationMs == null
          ? ""
          : ocptFormatShotDuration(shot.estimatedDurationMs),
      OcptShotListEditableField.sound => shot.sound,
      OcptShotListEditableField.notes => shot.notes,
      OcptShotListEditableField.locationNotes => shot.locationNotes,
    };
  }

  /// Dispatches the event [buildEvent] builds from [shot]'s id, or does nothing while [shot] is
  /// null: every inspector callback that acts on "the selected shot" goes through this, so none
  /// of them has to force-unwrap it.
  void _dispatchIfShotSelected(
    BuildContext context,
    OcptShot? shot,
    OcptShotListEvent Function(String shotId) buildEvent,
  ) {
    if (shot == null) {
      return;
    }
    context.read<OcptShotListBloc>().add(buildEvent(shot.id));
  }

  /// Opens the dialog a shot's scenario coverage is selected in, keeping it in step with the bloc
  /// for as long as it is open.
  ///
  /// The dialog is built inside a `BlocBuilder` of its own, on the bloc explicitly handed down
  /// rather than read from the dialog's context: a dialog is mounted in the navigator's own
  /// subtree, above this mode, so it inherits nothing from it. That builder is what makes a range
  /// appear the moment it is recorded, since every click writes through the same bloc events the
  /// inspector uses. It renders nothing at all in the two states where there is nothing to select
  /// in — no shot selected any more, or a shot whose sequence disappeared from the screenplay —
  /// which can only happen if the selection changes underneath an open dialog.
  Future<void> _handleCoverageSelectionRequested(BuildContext context) {
    final bloc = context.read<OcptShotListBloc>();

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: bloc,
        child: BlocBuilder<OcptShotListBloc, OcptShotListState>(
          builder: (context, state) {
            final shot = state.selectedShot;
            final layout = state.buildSelectedCoverageLayout();
            if (shot == null || layout == null) {
              return const SizedBox.shrink();
            }

            return OcptShotCoverageDialog(
              shotCode: shot.code,
              sequenceHeading: _sequenceHeadingFor(state.selectedSequence, shot),
              layout: layout,
              pageSetup: state.pageSetup,
              ownRanges: shot.coverageRanges,
              otherShotsRanges: state.otherShotsCoverageOfSelectedScene(),
              pendingAnchor: state.pendingCoverageAnchor,
              onWordTapped: (wordStartOffset, wordEndOffset) => bloc.add(
                OcptShotListCoverageWordClickedEvent(
                  shotId: shot.id,
                  wordStartOffset: wordStartOffset,
                  wordEndOffset: wordEndOffset,
                ),
              ),
              onClearAll: () => bloc.add(OcptShotListCoverageClearRequestedEvent(shotId: shot.id)),
              onAnchorCancelled: () => bloc.add(const OcptShotListCoverageAnchorCancelledEvent()),
            );
          },
        ),
      ),
    );
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

    final ioNotice = state.ioNotice;
    if (ioNotice != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_ioNoticeMessage(context, ioNotice))));
      context.read<OcptShotListBloc>().add(const OcptShotListIoNoticeDismissedEvent());
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
      context.read<OcptShotListBloc>().add(
        const OcptProjectPackageMissingFilesAskDismissedEvent(),
      );
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
      OcptShotListIoNoticeKind.xlsxExportSucceeded => notice.wasShared
          ? tr.exportSharedMessage
          : tr.shotListExportXlsxSuccessMessage(notice.path ?? ""),
      OcptShotListIoNoticeKind.xlsxExportFailed => tr.shotListExportXlsxError,
      OcptShotListIoNoticeKind.scenarioCoverageExportSucceeded => notice.wasShared
          ? tr.exportSharedMessage
          : tr.shotListExportCoverageSuccessMessage(notice.path ?? ""),
      OcptShotListIoNoticeKind.scenarioCoverageExportFailed => tr.shotListExportCoverageError,
      OcptShotListIoNoticeKind.storyboardExportSucceeded => notice.wasShared
          ? tr.exportSharedMessage
          : tr.shotListExportStoryboardSuccessMessage(notice.path ?? ""),
      OcptShotListIoNoticeKind.storyboardExportFailed => tr.shotListExportStoryboardError,
      OcptShotListIoNoticeKind.floorPlansExportSucceeded => notice.wasShared
          ? tr.exportSharedMessage
          : tr.shotListExportFloorPlansSuccessMessage(notice.path ?? ""),
      OcptShotListIoNoticeKind.floorPlansExportFailed => tr.shotListExportFloorPlansError,
    };
  }
}
