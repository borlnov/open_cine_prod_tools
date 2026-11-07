// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_report.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_export_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_export_pick.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_reveal_request.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_role_origin.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_export_document.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/types/ocpt_workspace_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_package_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_elements_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_export_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_locations_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_people_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_roles_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_contact_list_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_centre.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_list_panel_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_read_only_banner.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_right_dock_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_search_toggle.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_status_bar.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_view_effects.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_version_create_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock_layout_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_shell.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_event.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_project_package_missing_files_confirm.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_project_package_notice_message.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_project_version_notice_message.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_resources_labels.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_confirm_dialog.dart';

/// The resources production mode: the four-tab list (people, roles, locations, elements) on the
/// left, the selected item's editable sheet in the centre, and the shared `Versions` dock tab on
/// the right.
///
/// All four tabs answer the same gesture: a record is picked on the left and edited in the centre,
/// through `OcptPersonSheet`, `OcptRoleSheet`, `OcptLocationSheet` and `OcptElementSheet`
/// respectively — the address book, the cast, the locations with their sets, and the catalogue of
/// everything that must be on set and is not a person.
/// While a project version is being previewed, the mode shows that version's catalogue instead of
/// the working copy's, and shows it read-only: everything that would write — the `+ Add …`
/// buttons and every field, picker and delete action of the three sheets — is withheld, and the
/// shell carries the band naming the version. The toolbar's search toggle is never one of the
/// withheld affordances: it only filters what is already on screen, so it stays available while a
/// version is being previewed too.
class OcptResourcesMode extends StatelessWidget {
  /// What this mode should open on, handed over by the mode that sent the user here — today the
  /// breakdown's `Open in Resources` — or null to open on the mode's own default.
  ///
  /// It reaches [OcptResourcesBloc] through its constructor rather than as an event, so the tab and
  /// the selection are part of the very first loaded state: the load clears every selection, and an
  /// event racing it would be applied before or after it depending on the day.
  final OcptResourcesRevealRequest? revealRequest;

  /// Create the resources mode.
  const OcptResourcesMode({super.key, this.revealRequest});

  /// Build the resources mode as a [MultiBlocProvider].
  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (context) => OcptResourcesBloc(
          revealRequest: revealRequest,
          selectedEpisodeId: context.read<OcptWorkspaceBloc>().state.selectedEpisodeId,
        ),
      ),
      // Built with the mode rather than on first read: a view bloc registers itself with the mode
      // bloc when it is built, and one that is not there yet cannot be asked to write what it
      // holds.
      BlocProvider(
        lazy: false,
        create: (context) => OcptResourcesExportBloc(modeBloc: context.read<OcptResourcesBloc>()),
      ),
      BlocProvider(
        lazy: false,
        create: (context) => OcptResourcesPeopleBloc(modeBloc: context.read<OcptResourcesBloc>()),
      ),
      BlocProvider(
        lazy: false,
        create: (context) => OcptResourcesRolesBloc(modeBloc: context.read<OcptResourcesBloc>()),
      ),
      BlocProvider(
        lazy: false,
        create: (context) =>
            OcptResourcesLocationsBloc(modeBloc: context.read<OcptResourcesBloc>()),
      ),
      BlocProvider(
        lazy: false,
        create: (context) => OcptResourcesElementsBloc(modeBloc: context.read<OcptResourcesBloc>()),
      ),
    ],
    child: OcptResourcesViewEffects(child: _ResourcesView(hasRevealRequest: revealRequest != null)),
  );
}

/// The content of [OcptResourcesMode], separated from it so [OcptResourcesMode] only wires the
/// [OcptResourcesBloc] up.
///
/// This is a StatefulWidget (the documented exception) because it owns the dock layout
/// controller: the live dock fractions must survive a rebuild and be mutated imperatively while a
/// divider is being dragged, without emitting a bloc state per frame.
class _ResourcesView extends StatefulWidget {
  /// Whether the bloc this view was mounted with was handed a reveal request, and the workspace
  /// therefore still holds one to clear.
  final bool hasRevealRequest;

  /// Class constructor
  const _ResourcesView({required this.hasRevealRequest});

  /// Create the [_ResourcesViewState] holding the state of the resources view.
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

