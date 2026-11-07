// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_report.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_export_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_export_pick.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_export_document.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_package_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_export_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_inspector_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_tagging_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_centre.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_left_dock_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_read_only_banner.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_right_dock_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_sheets_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_status_bar.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_target_inspector.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_view_effects.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_version_create_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock_layout_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_shell.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_event.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_breakdown_labels.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_project_package_missing_files_confirm.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_project_package_notice_message.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_project_version_notice_message.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_workspace_episode_export_tag.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_confirm_dialog.dart';

/// The breakdown production mode (dépouillement du scénario): the scene list and, under it, the
/// category legend on the left, the mode's own header band and, under it, either the whole
/// screenplay typeset as a paper sheet or the recap cross-table in the centre, and the
/// `Inspector`/`Versions` right dock.
///
/// The centre is `OcptBreakdownHeader` above an `Expanded` showing whichever of
/// `OcptBreakdownScriptView`/`OcptBreakdownRecapTable` `OcptBreakdownState.centreView` currently
/// names — the header's own `Script`/`Recap` switch is what moves between the two, and its search
/// field, visible in both, filters the recap's rows and switches to it the moment the script view
/// is active and the field turns non-empty (`OcptBreakdownBloc._onSearchQueryChanged`'s own doc
/// comment): the script view is a reading surface, and the answer to "where is this?" is the table.
///
/// The script view lets every word be clicked — a tagged one selects its target, and selecting a
/// target opens the right dock on its `Inspector` tab, where `OcptBreakdownTargetInspector` shows
/// its sheet; selecting a scene with no target selected shows that scene's own breakdown sheet
/// instead, `OcptBreakdownSceneInspector`. Any other word drives the range interaction: a first
/// click opens an anchor, a second one in the same scene closes it and opens
/// `OcptBreakdownTagPopover`, which links the passage to an existing target or creates a new
/// element and tags it in one click — either way landing the selection on it, on the `Inspector`
/// tab, exactly as clicking an already-tagged word does. The recap's own rows land the very same
/// selection: clicking one dispatches the same event a tagged word's click does, passing the
/// target's own first scene id, so the left dock and the sheet stay in step without leaving the
/// recap. There is **no save control and no mode-specific toolbar action** — the shell simply isn't
/// handed one, rather than showing an inert one — since every write here (the popover's own links
/// and creations, the target inspector's chips, pickers, fields and suggested-occurrence
/// acceptances, the tag removal, and the scene inspector's own status chips) is written by its own
/// event rather than a single save; the target inspector's three free-text fields and the scene
/// inspector's own breakdown notes still autosave on the 2 s debounce every field like it does
/// elsewhere in the app.
///
/// While a project version is being previewed, the mode shows that version's own read instead of
/// the working copy's, and carries the shell's read-only banner naming it, exactly as the resources
/// and shot list modes do; the range interaction is withheld outright (`OcptBreakdownCentre`'s
/// script view), and both inspectors withhold every control that writes (see
/// [OcptBreakdownTargetInspector]'s and `OcptBreakdownSceneInspector`'s own doc comments) while
/// leaving both fully readable. The header and the recap table need no such gating at all: the view
/// switch, the search field and a recap row's click only ever read, so nothing here withholds
/// anything from a previewed version — see their own doc comments.
class OcptBreakdownMode extends StatelessWidget {
  /// Create the breakdown mode.
  const OcptBreakdownMode({super.key});

  /// Build the breakdown mode as a [MultiBlocProvider].
  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (context) => OcptBreakdownBloc(
          selectedEpisodeId: context.read<OcptWorkspaceBloc>().state.selectedEpisodeId,
        ),
      ),
      // Built with the mode rather than on first read: a view bloc registers itself with the mode
      // bloc when it is built, and one that is not there yet cannot be asked to write what it
      // holds.
      BlocProvider(
        lazy: false,
        create: (context) => OcptBreakdownExportBloc(modeBloc: context.read<OcptBreakdownBloc>()),
      ),
      BlocProvider(
        lazy: false,
        create: (context) =>
            OcptBreakdownInspectorBloc(modeBloc: context.read<OcptBreakdownBloc>()),
      ),
      BlocProvider(
        lazy: false,
        create: (context) => OcptBreakdownTaggingBloc(modeBloc: context.read<OcptBreakdownBloc>()),
      ),
    ],
    child: const OcptBreakdownViewEffects(child: _BreakdownView()),
  );
}

