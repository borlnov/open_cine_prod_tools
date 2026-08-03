// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_list_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_right_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_status_bar.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_version_create_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_versions_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock_layout_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_read_only_banner.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_shell.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_project_version_notice_message.dart';

/// The resources production mode: the four-tab list (people, roles, locations, elements) on the
/// left, the selected item's editable sheet in the centre, and the shared `Versions` dock tab on
/// the right.
///
/// This milestone gives only the people tab real content — creating, editing and erasing a person
/// — while the other three tabs show a shared, discreet placeholder line. While a project version
/// is being previewed, the mode shows that version's catalogue instead of the working copy's, and
/// shows it read-only: everything that would write — the `+ Add a person` button, the person
/// sheet's own fields — is withheld, and the shell carries the band naming the version.
class OcptResourcesMode extends StatelessWidget {
  /// Creates the resources mode.
  const OcptResourcesMode({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocProvider(create: (context) => OcptResourcesBloc(), child: const _ResourcesView());
}

/// The content of [OcptResourcesMode], separated from it so [OcptResourcesMode] only wires the
/// [OcptResourcesBloc] up (RFL3).
///
/// This is a StatefulWidget (the documented RFL1 exception) because it owns the dock layout
/// controller: the live dock fractions must survive a rebuild and be mutated imperatively while a
/// divider is being dragged, without emitting a bloc state per frame.
class _ResourcesView extends StatefulWidget {
  /// Class constructor
  const _ResourcesView();

  @override
  State<_ResourcesView> createState() => _ResourcesViewState();
}

/// The state of [_ResourcesView]: owns the dock layout controller and keeps it in sync with the
/// fractions the bloc persisted.
class _ResourcesViewState extends State<_ResourcesView> {
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
    // the last couple of seconds of typing in the person sheet survive it. See
    // `OcptShotListMode`'s own `deactivate()` for the same reasoning.
    unawaited(context.read<OcptResourcesBloc>().flushPendingFieldEdits());
    super.deactivate();
  }

  @override
  void dispose() {
    _dockLayoutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<OcptResourcesBloc, OcptResourcesState>(
    listener: _onStateChanged,
    builder: (context, state) {
      if (state.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }

      return OcptWorkspaceShell(
        title: state.title,
        isDirty: false,
        isReadOnly: state.isPreviewingVersion,
        onBack: () => context.read<OcptResourcesBloc>().add(const OcptResourcesBackRequestedEvent()),
        modeLabel: Tr.of(context).workspaceModeLabelResources,
        overflowEntries: _buildOverflowEntries(context),
        isLeftDockOpen: state.isListPanelVisible,
        onToggleLeftDock: () => context.read<OcptResourcesBloc>().add(
          const OcptResourcesLeftPanelToggledEvent(),
        ),
        isRightDockOpen: state.rightDockTab != null,
        onToggleRightDock: () => context.read<OcptResourcesBloc>().add(
          const OcptResourcesRightDockToggledEvent(),
        ),
        banner: _buildReadOnlyBanner(context, state),
        leftPanel: _buildListPanel(context, state),
        rightPanel: _buildRightDock(context, state),
        centre: _buildCentre(context, state),
        statusBar: OcptResourcesStatusBar(
          peopleCount: state.peopleCount,
          roleCount: state.roleCount,
          positionCount: state.positionCount,
          locationCount: state.locationCount,
          elementCount: state.elementCount,
        ),
        dockLayoutController: _dockLayoutController,
        onDockFractionsChanged: (fractions) => context.read<OcptResourcesBloc>().add(
          OcptResourcesDockFractionsChangedEvent(left: fractions.left, right: fractions.right),
        ),
      );
    },
  );

  /// Builds the mode's `⋮` overflow menu entries: only resetting the panel layout this milestone
  /// (the XLSX export follows once the four tabs all have content).
  List<PopupMenuEntry<void>> _buildOverflowEntries(BuildContext context) => [
    PopupMenuItem<void>(
      onTap: () =>
          context.read<OcptResourcesBloc>().add(const OcptResourcesDockLayoutResetEvent()),
      child: Text(Tr.of(context).resourcesResetPanelLayoutAction),
    ),
  ];

  /// Builds the left dock, the shell's `leftPanel`, or null while it's hidden.
  ///
  /// `+ Add a person` is withheld — a null `onAddPersonRequested` — while a project version is
  /// being previewed: the list is then a way of reading that version, not of changing it.
  Widget? _buildListPanel(BuildContext context, OcptResourcesState state) {
    if (!state.isListPanelVisible) {
      return null;
    }

    return OcptResourcesListPanel(
      activeTab: state.activeTab,
      people: state.people,
      selectedPersonId: state.selectedPersonId,
      onTabSelected: (tab) =>
          context.read<OcptResourcesBloc>().add(OcptResourcesTabSelectedEvent(tab: tab)),
      onPersonSelected: (personId) => context.read<OcptResourcesBloc>().add(
        OcptResourcesPersonSelectedEvent(personId: personId),
      ),
      onAddPersonRequested: state.isPreviewingVersion
          ? null
          : () => context.read<OcptResourcesBloc>().add(
              const OcptResourcesPersonCreationRequestedEvent(),
            ),
    );
  }

  /// Builds the shell's `centre`: the selected person's sheet, or the empty state while none is
  /// selected.
  // Placeholder centre — the second milestone replaces this with `OcptPersonSheet`.
  Widget _buildCentre(BuildContext context, OcptResourcesState state) {
    final selectedPerson = state.selectedPerson;
    if (selectedPerson == null) {
      return OcptWorkspaceEmptyMode(
        icon: Icons.groups_outlined,
        message: Tr.of(context).resourcesNoPersonSelectedHint,
      );
    }

    return _OcptPersonSheetPlaceholder(person: selectedPerson);
  }

  /// Builds the right dock, the shell's `rightPanel`, or null while the dock is closed.
  Widget? _buildRightDock(BuildContext context, OcptResourcesState state) {
    if (state.rightDockTab == null) {
      return null;
    }

    return OcptResourcesRightDock(
      versionsChild: _buildVersionsPanel(context, state),
      onClose: () =>
          context.read<OcptResourcesBloc>().add(const OcptResourcesRightDockClosedEvent()),
    );
  }

  /// Builds the band naming the version being previewed, the shell's `banner`, or null while the
  /// working copy is on screen.
  Widget? _buildReadOnlyBanner(BuildContext context, OcptResourcesState state) {
    final previewedVersion = state.previewedVersion;
    if (previewedVersion == null) {
      return null;
    }

    final tr = Tr.of(context);

    return OcptWorkspaceReadOnlyBanner(
      version: previewedVersion,
      onForkRequested: () => context.read<OcptResourcesBloc>().add(
        OcptProjectVersionRestoreConfirmedEvent(
          versionId: previewedVersion.id,
          safetyVersionName: tr.projectVersionRestoreSafetyName(previewedVersion.name),
        ),
      ),
      onExitPreview: () => context.read<OcptResourcesBloc>().add(
        const OcptProjectVersionPreviewExitRequestedEvent(),
      ),
    );
  }

  /// Builds the right dock's `Versions` tab: the working copy's own card and the project's named
  /// versions, the same panel every other mode's dock hosts, wired to the events
  /// `MixinOcptProjectVersionsBloc` handles.
  Widget _buildVersionsPanel(BuildContext context, OcptResourcesState state) =>
      OcptProjectVersionsPanel(
        versions: state.projectVersions,
        previewedVersionId: state.previewedVersionId,
        workingCopy: state.workingCopy,
        versionPendingDeletionId: state.versionPendingDeletionId,
        versionPendingRestoreId: state.versionPendingRestoreId,
        versionPendingRenameId: state.versionPendingRenameId,
        onCreateRequested: () => _requestVersionCreation(context),
        onPreviewRequested: (versionId) => context.read<OcptResourcesBloc>().add(
          OcptProjectVersionPreviewRequestedEvent(versionId: versionId),
        ),
        onPreviewExitRequested: () => context.read<OcptResourcesBloc>().add(
          const OcptProjectVersionPreviewExitRequestedEvent(),
        ),
        onRestoreRequested: (versionId) => context.read<OcptResourcesBloc>().add(
          OcptProjectVersionRestoreRequestedEvent(versionId: versionId),
        ),
        onRestoreCancelled: () => context.read<OcptResourcesBloc>().add(
          const OcptProjectVersionRestoreCancelledEvent(),
        ),
        onRestoreConfirmed: (version) => context.read<OcptResourcesBloc>().add(
          OcptProjectVersionRestoreConfirmedEvent(
            versionId: version.id,
            safetyVersionName: Tr.of(context).projectVersionRestoreSafetyName(version.name),
          ),
        ),
        onDeleteRequested: (versionId) => context.read<OcptResourcesBloc>().add(
          OcptProjectVersionDeletionRequestedEvent(versionId: versionId),
        ),
        onDeleteCancelled: () => context.read<OcptResourcesBloc>().add(
          const OcptProjectVersionDeletionCancelledEvent(),
        ),
        onDeleteConfirmed: (versionId) => context.read<OcptResourcesBloc>().add(
          OcptProjectVersionDeletionConfirmedEvent(versionId: versionId),
        ),
        onRenameRequested: (versionId) => context.read<OcptResourcesBloc>().add(
          OcptProjectVersionRenameRequestedEvent(versionId: versionId),
        ),
        onRenameCancelled: () => context.read<OcptResourcesBloc>().add(
          const OcptProjectVersionRenameCancelledEvent(),
        ),
        onRenameConfirmed: (versionId, name, note) => context.read<OcptResourcesBloc>().add(
          OcptProjectVersionRenameConfirmedEvent(versionId: versionId, name: name, note: note),
        ),
      );

  /// Shows the version creation dialog, then dispatches the capture if the user confirmed it.
  Future<void> _requestVersionCreation(BuildContext context) async {
    final bloc = context.read<OcptResourcesBloc>();
    final fields = await OcptProjectVersionCreateDialog.show(context);
    if (fields == null) {
      return;
    }

    bloc.add(OcptProjectVersionCreationRequestedEvent(name: fields.name, note: fields.note));
  }

  /// Applies bloc-driven effects onto the page: the live dock fractions, and the transient write
  /// error / version notice SnackBars.
  void _onStateChanged(BuildContext context, OcptResourcesState state) {
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
        ..showSnackBar(SnackBar(content: Text(Tr.of(context).resourcesWriteError)));
      context.read<OcptResourcesBloc>().add(const OcptResourcesWriteErrorDismissedEvent());
    }

    final versionNotice = state.projectVersionNotice;
    if (versionNotice != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(ocptProjectVersionNoticeMessage(context, versionNotice))),
        );
      context.read<OcptResourcesBloc>().add(const OcptProjectVersionNoticeDismissedEvent());
    }
  }
}

/// A temporary stand-in for the person sheet: the selected person's display name alone.
///
/// Replaced by `OcptPersonSheet` once the person sheet itself is built; every wire it will plug
/// into — the selection, the read-only flag, and the bloc's discrete-field and sub-list events —
/// already exists above and on `OcptResourcesBloc` itself.
/// `OcptPersonDeleteConfirmDialog` (`widgets/ocpt_person_delete_confirm_dialog.dart`) is ready for
/// the sheet's own delete action: show it, then dispatch
/// `OcptResourcesPersonDeletionRequestedEvent` if it confirms, exactly as
/// `OcptShotListMode._handleDeleteRequested` does for a shot.
class _OcptPersonSheetPlaceholder extends StatelessWidget {
  /// The person whose name is shown.
  final OcptPerson person;

  /// Class constructor
  const _OcptPersonSheetPlaceholder({required this.person});

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final name = person.displayName.isEmpty ? tr.resourcesUnnamedPerson : person.displayName;

    return Center(
      child: Text(name, style: Theme.of(context).textTheme.headlineSmall),
    );
  }
}
