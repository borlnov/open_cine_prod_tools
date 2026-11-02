// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:meta/meta.dart' show useResult;
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
import 'package:open_cine_prod_tools/models/ocpt_budget_account_seed.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_read.dart';

/// Read the budget mode's whole data from the open project: the services it joins are resolved
/// from the projects manager once, and [load] makes one pass over them.
///
/// It only reads. Which state the result lands in, and what is reconciled against it, is the mode
/// bloc's.
class OcptBudgetSnapshotLoader {
  /// The ten CNC accounts, already localized, seeded on the first read of an empty table.
  final List<OcptBudgetAccountSeed> seed;

  /// The manager used to read the project's currency, default VAT rate and prices.
  final OcptProjectsManager _projectsManager;

  /// The service used to read the quote: the accounts and their lines.
  final OcptBudgetQuoteService _budgetQuoteService;

  /// The service used to read the cash journal: every live entry and commitment, and the vouchers.
  final OcptBudgetJournalService _budgetJournalService;

  /// The service used to read the financing plan: the resources and the mileage rates.
  final OcptBudgetFinancingService _budgetFinancingService;

  /// The service used to read the defrayals.
  final OcptBudgetAllowancesService _budgetAllowancesService;

  /// The service used to read the revenue sharing: the takings and the shares.
  final OcptBudgetSharingService _budgetSharingService;

  /// The service the catering-and-travel pass reads its own days and slots off.
  final OcptScheduleService _scheduleService;

  /// The service the catering-and-travel pass reads every role's own kind and `personId` off.
  final OcptRoleIndexService _roleIndexService;

  /// The service the catering-and-travel pass reads every person off.
  final OcptPeopleService _peopleService;

  /// The service the project's locations and sets are read off, to name the set a day plays at.
  final OcptLocationsService _locationsService;

  /// The service the breakdown's own elements catalogue is read off.
  final OcptElementsService _elementsService;

  /// Class constructor
  OcptBudgetSnapshotLoader({required OcptProjectsManager projectsManager, required this.seed})
    : _projectsManager = projectsManager,
      _budgetQuoteService = projectsManager.budgetQuoteService,
      _budgetJournalService = projectsManager.budgetJournalService,
      _budgetFinancingService = projectsManager.budgetFinancingService,
      _budgetAllowancesService = projectsManager.budgetAllowancesService,
      _budgetSharingService = projectsManager.budgetSharingService,
      _scheduleService = projectsManager.scheduleService,
      _roleIndexService = projectsManager.roleIndexService,
      _peopleService = projectsManager.peopleService,
      _locationsService = projectsManager.locationsService,
      _elementsService = projectsManager.elementsService;

