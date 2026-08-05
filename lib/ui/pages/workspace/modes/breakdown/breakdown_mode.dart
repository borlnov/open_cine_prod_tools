// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_right_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_scene_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_script_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_status_bar.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_version_create_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_versions_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock_layout_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_read_only_banner.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_shell.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_project_version_notice_message.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_scene_bars.dart';

/// The breakdown production mode (dépouillement du scénario): the scene list on the left, the whole
/// screenplay typeset as a paper sheet in the centre, and the shared `Versions` dock tab on the
/// right.
///
/// This milestone's script view only reads: see `OcptBreakdownScriptView`'s own doc comment for
/// what is deliberately not here yet (the clickable, taggable words). There is therefore **no save
/// control and no mode-specific toolbar action** — the shell simply isn't handed one, rather than
/// showing an inert one — and the whole mode never withholds anything for a previewed version's
/// sake beyond what [OcptBreakdownScriptView] already never offered.
///
/// While a project version is being previewed, the mode shows that version's own read instead of
/// the working copy's, and carries the shell's read-only banner naming it, exactly as the resources
/// and shot list modes do.
class OcptBreakdownMode extends StatelessWidget {
  /// Creates the breakdown mode.
  const OcptBreakdownMode({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocProvider(create: (context) => OcptBreakdownBloc(), child: const _BreakdownView());
}

/// The content of [OcptBreakdownMode], separated from it so [OcptBreakdownMode] only wires the
/// [OcptBreakdownBloc] up (RFL3).
///
/// This is a StatefulWidget (the documented RFL1 exception) because it owns the dock layout
/// controller: the live dock fractions must survive a rebuild and be mutated imperatively while a
/// divider is being dragged, without emitting a bloc state per frame. Mirrors
/// `_ResourcesView`/`_ShotListView`.
class _BreakdownView extends StatefulWidget {
  /// Class constructor
  const _BreakdownView();

  @override
  State<_BreakdownView> createState() => _BreakdownViewState();
}

/// The state of [_BreakdownView]: owns the dock layout controller and keeps it in sync with the
/// fractions the bloc persisted.
class _BreakdownViewState extends State<_BreakdownView> {
  /// The live source of truth for the two dock fractions while dragging a divider. Initialized
  /// with the defaults; synced to the bloc's persisted values once the load (or a reset) resolves,
  /// in [_onStateChanged].
  final OcptWorkspaceDockLayoutController _dockLayoutController = OcptWorkspaceDockLayoutController(
    leftFraction: OcptWorkspaceDock.leftDefaultFraction,
    rightFraction: OcptWorkspaceDock.rightDefaultFraction,
  );

  @override
  void dispose() {
    _dockLayoutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<OcptBreakdownBloc, OcptBreakdownState>(
    listener: _onStateChanged,
    builder: (context, state) {
      if (state.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }

      return OcptWorkspaceShell(
        title: state.title,
        isDirty: false,
        isReadOnly: state.isPreviewingVersion,
        onBack: () => context.read<OcptBreakdownBloc>().add(const OcptBreakdownBackRequestedEvent()),
        modeLabel: Tr.of(context).workspaceModeLabelBreakdown,
        overflowEntries: _buildOverflowEntries(context),
        isLeftDockOpen: state.isListPanelVisible,
        onToggleLeftDock: () =>
            context.read<OcptBreakdownBloc>().add(const OcptBreakdownLeftPanelToggledEvent()),
        isRightDockOpen: state.rightDockTab != null,
        onToggleRightDock: () =>
            context.read<OcptBreakdownBloc>().add(const OcptBreakdownRightDockToggledEvent()),
        onProjectSettingsRequested: state.isPreviewingVersion
            ? null
            : () => _requestProjectSettings(context),
        banner: _buildReadOnlyBanner(context, state),
        leftPanel: _buildScenePanel(context, state),
        rightPanel: _buildRightDock(context, state),
        centre: _buildScriptView(state),
        statusBar: OcptBreakdownStatusBar(
          taggedTargetCount: state.taggedTargetCount,
          usedCategoryCount: state.usedCategoryCount,
          toFindCount: state.toFindCount,
        ),
        dockLayoutController: _dockLayoutController,
        onDockFractionsChanged: (fractions) => context.read<OcptBreakdownBloc>().add(
          OcptBreakdownDockFractionsChangedEvent(left: fractions.left, right: fractions.right),
        ),
      );
    },
  );

  /// Builds the mode's `⋮` overflow menu entries: resetting the panel layout, mirroring
  /// `OcptResourcesMode._buildOverflowEntries` minus the export entry this milestone has none of.
  List<PopupMenuEntry<void>> _buildOverflowEntries(BuildContext context) => [
    PopupMenuItem<void>(
      onTap: () =>
          context.read<OcptBreakdownBloc>().add(const OcptBreakdownDockLayoutResetEvent()),
      child: Text(Tr.of(context).breakdownResetPanelLayoutAction),
    ),
  ];

  /// Opens the project settings page, then reloads the mode's own read if the user changed
  /// anything there.
  Future<void> _requestProjectSettings(BuildContext context) async {
    final bloc = context.read<OcptBreakdownBloc>();
    final hasChanged = await globalGetIt().get<OcptRouterManager>().push<bool>(
      OcptRoute.projectSettings,
    );
    if (hasChanged != true) {
      return;
    }

    bloc.add(const OcptBreakdownProjectSettingsChangedEvent());
  }

  /// Builds the left dock, the shell's `leftPanel`, or null while it's hidden.
  Widget? _buildScenePanel(BuildContext context, OcptBreakdownState state) {
    if (!state.isListPanelVisible) {
      return null;
    }

    return OcptBreakdownScenePanel(
      scenes: state.scenes,
      targetById: ocptBreakdownTargetsById(state.targets),
      selectedSceneId: state.selectedSceneId,
      onSceneSelected: (sceneId) =>
          context.read<OcptBreakdownBloc>().add(OcptBreakdownSceneSelectedEvent(sceneId: sceneId)),
    );
  }

  /// Builds the shell's `centre`: the whole screenplay typeset as a paper sheet.
  Widget _buildScriptView(OcptBreakdownState state) => OcptBreakdownScriptView(
    screenplayText: state.screenplayText,
    scenes: state.scenes,
    targetById: ocptBreakdownTargetsById(state.targets),
    pageSetup: state.pageSetup,
    selectedSceneId: state.selectedSceneId,
    onSceneSelected: (sceneId) => context.read<OcptBreakdownBloc>().add(
      OcptBreakdownSceneSelectedEvent(sceneId: sceneId),
    ),
  );

  /// Builds the right dock, the shell's `rightPanel`, or null while the dock is closed.
  Widget? _buildRightDock(BuildContext context, OcptBreakdownState state) {
    if (state.rightDockTab == null) {
      return null;
    }

    return OcptBreakdownRightDock(
      versionsChild: _buildVersionsPanel(context, state),
      onClose: () =>
          context.read<OcptBreakdownBloc>().add(const OcptBreakdownRightDockClosedEvent()),
    );
  }

  /// Builds the band naming the version being previewed, the shell's `banner`, or null while the
  /// working copy is on screen.
  Widget? _buildReadOnlyBanner(BuildContext context, OcptBreakdownState state) {
    final previewedVersion = state.previewedVersion;
    if (previewedVersion == null) {
      return null;
    }

    final tr = Tr.of(context);

    return OcptWorkspaceReadOnlyBanner(
      version: previewedVersion,
      onForkRequested: () => context.read<OcptBreakdownBloc>().add(
        OcptProjectVersionRestoreConfirmedEvent(
          versionId: previewedVersion.id,
          safetyVersionName: tr.projectVersionRestoreSafetyName(previewedVersion.name),
        ),
      ),
      onExitPreview: () => context.read<OcptBreakdownBloc>().add(
        const OcptProjectVersionPreviewExitRequestedEvent(),
      ),
    );
  }

  /// Builds the right dock's `Versions` tab: the working copy's own card and the project's named
  /// versions, the same panel every other mode's dock hosts, wired to the events
  /// `MixinOcptProjectVersionsBloc` handles.
  Widget _buildVersionsPanel(BuildContext context, OcptBreakdownState state) =>
      OcptProjectVersionsPanel(
        versions: state.projectVersions,
        previewedVersionId: state.previewedVersionId,
        workingCopy: state.workingCopy,
        versionPendingDeletionId: state.versionPendingDeletionId,
        versionPendingRestoreId: state.versionPendingRestoreId,
        versionPendingRenameId: state.versionPendingRenameId,
        onCreateRequested: () => _requestVersionCreation(context),
        onPreviewRequested: (versionId) => context.read<OcptBreakdownBloc>().add(
          OcptProjectVersionPreviewRequestedEvent(versionId: versionId),
        ),
        onPreviewExitRequested: () => context.read<OcptBreakdownBloc>().add(
          const OcptProjectVersionPreviewExitRequestedEvent(),
        ),
        onRestoreRequested: (versionId) => context.read<OcptBreakdownBloc>().add(
          OcptProjectVersionRestoreRequestedEvent(versionId: versionId),
        ),
        onRestoreCancelled: () => context.read<OcptBreakdownBloc>().add(
          const OcptProjectVersionRestoreCancelledEvent(),
        ),
        onRestoreConfirmed: (version) => context.read<OcptBreakdownBloc>().add(
          OcptProjectVersionRestoreConfirmedEvent(
            versionId: version.id,
            safetyVersionName: Tr.of(context).projectVersionRestoreSafetyName(version.name),
          ),
        ),
        onDeleteRequested: (versionId) => context.read<OcptBreakdownBloc>().add(
          OcptProjectVersionDeletionRequestedEvent(versionId: versionId),
        ),
        onDeleteCancelled: () => context.read<OcptBreakdownBloc>().add(
          const OcptProjectVersionDeletionCancelledEvent(),
        ),
        onDeleteConfirmed: (versionId) => context.read<OcptBreakdownBloc>().add(
          OcptProjectVersionDeletionConfirmedEvent(versionId: versionId),
        ),
        onRenameRequested: (versionId) => context.read<OcptBreakdownBloc>().add(
          OcptProjectVersionRenameRequestedEvent(versionId: versionId),
        ),
        onRenameCancelled: () => context.read<OcptBreakdownBloc>().add(
          const OcptProjectVersionRenameCancelledEvent(),
        ),
        onRenameConfirmed: (versionId, name, note) => context.read<OcptBreakdownBloc>().add(
          OcptProjectVersionRenameConfirmedEvent(versionId: versionId, name: name, note: note),
        ),
      );

  /// Shows the version creation dialog, then dispatches the capture if the user confirmed it.
  Future<void> _requestVersionCreation(BuildContext context) async {
    final bloc = context.read<OcptBreakdownBloc>();
    final fields = await OcptProjectVersionCreateDialog.show(context);
    if (fields == null) {
      return;
    }

    bloc.add(OcptProjectVersionCreationRequestedEvent(name: fields.name, note: fields.note));
  }

  /// Applies bloc-driven effects onto the page: the live dock fractions, and the transient version
  /// notice SnackBar.
  void _onStateChanged(BuildContext context, OcptBreakdownState state) {
    // Pushes the bloc's persisted fractions (the initial load, or "Reset panel layout") onto the
    // live controller; a no-op once a drag's own end-of-gesture event brings the bloc back in sync
    // with the value the controller already holds.
    _dockLayoutController.syncFromPersisted(
      leftFraction: state.leftDockFraction,
      rightFraction: state.rightDockFraction,
    );

    final versionNotice = state.projectVersionNotice;
    if (versionNotice != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(ocptProjectVersionNoticeMessage(context, versionNotice))),
        );
      context.read<OcptBreakdownBloc>().add(const OcptProjectVersionNoticeDismissedEvent());
    }
  }
}