/// The content of [OcptBreakdownMode], separated from it so [OcptBreakdownMode] only wires the
/// [OcptBreakdownBloc] up.
///
/// This is a StatefulWidget (the documented exception) because it owns the dock layout
/// controller: the live dock fractions must survive a rebuild and be mutated imperatively while a
/// divider is being dragged, without emitting a bloc state per frame. Mirrors
/// `_ResourcesView`/`_ShotListView`.
class _BreakdownView extends StatefulWidget {
  /// Class constructor
  const _BreakdownView();

  /// Create the [_BreakdownViewState] holding the state of the breakdown view.
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

  /// Flush the pending field edits of the bloc before the view leaves the tree.
  @override
  void deactivate() {
    // `deactivate()` runs before `dispose()` for every removal from the tree (a mode switch swaps
    // this whole subtree out; going back to the projects flushes in the bloc, before the project
    // is closed, since this one would find it closed), so triggering the
    // flush here — rather than dispatching an event, which would only be processed on a later
    // microtask this widget might not survive to see — is what guarantees the last debounce worth
    // of typing into the target inspector's or the scene inspector's own fields isn't lost. Mirrors
    // `OcptShotListMode`'s/`OcptResourcesMode`'s own `deactivate()`.
    unawaited(context.read<OcptBreakdownBloc>().flushPendingFieldEdits());
    super.deactivate();
  }

  /// Build the breakdown view as a [BlocConsumer].
  @override
  Widget build(BuildContext context) => BlocConsumer<OcptBreakdownBloc, OcptBreakdownState>(
    listener: _onStateChanged,
    builder: (context, state) {
      if (state.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }

      final workspaceState = context.watch<OcptWorkspaceBloc>().state;
      final previewedVersion = state.previewedVersion;
      final rightDockTab = state.rightDockTab;

      return OcptWorkspaceShell(
        title: state.title,
        isDirty: false,
        isReadOnly: state.isPreviewingVersion,
        onBack: () =>
            context.read<OcptBreakdownBloc>().add(const OcptBreakdownBackRequestedEvent()),
        episodes: workspaceState.episodes,
        selectedEpisodeId: workspaceState.selectedEpisodeId,
        onEpisodeSelected: (episodeId) => context.read<OcptWorkspaceBloc>().add(
          OcptWorkspaceEpisodeSelectedEvent(episodeId: episodeId),
        ),
        modeLabel: Tr.of(context).workspaceModeLabelBreakdown,
        onExportRequested: (anchor) => unawaited(_requestExport(context, state, anchor)),
        overflowEntries: _overflowEntriesOf(context),
        isLeftDockOpen: state.isListPanelVisible,
        onToggleLeftDock: () =>
            context.read<OcptBreakdownBloc>().add(const OcptBreakdownLeftPanelToggledEvent()),
        isRightDockOpen: state.rightDockTab != null,
        onToggleRightDock: () =>
            context.read<OcptBreakdownBloc>().add(const OcptBreakdownRightDockToggledEvent()),
        onProjectSettingsRequested: state.isPreviewingVersion
            ? null
            : () => _requestProjectSettings(context),
        banner: previewedVersion == null
            ? null
            : OcptBreakdownReadOnlyBanner(previewedVersion: previewedVersion),
        leftPanel: state.isListPanelVisible ? OcptBreakdownLeftDockView(state: state) : null,
        rightPanel: rightDockTab == null
            ? null
            : OcptBreakdownRightDockView(
                state: state,
                activeTab: rightDockTab,
                onTagRemovalRequested: () => unawaited(_handleTagRemovalRequested(context)),
                onVersionCreationRequested: () => unawaited(_requestVersionCreation(context)),
              ),
        centre: OcptBreakdownCentre(state: state),
        statusBar: OcptBreakdownStatusBar(
          taggedTargetCount: state.taggedTargetCount,
          usedCategoryCount: state.usedCategoryCount,
          toFindCount: state.toFindCount,
          needsCheckTagCount: state.needsCheckTagCount,
        ),
        dockLayoutController: _dockLayoutController,
        onDockFractionsChanged: (fractions) => context.read<OcptBreakdownBloc>().add(
          OcptBreakdownDockFractionsChangedEvent(left: fractions.left, right: fractions.right),
        ),
      );
    },
  );

