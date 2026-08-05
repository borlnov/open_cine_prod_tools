// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/types/ocpt_workspace_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_right_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_scene_inspector.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_scene_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_script_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_status_bar.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_target_inspector.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_version_create_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_versions_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock_layout_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_read_only_banner.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_shell.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_event.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_project_version_notice_message.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_legend.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_scene_bars.dart';

/// The breakdown production mode (dépouillement du scénario): the scene list and, under it, the
/// category legend on the left, the whole screenplay typeset as a paper sheet in the centre, and the
/// `Inspector`/`Versions` right dock.
///
/// The script view lets every word be clicked — a tagged one selects its target, any other one
/// reports its own offsets for the range interaction a later change adds — and selecting a target
/// opens the right dock on its `Inspector` tab, where `OcptBreakdownTargetInspector` shows its sheet;
/// selecting a scene with no target selected shows that scene's own breakdown sheet instead,
/// `OcptBreakdownSceneInspector`. There is **no save control and no mode-specific toolbar action** —
/// the shell simply isn't handed one, rather than showing an inert one — since every write here (the
/// target inspector's chips, pickers and fields, and the tag removal) is written by its own event
/// rather than a single save; the target inspector's three free-text fields still autosave on the 2 s
/// debounce every field like it does elsewhere in the app.
///
/// While a project version is being previewed, the mode shows that version's own read instead of
/// the working copy's, and carries the shell's read-only banner naming it, exactly as the resources
/// and shot list modes do; the inspector then withholds every control that writes (see
/// [OcptBreakdownTargetInspector]'s own doc comment) while leaving both inspectors fully readable.
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
  void deactivate() {
    // `deactivate()` runs before `dispose()` for every removal from the tree (a mode switch swaps
    // this whole subtree out, and so does the workspace's own back navigation), so triggering the
    // flush here — rather than dispatching an event, which would only be processed on a later
    // microtask this widget might not survive to see — is what guarantees the last debounce worth
    // of typing into the target inspector's own fields isn't lost. Mirrors
    // `OcptShotListMode`'s/`OcptResourcesMode`'s own `deactivate()`.
    unawaited(context.read<OcptBreakdownBloc>().flushPendingFieldEdits());
    super.deactivate();
  }

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
        centre: _buildScriptView(context, state),
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
  /// `OcptResourcesMode._buildOverflowEntries` minus the export entry, which this mode has none of
  /// yet.
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
      legendEntries: ocptBreakdownLegendEntriesOf(state.targets),
      hiddenLegendKeys: state.hiddenLegendKeys,
      onLegendEntryToggled: (key) => context.read<OcptBreakdownBloc>().add(
        OcptBreakdownLegendEntryToggledEvent(key: key),
      ),
      onShowAllLegendKeysRequested: () => context.read<OcptBreakdownBloc>().add(
        const OcptBreakdownLegendShowAllRequestedEvent(),
      ),
    );
  }

  /// Builds the shell's `centre`: the whole screenplay typeset as a paper sheet, its words clickable.
  Widget _buildScriptView(BuildContext context, OcptBreakdownState state) => OcptBreakdownScriptView(
    screenplayText: state.screenplayText,
    scenes: state.scenes,
    targetById: ocptBreakdownTargetsById(state.targets),
    pageSetup: state.pageSetup,
    selectedSceneId: state.selectedSceneId,
    onSceneSelected: (sceneId) => context.read<OcptBreakdownBloc>().add(
      OcptBreakdownSceneSelectedEvent(sceneId: sceneId),
    ),
    hiddenLegendKeys: state.hiddenLegendKeys,
    selectedTargetRef: state.selectedTargetRef,
    onTargetSelected: (targetKind, targetId, sceneId) => context.read<OcptBreakdownBloc>().add(
      OcptBreakdownTargetSelectedEvent(targetKind: targetKind, targetId: targetId, sceneId: sceneId),
    ),
    onWordClicked: (sceneId, wordStartOffset, wordEndOffset) => context.read<OcptBreakdownBloc>().add(
      OcptBreakdownWordClickedEvent(
        sceneId: sceneId,
        wordStartOffset: wordStartOffset,
        wordEndOffset: wordEndOffset,
      ),
    ),
  );

  /// Builds the right dock, the shell's `rightPanel`, or null while the dock is closed.
  Widget? _buildRightDock(BuildContext context, OcptBreakdownState state) {
    final rightDockTab = state.rightDockTab;
    if (rightDockTab == null) {
      return null;
    }

    return OcptBreakdownRightDock(
      activeTab: rightDockTab,
      inspectorChild: _buildInspector(context, state),
      versionsChild: _buildVersionsPanel(context, state),
      onTabSelected: (tab) =>
          context.read<OcptBreakdownBloc>().add(OcptBreakdownRightDockTabSelectedEvent(tab: tab)),
      onClose: () =>
          context.read<OcptBreakdownBloc>().add(const OcptBreakdownRightDockClosedEvent()),
    );
  }

  /// Builds the `Inspector` tab's own content: the selected target's sheet, or — while nothing is
  /// selected — the selected scene's own breakdown sheet.
  Widget _buildInspector(BuildContext context, OcptBreakdownState state) {
    final target = state.selectedTarget;
    if (target == null) {
      return OcptBreakdownSceneInspector(
        scene: state.selectedScene,
        targetById: ocptBreakdownTargetsById(state.targets),
        onTargetSelected: (targetKind, targetId, sceneId) => context.read<OcptBreakdownBloc>().add(
          OcptBreakdownTargetSelectedEvent(
            targetKind: targetKind,
            targetId: targetId,
            sceneId: sceneId,
          ),
        ),
      );
    }

    final bloc = context.read<OcptBreakdownBloc>();
    final element = state.selectedElement;
    final isReadOnly = state.isPreviewingVersion;

    return OcptBreakdownTargetInspector(
      target: target,
      element: element,
      owner: element == null ? null : _personById(state.people, element.ownerPersonId),
      bringer: element == null ? null : _personById(state.people, element.broughtByPersonId),
      people: state.people,
      scenes: state.scenes,
      fieldValueOf: (field) => element == null
          ? ""
          : state.elementFieldValueOf(element.id, field, _storedElementFieldValue(element, field)),
      onBackToSceneRequested: () =>
          bloc.add(const OcptBreakdownTargetSelectionClearedEvent()),
      onStatusChanged: isReadOnly || element == null
          ? null
          : (status) => bloc.add(
              OcptBreakdownElementStatusChangedEvent(elementId: element.id, status: status),
            ),
      onCategoryChanged: isReadOnly || element == null
          ? null
          : (category) => bloc.add(
              OcptBreakdownElementCategoryChangedEvent(elementId: element.id, category: category),
            ),
      onFieldChanged: isReadOnly || element == null
          ? null
          : (field, rawValue) => bloc.add(
              OcptBreakdownElementFieldChangedEvent(
                elementId: element.id,
                field: field,
                rawValue: rawValue,
              ),
            ),
      onOwnerChanged: isReadOnly || element == null
          ? null
          : (personId) =>
              bloc.add(OcptBreakdownElementOwnerChangedEvent(elementId: element.id, personId: personId)),
      onBringerChanged: isReadOnly || element == null
          ? null
          : (personId) => bloc.add(
              OcptBreakdownElementBringerChangedEvent(elementId: element.id, personId: personId),
            ),
      onOccurrenceSelected: (sceneId) =>
          bloc.add(OcptBreakdownOccurrenceSelectedEvent(sceneId: sceneId)),
      onOpenInResourcesRequested: () => context.read<OcptWorkspaceBloc>().add(
        const OcptWorkspaceModeSelectedEvent(mode: OcptWorkspaceMode.resources),
      ),
      isTagRemovalPending: state.isTagRemovalPending,
      onTagRemovalRequested: isReadOnly
          ? null
          : () => bloc.add(const OcptBreakdownTagRemovalRequestedEvent()),
      onTagRemovalCancelled: isReadOnly
          ? null
          : () => bloc.add(const OcptBreakdownTagRemovalCancelledEvent()),
      onTagRemovalConfirmed: isReadOnly
          ? null
          : () => bloc.add(const OcptBreakdownTagRemovalConfirmedEvent()),
      isReadOnly: isReadOnly,
    );
  }

  /// The person named by [personId] among [people], or null while [personId] is null or names
  /// nobody in [people].
  OcptPerson? _personById(List<OcptPerson> people, String? personId) {
    if (personId == null) {
      return null;
    }

    for (final person in people) {
      if (person.id == personId) {
        return person;
      }
    }

    return null;
  }

  /// [element]'s own stored value for `field` — only `subCategory`, `quantity` and `notes` are ever
  /// asked for, the target inspector's other fields being single picks rather than typed text.
  String _storedElementFieldValue(OcptElement element, OcptElementField field) => switch (field) {
    OcptElementField.subCategory => element.subCategory,
    OcptElementField.quantity => element.quantity,
    OcptElementField.notes => element.notes,
    OcptElementField.name ||
    OcptElementField.code ||
    OcptElementField.ownerNotes ||
    OcptElementField.storageNotes ||
    OcptElementField.cost ||
    OcptElementField.purposeNotes => "",
  };

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