  /// Tell the workspace that a reveal request was taken into account, so it applies only once.
  @override
  void initState() {
    super.initState();

    if (widget.hasRevealRequest) {
      // The bloc already has the request — it was handed it at construction, above — so all that
      // is left is telling the workspace it has been taken into account. That is what makes a
      // reveal one-shot: coming back to this mode later rebuilds it with no request at all, and it
      // opens on its own default. Dispatched here rather than during the build that reads it,
      // since emitting a state while the tree is being built is not allowed.
      context.read<OcptWorkspaceBloc>().add(const OcptWorkspaceRevealRequestConsumedEvent());
    }
  }

  /// Flush the pending field edits of the bloc before the view leaves the tree.
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

  /// Build the resources view as a [BlocConsumer].
  @override
  @override
  Widget build(BuildContext context) => BlocConsumer<OcptResourcesBloc, OcptResourcesState>(
    listener: _onStateChanged,
    builder: (context, state) {
      if (state.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }

      final workspaceState = context.watch<OcptWorkspaceBloc>().state;
      final previewedVersion = state.previewedVersion;

      return OcptWorkspaceShell(
        title: state.title,
        isDirty: false,
        isReadOnly: state.isPreviewingVersion,
        onBack: () =>
            context.read<OcptResourcesBloc>().add(const OcptResourcesBackRequestedEvent()),
        episodes: workspaceState.episodes,
        selectedEpisodeId: workspaceState.selectedEpisodeId,
        onEpisodeSelected: (episodeId) => context.read<OcptWorkspaceBloc>().add(
          OcptWorkspaceEpisodeSelectedEvent(episodeId: episodeId),
        ),
        modeLabel: Tr.of(context).workspaceModeLabelResources,
        toolbarActions: [OcptResourcesSearchToggle(isSearchVisible: state.isSearchVisible)],
        onExportRequested: (anchor) => unawaited(_requestExport(context, state, anchor)),
        // The mode's `⋮` overflow menu: resetting the panel layout, alone — the exports are the
        // toolbar's own `Export` button and its panel (see [_requestExport]). A `⋮` holding one
        // entry is thin, but honest: moving it somewhere else is a separate question.
        overflowEntries: [
          PopupMenuItem<void>(
            onTap: () =>
                context.read<OcptResourcesBloc>().add(const OcptResourcesDockLayoutResetEvent()),
            child: Text(Tr.of(context).resourcesResetPanelLayoutAction),
          ),
        ],
        isLeftDockOpen: state.isListPanelVisible,
        onToggleLeftDock: () =>
            context.read<OcptResourcesBloc>().add(const OcptResourcesLeftPanelToggledEvent()),
        isRightDockOpen: state.rightDockTab != null,
        onToggleRightDock: () =>
            context.read<OcptResourcesBloc>().add(const OcptResourcesRightDockToggledEvent()),
        onProjectSettingsRequested: state.isPreviewingVersion
            ? null
            : () => _requestProjectSettings(context),
        banner: previewedVersion == null
            ? null
            : OcptResourcesReadOnlyBanner(previewedVersion: previewedVersion),
        leftPanel: state.isListPanelVisible
            ? OcptResourcesListPanelView(state: state, episodes: workspaceState.episodes)
            : null,
        rightPanel: state.rightDockTab == null
            ? null
            : OcptResourcesRightDockView(
                state: state,
                onVersionCreationRequested: () => unawaited(_requestVersionCreation(context)),
              ),
        centre: OcptResourcesCentre(
          state: state,
          episodes: workspaceState.episodes,
          onPersonDeleteRequested: () => unawaited(_handlePersonDeleteRequested(context, state)),
          onRoleDeleteRequested: () => unawaited(_handleRoleDeleteRequested(context, state)),
          onCandidateRemoveRequested: (candidateId) =>
              unawaited(_handleCandidateRemoveRequested(context, candidateId)),
          onRoleMergeRequested: (sourceRoleId, targetRoleId) =>
              unawaited(_handleRoleMergeRequested(context, state, sourceRoleId, targetRoleId)),
          onLocationDeleteRequested: () =>
              unawaited(_handleLocationDeleteRequested(context, state)),
          onElementDeleteRequested: () => unawaited(_handleElementDeleteRequested(context, state)),
        ),
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

  /// Build the two entries the toolbar's `Export` button offers: the resources workbook,
  /// unavailable while the whole catalogue is empty — there would be nothing in any of its four
  /// sheets but their header row — and the contact list, unavailable while nobody in the address
  /// book holds a position and no role is cast either — there would be no line to print.
  List<OcptWorkspaceExportEntry<OcptResourcesExportDocument>> _exportEntriesOf(
    BuildContext context,
    OcptResourcesState state,
  ) {
    final tr = Tr.of(context);
    final isCatalogueEmpty =
        state.peopleCount + state.roleCount + state.locationCount + state.elementCount == 0;
    final hasNoContact = state.positionCount == 0 && state.roleCount == 0;

    return [
      OcptWorkspaceExportEntry<OcptResourcesExportDocument>(
        value: OcptResourcesExportDocument.xlsx,
        title: tr.resourcesExportXlsxTitle,
        description: tr.resourcesExportXlsxDescription,
        formatLabel: "XLSX",
        unavailableReason: isCatalogueEmpty ? tr.resourcesExportUnavailableReason : null,
      ),
      OcptWorkspaceExportEntry<OcptResourcesExportDocument>(
        value: OcptResourcesExportDocument.contactList,
        title: tr.resourcesExportContactListTitle,
        description: tr.resourcesExportContactListDescription,
        formatLabel: "PDF",
        unavailableReason: hasNoContact ? tr.resourcesExportContactListUnavailableReason : null,
      ),
    ];
  }

  /// Open the export panel, then dispatch the picked document's own export request: the
  /// contact list opens its own options dialog first, through [_requestContactListExport], while
  /// the workbook goes straight from [_requestXlsxExport] to the bloc — it takes no options dialog
  /// at all.
  Future<void> _requestExport(
    BuildContext context,
    OcptResourcesState state,
    Rect? shareAnchor,
  ) async {
    final tr = Tr.of(context);
    final picked = await OcptWorkspaceExportDialog.show<OcptResourcesExportDocument>(
      context,
      title: tr.resourcesExportPanelTitle,
      message: tr.resourcesExportPanelMessage,
      entries: _exportEntriesOf(context, state),
      isPreviewingVersion: state.isPreviewingVersion,
    );
    if (picked == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    switch (picked) {
      case OcptWorkspaceExportDocumentPick<OcptResourcesExportDocument>(:final document):
        switch (document) {
          case OcptResourcesExportDocument.xlsx:
            _requestXlsxExport(context, state, shareAnchor);
          case OcptResourcesExportDocument.contactList:
            await _requestContactListExport(context, state, shareAnchor);
        }
      case OcptWorkspaceExportProjectPackagePick<OcptResourcesExportDocument>():
        _requestProjectPackageExport(context);
    }
  }

  /// Dispatch the XLSX export request, resolving here — the last place with a [BuildContext] —
  /// every localized string the four sheets and the native save dialog carry.
  void _requestXlsxExport(BuildContext context, OcptResourcesState state, Rect? shareAnchor) {
    final tr = Tr.of(context);

    context.read<OcptResourcesExportBloc>().add(
      OcptResourcesXlsxExportRequestedEvent(
        labels: ocptResourcesXlsxLabelsOf(context, state.scenes, currencyCode: state.currencyCode),
        fileTypeLabel: tr.resourcesExportXlsxFileTypeLabel,
        shareAnchor: shareAnchor,
      ),
    );
  }

  /// Show the contact list export options dialog — this document's own first, offering the page
  /// format alone — then dispatch the export request if the user applied it, resolving here every
  /// localized string the exported document and the native save dialog carry.
  Future<void> _requestContactListExport(
    BuildContext context,
    OcptResourcesState state,
    Rect? shareAnchor,
  ) async {
    final bloc = context.read<OcptResourcesExportBloc>();
    final options = await OcptContactListExportDialog.show(context, current: state.pageSetup);
    if (options == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    final tr = Tr.of(context);
    bloc.add(
      OcptResourcesContactListExportRequestedEvent(
        options: options,
        labels: ocptContactListLabelsOf(context),
        fileTypeLabel: tr.resourcesExportContactListFileTypeLabel,
        shareAnchor: shareAnchor,
      ),
    );
  }

  /// Open the project settings page, then reload the resources snapshot if the user changed
  /// anything there.
  ///
  /// Also tells `OcptWorkspaceBloc` to reload its episodes: the settings page's own `Episodes`
  /// card can add or delete one, which the workspace bloc otherwise only learns about from
  /// `OcptProjectsManager.currentProjectStream`, an event the episode CRUD does not fire.
  Future<void> _requestProjectSettings(BuildContext context) async {
    final bloc = context.read<OcptResourcesBloc>();
    final workspaceBloc = context.read<OcptWorkspaceBloc>();
    final hasChanged = await globalGetIt().get<OcptRouterManager>().push<bool>(
      OcptRoute.projectSettings,
    );
    if (hasChanged != true) {
      return;
    }

    bloc.add(const OcptResourcesProjectSettingsChangedEvent());
    workspaceBloc.add(const OcptWorkspaceEpisodesReloadRequestedEvent());
  }

  /// Ask [OcptConfirmDialog] the question [title] states, then dispatch [event] to [bloc] if the
  /// user answered `Delete`.
  ///
  /// The four tabs share this one path, so a record is deleted the same way whichever it belongs
  /// to — the way `OcptShotListMode._handleDeleteRequested` already asks it. Only the wording
  /// differs, and it is the caller's.
  Future<void> _handleDeleteRequested(
    BuildContext context, {
    required Bloc<BlocEventForMixin, Object?> bloc,
    required String title,
    required String message,
    required OcptResourcesEvent event,
  }) async {
    final tr = Tr.of(context);

    final confirmed = await OcptConfirmDialog.show(
      context,
      title: title,
      message: message,
      cancelLabel: tr.resourcesDeleteConfirmCancelAction,
      confirmLabel: tr.resourcesDeleteConfirmDeleteAction,
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(event);
  }

  /// Confirm and dispatch the deletion of the selected person of [state].
  Future<void> _handlePersonDeleteRequested(BuildContext context, OcptResourcesState state) async {
    final selectedPerson = state.selectedPerson;
    if (selectedPerson == null) {
      return;
    }

    final tr = Tr.of(context);

    await _handleDeleteRequested(
      context,
      bloc: context.read<OcptResourcesPeopleBloc>(),
      title: tr.resourcesDeleteConfirmTitle,
      message: tr.resourcesDeleteConfirmMessage(
        selectedPerson.displayName.isEmpty ? tr.resourcesUnnamedPerson : selectedPerson.displayName,
      ),
      event: OcptResourcesPersonDeletionRequestedEvent(personId: selectedPerson.id),
    );
  }

  /// Confirm and dispatch the deletion of the selected role of [state].
  Future<void> _handleRoleDeleteRequested(BuildContext context, OcptResourcesState state) async {
    final selectedRole = state.selectedRole;
    if (selectedRole == null) {
      return;
    }

    final tr = Tr.of(context);

    await _handleDeleteRequested(
      context,
      bloc: context.read<OcptResourcesRolesBloc>(),
      title: tr.resourcesRoleDeleteConfirmTitle,
      message:
          ocptRoleIsActionDetected(
            isFromScreenplay: selectedRole.isFromScreenplay,
            kind: selectedRole.kind,
          )
          ? tr.resourcesRoleActionDetectedDeleteConfirmMessage
          : tr.resourcesRoleDeleteConfirmMessage,
      event: OcptResourcesRoleDeletionRequestedEvent(roleId: selectedRole.id),
    );
  }

  /// Confirm and dispatch the removal of the candidacy [candidateId] from its role.
  Future<void> _handleCandidateRemoveRequested(BuildContext context, String candidateId) async {
    final tr = Tr.of(context);

    await _handleDeleteRequested(
      context,
      bloc: context.read<OcptResourcesRolesBloc>(),
      title: tr.resourcesRemoveCandidateConfirmTitle,
      message: tr.resourcesRemoveCandidateConfirmMessage,
      event: OcptResourcesRoleCandidateRemovedEvent(candidateId: candidateId),
    );
  }

  /// Confirm and dispatch the deletion of the selected location of [state].
  Future<void> _handleLocationDeleteRequested(
    BuildContext context,
    OcptResourcesState state,
  ) async {
    final selectedLocation = state.selectedLocation;
    if (selectedLocation == null) {
      return;
    }

    final tr = Tr.of(context);

    await _handleDeleteRequested(
      context,
      bloc: context.read<OcptResourcesLocationsBloc>(),
      title: tr.resourcesLocationDeleteConfirmTitle,
      message: tr.resourcesLocationDeleteConfirmMessage,
      event: OcptResourcesLocationDeletionRequestedEvent(locationId: selectedLocation.id),
    );
  }

  /// Confirm and dispatch the deletion of the selected element of [state].
  Future<void> _handleElementDeleteRequested(BuildContext context, OcptResourcesState state) async {
    final selectedElement = state.selectedElement;
    if (selectedElement == null) {
      return;
    }

    final tr = Tr.of(context);

    await _handleDeleteRequested(
      context,
      bloc: context.read<OcptResourcesElementsBloc>(),
      title: tr.resourcesElementDeleteConfirmTitle,
      message: tr.resourcesDeleteElementConfirm,
      event: OcptResourcesElementDeletionRequestedEvent(elementId: selectedElement.id),
    );
  }

  /// Get the display name of role [roleId] among [state]'s whole cast, or [roleId] itself as a last
  /// resort — the role merge confirmation names both roles, and a role gone from the cast between
  /// the click and the dialog opening is the only way this fallback is ever seen.
  String _roleNameOf(OcptResourcesState state, String roleId) =>
      state.roles.firstWhereOrNull((role) => role.id == roleId)?.name ?? roleId;

  /// Show the merge confirmation dialog, naming both roles, then dispatch the merge if the user
  /// confirmed it — the shared role alert banner's merge affordance, either variant.
  Future<void> _handleRoleMergeRequested(
    BuildContext context,
    OcptResourcesState state,
    String sourceRoleId,
    String targetRoleId,
  ) async {
    final tr = Tr.of(context);
    final confirmed = await OcptConfirmDialog.show(
      context,
      title: tr.roleAlertMergeConfirmTitle,
      message: tr.roleAlertMergeConfirmMessage(
        _roleNameOf(state, sourceRoleId),
        _roleNameOf(state, targetRoleId),
      ),
      cancelLabel: tr.resourcesDeleteConfirmCancelAction,
      confirmLabel: tr.roleAlertMergeConfirmAction,
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    context.read<OcptResourcesRolesBloc>().add(
      OcptResourcesRoleMergeRequestedEvent(sourceRoleId: sourceRoleId, targetRoleId: targetRoleId),
    );
  }

  /// Show the version creation dialog, then dispatch the capture if the user confirmed it.
  Future<void> _requestVersionCreation(BuildContext context) async {
    final bloc = context.read<OcptResourcesBloc>();
    final fields = await OcptProjectVersionCreateDialog.show(context);
    if (fields == null) {
      return;
    }

    bloc.add(OcptProjectVersionCreationRequestedEvent(name: fields.name, note: fields.note));
  }

  /// Apply bloc-driven effects onto the page: the live dock fractions, and the transient write
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

    final pendingShotListReveal = state.pendingShotListReveal;
    if (pendingShotListReveal != null) {
      context.read<OcptResourcesBloc>().add(const OcptResourcesShotListRevealDismissedEvent());
      context.read<OcptWorkspaceBloc>().add(
        OcptWorkspaceModeSelectedEvent(
          mode: OcptWorkspaceMode.shotList,
          episodeId: pendingShotListReveal.episodeId,
          revealRequest: OcptShotListRevealRequest(
            sceneId: pendingShotListReveal.sceneId,
            setId: pendingShotListReveal.setId,
          ),
        ),
      );
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

    final packagePendingExport = state.projectPackagePendingExport;
    if (packagePendingExport != null) {
      context.read<OcptResourcesBloc>().add(
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
      context.read<OcptResourcesBloc>().add(const OcptProjectPackageNoticeDismissedEvent());
    }
  }

  /// Dispatch the project package export, resolving here — the last place with a
  /// [BuildContext] — the label the native save dialog carries.
  ///
  /// What happens next depends on what the project references: everything being there, the save
  /// dialog opens straight away; anything missing, the bloc asks back through its own state and
  /// [_askAboutMissingPackagedFiles] is what puts that question on screen.
  void _requestProjectPackageExport(BuildContext context) {
    context.read<OcptResourcesBloc>().add(
      OcptProjectPackageExportRequestedEvent(
        fileTypeLabel: Tr.of(context).projectPackageFileTypeLabel,
      ),
    );
  }

  /// {@macro open_cine_prod_tools.packageMissingFilesDialogFlow}
  Future<void> _askAboutMissingPackagedFiles(
    BuildContext context,
    OcptProjectPackagePreflight preflight,
  ) async {
    final bloc = context.read<OcptResourcesBloc>();
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
