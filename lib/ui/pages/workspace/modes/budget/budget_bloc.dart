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
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_allowances_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_financing_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_journal_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_quote_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_sharing_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_people_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_project_info_table.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_mileage_rate.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste_seed.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
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
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';

/// This is the bloc class for the budget production mode.
///
/// It loads the current project's title and the mode's own whole read on entry: the quote itself
/// ([_budgetQuoteService], seeding [_seed]'s ten CNC postes on the first read of an empty table),
/// the cash journal ([_budgetJournalService]: every live entry and commitment, and every live
/// voucher keyed by the entry it evidences), the financing plan ([_budgetFinancingService]: every
/// live resource and mileage rate), the catering-and-travel pass's own reads ([_scheduleService]'s
/// schedule, [_roleIndexService]'s roles, [_peopleService]'s people and [_locationsService]'s
/// locations — the last read only to name the decor a day shoots at, never carried on state
/// itself), the breakdown's own elements catalogue ([_elementsService], read the same way
/// `OcptScheduleBloc` already does, carried on state raw beside the roles and the people), and the
/// project's currency, default VAT rate and meal/snack prices. It mixes in
/// [MixinOcptProjectVersionsBloc], answering its two hooks through [flushPendingProjectWrites] and
/// [reloadFromProjectDatabase].
///
/// **[_seed] is a constructor argument, captured once, rather than watched.** No bloc or service
/// may ever see a `Tr` (`AGENTS.md`), so `OcptBudgetMode` resolves `ocptBudgetCncPosteSeeds(Tr.of
/// (context))` and hands the list in when it creates this bloc; [reloadFromProjectDatabase] reuses
/// the very list it was given rather than re-resolving it, since a preview or a restore swaps the
/// database, not the app's own locale — nothing about the seed's own words has changed by the time
/// a reload runs, and this bloc has no `BuildContext` to re-resolve them with even if it had.
///
/// **There is no episode selector.** One budget serves the whole production (ADR 0019): the
/// catalogue this bloc reads is project-wide, naming no episode at all, so the mode keeps the
/// shell's own `onEpisodeSelected` null for the same reason the schedule mode does — not for want
/// of a bloc, but because a selector would filter a read that was never split by episode to begin
/// with.
///
/// The right dock fraction and the last right dock tab are persisted through
/// [_propertiesManager]'s `budgetRightDockFraction`/`budgetLastRightDockTab`, mirroring
/// `OcptScheduleBloc`'s own pair — the mode carries no left dock any more, so there is no fraction
/// of its own to persist.
///
/// Every write but the free-text fields (which ride the expenses view's debounce, flushed by
/// [_flushAllPendingWrites] on a selection change, a dock tab change, a version preview and the
/// mode's own `deactivate()`) lands the moment it is dispatched, then reloads the quote snapshot
/// through [_applyBudgetSnapshot] — which also reconciles [OcptBudgetState.selection] against the
/// freshly loaded snapshot, and, while the `Versions` tab is open, asks
/// [MixinOcptProjectVersionsBloc] for a fresh working-copy capture, the mode's own stand-in for "a
/// save landing while it is open".
///
/// It mixes in [MixinOcptProjectPackageBloc] too: the `Export` panel's own standing project-package
/// card is wired here exactly as every other mode's is, beside the budget's own documents — see
/// `OcptBudgetMode`'s own doc comment.
class OcptBudgetBloc extends BlocForMixin<OcptBudgetState>
    with
        MixinOcptProjectVersionsBloc<OcptBudgetState>,
        MixinOcptProjectPackageBloc<OcptBudgetState>,
        MixinOcptModeBloc<OcptBudgetState, OcptBudgetReloadScope> {
  /// The logger category linked to this BLoC.
  static const _loggerCategory = "budget_bloc";

  /// The logger this BLoC writes to.
  final LogsHelper _logger = buildOcptLogsHelper(_loggerCategory);

  /// The default delay between the last field edit and its autosave write, for the expenses view.
  static const defaultFieldEditDebounce = Duration(seconds: 2);

  /// The manager used to access the project currently open.
  final OcptProjectsManager _projectsManager;

  /// The manager used to load and persist the mode's right dock fraction and last right dock tab.
  final OcptPropertiesManager _propertiesManager;

  /// The router manager used to navigate back to the home page when leaving the workspace.
  final OcptRouterManager _routerManager;

  /// The manager the project package export goes through.
  final OcptExportManager _exportManager;

  /// The service used to read and write the quote: the postes and their lines.
  final OcptBudgetQuoteService _budgetQuoteService;

  /// The service used to read the cash journal: every live entry and commitment. Its own
  /// [OcptBudgetJournalService.setEntryReceipt]/[OcptBudgetJournalService.clearEntryReceipt] are
  /// what the bloc's own handlers write an entry's voucher through — never `OcptBudgetEntryDialog`
  /// itself, exactly as every other write in this mode.
  final OcptBudgetJournalService _budgetJournalService;

  /// The service used to read and write the financing plan: the `budget_resources` catalogue and
  /// the `budget_mileage_rates` [_loadBudgetSnapshot] resolves a traveller's own reimbursement
  /// against.
  final OcptBudgetFinancingService _budgetFinancingService;

  /// The service used to read and write the defrayals: the `budget_allowances` a production types
  /// for itself, which nothing here deduces from the schedule.
  final OcptBudgetAllowancesService _budgetAllowancesService;

  /// The service used to read and write the revenue sharing: the `budget_revenues` takings and the
  /// `budget_shares` splitting what they bring in.
  final OcptBudgetSharingService _budgetSharingService;

  /// The service the catering-and-travel pass reads its own days and slots off — never an
  /// `OcptSchedulePlanSnapshot`, see [_loadBudgetSnapshot]'s own doc comment.
  final OcptScheduleService _scheduleService;

  /// The service the catering-and-travel pass reads every role's own kind and `personId` off, to
  /// split cast from extras and to join a convoked role back to the human playing it.
  final OcptRoleIndexService _roleIndexService;

  /// The service the catering-and-travel pass reads every person's own display name, commute
  /// distance, mileage rate and declared crew positions off.
  final OcptPeopleService _peopleService;

  /// The service [_loadBudgetSnapshot] reads the project's locations and sets off, for the one
  /// reading that needs them: naming the decor a shooting day plays at.
  final OcptLocationsService _locationsService;

  /// The service [_loadBudgetSnapshot] reads the breakdown's own elements catalogue off — what the
  /// feed card's own breakdown row counts against, and what `+ From breakdown` picks a fresh quote
  /// line from. Mirrors `OcptScheduleBloc._elementsService`.
  final OcptElementsService _elementsService;

  /// The ten CNC postes, already localized — see the class doc comment for why this is a
  /// constructor argument captured once rather than watched.
  final List<OcptBudgetPosteSeed> _seed;

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
    OcptBudgetQuoteService? budgetQuoteService,
    OcptBudgetJournalService? budgetJournalService,
    OcptBudgetFinancingService? budgetFinancingService,
    OcptBudgetAllowancesService? budgetAllowancesService,
    OcptBudgetSharingService? budgetSharingService,
    OcptScheduleService? scheduleService,
    OcptRoleIndexService? roleIndexService,
    OcptPeopleService? peopleService,
    OcptLocationsService? locationsService,
    OcptElementsService? elementsService,
  }) : _seed = seed,
       _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _propertiesManager = propertiesManager ?? globalGetIt().get<OcptPropertiesManager>(),
       _routerManager = routerManager ?? globalGetIt().get<OcptRouterManager>(),
       _exportManager = exportManager ?? globalGetIt().get<OcptExportManager>(),
       _budgetQuoteService =
           budgetQuoteService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).budgetQuoteService,
       _budgetJournalService =
           budgetJournalService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).budgetJournalService,
       _budgetFinancingService =
           budgetFinancingService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).budgetFinancingService,
       _budgetAllowancesService =
           budgetAllowancesService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).budgetAllowancesService,
       _budgetSharingService =
           budgetSharingService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).budgetSharingService,
       _scheduleService =
           scheduleService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).scheduleService,
       _roleIndexService =
           roleIndexService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).roleIndexService,
       _peopleService =
           peopleService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).peopleService,
       _locationsService =
           locationsService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).locationsService,
       _elementsService =
           elementsService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).elementsService,
       super(const OcptBudgetState.init()) {
    add(const OcptBudgetLoadRequestedEvent());
  }

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptBudgetLoadRequestedEvent>(_onLoadRequested);
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

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsBloc.projectsManager}
  @protected
  @override
  OcptProjectsManager get projectsManager => _projectsManager;

  /// {@macro open_cine_prod_tools.MixinOcptProjectPackageBloc.exportManager}
  @protected
  @override
  OcptExportManager get exportManager => _exportManager;

  /// Has every view write what it holds, so a preview about to swap the database can't send a typed
  /// edit into the previewed version instead, then clears the selection: whatever it named out of
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

    emitter(
      state.copyWith(
        forceSelectionValue: true,
        forceSelectedShareIdValue: true,
        selectionEpoch: state.selectionEpoch + 1,
        selectionCause: OcptBudgetSelectionCause.cleared,
      ),
    );
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

    try {
      // A switch statement over an enum must name every value: a scope added to the enum does not
      // compile until it is read here.
      for (final scope in scopes) {
        switch (scope) {
          case OcptBudgetReloadScope.snapshot:
            await _readBudgetSnapshot(emitter, project);
        }
      }

      return true;
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to read again the $scopes of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      return false;
    }
  }

  /// Asks every view to write what it holds, and answers whether they all could.
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

  /// Writes every pending edit of the views directly to the database, without touching [state].
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
  Future<void> reloadFromProjectDatabase(Emitter<OcptBudgetState> emitter) =>
      _onLoadRequested(const OcptBudgetLoadRequestedEvent(), emitter);

  /// Loads the current project's whole quote read: the postes with their lines (seeding [_seed]'s
  /// ten CNC postes on the first read of an empty table), the currency and the default VAT rate.
  ///
  /// This is also [MixinOcptProjectVersionsBloc]'s [reloadFromProjectDatabase] hook, so it emits
  /// which version is being previewed alongside the read it just performed. The selection and any
  /// pending field edit are always cleared on a (re)load: a preview or a restore changes the whole
  /// database underneath, so a stale selection is dropped rather than trusted to still mean
  /// something.
  Future<void> _onLoadRequested(
    OcptBudgetLoadRequestedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    final rightDockFraction =
        await _propertiesManager.budgetRightDockFraction.load() ??
        OcptWorkspaceDock.rightDefaultFraction;
    final lastRightDockTab =
        await _propertiesManager.budgetLastRightDockTab.load() ?? OcptBudgetRightDockTab.inspector;

    final project = _projectsManager.currentProject;
    if (project == null) {
      emitter(
        state.copyWith(
          isLoading: false,
          rightDockFraction: rightDockFraction,
          lastRightDockTab: lastRightDockTab,
          forcePreviewedVersionIdValue: true,
          forceSelectionValue: true,
          forceSelectedShareIdValue: true,
          roles: const [],
          people: const [],
          elements: const [],
          regieDecorNameByDayId: const {},
          selectionEpoch: state.selectionEpoch + 1,
          selectionCause: OcptBudgetSelectionCause.load,
        ),
      );
      return;
    }

    // Queued with the views' reloads: a read made here but emitted after a newer one would put
    // older data over it.
    await runSerially(() async {
      final previewedVersion = project.previewedVersion;
      final loaded = await _loadBudgetSnapshot(project);
      final pageSetup = await _loadPageSetup(project);

      emitter(
        state.copyWith(
          isLoading: false,
          title: project.name,
          previewedVersionId: previewedVersion?.id,
          forcePreviewedVersionIdValue: previewedVersion == null,
          snapshot: loaded.snapshot,
          currencyCode: loaded.snapshot.currencyCode,
          forceSelectionValue: true,
          forceSelectedShareIdValue: true,
          roles: loaded.roles,
          people: loaded.people,
          elements: loaded.elements,
          mileageRates: loaded.mileageRates,
          provisionPosteId: _defaultProvisionPosteIdOf(loaded.snapshot.postes),
          regieDecorNameByDayId: loaded.regieDecorNameByDayId,
          rightDockFraction: rightDockFraction,
          lastRightDockTab: lastRightDockTab,
          pageSetup: pageSetup,
          selectionEpoch: state.selectionEpoch + 1,
          selectionCause: OcptBudgetSelectionCause.load,
        ),
      );
    });
  }

  /// Reads the page setup the mode's own three PDF export dialogs are pre-filled with: the open
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

  /// Reads [project]'s whole read: the postes with their lines, the cash journal's own entries and
  /// commitments, the financing plan's own resources and mileage rates, the catering-and-travel
  /// pass's own reads, the breakdown's own elements catalogue, the currency, the default VAT rate
  /// and the meal/buffet prices, joined into one [OcptBudgetSnapshot] alongside the raw
  /// roles/people/elements and the decor name map the view reads directly.
  ///
  /// **Reads `OcptScheduleService.loadSchedule`'s own `OcptScheduleSnapshot` directly, never an
  /// `OcptSchedulePlanSnapshot`.** A plan snapshot additionally joins every episode's own shot list
  /// and the episode list — neither of which a head count needs — so building one here would make
  /// the budget mode load the whole découpage to count meals; the schedule snapshot alone already
  /// carries the days, the slots (each with its own live crew, cast and guests already nested) and
  /// the blocks that `OcptBudgetSnapshot.build` reads the catering-and-travel pass's own meal
  /// sittings from.
  ///
  /// `elements` is carried raw, beside `roles`/`people`, rather than folded into
  /// [OcptBudgetSnapshot]: `OcptBudgetFiche`'s own `+ From breakdown` picker needs the
  /// whole catalogue, not just the two counts `OcptBudgetState.elementLinkCounts` derives from it.
  Future<
    ({
      OcptBudgetSnapshot snapshot,
      List<OcptRole> roles,
      List<OcptPerson> people,
      List<OcptElement> elements,
      List<OcptBudgetMileageRate> mileageRates,
      Map<String, String> regieDecorNameByDayId,
    })
  >
  _loadBudgetSnapshot(OcptOpenProjectModel project) async {
    final database = project.database;
    final postes = await _budgetQuoteService.loadPostes(database: database, seed: _seed);
    final entries = await _budgetJournalService.loadEntries(database: database);
    final commitments = await _budgetJournalService.loadCommitments(database: database);
    final resources = await _budgetFinancingService.loadResources(database: database);
    final revenues = await _budgetSharingService.loadRevenues(database: database);
    final shares = await _budgetSharingService.loadShares(database: database);
    final receipts = await _budgetJournalService.loadReceipts(database: database);
    final currencyCode = await _projectsManager.loadCurrentProjectCurrencyCode();
    final defaultVatRateBasisPoints = await _projectsManager
        .loadCurrentProjectDefaultVatRateBasisPoints();

    final scheduleSnapshot = await _scheduleService.loadSchedule(database: database);
    final roles = await _roleIndexService.loadRoles(database: database);
    final people = await _peopleService.loadPeople(database: database);
    final elements = await _elementsService.loadElements(database: database);
    final locations = await _locationsService.loadLocations(database: database);
    final mileageRates = await _budgetFinancingService.loadMileageRates(database: database);
    final allowances = await _budgetAllowancesService.loadAllowances(database: database);
    final mealPriceCents = await _projectsManager.loadCurrentProjectMealPriceCents();
    // `project_info.snackPriceCents` under its user-facing name — the column keeps the schema's
    // own name, but what it prices is the buffet, never a snack in the trade's own words.
    final buffetPriceCents = await _projectsManager.loadCurrentProjectSnackPriceCents();

    final snapshot = OcptBudgetSnapshot.build(
      postes: postes,
      entries: entries,
      commitments: commitments,
      resources: resources,
      defaultVatRateBasisPoints: defaultVatRateBasisPoints,
      currencyCode: currencyCode ?? ocptDefaultCurrencyCode,
      receiptsByEntryId: receipts,
      scheduleDays: scheduleSnapshot.days,
      slotsByDayId: scheduleSnapshot.slotsByDayId,
      blocksByDayId: scheduleSnapshot.blocksByDayId,
      roles: roles,
      allowances: allowances,
      mealPriceCents: mealPriceCents,
      buffetPriceCents: buffetPriceCents,
      revenues: revenues,
      shares: shares,
    );

    return (
      snapshot: snapshot,
      roles: roles,
      people: people,
      elements: elements,
      mileageRates: mileageRates,
      regieDecorNameByDayId: _regieDecorNameByDayId(
        days: scheduleSnapshot.days,
        slotsByDayId: scheduleSnapshot.slotsByDayId,
        locations: locations,
      ),
    );
  }

  /// The poste the régie view's own provisioning starts out pointed at: the CNC nomenclature's own
  /// `Transports, défraiements, régie`, by its **stable seeded id**, when the project still has it,
  /// and the first poste otherwise.
  ///
  /// **A preference among the postes that exist, never an assumption that one of them does.** A
  /// production is free to have renamed, split or deleted that poste — the nomenclature is seeded,
  /// not frozen — and a project with no poste at all has nowhere to provision into, which the view
  /// says rather than pretending otherwise.
  String? _defaultProvisionPosteIdOf(List<OcptBudgetPoste> postes) {
    const regiePosteId = 'd75aa74c-ed99-494a-bca0-3508b166ec18';

    return postes.any((poste) => poste.id == regiePosteId) ? regiePosteId : postes.firstOrNull?.id;
  }

  /// The decor name `OcptBudgetRegie` prints under each shooting day: the name of the first set, or
  /// failing that the first location, that any of [days]' own [slotsByDayId] entries name, in slot
  /// order — resolved out of [locations] (and their own live sets) alone.
  /// `lib/models/rules/ocpt_budget_regie.dart`'s own pass reads no location or set at all, being
  /// pure arithmetic over head counts, so this is a separate, purely presentational reading rather
  /// than a second implementation of anything that file states. A day whose slots name neither
  /// carries no key here, which the view reads as nothing rather than a placeholder.
  Map<String, String> _regieDecorNameByDayId({
    required List<OcptShootingDay> days,
    required Map<String, List<OcptShootingSlot>> slotsByDayId,
    required List<OcptLocation> locations,
  }) {
    final locationById = {for (final location in locations) location.id: location};
    final setById = {
      for (final location in locations)
        for (final set in location.sets) set.id: set,
    };

    final decorNameByDayId = <String, String>{};
    for (final day in days) {
      for (final slot in slotsByDayId[day.id] ?? const <OcptShootingSlot>[]) {
        final set = slot.setId == null ? null : setById[slot.setId];
        if (set != null) {
          decorNameByDayId[day.id] = set.name;
          break;
        }

        final location = slot.locationId == null ? null : locationById[slot.locationId];
        if (location != null) {
          decorNameByDayId[day.id] = location.name;
          break;
        }
      }
    }

    return decorNameByDayId;
  }

  /// Leaves the workspace: closes the current project and navigates back to the home page.
  Future<void> _onBackRequested(
    OcptBudgetBackRequestedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    await _projectsManager.closeCurrentProject();
    _routerManager.pop();
  }

  /// Selects a tab of the right dock (the already-active tab closes the dock, any other one opens
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
    emitter(
      state.copyWith(
        rightDockTab: isAlreadyActive ? null : event.tab,
        forceRightDockTabValue: isAlreadyActive,
        lastRightDockTab: event.tab,
      ),
    );

    if (!isAlreadyActive && event.tab == OcptBudgetRightDockTab.versions) {
      add(const OcptProjectWorkingCopyRefreshRequestedEvent());
    }
  }

  /// Toggles the right dock from the workspace toolbar: an open dock closes, a closed one reopens
  /// on [OcptBudgetState.lastRightDockTab].
  Future<void> _onRightDockToggled(
    OcptBudgetRightDockToggledEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    if (state.rightDockTab != null) {
      emitter(state.copyWith(forceRightDockTabValue: true));
      return;
    }

    emitter(state.copyWith(rightDockTab: state.lastRightDockTab));

    if (state.lastRightDockTab == OcptBudgetRightDockTab.versions) {
      add(const OcptProjectWorkingCopyRefreshRequestedEvent());
    }
  }

  /// Closes the right dock via its own × close button.
  Future<void> _onRightDockClosed(
    OcptBudgetRightDockClosedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    emitter(state.copyWith(forceRightDockTabValue: true));
  }

  /// Applies and persists the right dock's new width fraction.
  Future<void> _onRightDockFractionChanged(
    OcptBudgetRightDockFractionChangedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    await _propertiesManager.budgetRightDockFraction.store(event.fraction);
    emitter(state.copyWith(rightDockFraction: event.fraction));
  }

  /// Persists [tab] as the mode's last right dock tab, unless it already is.
  Future<void> _persistLastRightDockTab(OcptBudgetRightDockTab tab) async {
    if (state.lastRightDockTab == tab) {
      return;
    }

    await _propertiesManager.budgetLastRightDockTab.store(tab);
  }

  /// Switches which of the mode's views is shown — dispatched by one of the header's own chips,
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

    emitter(
      state.copyWith(
        view: event.view,
        forceSelectionValue: event.clearSelection,
        selectionEpoch: event.clearSelection ? state.selectionEpoch + 1 : null,
        selectionCause: event.clearSelection ? OcptBudgetSelectionCause.viewChanged : null,
      ),
    );
  }

  /// Switches which of the tools drawer's own three pages is shown — dispatched by the header's
  /// own second segmented switch. Mirrors [_onViewSelected] exactly, flush included: leaving
  /// `Régie`'s own provisioning band for `Flux de trésorerie` reads the very figures a pending
  /// edit has not reached yet.
  Future<void> _onToolsViewSelected(
    OcptBudgetToolsViewSelectedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    if (!await _flushAllPendingWrites()) {
      return;
    }

    emitter(
      state.copyWith(
        toolsView: event.toolsView,
        forceSelectionValue: event.clearSelection,
        selectionEpoch: event.clearSelection ? state.selectionEpoch + 1 : null,
        selectionCause: event.clearSelection ? OcptBudgetSelectionCause.viewChanged : null,
      ),
    );
  }

  /// Toggles the header's simplified/detailed switch.
  Future<void> _onSimplifiedToggled(
    OcptBudgetSimplifiedToggledEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    // Flushed for [_onCentreViewSelected]'s own reason: both toggles re-read the very figures a
    // pending edit has not reached yet.
    if (!await _flushAllPendingWrites()) {
      return;
    }

    emitter(state.copyWith(isSimplified: event.isSimplified));
  }

  /// Switches the header's excluding/including-tax toggle.
  Future<void> _onTaxBasisChanged(
    OcptBudgetTaxBasisChangedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    // Flushed for [_onCentreViewSelected]'s own reason: both toggles re-read the very figures a
    // pending edit has not reached yet.
    if (!await _flushAllPendingWrites()) {
      return;
    }

    emitter(state.copyWith(taxBasis: event.basis));
  }

  /// Selects poste `event.posteId`, opening the right dock on the `Inspector` tab. A poste id
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

    emitter(
      state.copyWith(
        selection: OcptBudgetPosteSelection(event.posteId),
        rightDockTab: OcptBudgetRightDockTab.inspector,
        lastRightDockTab: OcptBudgetRightDockTab.inspector,
        selectionEpoch: state.selectionEpoch + 1,
        selectionCause: OcptBudgetSelectionCause.selected,
      ),
    );
  }

  /// Expands or collapses expenses-tree node `event.nodeId` — an already-expanded one collapses, a
  /// collapsed one expands, independently of every other node.
  Future<void> _onRowExpansionToggled(
    OcptBudgetRowExpansionToggledEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    final expandedNodeIds = Set<String>.of(state.expandedNodeIds);
    if (!expandedNodeIds.remove(event.nodeId)) {
      expandedNodeIds.add(event.nodeId);
    }

    emitter(state.copyWith(expandedNodeIds: expandedNodeIds));
  }

  /// Selects quote line `event.lineId`, opening the right dock on the `Inspector` tab — mirrors
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

    emitter(
      state.copyWith(
        selection: OcptBudgetLineSelection(event.lineId),
        rightDockTab: OcptBudgetRightDockTab.inspector,
        lastRightDockTab: OcptBudgetRightDockTab.inspector,
        selectionEpoch: state.selectionEpoch + 1,
        selectionCause: OcptBudgetSelectionCause.selected,
      ),
    );
  }

  /// Selects commitment `event.commitmentId`, opening the right dock on the `Inspector` tab —
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
      state.copyWith(
        selection: OcptBudgetCommitmentSelection(event.commitmentId),
        rightDockTab: OcptBudgetRightDockTab.inspector,
        lastRightDockTab: OcptBudgetRightDockTab.inspector,
        selectionEpoch: state.selectionEpoch + 1,
        selectionCause: OcptBudgetSelectionCause.selected,
      ),
    );
  }

  /// Selects journal entry `event.entryId`, opening the right dock on the `Inspector` tab —
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

    emitter(
      state.copyWith(
        selection: OcptBudgetEntrySelection(event.entryId),
        rightDockTab: OcptBudgetRightDockTab.inspector,
        lastRightDockTab: OcptBudgetRightDockTab.inspector,
        selectionEpoch: state.selectionEpoch + 1,
        selectionCause: OcptBudgetSelectionCause.selected,
      ),
    );
  }

  /// Selects receipt `event.receiptId` — a sub-row of the resources tree — opening the right dock
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
      state.copyWith(
        selection: OcptBudgetReceiptSelection(event.receiptId),
        rightDockTab: OcptBudgetRightDockTab.inspector,
        lastRightDockTab: OcptBudgetRightDockTab.inspector,
        selectionEpoch: state.selectionEpoch + 1,
        selectionCause: OcptBudgetSelectionCause.selected,
      ),
    );
  }

  /// Selects the poste, the quote line, the resource or the taking a view has just created, without
  /// writing what is pending: the view did so, and has read the snapshot again. A poste and a line
  /// open the right dock on the `Inspector` tab, a resource and a taking do not.
  Future<void> _onSelectionCreated(
    OcptBudgetSelectionCreatedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    emitter(
      state.copyWith(
        selection: event.selection,
        rightDockTab: event.opensInspector ? OcptBudgetRightDockTab.inspector : null,
        lastRightDockTab: event.opensInspector ? OcptBudgetRightDockTab.inspector : null,
        selectionEpoch: state.selectionEpoch + 1,
        selectionCause: OcptBudgetSelectionCause.created,
      ),
    );
  }

  /// Highlights the share a view has just created, without writing what is pending.
  Future<void> _onShareCreated(
    OcptBudgetShareCreatedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    emitter(
      state.copyWith(
        selectedShareId: event.shareId,
        selectionEpoch: state.selectionEpoch + 1,
        selectionCause: OcptBudgetSelectionCause.created,
      ),
    );
  }

  /// Re-reads the project's currency and default VAT rate after the project settings page changed
  /// something — mirrors `OcptScheduleProjectSettingsChangedEvent`'s own handler.
  Future<void> _onProjectSettingsChanged(
    OcptBudgetProjectSettingsChangedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _applyBudgetSnapshot(emitter, project);
  }

  /// Narrows every view of the mode to `event.posteId`, or clears the filter when it is null — see
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
      emitter(
        state.copyWith(
          forceFilterPosteIdValue: true,
          selectionEpoch: state.selectionEpoch + 1,
          selectionCause: OcptBudgetSelectionCause.filtered,
        ),
      );
      return;
    }

    if (state.postes.any((poste) => poste.id == posteId)) {
      emitter(
        state.copyWith(
          filterPosteId: posteId,
          selectionEpoch: state.selectionEpoch + 1,
          selectionCause: OcptBudgetSelectionCause.filtered,
        ),
      );
    }
  }

  /// Re-reads the quote of [project] and applies it, reconciling [OcptBudgetState.selection]
  /// against what the fresh snapshot still holds — whichever object it names, gone missing, is
  /// dropped rather than trusted to still mean something. `OcptBudgetReceiptSelection` names a
  /// `budget_entries` row exactly as `OcptBudgetEntrySelection` does, so it is checked against
  /// [OcptBudgetSnapshot.entries] the same way; this also covers
  /// `OcptBudgetState.selectedRevenueId`, which is now a getter over [OcptBudgetState.selection]
  /// rather than a field of its own.
  ///
  /// Every handler that writes to the quote tables ends here, which is also the mode's own stand-in
  /// for "a save landing while the `Versions` tab is open":
  /// [OcptProjectWorkingCopyRefreshRequestedEvent] is dispatched once the fresh snapshot has
  /// landed, mirroring `OcptScheduleBloc ._applyScheduleSnapshot`.
  Future<void> _applyBudgetSnapshot(
    Emitter<OcptBudgetState> emitter,
    OcptOpenProjectModel project,
  ) => runSerially(() => _readBudgetSnapshot(emitter, project));

  /// Reads [project]'s whole snapshot, reconciles the shared selection against it, emits both in
  /// one state, and asks for a fresh working-copy capture while the `Versions` tab is open.
  ///
  /// Not queued: [_applyBudgetSnapshot] and [reloadScopesIn] queue it, each in its own way. Whatever
  /// the selection, the filter or the share named that the snapshot no longer holds is dropped in
  /// the very state that carries the snapshot, and moves the selection epoch with
  /// [OcptBudgetSelectionCause.reconciled].
  Future<void> _readBudgetSnapshot(
    Emitter<OcptBudgetState> emitter,
    OcptOpenProjectModel project,
  ) async {
    final loaded = await _loadBudgetSnapshot(project);
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

    final hasDroppedSelection = !selectionStillExists || !filterStillExists || !shareStillExists;

    emitter(
      state.copyWith(
        snapshot: snapshot,
        currencyCode: snapshot.currencyCode,
        roles: loaded.roles,
        people: loaded.people,
        elements: loaded.elements,
        mileageRates: loaded.mileageRates,
        provisionPosteId:
            state.provisionPosteId != null &&
                loaded.snapshot.postes.any((poste) => poste.id == state.provisionPosteId)
            ? state.provisionPosteId
            : _defaultProvisionPosteIdOf(loaded.snapshot.postes),
        regieDecorNameByDayId: loaded.regieDecorNameByDayId,
        forceSelectionValue: !selectionStillExists,
        forceFilterPosteIdValue: !filterStillExists,
        forceSelectedShareIdValue: !shareStillExists,
        selectionEpoch: hasDroppedSelection ? state.selectionEpoch + 1 : null,
        selectionCause: hasDroppedSelection ? OcptBudgetSelectionCause.reconciled : null,
      ),
    );

    if (state.rightDockTab == OcptBudgetRightDockTab.versions) {
      add(const OcptProjectWorkingCopyRefreshRequestedEvent());
    }
  }

  /// Selects financing resource `event.resourceId`, opening the right dock on the `Inspector` tab —
  /// mirrors [_onPosteSelected]. A resource id naming no live resource is ignored.
  Future<void> _onResourceSelected(
    OcptBudgetResourceSelectedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    if (!state.resources.any((resource) => resource.id == event.resourceId)) {
      return;
    }

    emitter(
      state.copyWith(
        selection: OcptBudgetResourceSelection(event.resourceId),
        rightDockTab: OcptBudgetRightDockTab.inspector,
        lastRightDockTab: OcptBudgetRightDockTab.inspector,
        selectionEpoch: state.selectionEpoch + 1,
        selectionCause: OcptBudgetSelectionCause.selected,
      ),
    );
  }

  /// Points the provisioning at `event.posteId` — a selection, written nowhere.
  void _onProvisionPosteSelected(
    OcptBudgetProvisionPosteSelectedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) => emitter(
    state.copyWith(
      provisionPosteId: event.posteId,
      selectionEpoch: state.selectionEpoch + 1,
      selectionCause: OcptBudgetSelectionCause.provisionSelected,
    ),
  );

  /// Selects taking `event.revenueId`, opening the right dock on the `Inspector` tab — mirrors
  /// [_onResourceSelected]. A revenue id naming no live revenue is ignored.
  Future<void> _onRevenueSelected(
    OcptBudgetRevenueSelectedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    if (!state.revenues.any((revenue) => revenue.id == event.revenueId)) {
      return;
    }

    emitter(
      state.copyWith(
        selection: OcptBudgetRevenueSelection(event.revenueId),
        rightDockTab: OcptBudgetRightDockTab.inspector,
        lastRightDockTab: OcptBudgetRightDockTab.inspector,
        selectionEpoch: state.selectionEpoch + 1,
        selectionCause: OcptBudgetSelectionCause.selected,
      ),
    );
  }

  /// Selects share `event.shareId`, drawn as a plain highlight — mirrors [_onRevenueSelected]. A
  /// share id naming no live share is ignored.
  Future<void> _onShareSelected(
    OcptBudgetShareSelectedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    if (!state.shares.any((share) => share.id == event.shareId)) {
      return;
    }

    emitter(
      state.copyWith(
        selectedShareId: event.shareId,
        selectionEpoch: state.selectionEpoch + 1,
        selectionCause: OcptBudgetSelectionCause.shareSelected,
      ),
    );
  }
}