  /// Build the mode's `⋮` overflow menu entries: resetting the panel layout, alone — the
  /// breakdown sheets export moved to the toolbar's own `Export` button and its panel (see
  /// [_requestExport]), and this is the only entry the breakdown mode has left to offer. A `⋮`
  /// holding one entry is thin, but honest: moving it somewhere else is a separate question this
  /// doesn't answer.
  List<PopupMenuEntry<void>> _overflowEntriesOf(BuildContext context) => [
    PopupMenuItem<void>(
      onTap: () => context.read<OcptBreakdownBloc>().add(const OcptBreakdownDockLayoutResetEvent()),
      child: Text(Tr.of(context).breakdownResetPanelLayoutAction),
    ),
  ];

  /// Build the two entries the toolbar's `Export` button offers: the breakdown sheets and the
  /// breakdown workbook, both unavailable while the screenplay holds no scene at all — there would
  /// be nothing to print a sheet for, or a row to write into a workbook.
  List<OcptWorkspaceExportEntry<OcptBreakdownExportDocument>> _exportEntriesOf(
    BuildContext context,
    OcptBreakdownState state,
  ) {
    final tr = Tr.of(context);
    final unavailableReason = state.scenes.isEmpty ? tr.breakdownExportUnavailableReason : null;

    return [
      OcptWorkspaceExportEntry<OcptBreakdownExportDocument>(
        value: OcptBreakdownExportDocument.sheets,
        title: tr.breakdownExportSheetsTitle,
        description: tr.breakdownExportSheetsDescription,
        formatLabel: "PDF",
        unavailableReason: unavailableReason,
      ),
      OcptWorkspaceExportEntry<OcptBreakdownExportDocument>(
        value: OcptBreakdownExportDocument.xlsx,
        title: tr.breakdownExportXlsxTitle,
        description: tr.breakdownExportXlsxDescription,
        formatLabel: "XLSX",
        unavailableReason: unavailableReason,
      ),
    ];
  }

  /// Open the export panel, then dispatch the picked document's own export request: the
  /// breakdown sheets go through [_requestSheetsExport], which opens their own options dialog
  /// first, while the workbook goes straight from [_requestXlsxExport] to the bloc — it takes no
  /// options dialog at all.
  Future<void> _requestExport(
    BuildContext context,
    OcptBreakdownState state,
    Rect? shareAnchor,
  ) async {
    final tr = Tr.of(context);
    final picked = await OcptWorkspaceExportDialog.show<OcptBreakdownExportDocument>(
      context,
      title: tr.breakdownExportPanelTitle,
      message: tr.breakdownExportPanelMessage,
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
      case OcptWorkspaceExportDocumentPick<OcptBreakdownExportDocument>(:final document):
        switch (document) {
          case OcptBreakdownExportDocument.sheets:
            await _requestSheetsExport(context, state, shareAnchor);
          case OcptBreakdownExportDocument.xlsx:
            _requestXlsxExport(context, shareAnchor);
        }
      case OcptWorkspaceExportProjectPackagePick<OcptBreakdownExportDocument>():
        _requestProjectPackageExport(context);
    }
  }