  /// Read [project]'s whole budget: the accounts with their lines, the cash journal's own entries
  /// and commitments, the financing plan's own resources and mileage rates, the catering-and-travel
  /// pass's own reads, the breakdown's own elements catalogue, the currency, the default VAT rate
  /// and the meal/buffet prices, joined into one [OcptBudgetSnapshot] alongside the raw
  /// roles/people/elements and the set name map the view reads directly.
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
  /// [OcptBudgetSnapshot]: `OcptBudgetDetail`'s own `+ From breakdown` picker needs the
  /// whole catalogue, not just the two counts `OcptBudgetState.elementLinkCounts` derives from it.
  ///
  /// Answers the failure of the schedule, the accounts and their lines, the resources, the mileage
  /// rates, the defrayals, the takings and the shares reads, in place of the whole read: they are
  /// the only reads that answer a result so far. The cash journal's own reads still raise when the
  /// database fails, and the caller catches what they raise. This sentence changes as that service
  /// converts, each read then answering its failure in the same way.
  @useResult
  Future<OcptDatabaseResult<OcptBudgetRead>> load(OcptOpenProjectModel project) async {
    final database = project.database;
    final accountsRead = await _budgetQuoteService.loadAccounts(database: database, seed: seed);
    if (accountsRead.isError) {
      return OcptDatabaseResult(status: accountsRead.status, extraInfo: accountsRead.extraInfo);
    }

    final accounts = accountsRead.value!;
    final entries = await _budgetJournalService.loadEntries(database: database);
    final commitments = await _budgetJournalService.loadCommitments(database: database);
    final resourcesRead = await _budgetFinancingService.loadResources(database: database);
    if (resourcesRead.isError) {
      return OcptDatabaseResult(status: resourcesRead.status, extraInfo: resourcesRead.extraInfo);
    }

    final resources = resourcesRead.value!;
    final revenuesRead = await _budgetSharingService.loadRevenues(database: database);
    if (revenuesRead.isError) {
      return OcptDatabaseResult(status: revenuesRead.status, extraInfo: revenuesRead.extraInfo);
    }

    final revenues = revenuesRead.value!;
    final sharesRead = await _budgetSharingService.loadShares(database: database);
    if (sharesRead.isError) {
      return OcptDatabaseResult(status: sharesRead.status, extraInfo: sharesRead.extraInfo);
    }

    final shares = sharesRead.value!;
    final receipts = await _budgetJournalService.loadReceipts(database: database);
    final currencyCode = await _projectsManager.loadCurrentProjectCurrencyCode();
    final defaultVatRateBasisPoints = await _projectsManager
        .loadCurrentProjectDefaultVatRateBasisPoints();

    final scheduleRead = await _scheduleService.loadSchedule(database: database);
    if (scheduleRead.isError) {
      return OcptDatabaseResult(status: scheduleRead.status, extraInfo: scheduleRead.extraInfo);
    }

    final scheduleSnapshot = scheduleRead.value!;
    final roles = await _roleIndexService.loadRoles(database: database);
    final people = await _peopleService.loadPeople(database: database);
    final elements = await _elementsService.loadElements(database: database);
    final locations = await _locationsService.loadLocations(database: database);
    final mileageRatesRead = await _budgetFinancingService.loadMileageRates(database: database);
    if (mileageRatesRead.isError) {
      return OcptDatabaseResult(
        status: mileageRatesRead.status,
        extraInfo: mileageRatesRead.extraInfo,
      );
    }

    final mileageRates = mileageRatesRead.value!;
    final allowancesRead = await _budgetAllowancesService.loadAllowances(database: database);
    if (allowancesRead.isError) {
      return OcptDatabaseResult(status: allowancesRead.status, extraInfo: allowancesRead.extraInfo);
    }

    final allowances = allowancesRead.value!;
    final mealPriceCents = await _projectsManager.loadCurrentProjectMealPriceCents();
    // `project_info.snackPriceCents` under its user-facing name — the column keeps the schema's
    // own name, but what it prices is the buffet, never a snack in the trade's own words.
    final buffetPriceCents = await _projectsManager.loadCurrentProjectSnackPriceCents();

    final snapshot = OcptBudgetSnapshot.build(
      accounts: accounts,
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

    return OcptDatabaseResult(
      status: OcptDatabaseStatus.ok,
      value: OcptBudgetRead(
        snapshot: snapshot,
        roles: roles,
        people: people,
        elements: elements,
        mileageRates: mileageRates,
        logisticsSetNameByDayId: _logisticsSetNameByDayId(
          days: scheduleSnapshot.days,
          slotsByDayId: scheduleSnapshot.slotsByDayId,
          locations: locations,
        ),
      ),
    );
  }

  /// Get the set name `OcptBudgetLogistics` prints under each shooting day: the name of the first
  /// set, or
  /// failing that the first location, that any of [days]' own [slotsByDayId] entries name, in slot
  /// order — resolved out of [locations] (and their own live sets) alone.
  /// `lib/models/rules/ocpt_budget_logistics.dart`'s own pass reads no location or set at all,
  /// being pure arithmetic over head counts, so this is a separate, purely presentational reading
  /// rather than a second implementation of anything that file states. A day whose slots name
  /// neither carries no key here, which the view reads as nothing rather than a placeholder.
  Map<String, String> _logisticsSetNameByDayId({
    required List<OcptShootingDay> days,
    required Map<String, List<OcptShootingSlot>> slotsByDayId,
    required List<OcptLocation> locations,
  }) {
    final locationById = {for (final location in locations) location.id: location};
    final setById = {
      for (final location in locations)
        for (final set in location.sets) set.id: set,
    };

    final setNameByDayId = <String, String>{};
    for (final day in days) {
      for (final slot in slotsByDayId[day.id] ?? const <OcptShootingSlot>[]) {
        final set = slot.setId == null ? null : setById[slot.setId];
        if (set != null) {
          setNameByDayId[day.id] = set.name;
          break;
        }

        final location = slot.locationId == null ? null : locationById[slot.locationId];
        if (location != null) {
          setNameByDayId[day.id] = location.name;
          break;
        }
      }
    }

    return setNameByDayId;
  }
}
