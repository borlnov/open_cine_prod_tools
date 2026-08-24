// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
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
import 'package:open_cine_prod_tools/models/ocpt_budget_entry_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_mileage_rate.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste_seed.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_document.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_selection.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_package_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_versions_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_vat.dart';
import 'package:open_cine_prod_tools/utils/ocpt_cost_amount.dart';

/// This is the bloc class for the budget production mode.
///
/// It loads the current project's title and the mode's own whole read on entry: the quote itself
/// ([_budgetQuoteService], seeding [_seed]'s ten CNC postes on the first read of an empty table),
/// the cash journal ([_budgetJournalService]: every live entry and commitment, and every live
/// voucher keyed by the entry it evidences), the financing plan ([_budgetFinancingService]: every
/// live resource and mileage rate), the catering-and-travel pass's own reads ([_scheduleService]'s
/// schedule, [_roleIndexService]'s roles, [_peopleService]'s people and [_locationsService]'s
/// locations — the last read only to name the decor a day shoots at, never carried on state itself),
/// the breakdown's own elements catalogue ([_elementsService], read the same way
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
/// `OcptScheduleBloc`'s own pair — there is no left fraction, this mode having no left dock.
///
/// Every write but the free-text fields (which ride [_fieldEditDebounce], flushed by
/// [_flushPendingFieldEdits] on a selection change, a dock tab change, a version preview and the
/// mode's own `deactivate()`) lands the moment it is dispatched, then reloads the quote snapshot
/// through [_applyBudgetSnapshot] — which also reconciles [OcptBudgetState.selection] against the
/// freshly loaded snapshot, and, while the `Versions` tab is open, asks
/// [MixinOcptProjectVersionsBloc] for a fresh working-copy capture, the mode's own stand-in for "a
/// save landing while it is open".
///
/// It mixes in [MixinOcptProjectPackageBloc] too: the `Export` panel's own standing project-package
/// card is wired here exactly as every other mode's is, even though this milestone offers no
/// document of its own — see `OcptBudgetMode`'s own doc comment for why the panel still opens.
class OcptBudgetBloc extends BlocForMixin<OcptBudgetState>
    with
        MixinOcptProjectVersionsBloc<OcptBudgetState>,
        MixinOcptProjectPackageBloc<OcptBudgetState> {
  /// The default delay between the last field edit and its autosave write.
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
  /// dashboard's own breakdown reading counts against, and what `+ From breakdown` picks a fresh
  /// quote line from. Mirrors `OcptScheduleBloc._elementsService`.
  final OcptElementsService _elementsService;

  /// The ten CNC postes, already localized — see the class doc comment for why this is a
  /// constructor argument captured once rather than watched.
  final List<OcptBudgetPosteSeed> _seed;

  /// The delay between the last field edit and its autosave write.
  final Duration _fieldEditDebounce;

  /// The running field-edit debounce timer, if any.
  Timer? _fieldEditTimer;

  /// Class constructor
  ///
  /// Every dependency can be overridden, which is what the tests do; in the app they all resolve
  /// through [globalGetIt]. [fieldEditDebounce] is only meant to be overridden by tests, to keep it
  /// fast and deterministic.
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
    Duration fieldEditDebounce = defaultFieldEditDebounce,
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
       _fieldEditDebounce = fieldEditDebounce,
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
    on<OcptBudgetDocumentSelectedEvent>(_onDocumentSelected);
    on<OcptBudgetDocumentReadingSelectedEvent>(_onDocumentReadingSelected);
    on<OcptBudgetSubPageSelectedEvent>(_onSubPageSelected);
    on<OcptBudgetSimplifiedToggledEvent>(_onSimplifiedToggled);
    on<OcptBudgetTaxBasisChangedEvent>(_onTaxBasisChanged);
    on<OcptBudgetPosteSelectedEvent>(_onPosteSelected);
    on<OcptBudgetPosteCreatedEvent>(_onPosteCreated);
    on<OcptBudgetPosteReorderedEvent>(_onPosteReordered);
    on<OcptBudgetPosteDeletionConfirmedEvent>(_onPosteDeletionConfirmed);
    on<OcptBudgetRowExpansionToggledEvent>(_onRowExpansionToggled);
    on<OcptBudgetLineSelectedEvent>(_onLineSelected);
    on<OcptBudgetCommitmentSelectedEvent>(_onCommitmentSelected);
    on<OcptBudgetEntrySelectedEvent>(_onEntrySelected);
    on<OcptBudgetLineCreatedEvent>(_onLineCreated);
    on<OcptBudgetLineCreatedFromElementEvent>(_onLineCreatedFromElement);
    on<OcptBudgetLineDeletionConfirmedEvent>(_onLineDeletionConfirmed);
    on<OcptBudgetLineTaxInclusiveChangedEvent>(_onLineTaxInclusiveChanged);
    on<OcptBudgetLineVatRateInheritedRequestedEvent>(_onLineVatRateInheritedRequested);
    on<OcptBudgetPosteEstimateToCompleteDerivedRequestedEvent>(
      _onPosteEstimateToCompleteDerivedRequested,
    );
    on<OcptBudgetFieldChangedEvent>(_onFieldChanged);
    on<OcptBudgetFieldEditFlushRequestedEvent>(_onFieldEditFlushRequested);
    on<OcptBudgetProjectSettingsChangedEvent>(_onProjectSettingsChanged);
    on<OcptBudgetEntryCreationConfirmedEvent>(_onEntryCreationConfirmed);
    on<OcptBudgetEntryUpdateConfirmedEvent>(_onEntryUpdateConfirmed);
    on<OcptBudgetEntryDeletionConfirmedEvent>(_onEntryDeletionConfirmed);
    on<OcptBudgetPosteFilterSelectedEvent>(_onPosteFilterSelected);
    on<OcptBudgetCommitmentCreationConfirmedEvent>(_onCommitmentCreationConfirmed);
    on<OcptBudgetCommitmentUpdateConfirmedEvent>(_onCommitmentUpdateConfirmed);
    on<OcptBudgetCommitmentDeletionConfirmedEvent>(_onCommitmentDeletionConfirmed);
    on<OcptBudgetCommitmentSettlementConfirmedEvent>(_onCommitmentSettlementConfirmed);
    on<OcptBudgetCommitmentUnsettleRequestedEvent>(_onCommitmentUnsettleRequested);
    on<OcptBudgetResourceSelectedEvent>(_onResourceSelected);
    on<OcptBudgetAllowanceCreationConfirmedEvent>(_onAllowanceCreationConfirmed);
    on<OcptBudgetAllowanceUpdateConfirmedEvent>(_onAllowanceUpdateConfirmed);
    on<OcptBudgetAllowanceDeletionConfirmedEvent>(_onAllowanceDeletionConfirmed);
    on<OcptBudgetProvisionPosteSelectedEvent>(_onProvisionPosteSelected);
    on<OcptBudgetProvisionConfirmedEvent>(_onProvisionConfirmed);
    on<OcptBudgetResourceCreationConfirmedEvent>(_onResourceCreationConfirmed);
    on<OcptBudgetResourceUpdateConfirmedEvent>(_onResourceUpdateConfirmed);
    on<OcptBudgetResourceDeletionConfirmedEvent>(_onResourceDeletionConfirmed);
    on<OcptBudgetRevenueSelectedEvent>(_onRevenueSelected);
    on<OcptBudgetRevenueCreationConfirmedEvent>(_onRevenueCreationConfirmed);
    on<OcptBudgetRevenueUpdateConfirmedEvent>(_onRevenueUpdateConfirmed);
    on<OcptBudgetRevenueReorderedEvent>(_onRevenueReordered);
    on<OcptBudgetRevenueDeletionConfirmedEvent>(_onRevenueDeletionConfirmed);
    on<OcptBudgetShareSelectedEvent>(_onShareSelected);
    on<OcptBudgetShareCreationConfirmedEvent>(_onShareCreationConfirmed);
    on<OcptBudgetShareUpdateConfirmedEvent>(_onShareUpdateConfirmed);
    on<OcptBudgetShareReorderedEvent>(_onShareReordered);
    on<OcptBudgetShareDeletionConfirmedEvent>(_onShareDeletionConfirmed);
    on<OcptBudgetQuoteExportRequestedEvent>(_onQuoteExportRequested);
    on<OcptBudgetFinancingPlanExportRequestedEvent>(_onFinancingPlanExportRequested);
    on<OcptBudgetCashJournalExportRequestedEvent>(_onCashJournalExportRequested);
    on<OcptBudgetFinancialReportExportRequestedEvent>(_onFinancialReportExportRequested);
    on<OcptBudgetIoNoticeDismissedEvent>(_onIoNoticeDismissed);
  }

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsBloc.projectsManager}
  @protected
  @override
  OcptProjectsManager get projectsManager => _projectsManager;

  /// {@macro open_cine_prod_tools.MixinOcptProjectPackageBloc.exportManager}
  @protected
  @override
  OcptExportManager get exportManager => _exportManager;

  /// Writes whatever free-text field edit is still sitting in the field-edit debounce, so a preview
  /// about to swap the database can't send it into the previewed version instead, then clears the
  /// selection: whatever it named out of the working copy's own catalogue means nothing once a
  /// preview swaps that data out.
  @protected
  @override
  Future<void> flushPendingProjectWrites(Emitter<OcptBudgetState> emitter) async {
    await _flushPendingFieldEdits(emitter);
    emitter(
      state.copyWith(
        clearSelection: true,
        clearSelectedRevenueId: true,
        clearSelectedShareId: true,
      ),
    );
  }

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
          clearPreviewedVersionId: true,
          clearSelection: true,
          clearSelectedRevenueId: true,
          clearSelectedShareId: true,
          pendingFieldEdits: const {},
          roles: const [],
          people: const [],
          elements: const [],
          regieDecorNameByDayId: const {},
        ),
      );
      return;
    }

    final previewedVersion = project.previewedVersion;
    final loaded = await _loadBudgetSnapshot(project);
    final pageSetup = await _loadPageSetup(project);

    emitter(
      state.copyWith(
        isLoading: false,
        title: project.name,
        previewedVersionId: previewedVersion?.id,
        clearPreviewedVersionId: previewedVersion == null,
        snapshot: loaded.snapshot,
        currencyCode: loaded.snapshot.currencyCode,
        clearSelection: true,
        clearSelectedRevenueId: true,
        clearSelectedShareId: true,
        pendingFieldEdits: const {},
        roles: loaded.roles,
        people: loaded.people,
        elements: loaded.elements,
        mileageRates: loaded.mileageRates,
        provisionPosteId: _defaultProvisionPosteIdOf(loaded.snapshot.postes),
        regieDecorNameByDayId: loaded.regieDecorNameByDayId,
        rightDockFraction: rightDockFraction,
        lastRightDockTab: lastRightDockTab,
        pageSetup: pageSetup,
      ),
    );
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
        margins: await _propertiesManager.pageMargins.load() ?? const FountainPageMargins.standard(),
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
  /// [OcptBudgetSnapshot]: `OcptBudgetPosteInspector`'s own `+ From breakdown` picker needs the
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

    return postes.any((poste) => poste.id == regiePosteId)
        ? regiePosteId
        : postes.firstOrNull?.id;
  }

  /// The decor name `OcptBudgetRegie` prints under each shooting day: the name of the first set, or
  /// failing that the first location, that any of [days]' own [slotsByDayId] entries name, in slot
  /// order — resolved out of [locations] (and their own live sets) alone. `lib/utils
  /// /ocpt_budget_regie.dart`'s own pass reads no location or set at all, being pure arithmetic over
  /// head counts, so this is a separate, purely presentational reading rather than a second
  /// implementation of anything that file states. A day whose slots name neither carries no key
  /// here, which the view reads as nothing rather than a placeholder.
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
    await _flushPendingFieldEdits(emitter);

    final isAlreadyActive = state.rightDockTab == event.tab;
    await _persistLastRightDockTab(event.tab);
    emitter(
      state.copyWith(
        rightDockTab: isAlreadyActive ? null : event.tab,
        clearRightDockTab: isAlreadyActive,
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
      emitter(state.copyWith(clearRightDockTab: true));
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
    emitter(state.copyWith(clearRightDockTab: true));
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

  /// Switches which of the mode's three documents is shown, and returns to its own top level —
  /// dispatched by one of the header's own three chips, and by the breadcrumb's own document
  /// ancestor.
  Future<void> _onDocumentSelected(
    OcptBudgetDocumentSelectedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    // Flushed here for the reason a selection change and a dock tab change already flush: the user
    // has stopped typing and is about to *read* figures somewhere else. Without it, an amount typed
    // in the cost-tracking table and followed straight by a click on `Resources` was still sitting
    // in the debounce, so that document drew the snapshot from before it — and corrected itself two
    // seconds later, once the timer fired. The write was never lost; it simply was not shown, which
    // reads exactly like an app that ignores what it is told.
    await _flushPendingFieldEdits(emitter);

    emitter(state.copyWith(document: event.document, clearSubPage: true));
  }

  /// Switches which order the current document's own rows are read in, and returns to its own top
  /// level — dispatched by the header's own reading switch, offered on
  /// `OcptBudgetDocument.expenses` alone.
  ///
  /// **Also clears `OcptBudgetState.subPage`**, mirroring [_onDocumentSelected]'s own reason:
  /// picking a reading is itself a "go to this top-level reading" gesture, and is the way back to
  /// either the cost-tracking table or the cash journal from inside a sub-page.
  Future<void> _onDocumentReadingSelected(
    OcptBudgetDocumentReadingSelectedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    await _flushPendingFieldEdits(emitter);

    emitter(state.copyWith(reading: event.reading, clearSubPage: true));
  }

  /// Opens sub-page `event.subPage` of `OcptBudgetDocument.expenses` — dispatched by whichever
  /// gesture already led to it before this milestone (`OcptBudgetSubPageSelectedEvent`'s own doc
  /// comment names every one of them).
  ///
  /// Sets [OcptBudgetState.document] to `expenses` defensively: every gesture that reaches this
  /// today already stands on that document, but a sub-page belongs to it and to no other.
  Future<void> _onSubPageSelected(
    OcptBudgetSubPageSelectedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    await _flushPendingFieldEdits(emitter);

    emitter(state.copyWith(document: OcptBudgetDocument.expenses, subPage: event.subPage));
  }

  /// Toggles the header's simplified/detailed switch.
  Future<void> _onSimplifiedToggled(
    OcptBudgetSimplifiedToggledEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    // Flushed for [_onCentreViewSelected]'s own reason: both toggles re-read the very figures a
    // pending edit has not reached yet.
    await _flushPendingFieldEdits(emitter);

    emitter(state.copyWith(isSimplified: event.isSimplified));
  }

  /// Switches the header's excluding/including-tax toggle.
  Future<void> _onTaxBasisChanged(
    OcptBudgetTaxBasisChangedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    // Flushed for [_onCentreViewSelected]'s own reason: both toggles re-read the very figures a
    // pending edit has not reached yet.
    await _flushPendingFieldEdits(emitter);

    emitter(state.copyWith(taxBasis: event.basis));
  }

  /// Selects poste `event.posteId`, opening the right dock on the `Inspector` tab. A poste id
  /// naming no live poste is ignored. Flushes any pending field edit first: switching which poste's
  /// own fields are on screen is exactly the selection change every other mode flushes on.
  Future<void> _onPosteSelected(
    OcptBudgetPosteSelectedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    await _flushPendingFieldEdits(emitter);

    if (!state.postes.any((poste) => poste.id == event.posteId)) {
      return;
    }

    emitter(
      state.copyWith(
        selection: OcptBudgetPosteSelection(event.posteId),
        rightDockTab: OcptBudgetRightDockTab.inspector,
        lastRightDockTab: OcptBudgetRightDockTab.inspector,
      ),
    );
  }

  /// Creates a new, unnamed poste, appended at the end of the catalogue, and selects it.
  Future<void> _onPosteCreated(
    OcptBudgetPosteCreatedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final posteId = await _budgetQuoteService.createPoste(database: project.database, label: "");

    await _applyBudgetSnapshot(emitter, project);
    if (posteId != null) {
      emitter(
        state.copyWith(
          selection: OcptBudgetPosteSelection(posteId),
          rightDockTab: OcptBudgetRightDockTab.inspector,
          lastRightDockTab: OcptBudgetRightDockTab.inspector,
        ),
      );
    }
  }

  /// Moves poste `event.posteId` to `event.newPosition` within the catalogue's flat order.
  Future<void> _onPosteReordered(
    OcptBudgetPosteReorderedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _budgetQuoteService.reorderPoste(
      database: project.database,
      posteId: event.posteId,
      newPosition: event.newPosition,
    );
    await _applyBudgetSnapshot(emitter, project);
  }

  /// Deletes poste `event.posteId` for good, along with every quote line it holds, confirmed by the
  /// mode's own `OcptConfirmDialog`.
  Future<void> _onPosteDeletionConfirmed(
    OcptBudgetPosteDeletionConfirmedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _budgetQuoteService.deletePoste(database: project.database, posteId: event.posteId);
    await _applyBudgetSnapshot(emitter, project);
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
    await _flushPendingFieldEdits(emitter);

    if (!state.postes.any((poste) => poste.lines.any((line) => line.id == event.lineId))) {
      return;
    }

    emitter(
      state.copyWith(
        selection: OcptBudgetLineSelection(event.lineId),
        rightDockTab: OcptBudgetRightDockTab.inspector,
        lastRightDockTab: OcptBudgetRightDockTab.inspector,
      ),
    );
  }

  /// Selects commitment `event.commitmentId`, opening the right dock on the `Inspector` tab —
  /// mirrors [_onLineSelected]. A commitment id naming no live commitment is ignored.
  Future<void> _onCommitmentSelected(
    OcptBudgetCommitmentSelectedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    await _flushPendingFieldEdits(emitter);

    if (!state.commitments.any((commitment) => commitment.id == event.commitmentId)) {
      return;
    }

    emitter(
      state.copyWith(
        selection: OcptBudgetCommitmentSelection(event.commitmentId),
        rightDockTab: OcptBudgetRightDockTab.inspector,
        lastRightDockTab: OcptBudgetRightDockTab.inspector,
      ),
    );
  }

  /// Selects journal entry `event.entryId`, opening the right dock on the `Inspector` tab —
  /// mirrors [_onLineSelected]. An entry id naming no live entry is ignored.
  Future<void> _onEntrySelected(
    OcptBudgetEntrySelectedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    await _flushPendingFieldEdits(emitter);

    if (!state.entries.any((entry) => entry.id == event.entryId)) {
      return;
    }

    emitter(
      state.copyWith(
        selection: OcptBudgetEntrySelection(event.entryId),
        rightDockTab: OcptBudgetRightDockTab.inspector,
        lastRightDockTab: OcptBudgetRightDockTab.inspector,
      ),
    );
  }

  /// Creates a new, unnamed quote line inside poste `event.posteId`, appended at the end of its own
  /// lines, and selects it, opening the right dock on the `Inspector` tab — a line is now selected
  /// rather than expanded, mirroring [_onLineSelected].
  Future<void> _onLineCreated(
    OcptBudgetLineCreatedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final lineId = await _budgetQuoteService.createLine(
      database: project.database,
      posteId: event.posteId,
      label: "",
    );

    await _applyBudgetSnapshot(emitter, project);
    if (lineId != null) {
      emitter(
        state.copyWith(
          selection: OcptBudgetLineSelection(lineId),
          rightDockTab: OcptBudgetRightDockTab.inspector,
          lastRightDockTab: OcptBudgetRightDockTab.inspector,
        ),
      );
    }
  }

  /// Creates a new quote line inside poste `event.posteId` **from** breakdown element
  /// `event.elementId`, and selects it — dispatched by the poste fiche's own `From breakdown`
  /// action once its picker has returned an element. An element id naming no live element of
  /// [OcptBudgetState.elements] is ignored: the picker only ever offers a live one, so this should
  /// not happen outside a stale dialog result.
  ///
  /// Mints the line with `OcptElement.name` as its own label and `elementId` naming the element —
  /// `element.cost` seeds `unitAmountCents` when it is known, and is passed on as
  /// [Value.absent] rather than [Value] of zero when it is not: see
  /// `OcptBudgetQuoteService.createLine`'s own doc comment for why a null cost is not a zero unit
  /// price.
  Future<void> _onLineCreatedFromElement(
    OcptBudgetLineCreatedFromElementEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    OcptElement? element;
    for (final candidate in state.elements) {
      if (candidate.id == event.elementId) {
        element = candidate;
        break;
      }
    }
    if (element == null) {
      return;
    }

    final cost = element.cost;
    final lineId = await _budgetQuoteService.createLine(
      database: project.database,
      posteId: event.posteId,
      label: element.name,
      elementId: Value(element.id),
      unitAmountCents: cost == null ? const Value.absent() : Value(cost),
    );

    await _applyBudgetSnapshot(emitter, project);
    if (lineId != null) {
      emitter(
        state.copyWith(
          selection: OcptBudgetLineSelection(lineId),
          rightDockTab: OcptBudgetRightDockTab.inspector,
          lastRightDockTab: OcptBudgetRightDockTab.inspector,
        ),
      );
    }
  }

  /// Deletes quote line `event.lineId` for good, confirmed by the mode's own `OcptConfirmDialog`.
  Future<void> _onLineDeletionConfirmed(
    OcptBudgetLineDeletionConfirmedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _budgetQuoteService.deleteLine(database: project.database, lineId: event.lineId);
    await _applyBudgetSnapshot(emitter, project);
  }

  /// Writes a new including/excluding-tax basis onto line `event.lineId`'s own unit price
  /// immediately — a pick, not typing.
  Future<void> _onLineTaxInclusiveChanged(
    OcptBudgetLineTaxInclusiveChangedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _budgetQuoteService.updateLine(
      database: project.database,
      lineId: event.lineId,
      isTaxInclusive: Value(event.isTaxInclusive),
    );
    await _applyBudgetSnapshot(emitter, project);
  }

  /// Puts line `event.lineId`'s own VAT rate back to inheriting the project's default, immediately —
  /// see `OcptBudgetLineVatRateInheritedRequestedEvent`'s own doc comment for why this is a
  /// dedicated event rather than something an empty field submission could trigger.
  Future<void> _onLineVatRateInheritedRequested(
    OcptBudgetLineVatRateInheritedRequestedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _budgetQuoteService.updateLine(
      database: project.database,
      lineId: event.lineId,
      vatRateBasisPoints: const Value(null),
    );
    await _applyBudgetSnapshot(emitter, project);
  }

  /// Puts poste `event.posteId`'s own estimate to complete back to being derived, immediately — see
  /// `OcptBudgetPosteEstimateToCompleteDerivedRequestedEvent`'s own doc comment.
  Future<void> _onPosteEstimateToCompleteDerivedRequested(
    OcptBudgetPosteEstimateToCompleteDerivedRequestedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _budgetQuoteService.updatePoste(
      database: project.database,
      posteId: event.posteId,
      estimateToCompleteCents: const Value(null),
    );
    await _applyBudgetSnapshot(emitter, project);
  }

  /// Records the raw text just typed into a field as a pending edit, visible immediately, and
  /// (re)starts the field-edit debounce.
  Future<void> _onFieldChanged(
    OcptBudgetFieldChangedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    final pending = Map<OcptBudgetPendingFieldKey, String>.of(state.pendingFieldEdits)
      ..[(event.targetId, event.field)] = event.rawValue;
    emitter(state.copyWith(pendingFieldEdits: pending));

    _fieldEditTimer?.cancel();
    _fieldEditTimer = Timer(_fieldEditDebounce, () {
      if (!isClosed) {
        add(const OcptBudgetFieldEditFlushRequestedEvent());
      }
    });
  }

  /// Fired by the field-edit debounce timer: writes every pending field edit.
  Future<void> _onFieldEditFlushRequested(
    OcptBudgetFieldEditFlushRequestedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) => _flushPendingFieldEdits(emitter);

  /// Writes every field edit still sitting in the debounce, cancelling the running timer first.
  ///
  /// A no-op when nothing is pending: called on every selection-changing path and on every
  /// version-preview transition, most of which have nothing waiting.
  Future<void> _flushPendingFieldEdits(Emitter<OcptBudgetState> emitter) async {
    _fieldEditTimer?.cancel();
    _fieldEditTimer = null;

    final edits = state.pendingFieldEdits;
    if (edits.isEmpty) {
      return;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      emitter(state.copyWith(pendingFieldEdits: const {}));
      return;
    }

    await _writeAllPendingFieldEdits(project, edits);

    emitter(state.copyWith(pendingFieldEdits: const {}));
    await _applyBudgetSnapshot(emitter, project);
  }

  /// Writes every pending field edit directly to the database, bypassing both the debounce timer
  /// and the bloc's own event queue.
  ///
  /// Called by the mode's own `deactivate()`, mirroring `OcptScheduleBloc.flushPendingFieldEdits`:
  /// `deactivate()` runs before `dispose()` for every removal from the tree, so triggering the
  /// write here — rather than dispatching an event, which would only be processed on a later
  /// microtask this widget might not survive to see — is what guarantees the last
  /// [_fieldEditDebounce] worth of typing isn't lost. Unlike [_flushPendingFieldEdits], this never
  /// touches [state]: `emit` may only be called from inside a registered `on<Event>` handler, and
  /// by the time this runs the widget tree that would show a fresh state is already gone anyway. A
  /// failure here is only logged.
  Future<void> flushPendingFieldEdits() async {
    _fieldEditTimer?.cancel();
    _fieldEditTimer = null;

    final edits = state.pendingFieldEdits;
    if (edits.isEmpty) {
      return;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      await _writeAllPendingFieldEdits(project, edits);
    } catch (error) {
      appLogger().e("A problem occurred when tried to flush a pending budget field edit of the "
          "project at ${project.path}: $error");
    }
  }

  /// Writes every one of [edits] to [project]'s database, one write per entry — the shared write
  /// loop [_flushPendingFieldEdits] and [flushPendingFieldEdits] both run, so the switch over
  /// [OcptBudgetField] is written once.
  ///
  /// The four numeric fields ([OcptBudgetField.posteEstimateToComplete],
  /// [OcptBudgetField.lineQuantity], [OcptBudgetField.lineUnitAmount],
  /// [OcptBudgetField.lineVatRateOverride]) are parsed here, and a submission that doesn't parse is
  /// **skipped** rather than written: `quantityMilli` and `unitAmountCents` are never nullable, so
  /// there is no null they could legitimately become, and an estimate's or an override's own
  /// empty/unparseable reading is deliberately not "clear it" (`OcptBudgetField`'s own doc comment) —
  /// the field simply reverts to whatever the database already holds on the next read.
  Future<void> _writeAllPendingFieldEdits(
    OcptOpenProjectModel project,
    Map<OcptBudgetPendingFieldKey, String> edits,
  ) async {
    for (final entry in edits.entries) {
      final (targetId, field) = entry.key;
      final value = entry.value;

      switch (field) {
        case OcptBudgetField.posteLabel:
          await _budgetQuoteService.updatePoste(
            database: project.database,
            posteId: targetId,
            label: Value(value),
          );
        case OcptBudgetField.posteCode:
          await _budgetQuoteService.updatePoste(
            database: project.database,
            posteId: targetId,
            code: Value(value),
          );
        case OcptBudgetField.posteSimpleLabel:
          await _budgetQuoteService.updatePoste(
            database: project.database,
            posteId: targetId,
            simpleLabel: Value(value.isEmpty ? null : value),
          );
        case OcptBudgetField.posteEstimateToComplete:
          final amountCents = ocptCostCentsOf(value);
          if (amountCents != null) {
            await _budgetQuoteService.updatePoste(
              database: project.database,
              posteId: targetId,
              estimateToCompleteCents: Value(amountCents),
            );
          }
        case OcptBudgetField.lineLabel:
          await _budgetQuoteService.updateLine(
            database: project.database,
            lineId: targetId,
            label: Value(value),
          );
        case OcptBudgetField.lineQuantity:
          final quantityMilli = ocptBudgetQuantityMilliOf(value);
          if (quantityMilli != null) {
            await _budgetQuoteService.updateLine(
              database: project.database,
              lineId: targetId,
              quantityMilli: Value(quantityMilli),
            );
          }
        case OcptBudgetField.lineUnit:
          await _budgetQuoteService.updateLine(
            database: project.database,
            lineId: targetId,
            unit: Value(value),
          );
        case OcptBudgetField.lineUnitAmount:
          final amountCents = ocptCostCentsOf(value);
          if (amountCents != null) {
            await _budgetQuoteService.updateLine(
              database: project.database,
              lineId: targetId,
              unitAmountCents: Value(amountCents),
            );
          }
        case OcptBudgetField.lineVatRateOverride:
          final basisPoints = ocptVatRateBasisPointsOf(value);
          if (basisPoints != null) {
            await _budgetQuoteService.updateLine(
              database: project.database,
              lineId: targetId,
              vatRateBasisPoints: Value(basisPoints),
            );
          }
        case OcptBudgetField.lineNotes:
          await _budgetQuoteService.updateLine(
            database: project.database,
            lineId: targetId,
            notes: Value(value),
          );
      }
    }
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

  /// Creates a new cash-journal entry from `event.fields`, writing its typed amount onto whichever
  /// of `debitCents`/`creditCents` [OcptBudgetEntryFormFields.isDebit] names and zero onto the
  /// other — the one reading no single database column mirrors, see that model's own doc comment.
  ///
  /// Writes whatever `event.fields` collected about the fresh entry's own voucher
  /// ([_writeEntryReceiptChange]) once it exists, in this very handler, before the one reload at
  /// its end.
  Future<void> _onEntryCreationConfirmed(
    OcptBudgetEntryCreationConfirmedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final fields = event.fields;
    final revenueId = await _createNewRevenueOf(project, fields);
    final entryId = await _budgetJournalService.createEntry(
      database: project.database,
      date: fields.date,
      label: fields.label,
      posteId: fields.posteId,
      resourceId: fields.resourceId,
      revenueId: revenueId ?? fields.revenueId,
      shareId: fields.shareId,
      debitCents: fields.isDebit ? fields.amountCents : 0,
      creditCents: fields.isDebit ? 0 : fields.amountCents,
      isTaxInclusive: fields.isTaxInclusive,
      vatRateBasisPoints: fields.vatRateBasisPoints,
    );
    if (entryId != null) {
      await _writeEntryReceiptChange(project, entryId, fields);
    }

    await _applyBudgetSnapshot(emitter, project);
  }

  /// Writes `event.fields` onto entry `event.entryId`, including its own voucher number — see
  /// [OcptBudgetEntryFormFields.voucherNumber]'s own doc comment for why it is always set here, an
  /// entry dialog only ever being opened to edit with one already loaded.
  ///
  /// Writes whatever `event.fields` collected about the entry's own voucher
  /// ([_writeEntryReceiptChange]) in this very handler too, before the one reload at its end.
  Future<void> _onEntryUpdateConfirmed(
    OcptBudgetEntryUpdateConfirmedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final fields = event.fields;
    final voucherNumber = fields.voucherNumber;
    final revenueId = await _createNewRevenueOf(project, fields);
    await _budgetJournalService.updateEntry(
      database: project.database,
      entryId: event.entryId,
      date: Value(fields.date),
      label: Value(fields.label),
      posteId: Value(fields.posteId),
      resourceId: Value(fields.resourceId),
      revenueId: Value(revenueId ?? fields.revenueId),
      shareId: Value(fields.shareId),
      debitCents: Value(fields.isDebit ? fields.amountCents : 0),
      creditCents: Value(fields.isDebit ? 0 : fields.amountCents),
      isTaxInclusive: Value(fields.isTaxInclusive),
      vatRateBasisPoints: Value(fields.vatRateBasisPoints),
      voucherNumber: voucherNumber == null ? const Value.absent() : Value(voucherNumber),
    );
    await _writeEntryReceiptChange(project, event.entryId, fields);

    await _applyBudgetSnapshot(emitter, project);
  }

  /// Creates the taking `fields` carries as still-to-be-made
  /// ([OcptBudgetEntryFormFields.newRevenue]) and answers its fresh id, or null while it carries
  /// none — which is the ordinary case.
  ///
  /// **Written exactly the way [_onRevenueCreationConfirmed] writes one**, through the same two
  /// calls, so a taking born in the journal is indistinguishable from one born in the sharing
  /// view: the door differs, never the row.
  Future<String?> _createNewRevenueOf(
    OcptOpenProjectModel project,
    OcptBudgetEntryFormFields fields,
  ) async {
    final newRevenue = fields.newRevenue;
    if (newRevenue == null) {
      return null;
    }

    final revenueId = await _budgetSharingService.createRevenue(
      database: project.database,
      date: newRevenue.date,
      label: newRevenue.label,
    );
    if (revenueId != null) {
      await _writeRevenueFields(project, revenueId, newRevenue);
    }

    return revenueId;
  }

  /// Writes whatever `fields` collected about a journal entry's own voucher, once the entry itself
  /// exists: a fresh pick ([OcptBudgetEntryFormFields.pickedReceiptPath]) references it, replacing
  /// whatever the entry already carried; the dialog's own `Detach` action
  /// ([OcptBudgetEntryFormFields.isReceiptDetached]) drops it instead — never both at once, see that
  /// field's own doc comment. A no-op when the dialog asked for neither.
  ///
  /// Shared by every handler that creates or writes a journal entry ([_onEntryCreationConfirmed],
  /// [_onEntryUpdateConfirmed], [_onCommitmentSettlementConfirmed]), each already reloading the
  /// snapshot once on its own right after calling this.
  Future<void> _writeEntryReceiptChange(
    OcptOpenProjectModel project,
    String entryId,
    OcptBudgetEntryFormFields fields,
  ) async {
    final pickedReceiptPath = fields.pickedReceiptPath;
    if (pickedReceiptPath != null) {
      await _budgetJournalService.setEntryReceipt(
        database: project.database,
        entryId: entryId,
        path: pickedReceiptPath,
      );
      return;
    }

    if (fields.isReceiptDetached) {
      await _budgetJournalService.clearEntryReceipt(database: project.database, entryId: entryId);
    }
  }

  /// Deletes cash-journal entry `event.entryId` for good, confirmed by the mode's own
  /// `OcptConfirmDialog`.
  Future<void> _onEntryDeletionConfirmed(
    OcptBudgetEntryDeletionConfirmedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _budgetJournalService.deleteEntry(database: project.database, entryId: event.entryId);
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
    await _flushPendingFieldEdits(emitter);

    final posteId = event.posteId;
    if (posteId == null) {
      emitter(state.copyWith(clearFilterPosteId: true));
      return;
    }

    if (state.postes.any((poste) => poste.id == posteId)) {
      emitter(state.copyWith(filterPosteId: posteId));
    }
  }

  /// Creates a new commitment from `event.fields`.
  Future<void> _onCommitmentCreationConfirmed(
    OcptBudgetCommitmentCreationConfirmedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final fields = event.fields;
    await _budgetJournalService.createCommitment(
      database: project.database,
      posteId: fields.posteId,
      label: fields.label,
      dueDate: fields.dueDate,
      amountCents: fields.amountCents,
      isTaxInclusive: fields.isTaxInclusive,
      vatRateBasisPoints: fields.vatRateBasisPoints,
      status: fields.status,
      lineId: event.lineId,
    );

    await _applyBudgetSnapshot(emitter, project);
  }

  /// Writes `event.fields` onto commitment `event.commitmentId` — `fields.posteId` is never sent
  /// on, see `OcptBudgetCommitmentUpdateConfirmedEvent`'s own doc comment.
  Future<void> _onCommitmentUpdateConfirmed(
    OcptBudgetCommitmentUpdateConfirmedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final fields = event.fields;
    await _budgetJournalService.updateCommitment(
      database: project.database,
      commitmentId: event.commitmentId,
      dueDate: Value(fields.dueDate),
      label: Value(fields.label),
      posteId: Value(fields.posteId),
      amountCents: Value(fields.amountCents),
      isTaxInclusive: Value(fields.isTaxInclusive),
      vatRateBasisPoints: Value(fields.vatRateBasisPoints),
      status: Value(fields.status),
    );

    await _applyBudgetSnapshot(emitter, project);
  }

  /// Deletes commitment `event.commitmentId` for good, confirmed by the mode's own
  /// `OcptConfirmDialog`.
  Future<void> _onCommitmentDeletionConfirmed(
    OcptBudgetCommitmentDeletionConfirmedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _budgetJournalService.deleteCommitment(
      database: project.database,
      commitmentId: event.commitmentId,
    );
    await _applyBudgetSnapshot(emitter, project);
  }

  /// Records commitment `event.commitmentId`'s own payment: creates the journal entry
  /// `event.fields` describes and, once it exists, points the commitment's own `settledEntryId` at
  /// it — one dispatched event, two writes, then one reload. A write refused by the preview guard
  /// (`createEntry` answering null) skips the second write rather than linking a commitment to an
  /// entry that was never actually created.
  Future<void> _onCommitmentSettlementConfirmed(
    OcptBudgetCommitmentSettlementConfirmedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final fields = event.fields;
    final entryId = await _budgetJournalService.createEntry(
      database: project.database,
      date: fields.date,
      label: fields.label,
      posteId: fields.posteId,
      resourceId: fields.resourceId,
      revenueId: fields.revenueId,
      shareId: fields.shareId,
      debitCents: fields.isDebit ? fields.amountCents : 0,
      creditCents: fields.isDebit ? 0 : fields.amountCents,
      isTaxInclusive: fields.isTaxInclusive,
      vatRateBasisPoints: fields.vatRateBasisPoints,
    );

    if (entryId != null) {
      await _budgetJournalService.updateCommitment(
        database: project.database,
        commitmentId: event.commitmentId,
        settledEntryId: Value(entryId),
      );
      await _writeEntryReceiptChange(project, entryId, fields);
    }

    await _applyBudgetSnapshot(emitter, project);
  }

  /// Undoes commitment `event.commitmentId`'s own settlement: clears `settledEntryId` back to null
  /// alone, the journal entry it named untouched — see
  /// `OcptBudgetCommitmentUnsettleRequestedEvent`'s own doc comment.
  Future<void> _onCommitmentUnsettleRequested(
    OcptBudgetCommitmentUnsettleRequestedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _budgetJournalService.updateCommitment(
      database: project.database,
      commitmentId: event.commitmentId,
      settledEntryId: const Value(null),
    );
    await _applyBudgetSnapshot(emitter, project);
  }

  /// Re-reads the quote of [project] and applies it, reconciling [OcptBudgetState.selection]
  /// against what the fresh snapshot still holds — whichever object it names, gone missing, is
  /// dropped rather than trusted to still mean something. `OcptBudgetReceiptSelection` is not yet
  /// dispatched by this bloc (M6 wires it), so it is treated as always live, exactly as a null
  /// selection is.
  ///
  /// Every handler that writes to the quote tables ends here, which is also the mode's own
  /// stand-in for "a save landing while the `Versions` tab is open": [OcptProjectWorkingCopyRefreshRequestedEvent]
  /// is dispatched once the fresh snapshot has landed, mirroring `OcptScheduleBloc
  /// ._applyScheduleSnapshot`.
  Future<void> _applyBudgetSnapshot(
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
      OcptBudgetPosteSelection(:final posteId) => snapshot.postes.any((poste) => poste.id == posteId),
      OcptBudgetLineSelection(:final lineId) =>
        snapshot.postes.any((poste) => poste.lines.any((line) => line.id == lineId)),
      OcptBudgetCommitmentSelection(:final commitmentId) =>
        snapshot.commitments.any((commitment) => commitment.id == commitmentId),
      OcptBudgetEntrySelection(:final entryId) => snapshot.entries.any((entry) => entry.id == entryId),
      OcptBudgetResourceSelection(:final resourceId) =>
        snapshot.resources.any((resource) => resource.id == resourceId),
      OcptBudgetRevenueSelection(:final revenueId) =>
        snapshot.revenues.any((revenue) => revenue.id == revenueId),
      OcptBudgetReceiptSelection() => true,
    };
    final revenueStillExists =
        state.selectedRevenueId == null ||
        snapshot.revenues.any((revenue) => revenue.id == state.selectedRevenueId);
    final shareStillExists =
        state.selectedShareId == null ||
        snapshot.shares.any((share) => share.id == state.selectedShareId);

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
        clearSelection: !selectionStillExists,
        clearFilterPosteId: !filterStillExists,
        clearSelectedRevenueId: !revenueStillExists,
        clearSelectedShareId: !shareStillExists,
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
      ),
    );
  }

  /// Creates a new financing resource from `event.fields` and selects it.
  ///
  /// [OcptBudgetFinancingService.createResource] mints the row from a label alone (mirroring
  /// `OcptBudgetQuoteService.createPoste`'s own shape, unlike `createCommitment`'s single insert):
  /// every other field `event.fields` collected is written straight after, in the very same
  /// [OcptBudgetFinancingService.updateResource] call [_onResourceUpdateConfirmed] itself uses, so
  /// there is exactly one place that turns a whole [OcptBudgetResourceFormFields] into a write.
  Future<void> _onResourceCreationConfirmed(
    OcptBudgetResourceCreationConfirmedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final fields = event.fields;
    final resourceId = await _budgetFinancingService.createResource(
      database: project.database,
      label: fields.label,
    );
    if (resourceId != null) {
      await _writeResourceFields(project, resourceId, fields);
    }

    await _applyBudgetSnapshot(emitter, project);
    if (resourceId != null) {
      emitter(state.copyWith(selection: OcptBudgetResourceSelection(resourceId)));
    }
  }

  /// Writes `event.fields` onto resource `event.resourceId`.
  Future<void> _onResourceUpdateConfirmed(
    OcptBudgetResourceUpdateConfirmedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _writeResourceFields(project, event.resourceId, event.fields);
    await _applyBudgetSnapshot(emitter, project);
  }

  /// Writes every field of `fields` onto resource `resourceId` — shared by
  /// [_onResourceCreationConfirmed] (right after minting the row) and
  /// [_onResourceUpdateConfirmed].
  Future<void> _writeResourceFields(
    OcptOpenProjectModel project,
    String resourceId,
    OcptBudgetResourceFormFields fields,
  ) => _budgetFinancingService.updateResource(
    database: project.database,
    resourceId: resourceId,
    groupKind: Value(fields.groupKind),
    personId: Value(fields.personId),
    label: Value(fields.label),
    amountCents: Value(fields.amountCents),
    status: Value(fields.status),
    isReimbursable: Value(fields.isReimbursable),
    notes: Value(fields.notes),
  );

  /// Creates a defrayal from `event.fields`.
  ///
  /// **One insert, unlike a resource's own two**: `OcptBudgetAllowancesService.createAllowance`
  /// takes every field the dialog collected, because a defrayal is only ever minted from a form
  /// already filled in — there is no "create it empty and name it afterwards" gesture here.
  Future<void> _onAllowanceCreationConfirmed(
    OcptBudgetAllowanceCreationConfirmedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final fields = event.fields;
    await _budgetAllowancesService.createAllowance(
      database: project.database,
      personId: fields.personId,
      kind: fields.kind,
      label: fields.label,
      date: fields.date,
      endDate: fields.endDate,
      quantityMilli: fields.quantityMilli,
      unitAmountMilliCents: fields.unitAmountMilliCents,
      notes: fields.notes,
    );
    await _applyBudgetSnapshot(emitter, project);
  }

  /// Writes `event.fields` onto defrayal `event.allowanceId`.
  Future<void> _onAllowanceUpdateConfirmed(
    OcptBudgetAllowanceUpdateConfirmedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final fields = event.fields;
    await _budgetAllowancesService.updateAllowance(
      database: project.database,
      allowanceId: event.allowanceId,
      personId: Value(fields.personId),
      kind: Value(fields.kind),
      label: Value(fields.label),
      date: Value(fields.date),
      endDate: Value(fields.endDate),
      quantityMilli: Value(fields.quantityMilli),
      unitAmountMilliCents: Value(fields.unitAmountMilliCents),
      notes: Value(fields.notes),
    );
    await _applyBudgetSnapshot(emitter, project);
  }

  /// Deletes defrayal `event.allowanceId` for good, confirmed by the mode's own
  /// `OcptConfirmDialog`.
  Future<void> _onAllowanceDeletionConfirmed(
    OcptBudgetAllowanceDeletionConfirmedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _budgetAllowancesService.deleteAllowance(
      database: project.database,
      allowanceId: event.allowanceId,
    );
    await _applyBudgetSnapshot(emitter, project);
  }

  /// Points the provisioning at `event.posteId` — a selection, written nowhere.
  void _onProvisionPosteSelected(
    OcptBudgetProvisionPosteSelectedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) => emitter(state.copyWith(provisionPosteId: event.posteId));

  /// Carries out `event.entries` against poste `event.posteId`, confirmed by the mode's own
  /// `OcptConfirmDialog`.
  Future<void> _onProvisionConfirmed(
    OcptBudgetProvisionConfirmedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _budgetQuoteService.applyProvision(
      database: project.database,
      posteId: event.posteId,
      entries: event.entries,
    );
    await _applyBudgetSnapshot(emitter, project);
  }

  /// Deletes financing resource `event.resourceId` for good, confirmed by the mode's own
  /// `OcptConfirmDialog`.
  Future<void> _onResourceDeletionConfirmed(
    OcptBudgetResourceDeletionConfirmedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _budgetFinancingService.deleteResource(
      database: project.database,
      resourceId: event.resourceId,
    );
    await _applyBudgetSnapshot(emitter, project);
  }

  /// Selects taking `event.revenueId`, drawn as a plain highlight by the sharing view rather than
  /// opening a dock tab — mirrors [_onResourceSelected]. A revenue id naming no live revenue is
  /// ignored.
  Future<void> _onRevenueSelected(
    OcptBudgetRevenueSelectedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    if (!state.revenues.any((revenue) => revenue.id == event.revenueId)) {
      return;
    }

    emitter(state.copyWith(selectedRevenueId: event.revenueId));
  }

  /// Creates a new taking from `event.fields` and selects it — mirrors
  /// [_onResourceCreationConfirmed]: `OcptBudgetSharingService.createRevenue` mints the row from a
  /// date and a label alone, every other field written straight after through
  /// [_writeRevenueFields], the very same call [_onRevenueUpdateConfirmed] itself uses.
  Future<void> _onRevenueCreationConfirmed(
    OcptBudgetRevenueCreationConfirmedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final fields = event.fields;
    final revenueId = await _budgetSharingService.createRevenue(
      database: project.database,
      date: fields.date,
      label: fields.label,
    );
    if (revenueId != null) {
      await _writeRevenueFields(project, revenueId, fields);
    }

    await _applyBudgetSnapshot(emitter, project);
    if (revenueId != null) {
      emitter(state.copyWith(selectedRevenueId: revenueId));
    }
  }

  /// Writes `event.fields` onto revenue `event.revenueId`.
  Future<void> _onRevenueUpdateConfirmed(
    OcptBudgetRevenueUpdateConfirmedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _writeRevenueFields(project, event.revenueId, event.fields);
    await _applyBudgetSnapshot(emitter, project);
  }

  /// Writes every field of `fields` onto revenue `revenueId` — shared by
  /// [_onRevenueCreationConfirmed] (right after minting the row) and [_onRevenueUpdateConfirmed].
  Future<void> _writeRevenueFields(
    OcptOpenProjectModel project,
    String revenueId,
    OcptBudgetRevenueFormFields fields,
  ) => _budgetSharingService.updateRevenue(
    database: project.database,
    revenueId: revenueId,
    date: Value(fields.date),
    label: Value(fields.label),
    amountCents: Value(fields.amountCents),
    status: Value(fields.status),
    notes: Value(fields.notes),
  );

  /// Moves revenue `event.revenueId` to `event.newPosition` within the sharing view's own flat
  /// order — mirrors [_onPosteReordered].
  Future<void> _onRevenueReordered(
    OcptBudgetRevenueReorderedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _budgetSharingService.reorderRevenue(
      database: project.database,
      revenueId: event.revenueId,
      newPosition: event.newPosition,
    );
    await _applyBudgetSnapshot(emitter, project);
  }

  /// Deletes taking `event.revenueId` for good, confirmed by the mode's own `OcptConfirmDialog` —
  /// mirrors [_onResourceDeletionConfirmed].
  Future<void> _onRevenueDeletionConfirmed(
    OcptBudgetRevenueDeletionConfirmedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _budgetSharingService.deleteRevenue(database: project.database, revenueId: event.revenueId);
    await _applyBudgetSnapshot(emitter, project);
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

    emitter(state.copyWith(selectedShareId: event.shareId));
  }

  /// Creates a new share from `event.fields` and selects it — mirrors
  /// [_onRevenueCreationConfirmed].
  Future<void> _onShareCreationConfirmed(
    OcptBudgetShareCreationConfirmedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final fields = event.fields;
    final shareId = await _budgetSharingService.createShare(
      database: project.database,
      label: fields.label,
    );
    if (shareId != null) {
      await _writeShareFields(project, shareId, fields);
    }

    await _applyBudgetSnapshot(emitter, project);
    if (shareId != null) {
      emitter(state.copyWith(selectedShareId: shareId));
    }
  }

  /// Writes `event.fields` onto share `event.shareId`.
  Future<void> _onShareUpdateConfirmed(
    OcptBudgetShareUpdateConfirmedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _writeShareFields(project, event.shareId, event.fields);
    await _applyBudgetSnapshot(emitter, project);
  }

  /// Writes every field of `fields` onto share `shareId` — shared by [_onShareCreationConfirmed]
  /// (right after minting the row) and [_onShareUpdateConfirmed].
  Future<void> _writeShareFields(
    OcptOpenProjectModel project,
    String shareId,
    OcptBudgetShareFormFields fields,
  ) => _budgetSharingService.updateShare(
    database: project.database,
    shareId: shareId,
    personId: Value(fields.personId),
    label: Value(fields.label),
    sharePermille: Value(fields.sharePermille),
    reinvestPermille: Value(fields.reinvestPermille),
    notes: Value(fields.notes),
  );

  /// Moves share `event.shareId` to `event.newPosition` within the sharing view's own flat order —
  /// mirrors [_onRevenueReordered].
  Future<void> _onShareReordered(
    OcptBudgetShareReorderedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _budgetSharingService.reorderShare(
      database: project.database,
      shareId: event.shareId,
      newPosition: event.newPosition,
    );
    await _applyBudgetSnapshot(emitter, project);
  }

  /// Deletes share `event.shareId` for good, confirmed by the mode's own `OcptConfirmDialog` —
  /// mirrors [_onRevenueDeletionConfirmed].
  Future<void> _onShareDeletionConfirmed(
    OcptBudgetShareDeletionConfirmedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _budgetSharingService.deleteShare(database: project.database, shareId: event.shareId);
    await _applyBudgetSnapshot(emitter, project);
  }

  /// Exports the quote as a single PDF, written through the native save dialog.
  ///
  /// Built exactly as every other mode's own export handlers are: flush whatever field edit is
  /// still sitting in the debounce first — an export must never print a figure the user has typed
  /// but the debounce has not yet written (`OcptBudgetMode`'s own class doc comment) — then hand
  /// what [state] now carries to [OcptExportManager.exportBudgetQuote]. A cancelled save dialog is
  /// a silent no-op; a failure raises the transient export-failed notice.
  Future<void> _onQuoteExportRequested(
    OcptBudgetQuoteExportRequestedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    await _flushPendingFieldEdits(emitter);

    final snapshot = state.snapshot;
    if (snapshot == null) {
      return;
    }

    try {
      final options = event.options;
      final path = await _exportManager.exportBudgetQuote(
        snapshot: snapshot,
        elementNameById: event.elementNameById,
        pageSetup: OcptPageSetup(format: options.format, margins: options.margins),
        taxBasis: options.taxBasis,
        labels: event.labels,
        projectName: state.title,
        includeTitlePage: options.includeTitlePage,
        fileTypeLabel: event.fileTypeLabel,
      );
      if (path == null) {
        // The user cancelled the save dialog.
        return;
      }

      emitter(
        state.copyWith(
          ioNotice: OcptBudgetIoNotice(kind: OcptBudgetIoNoticeKind.fileExportSucceeded, path: path),
        ),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to export the quote of the project at "
          "${_projectsManager.currentProject?.path}: $error");
      emitter(state.copyWith(ioNotice: const OcptBudgetIoNotice(kind: OcptBudgetIoNoticeKind.exportFailed)));
    }
  }

  /// Exports the financing plan as a single PDF, written through the native save dialog. Mirrors
  /// [_onQuoteExportRequested] — see its own doc comment for the flush and the cancellation
  /// contract, identical here.
  Future<void> _onFinancingPlanExportRequested(
    OcptBudgetFinancingPlanExportRequestedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    await _flushPendingFieldEdits(emitter);

    final snapshot = state.snapshot;
    if (snapshot == null) {
      return;
    }

    try {
      final options = event.options;
      final path = await _exportManager.exportBudgetFinancingPlan(
        snapshot: snapshot,
        pageSetup: OcptPageSetup(format: options.format, margins: options.margins),
        labels: event.labels,
        projectName: state.title,
        includeTitlePage: options.includeTitlePage,
        fileTypeLabel: event.fileTypeLabel,
      );
      if (path == null) {
        // The user cancelled the save dialog.
        return;
      }

      emitter(
        state.copyWith(
          ioNotice: OcptBudgetIoNotice(kind: OcptBudgetIoNoticeKind.fileExportSucceeded, path: path),
        ),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to export the financing plan of the project at "
          "${_projectsManager.currentProject?.path}: $error");
      emitter(state.copyWith(ioNotice: const OcptBudgetIoNotice(kind: OcptBudgetIoNoticeKind.exportFailed)));
    }
  }

  /// Exports the cash journal as a single XLSX workbook, written through the native save dialog.
  ///
  /// Built exactly as [_onQuoteExportRequested] is: flush whatever is still pending, then hand what
  /// [state] now carries to [OcptExportManager.exportBudgetCashJournalXlsx]. There is no options
  /// dialog to read first — this export takes none.
  Future<void> _onCashJournalExportRequested(
    OcptBudgetCashJournalExportRequestedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    await _flushPendingFieldEdits(emitter);

    final snapshot = state.snapshot;
    if (snapshot == null) {
      return;
    }

    try {
      final path = await _exportManager.exportBudgetCashJournalXlsx(
        snapshot: snapshot,
        linkLabelByEntryId: event.linkLabelByEntryId,
        labels: event.labels,
        projectName: state.title,
        fileTypeLabel: event.fileTypeLabel,
      );
      if (path == null) {
        // The user cancelled the save dialog.
        return;
      }

      emitter(
        state.copyWith(
          ioNotice: OcptBudgetIoNotice(kind: OcptBudgetIoNoticeKind.fileExportSucceeded, path: path),
        ),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to export the cash journal of the project at "
          "${_projectsManager.currentProject?.path}: $error");
      emitter(state.copyWith(ioNotice: const OcptBudgetIoNotice(kind: OcptBudgetIoNoticeKind.exportFailed)));
    }
  }

  /// Exports the financial report as a single PDF, written through the native save dialog. Mirrors
  /// [_onQuoteExportRequested] — see its own doc comment for the flush and the cancellation
  /// contract, identical here.
  Future<void> _onFinancialReportExportRequested(
    OcptBudgetFinancialReportExportRequestedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    await _flushPendingFieldEdits(emitter);

    final snapshot = state.snapshot;
    if (snapshot == null) {
      return;
    }

    try {
      final options = event.options;
      final path = await _exportManager.exportBudgetFinancialReport(
        snapshot: snapshot,
        pageSetup: OcptPageSetup(format: options.format, margins: options.margins),
        labels: event.labels,
        projectName: state.title,
        includeTitlePage: options.includeTitlePage,
        fileTypeLabel: event.fileTypeLabel,
      );
      if (path == null) {
        // The user cancelled the save dialog.
        return;
      }

      emitter(
        state.copyWith(
          ioNotice: OcptBudgetIoNotice(kind: OcptBudgetIoNoticeKind.fileExportSucceeded, path: path),
        ),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to export the financial report of the project "
          "at ${_projectsManager.currentProject?.path}: $error");
      emitter(state.copyWith(ioNotice: const OcptBudgetIoNotice(kind: OcptBudgetIoNoticeKind.exportFailed)));
    }
  }

  /// Clears the transient export notice currently shown, if any.
  Future<void> _onIoNoticeDismissed(
    OcptBudgetIoNoticeDismissedEvent event,
    Emitter<OcptBudgetState> emitter,
  ) async {
    emitter(state.copyWith(clearIoNotice: true));
  }
}