  /// Show the breakdown sheets export options dialog, then dispatch the export request if the
  /// user applied it, resolving here — the last place with a [BuildContext] — every localized
  /// string the exported document and the native save dialog carry.
  Future<void> _requestSheetsExport(
    BuildContext context,
    OcptBreakdownState state,
    Rect? shareAnchor,
  ) async {
    final bloc = context.read<OcptBreakdownExportBloc>();
    final options = await OcptBreakdownSheetsExportDialog.show(context, current: state.pageSetup);
    if (options == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    final tr = Tr.of(context);
    bloc.add(
      OcptBreakdownSheetsExportRequestedEvent(
        options: options,
        labels: ocptBreakdownSheetsLabelsOf(tr, state.scenes),
        fileTypeLabel: tr.breakdownExportSheetsFileTypeLabel,
        episodeTag: _episodeExportTag(context),
        shareAnchor: shareAnchor,
      ),
    );
  }

  /// Dispatch the breakdown workbook export request straight away — resolving here every
  /// localized string the exported document and the native save dialog carry, exactly as
  /// [_requestSheetsExport] does, but with no options dialog first: the workbook takes none.
  void _requestXlsxExport(BuildContext context, Rect? shareAnchor) {
    final bloc = context.read<OcptBreakdownExportBloc>();
    final tr = Tr.of(context);
    bloc.add(
      OcptBreakdownXlsxExportRequestedEvent(
        labels: ocptBreakdownXlsxLabelsOf(tr),
        fileTypeLabel: tr.breakdownExportXlsxFileTypeLabel,
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

  /// Ask [OcptConfirmDialog] whether the selected target's tags really are to leave the selected
  /// scene, then dispatch the removal if the user answered `Remove`.
  ///
  /// A dialog rather than an inline yes/no, the way `OcptShotListMode._handleDeleteRequested` and
  /// `OcptResourcesMode._handleDeleteRequested` already ask their own question: removing a tag
  /// cannot be undone, and an irreversible action is answered the same way everywhere in the app.
  Future<void> _handleTagRemovalRequested(BuildContext context) async {
    final inspectorBloc = context.read<OcptBreakdownInspectorBloc>();
    final tr = Tr.of(context);

    final confirmed = await OcptConfirmDialog.show(
      context,
      title: tr.breakdownRemoveFromBreakdownConfirmTitle,
      message: tr.breakdownRemoveFromBreakdownConfirmMessage,
      cancelLabel: tr.breakdownRemoveFromBreakdownCancelAction,
      confirmLabel: tr.breakdownRemoveFromBreakdownConfirmAction,
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    inspectorBloc.add(const OcptBreakdownTagRemovalConfirmedEvent());
  }

  /// Open the project settings page, then reload the mode's own read if the user changed
  /// anything there.
  ///
  /// Also tells `OcptWorkspaceBloc` to reload its episodes: the settings page's own `Episodes`
  /// card can add or delete one, which the workspace bloc otherwise only learns about from
  /// `OcptProjectsManager.currentProjectStream`, an event the episode CRUD does not fire.
  Future<void> _requestProjectSettings(BuildContext context) async {
    final bloc = context.read<OcptBreakdownBloc>();
    final workspaceBloc = context.read<OcptWorkspaceBloc>();
    final hasChanged = await globalGetIt().get<OcptRouterManager>().push<bool>(
      OcptRoute.projectSettings,
    );
    if (hasChanged != true) {
      return;
    }

    bloc.add(const OcptBreakdownProjectSettingsChangedEvent());
    workspaceBloc.add(const OcptWorkspaceEpisodesReloadRequestedEvent());
  }

  /// Show the version creation dialog, then dispatch the capture if the user confirmed it.
  Future<void> _requestVersionCreation(BuildContext context) async {
    final bloc = context.read<OcptBreakdownBloc>();
    final fields = await OcptProjectVersionCreateDialog.show(context);
    if (fields == null) {
      return;
    }

    bloc.add(OcptProjectVersionCreationRequestedEvent(name: fields.name, note: fields.note));
  }

  /// Apply bloc-driven effects onto the page: the live dock fractions, and the transient version
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

    final packagePendingExport = state.projectPackagePendingExport;
    if (packagePendingExport != null) {
      context.read<OcptBreakdownBloc>().add(
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
      context.read<OcptBreakdownBloc>().add(const OcptProjectPackageNoticeDismissedEvent());
    }
  }

  /// Dispatch the project package export, resolving here — the last place with a
  /// [BuildContext] — the label the native save dialog carries.
  ///
  /// What happens next depends on what the project references: everything being there, the save
  /// dialog opens straight away; anything missing, the bloc asks back through its own state and
  /// [_askAboutMissingPackagedFiles] is what puts that question on screen.
  void _requestProjectPackageExport(BuildContext context) {
    context.read<OcptBreakdownBloc>().add(
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
    final bloc = context.read<OcptBreakdownBloc>();
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
