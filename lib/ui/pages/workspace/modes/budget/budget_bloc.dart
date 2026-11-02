// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/logging/ocpt_logs_helper_builder.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_account_seed.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_selection.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_selection_cause.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_mode_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_package_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_versions_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_snapshot_loader.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';

/// This is the bloc class for the budget production mode: its **mode bloc**.
///
/// It reads the current project's whole budget through [_loader] on entry (the quote, seeding the
/// ten CNC postes on the first read of an empty table; the cash journal; the financing plan; the
/// revenue sharing; the catering-and-travel pass and the catalogues it is joined with; and the
/// project's currency, default VAT rate and prices), and owns that data, the page setup, the shared
/// selection (the selected row, the filtered poste, the highlighted share, the poste the logistics
/// provisions into, the expanded nodes), the chrome (the central view, the tools page, the
/// simplified and tax-basis switches, the right dock) and the transient write error of none of
/// them.
///
/// Everything a view writes belongs to that view's bloc — `OcptBudgetExpensesBloc`,
/// `OcptBudgetCashJournalBloc`, `OcptBudgetFinancingBloc` and `OcptBudgetSharingBloc` — which
/// writes through the services and asks this bloc to read the snapshot again ([reload]) before it
/// selects or forgets anything; `OcptBudgetExportBloc` owns the four exports. A view selects the
/// record it has just created through [OcptBudgetSelectionCreatedEvent] and
/// [OcptBudgetShareCreatedEvent].
///
/// **Every read of the snapshot reconciles the shared selection** ([_readBudgetSnapshot]): a
/// selected row, a filtered poste or a highlighted share that the fresh snapshot no longer holds is
/// dropped in the very state that carries the snapshot, and the selection epoch moves with
/// [OcptBudgetSelectionCause.reconciled]. While the `Versions` tab is open, the working-copy card
/// is refreshed once the data has landed, the mode's stand-in for "a save landing while it is
/// open".
///
/// **A failed write is not caught anywhere in this mode.** The view whose write failed keeps its
/// edit pending, and the action the flush was for does not happen: [flushAllPendingWritesIn] and
/// [flushPendingProjectWrites] answer false, and the handler stops. Which actions flush is the old
/// handlers' own list: a dock tab change, a view, a tools page, the simplified and tax-basis
/// switches, the selection of a poste, a line, a commitment or an entry, the poste filter, an
/// export, a version preview, a restore, a saved version and a package export. The selection of a
/// receipt, a resource, a taking or a share, going back, creating a record and the project
/// settings do not.
///
/// **[_loader] holds the seed, captured once, rather than watched.** No bloc or service may ever
/// see a `Tr` (`AGENTS.md`), so `OcptBudgetMode` resolves `ocptBudgetCncPosteSeeds(Tr.of(context))`
/// and hands the list in when it creates this bloc; a preview or a restore reuses the very list
/// rather than re-resolving it, since it swaps the database, not the app's own locale.
///
/// **There is no episode selector.** One budget serves the whole production (ADR 0019): the
/// catalogue this bloc reads is project-wide, naming no episode at all, so the mode keeps the
/// shell's own `onEpisodeSelected` null for the same reason the schedule mode does.
///
/// The right dock fraction and the last right dock tab are persisted through
/// [_propertiesManager]'s `budgetRightDockFraction`/`budgetLastRightDockTab`, mirroring
/// `OcptScheduleBloc`'s own pair — the mode carries no left dock any more.
///
/// It mixes in [MixinOcptProjectVersionsBloc], answering its two hooks through
/// [flushPendingProjectWrites] and [reloadFromProjectDatabase] (the entry read), and
/// [MixinOcptProjectPackageBloc] too: the `Export` panel's own standing project-package card is
/// wired here exactly as every other mode's is, beside the budget's own documents.
class OcptBudgetBloc extends BlocForMixin<OcptBudgetState>
    with
        MixinAsyncInitBloc<OcptBudgetState>,
        MixinOcptProjectVersionsBloc<OcptBudgetState>,
        MixinOcptProjectPackageBloc<OcptBudgetState>,
        MixinOcptModeBloc<OcptBudgetState, OcptBudgetReloadScope> {
  /// The default delay between the last field edit and its autosave write, for the expenses view.
  static const defaultFieldEditDebounce = Duration(seconds: 2);

  /// The logger category linked to this BLoC.
  static const _loggerCategory = "budget_bloc";

  /// The logger this BLoC writes to.
  final LogsHelper _logger;

  /// The manager used to access the project currently open.
  final OcptProjectsManager _projectsManager;

  /// The manager used to load and persist the mode's right dock fraction and last right dock tab.
  final OcptPropertiesManager _propertiesManager;

  /// The router manager used to navigate back to the home page when leaving the workspace.
  final OcptRouterManager _routerManager;

  /// The manager the project package export goes through.
  final OcptExportManager _exportManager;

  /// Reads the whole budget from the open project, see [OcptBudgetSnapshotLoader].
  final OcptBudgetSnapshotLoader _loader;

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsBloc.projectsManager}
  @protected
  @override
  OcptProjectsManager get projectsManager => _projectsManager;

  /// {@macro open_cine_prod_tools.MixinOcptProjectPackageBloc.exportManager}
  @protected
  @override
  OcptExportManager get exportManager => _exportManager;

  /// Class constructor
  ///
  /// Every dependency can be overridden, which is what the tests do; in the app they all resolve
  /// through [globalGetIt].
  OcptBudgetBloc({
    required List<OcptBudgetPosteSeed> seed,
    OcptProjectsManager? projectsManager,
    OcptPropertiesManager? propertiesManager,
    OcptRouterManager? routerManager,
    OcptExportManager? exportManager,
    OcptBudgetSnapshotLoader? snapshotLoader,
  }) : _logger = buildOcptLogsHelper(_loggerCategory),
       _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _propertiesManager = propertiesManager ?? globalGetIt().get<OcptPropertiesManager>(),
       _routerManager = routerManager ?? globalGetIt().get<OcptRouterManager>(),
       _exportManager = exportManager ?? globalGetIt().get<OcptExportManager>(),
       _loader =
           snapshotLoader ??
           OcptBudgetSnapshotLoader(
             projectsManager: projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
             seed: seed,
           ),
       super(const OcptBudgetState.init());

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptBudgetBackRequestedEvent>(_onBackRequested);
    on<OcptBudgetRightDockTabSelectedEvent>(_onRightDockTabSelected);
    on<OcptBudgetRightDockToggledEvent>(_onRightDockToggled);
    on<OcptBudgetRightDockClosedEvent>(_onRightDockClosed);
    on<OcptBudgetRightDockFractionChangedEvent>(_onRightDockFractionChanged);
    on<OcptBudgetViewSelectedEvent>(_onViewSelected);
    on<OcptBudgetToolsViewSelectedEvent>(_onToolsViewSelected);
    on<OcptBudgetSimplifiedToggledEvent>(_onSimplifiedToggled);
    on<OcptBudgetTaxBasisChangedEvent>(_onTaxBasisChanged);
    on<OcptBudgetPosteSelectedEvent>(_onPosteSelected);
    on<OcptBudgetRowExpansionToggledEvent>(_onRowExpansionToggled);
    on<OcptBudgetLineSelectedEvent>(_onLineSelected);
    on<OcptBudgetCommitmentSelectedEvent>(_onCommitmentSelected);
    on<OcptBudgetEntrySelectedEvent>(_onEntrySelected);
    on<OcptBudgetReceiptSelectedEvent>(_onReceiptSelected);
    onAwaited<OcptBudgetSelectionCreatedEvent>(_onSelectionCreated);
    onAwaited<OcptBudgetShareCreatedEvent>(_onShareCreated);
    on<OcptBudgetProjectSettingsChangedEvent>(_onProjectSettingsChanged);
    on<OcptBudgetPosteFilterSelectedEvent>(_onPosteFilterSelected);
    on<OcptBudgetResourceSelectedEvent>(_onResourceSelected);
    on<OcptBudgetProvisionPosteSelectedEvent>(_onProvisionPosteSelected);
    on<OcptBudgetRevenueSelectedEvent>(_onRevenueSelected);
    on<OcptBudgetShareSelectedEvent>(_onShareSelected);
  }

  /// Have every view write what it holds, so a preview about to swap the database can't send a
  /// typed edit into the previewed version instead, then clear the selection: whatever it named out
  /// of
  /// the working copy's own catalogue means nothing once a preview swaps that data out.
  ///
  /// Answers false, with the selection untouched, when a typed edit could not be written: the
  /// preview, the restore, the saved version or the package then does not happen, and the edit
  /// stays pending, which is where the write failure stopped this handler before the views.
  @protected
  @override
  Future<bool> flushPendingProjectWrites(Emitter<OcptBudgetState> emitter) async {
    if (!await _flushAllPendingWrites()) {
      return false;
    }

    emitter(state.copyWithSelectionCleared());
    return true;
  }

  /// {@macro open_cine_prod_tools.MixinOcptModeBloc.flushAllPendingWritesIn}
  ///
  /// False when a typed edit could not be written, for the reason [flushPendingProjectWrites]
  /// gives: an export would print the value the database still holds and report success.
  @protected
  @override
  Future<bool> flushAllPendingWritesIn(Emitter<OcptBudgetState> emitter) =>
      _flushAllPendingWrites();

  /// {@macro open_cine_prod_tools.MixinOcptModeBloc.reloadScopesIn}
  ///
  /// Reading the snapshot also reconciles the shared selection against what was read
  /// ([_readBudgetSnapshot]). A read that fails is logged and answers false, which stops the view
  /// that asked: it must not select a row the state may not hold.
  @protected
  @override
  Future<bool> reloadScopesIn(
    Set<OcptBudgetReloadScope> scopes,
    Emitter<OcptBudgetState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return false;
    }

    var isReloaded = false;
    try {
      // A switch statement over an enum must name every value: a scope added to the enum does not
      // compile until it is read here.
      for (final scope in scopes) {
        switch (scope) {
          case OcptBudgetReloadScope.snapshot:
            await _readBudgetSnapshot(emitter, project);
        }
      }

      isReloaded = true;
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to read again the $scopes of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
    }

    return isReloaded;
  }

  /// Write every pending edit of the views directly to the database, without touching [state].
  ///
  /// Called by the mode's own `deactivate()`, mirroring `OcptScheduleBloc.flushPendingFieldEdits`:
  /// `deactivate()` runs before `dispose()` for every removal from the tree, so triggering the
  /// write here — rather than dispatching an event, which would only be processed on a later
  /// microtask this widget might not survive to see — is what guarantees the last
  /// [defaultFieldEditDebounce] worth of typing isn't lost.
  Future<void> flushPendingFieldEdits() => runPendingWritesFlushersWithoutState();

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsBloc.reloadFromProjectDatabase}
  @protected
  @override
  Future<void> reloadFromProjectDatabase(Emitter<OcptBudgetState> emitter) => _load(emitter);

  /// {@macro act_flutter_utility.MixinAsyncInitBloc.initAsyncBloc}
  ///
  /// Loads the mode for the first time, see [_load]; adding an [AsyncInitEvent] again loads it
  /// again.
  @protected
  @override
  Future<void> initAsyncBloc({required Emitter<OcptBudgetState> emit}) async {
    await super.initAsyncBloc(emit: emit);
    await _load(emit);
  }

  /// Ask every view to write what it holds, and answer whether they all could.
  ///
  /// Nothing in this mode catches a failed write: the view that failed keeps its edit pending, the
  /// views after it are still asked, and the action this flush was for (a selection, a view or dock
  /// change, an export, a version preview) does not happen. Selecting a resource, a taking, a share
  /// or a receipt, going back and creating a record never ask: an edit typed before them is written
  /// by its own debounce.
  Future<bool> _flushAllPendingWrites() async {
    final run = await runPendingWritesFlushers();
    return !run.hasFailed;
  }

  /// Load the current project's whole budget through [_loader] (which seeds the ten CNC postes on
  /// the first read of an empty table), the page setup and the persisted dock state.
  ///
  /// This is also [MixinOcptProjectVersionsBloc]'s [reloadFromProjectDatabase] hook, so it emits
  /// which version is being previewed alongside the read it just performed. The selection and any
  /// pending field edit are always cleared on a (re)load: a preview or a restore changes the whole
  /// database underneath, so a stale selection is dropped rather than trusted to still mean
  /// something.
  Future<void> _load(Emitter<OcptBudgetState> emitter) async {
    final rightDockFraction =
        await _propertiesManager.budgetRightDockFraction.load() ??
        OcptWorkspaceDock.rightDefaultFraction;
    final lastRightDockTab =
        await _propertiesManager.budgetLastRightDockTab.load() ?? OcptBudgetRightDockTab.inspector;

    final project = _projectsManager.currentProject;
    if (project == null) {
      emitter(
        state.copyToLoadedWithoutProject(
          rightDockFraction: rightDockFraction,
          lastRightDockTab: lastRightDockTab,
        ),
      );
      return;
    }

    // Queued with the views' reloads: a read made here but emitted after a newer one would put
    // older data over it.
    await runSerially(() async {
      final previewedVersion = project.previewedVersion;
      final loaded = await _loader.load(project);
      final pageSetup = await _loadPageSetup(project);

      emitter(
        state.copyToLoaded(
          title: project.name,
          previewedVersionId: previewedVersion?.id,
          snapshot: loaded.snapshot,
          roles: loaded.roles,
          people: loaded.people,
          elements: loaded.elements,
          mileageRates: loaded.mileageRates,
          logisticsDecorNameByDayId: loaded.logisticsDecorNameByDayId,
          rightDockFraction: rightDockFraction,
          lastRightDockTab: lastRightDockTab,
          pageSetup: pageSetup,
        ),
      );
    });
  }

  /// Read the page setup the mode's own three PDF export dialogs are pre-filled with: the open
  /// project's own page format, paired with the app-wide margins preference, exactly as
  /// `OcptResourcesBloc`'s own `_loadPageSetup` pairs them.
  ///
  /// A version being previewed is laid out with the setup it was written against instead, which
  /// travels on the open project model and is never written anywhere.
  Future<OcptPageSetup> _loadPageSetup(OcptOpenProjectModel project) async =>
      project.previewedPageSetup ??
      OcptPageSetup(
        format: await _projectsManager.loadCurrentProjectPageFormat() ?? OcptPageFormat.usLetter,
        margins:
            await _propertiesManager.pageMargins.load() ?? const FountainPageMargins.standard(),
      );

  /// Leave the workspace: closes the current project and navigates back to the home page.
  Future<void> _onBackRequested(
    OcptBudgetBackRequestedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    await _projectsManager.closeCurrentProject();
    _routerManager.pop();
  }

  /// Select a tab of the right dock (the already-active tab closes the dock, any other one opens
  /// or switches to it). Flushes any pending field edit first, mirroring every other mode.
  Future<void> _onRightDockTabSelected(
    OcptBudgetRightDockTabSelectedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    if (!await _flushAllPendingWrites()) {
      return;
    }

    final isAlreadyActive = state.rightDockTab == event.tab;
    await _persistLastRightDockTab(event.tab);
    emitter(state.copyWithToggledRightDockTab(tab: event.tab, isAlreadyActive: isAlreadyActive));

    if (!isAlreadyActive && event.tab == OcptBudgetRightDockTab.versions) {
      add(const OcptProjectWorkingCopyRefreshRequestedEvent());
    }
  }

  /// Toggle the right dock from the workspace toolbar: an open dock closes, a closed one reopens
  /// on [OcptBudgetState.lastRightDockTab].
  Future<void> _onRightDockToggled(
    OcptBudgetRightDockToggledEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    if (state.rightDockTab != null) {
      emitter(state.copyWithRightDockClosed());
      return;
    }

    emitter(state.copyWithRightDockReopened());

    if (state.lastRightDockTab == OcptBudgetRightDockTab.versions) {
      add(const OcptProjectWorkingCopyRefreshRequestedEvent());
    }
  }

  /// Close the right dock via its own × close button.
  Future<void> _onRightDockClosed(
    OcptBudgetRightDockClosedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    emitter(state.copyWithRightDockClosed());
  }

  /// Apply and persist the right dock's new width fraction.
  Future<void> _onRightDockFractionChanged(
    OcptBudgetRightDockFractionChangedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    await _propertiesManager.budgetRightDockFraction.store(event.fraction);
    emitter(state.copyWithRightDockFraction(fraction: event.fraction));
  }

  /// Persist [tab] as the mode's last right dock tab, unless it already is.
  Future<void> _persistLastRightDockTab(OcptBudgetRightDockTab tab) async {
    if (state.lastRightDockTab == tab) {
      return;
    }

    await _propertiesManager.budgetLastRightDockTab.store(tab);
  }

  /// Switch which of the mode's views is shown — dispatched by one of the header's own chips,
  /// and by every other gesture that leads to a view of its own.
  Future<void> _onViewSelected(
    OcptBudgetViewSelectedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    // Flushed here for the reason a selection change and a dock tab change already flush: the user
    // has stopped typing and is about to *read* figures somewhere else. Without it, an amount typed
    // in the cost-tracking table and followed straight by a click on `Financing` was still sitting
    // in the debounce, so that view drew the snapshot from before it — and corrected itself two
    // seconds later, once the timer fired. The write was never lost; it simply was not shown, which
    // reads exactly like an app that ignores what it is told.
    if (!await _flushAllPendingWrites()) {
      return;
    }

    emitter(state.copyWithView(view: event.view, clearSelection: event.clearSelection));
  }

  /// Switch which of the tools drawer's own three pages is shown — dispatched by the header's
  /// own second segmented switch. Mirrors [_onViewSelected] exactly, flush included: leaving
  /// `Logistics`'s own provisioning band for `Flux de trésorerie` reads the very figures a pending
  /// edit has not reached yet.
  Future<void> _onToolsViewSelected(
    OcptBudgetToolsViewSelectedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    if (!await _flushAllPendingWrites()) {
      return;
    }

    emitter(
      state.copyWithToolsView(toolsView: event.toolsView, clearSelection: event.clearSelection),
    );
  }

  /// Toggle the header's simplified/detailed switch.
  Future<void> _onSimplifiedToggled(
    OcptBudgetSimplifiedToggledEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    // Flushed for [_onCentreViewSelected]'s own reason: both toggles re-read the very figures a
    // pending edit has not reached yet.
    if (!await _flushAllPendingWrites()) {
      return;
    }

    emitter(state.copyWithSimplified(isSimplified: event.isSimplified));
  }

  /// Switch the header's excluding/including-tax toggle.
  Future<void> _onTaxBasisChanged(
    OcptBudgetTaxBasisChangedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    // Flushed for [_onCentreViewSelected]'s own reason: both toggles re-read the very figures a
    // pending edit has not reached yet.
    if (!await _flushAllPendingWrites()) {
      return;
    }

    emitter(state.copyWithTaxBasis(basis: event.basis));
  }

  /// Select poste `event.posteId`, opening the right dock on the `Inspector` tab. A poste id
  /// naming no live poste is ignored. Flushes any pending field edit first: switching which poste's
  /// own fields are on screen is exactly the selection change every other mode flushes on.
  Future<void> _onPosteSelected(
    OcptBudgetPosteSelectedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    if (!await _flushAllPendingWrites()) {
      return;
    }

    if (!state.postes.any((poste) => poste.id == event.posteId)) {
      return;
    }

    emitter(state.copyWithInspectedSelection(selection: OcptBudgetPosteSelection(event.posteId)));
  }

  /// Expand or collapse expenses-tree node `event.nodeId` — an already-expanded one collapses, a
  /// collapsed one expands, independently of every other node.
  Future<void> _onRowExpansionToggled(
    OcptBudgetRowExpansionToggledEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    final expandedNodeIds = Set<String>.of(state.expandedNodeIds);
    if (!expandedNodeIds.remove(event.nodeId)) {
      expandedNodeIds.add(event.nodeId);
    }

    emitter(state.copyWithExpandedNodeIds(expandedNodeIds: expandedNodeIds));
  }

  /// Select quote line `event.lineId`, opening the right dock on the `Inspector` tab — mirrors
  /// [_onPosteSelected], flushing any pending field edit first for the same reason: the newly
  /// selected line may belong to a different poste than whichever one's fields are on screen. A
  /// line id naming no live line is ignored.
  Future<void> _onLineSelected(
    OcptBudgetLineSelectedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    if (!await _flushAllPendingWrites()) {
      return;
    }

    if (!state.postes.any((poste) => poste.lines.any((line) => line.id == event.lineId))) {
      return;
    }

    emitter(state.copyWithInspectedSelection(selection: OcptBudgetLineSelection(event.lineId)));
  }

  /// Select commitment `event.commitmentId`, opening the right dock on the `Inspector` tab —
  /// mirrors [_onLineSelected]. A commitment id naming no live commitment is ignored.
  Future<void> _onCommitmentSelected(
    OcptBudgetCommitmentSelectedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    if (!await _flushAllPendingWrites()) {
      return;
    }

    if (!state.commitments.any((commitment) => commitment.id == event.commitmentId)) {
      return;
    }

    emitter(
      state.copyWithInspectedSelection(
        selection: OcptBudgetCommitmentSelection(event.commitmentId),
      ),
    );
  }

  /// Select journal entry `event.entryId`, opening the right dock on the `Inspector` tab —
  /// mirrors [_onLineSelected]. An entry id naming no live entry is ignored.
  Future<void> _onEntrySelected(
    OcptBudgetEntrySelectedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    if (!await _flushAllPendingWrites()) {
      return;
    }

    if (!state.entries.any((entry) => entry.id == event.entryId)) {
      return;
    }

    emitter(state.copyWithInspectedSelection(selection: OcptBudgetEntrySelection(event.entryId)));
  }

  /// Select receipt `event.receiptId` — a sub-row of the resources tree — opening the right dock
  /// on the `Inspector` tab. Mirrors [_onEntrySelected] exactly: a receipt is the very same
  /// `budget_entries` row read under a different name, so it is looked up in
  /// [OcptBudgetState.entries] the same way. A receipt id naming no live entry is ignored.
  Future<void> _onReceiptSelected(
    OcptBudgetReceiptSelectedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    if (!state.entries.any((entry) => entry.id == event.receiptId)) {
      return;
    }

    emitter(
      state.copyWithInspectedSelection(selection: OcptBudgetReceiptSelection(event.receiptId)),
    );
  }

  /// Select the poste, the quote line, the resource or the taking a view has just created, without
  /// writing what is pending: the view did so, and has read the snapshot again. A poste and a line
  /// open the right dock on the `Inspector` tab, a resource and a taking do not.
  Future<void> _onSelectionCreated(
    OcptBudgetSelectionCreatedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    emitter(
      state.copyWithCreatedSelection(
        selection: event.selection,
        opensInspector: event.opensInspector,
      ),
    );
  }

  /// Highlight the share a view has just created, without writing what is pending.
  Future<void> _onShareCreated(
    OcptBudgetShareCreatedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    emitter(state.copyWithCreatedShare(shareId: event.shareId));
  }

  /// Re-read the project's currency and default VAT rate after the project settings page changed
  /// something — mirrors `OcptScheduleProjectSettingsChangedEvent`'s own handler.
  Future<void> _onProjectSettingsChanged(
    OcptBudgetProjectSettingsChangedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await runSerially(() => _readBudgetSnapshot(emitter, project));
  }

  /// Narrow every view of the mode to `event.posteId`, or clear the filter when it is null — see
  /// [OcptBudgetPosteFilterSelectedEvent]'s own doc comment for why this is not the selection.
  ///
  /// Flushes any pending field edit first, mirroring every other handler that changes what is on
  /// screen: a figure still sitting in the autosave debounce would otherwise be read back from the
  /// snapshot as it was before it was typed.
  ///
  /// **A poste id naming no live poste is ignored**, exactly as [_onPosteSelected] ignores one.
  Future<void> _onPosteFilterSelected(
    OcptBudgetPosteFilterSelectedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    if (!await _flushAllPendingWrites()) {
      return;
    }

    final posteId = event.posteId;
    if (posteId == null) {
      emitter(state.copyWithPosteFilterCleared());
      return;
    }

    if (state.postes.any((poste) => poste.id == posteId)) {
      emitter(state.copyWithPosteFilter(posteId: posteId));
    }
  }

  /// Read [project]'s whole snapshot, reconcile the shared selection against it, emit both in one
  /// state, and ask for a fresh working-copy capture while the `Versions` tab is open.
  ///
  /// Not queued: [reloadScopesIn] and the settings handler queue it, each in its own way. Whatever
  /// the selection, the filter or the share named that the snapshot no longer holds is dropped in
  /// the very state that carries the snapshot, and moves the selection epoch with
  /// [OcptBudgetSelectionCause.reconciled]. `OcptBudgetReceiptSelection` names a `budget_entries`
  /// row exactly as `OcptBudgetEntrySelection` does, so it is checked against the entries the same
  /// way.
  Future<void> _readBudgetSnapshot(
    Emitter<OcptBudgetState> emitter,
    OcptOpenProjectModel project,
  ) async {
    final loaded = await _loader.load(project);
    final snapshot = loaded.snapshot;
    // The filter is reconciled exactly as the selection is: a poste deleted while every view was
    // narrowed to it would otherwise leave the mode showing nothing at all, with a header chip
    // naming a poste the project no longer has.
    final filterStillExists =
        state.filterPosteId == null ||
        snapshot.postes.any((poste) => poste.id == state.filterPosteId);
    final selectionStillExists = switch (state.selection) {
      null => true,
      OcptBudgetPosteSelection(:final posteId) => snapshot.postes.any(
        (poste) => poste.id == posteId,
      ),
      OcptBudgetLineSelection(:final lineId) => snapshot.postes.any(
        (poste) => poste.lines.any((line) => line.id == lineId),
      ),
      OcptBudgetCommitmentSelection(:final commitmentId) => snapshot.commitments.any(
        (commitment) => commitment.id == commitmentId,
      ),
      OcptBudgetEntrySelection(:final entryId) => snapshot.entries.any(
        (entry) => entry.id == entryId,
      ),
      OcptBudgetResourceSelection(:final resourceId) => snapshot.resources.any(
        (resource) => resource.id == resourceId,
      ),
      OcptBudgetRevenueSelection(:final revenueId) => snapshot.revenues.any(
        (revenue) => revenue.id == revenueId,
      ),
      OcptBudgetReceiptSelection(:final receiptId) => snapshot.entries.any(
        (entry) => entry.id == receiptId,
      ),
    };
    final shareStillExists =
        state.selectedShareId == null ||
        snapshot.shares.any((share) => share.id == state.selectedShareId);

    emitter(
      state.copyWithReconciledSnapshot(
        snapshot: snapshot,
        roles: loaded.roles,
        people: loaded.people,
        elements: loaded.elements,
        mileageRates: loaded.mileageRates,
        logisticsDecorNameByDayId: loaded.logisticsDecorNameByDayId,
        selectionStillExists: selectionStillExists,
        filterStillExists: filterStillExists,
        shareStillExists: shareStillExists,
      ),
    );

    if (state.rightDockTab == OcptBudgetRightDockTab.versions) {
      add(const OcptProjectWorkingCopyRefreshRequestedEvent());
    }
  }

  /// Select financing resource `event.resourceId`, opening the right dock on the `Inspector` tab —
  /// mirrors [_onPosteSelected]. A resource id naming no live resource is ignored.
  Future<void> _onResourceSelected(
    OcptBudgetResourceSelectedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    if (!state.resources.any((resource) => resource.id == event.resourceId)) {
      return;
    }

    emitter(
      state.copyWithInspectedSelection(selection: OcptBudgetResourceSelection(event.resourceId)),
    );
  }

  /// Point the provisioning at `event.posteId` — a selection, written nowhere.
  void _onProvisionPosteSelected(
    OcptBudgetProvisionPosteSelectedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) => emitter(state.copyWithProvisionPoste(posteId: event.posteId));

  /// Select taking `event.revenueId`, opening the right dock on the `Inspector` tab — mirrors
  /// [_onResourceSelected]. A revenue id naming no live revenue is ignored.
  Future<void> _onRevenueSelected(
    OcptBudgetRevenueSelectedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    if (!state.revenues.any((revenue) => revenue.id == event.revenueId)) {
      return;
    }

    emitter(
      state.copyWithInspectedSelection(selection: OcptBudgetRevenueSelection(event.revenueId)),
    );
  }

  /// Select share `event.shareId`, drawn as a plain highlight — mirrors [_onRevenueSelected]. A
  /// share id naming no live share is ignored.
  Future<void> _onShareSelected(
    OcptBudgetShareSelectedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    if (!state.shares.any((share) => share.id == event.shareId)) {
      return;
    }

    emitter(state.copyWithSelectedShare(shareId: event.shareId));
  }
}
