// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_save_location_service.dart';
import 'package:open_cine_prod_tools/managers/logging/ocpt_logs_helper_builder.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_journal_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_quote_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_cash_journal_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_financial_report_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_financing_plan_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_quote_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_allowance_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/types/ocpt_export_outcome.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_header.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_bloc.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_confirm_dialog.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// The navigator [BudgetScenarioHarness.wrap] mounts, so [BudgetScenarioRouterManager.pop] closes
/// a dialog opened through `showDialog` exactly as the real router would.
final _navigatorKey = GlobalKey<NavigatorState>();

/// Answers the device identifier the failing services stamp their rows with.
Future<String> _scenarioDeviceId() async => "scenario-device";

/// A router manager whose [pop] pops [_navigatorKey]'s navigator and whose [push] answers with
/// [pushAnswer] instead of opening a page, so the project settings detour can be driven.
class BudgetScenarioRouterManager extends OcptRouterManager {
  /// The answer every [push] gives, what the project settings page returns when it closes.
  bool? pushAnswer;

  /// The number of pages pushed since the last reset.
  int pushCount = 0;

  /// The number of times the mode asked to leave since the last reset.
  int popCount = 0;

  /// Count the pop, then pop the route of the test's own navigator, when it can pop.
  @override
  void pop<Y extends Object?>([Y? result]) {
    popCount++;
    final navigator = _navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop(result);
    }
  }

  /// Count the push, and answer with the canned answer when its type fits.
  @override
  Future<Y?> push<Y extends Object?>(
    OcptRoute route, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, dynamic> queryParameters = const <String, dynamic>{},
    Object? extra,
  }) async {
    pushCount++;
    final answer = pushAnswer;
    return answer is Y ? answer as Y : null;
  }
}

/// A save location service whose dialog never opens: it counts how often it was asked and answers
/// as if the user had cancelled.
class BudgetScenarioSaveLocationService extends OcptSaveLocationService {
  /// The number of times a save dialog was requested since the last reset.
  int askedCount = 0;

  /// Class constructor
  BudgetScenarioSaveLocationService()
    : super(logger: buildOcptLogsHelper("budget_scenarios_save_location"));

  /// Count the question and answer that nothing was picked.
  @override
  Future<String?> pickSaveLocation({
    required String suggestedFileName,
    required String fileTypeLabel,
    required List<String> extensions,
    String? initialDirectory,
  }) async {
    askedCount++;
    return null;
  }
}

/// One budget export a [BudgetRecordingExportManager] was asked for.
class BudgetRecordedExport {
  /// The name of the export that ran: `quote`, `financingPlan`, `cashJournal` or
  /// `financialReport`.
  final String document;

  /// The budget the mode handed over.
  final OcptBudgetSnapshot snapshot;

  /// The project name the export was handed.
  final String projectName;

  /// The page setup the PDF is typeset with, null for the workbook.
  final OcptPageSetup? pageSetup;

  /// The tax basis the quote is read in, null for every other document.
  final OcptBudgetTaxBasis? taxBasis;

  /// Whether the title page is printed, null for the workbook.
  final bool? includeTitlePage;

  /// The link labels the workbook was handed, null for the PDFs.
  final Map<String, String>? linkLabelByEntryId;

  /// The breakdown element names the quote was handed, null for the other documents.
  final Map<String, String>? elementNameById;

  /// Class constructor
  const BudgetRecordedExport({
    required this.document,
    required this.snapshot,
    required this.projectName,
    this.pageSetup,
    this.taxBasis,
    this.includeTitlePage,
    this.linkLabelByEntryId,
    this.elementNameById,
  });
}

/// An export manager answering the four budget exports with a saved file, and recording what each
/// one was handed so a scenario can tell what the mode had read at the moment of the export.
class BudgetRecordingExportManager extends OcptExportManager {
  /// Every export run since the last [reset], in order.
  final List<BudgetRecordedExport> exports = [];

  /// Whether the next exports throw instead of answering.
  bool shouldFail = false;

  /// Whether the next exports answer as if the user had cancelled the dialog.
  bool shouldCancel = false;

  /// Whether the next workbook export answers with a failure outcome instead of a saved file.
  bool shouldAnswerFailed = false;

  /// The save location service the project package export asks, counting its dialogs.
  BudgetScenarioSaveLocationService get saveDialog =>
      saveLocationService as BudgetScenarioSaveLocationService;

  /// Class constructor
  BudgetRecordingExportManager()
    : super(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: BudgetScenarioSaveLocationService(),
      );

  /// Forgets everything recorded and answers normally again.
  void reset() {
    exports.clear();
    shouldFail = false;
    shouldCancel = false;
    shouldAnswerFailed = false;
    saveDialog.askedCount = 0;
  }

  /// Record the export as a quote, with its tax basis and options.
  @override
  Future<OcptExportOutcome?> exportBudgetQuote({
    required OcptBudgetSnapshot snapshot,
    required Map<String, String> elementNameById,
    required OcptPageSetup pageSetup,
    required OcptBudgetTaxBasis taxBasis,
    required OcptBudgetQuoteLabels labels,
    required String projectName,
    required bool includeTitlePage,
    required String fileTypeLabel,
    Rect? shareAnchor,
  }) async => _record(
    BudgetRecordedExport(
      document: "quote",
      snapshot: snapshot,
      projectName: projectName,
      pageSetup: pageSetup,
      taxBasis: taxBasis,
      includeTitlePage: includeTitlePage,
      elementNameById: elementNameById,
    ),
  );

  /// Record the export as a financing plan.
  @override
  Future<OcptExportOutcome?> exportBudgetFinancingPlan({
    required OcptBudgetSnapshot snapshot,
    required OcptPageSetup pageSetup,
    required OcptBudgetFinancingPlanLabels labels,
    required String projectName,
    required bool includeTitlePage,
    required String fileTypeLabel,
    Rect? shareAnchor,
  }) async => _record(
    BudgetRecordedExport(
      document: "financingPlan",
      snapshot: snapshot,
      projectName: projectName,
      pageSetup: pageSetup,
      includeTitlePage: includeTitlePage,
    ),
  );

  /// Record the export as a cash journal workbook.
  @override
  Future<OcptExportOutcome?> exportBudgetCashJournalXlsx({
    required OcptBudgetSnapshot snapshot,
    required Map<String, String> linkLabelByEntryId,
    required OcptBudgetCashJournalXlsxLabels labels,
    required String projectName,
    required String fileTypeLabel,
    Rect? shareAnchor,
  }) async => _record(
    BudgetRecordedExport(
      document: "cashJournal",
      snapshot: snapshot,
      projectName: projectName,
      linkLabelByEntryId: linkLabelByEntryId,
    ),
    isWorkbook: true,
  );

  /// Record the export as a financial report.
  @override
  Future<OcptExportOutcome?> exportBudgetFinancialReport({
    required OcptBudgetSnapshot snapshot,
    required OcptPageSetup pageSetup,
    required OcptBudgetFinancialReportLabels labels,
    required String projectName,
    required bool includeTitlePage,
    required String fileTypeLabel,
    Rect? shareAnchor,
  }) async => _record(
    BudgetRecordedExport(
      document: "financialReport",
      snapshot: snapshot,
      projectName: projectName,
      pageSetup: pageSetup,
      includeTitlePage: includeTitlePage,
    ),
  );

  /// Records [export], then answers the way the switches say.
  OcptExportOutcome? _record(BudgetRecordedExport export, {bool isWorkbook = false}) {
    exports.add(export);
    if (shouldFail) {
      throw StateError("${export.document} export intentionally failed for the scenario");
    }
    if (isWorkbook && shouldAnswerFailed) {
      return const OcptExportFailed();
    }

    return shouldCancel ? null : OcptExportSaved("/tmp/${export.document}.out");
  }
}

/// The switches [BudgetScenarioProjectsManager] reads to decide which write fails.
class BudgetScenarioFailures {
  /// Whether updating a quote line throws.
  bool failLineUpdates = false;

  /// Whether creating a journal entry throws.
  bool failEntryCreation = false;

  /// Switches every failure off.
  void reset() {
    failLineUpdates = false;
    failEntryCreation = false;
  }
}

/// A quote service whose [updateLine] fails while [failures] says so.
class _ScenarioBudgetQuoteService extends OcptBudgetQuoteService {
  /// The switches read on every write.
  final BudgetScenarioFailures failures;

  /// Class constructor
  const _ScenarioBudgetQuoteService({required this.failures})
    : super(logger: const SilentLogger(), deviceId: _scenarioDeviceId);

  /// Fail while the scenario asks for line updates to fail, otherwise update the line as the real
  /// service does.
  @override
  Future<void> updateLine({
    required OcptProjectDatabase database,
    required String lineId,
    Value<String> label = const Value.absent(),
    Value<int> quantityMilli = const Value.absent(),
    Value<String> unit = const Value.absent(),
    Value<int> unitAmountCents = const Value.absent(),
    Value<bool> isTaxInclusive = const Value.absent(),
    Value<int?> vatRateBasisPoints = const Value.absent(),
    Value<String?> elementId = const Value.absent(),
    Value<String?> provisionKey = const Value.absent(),
    Value<String?> provisionDigest = const Value.absent(),
    Value<String> notes = const Value.absent(),
    Value<String?> inKindResourceId = const Value.absent(),
  }) async {
    if (failures.failLineUpdates) {
      throw StateError("line update intentionally failed for the scenario");
    }

    return super.updateLine(
      database: database,
      lineId: lineId,
      label: label,
      quantityMilli: quantityMilli,
      unit: unit,
      unitAmountCents: unitAmountCents,
      isTaxInclusive: isTaxInclusive,
      vatRateBasisPoints: vatRateBasisPoints,
      elementId: elementId,
      provisionKey: provisionKey,
      provisionDigest: provisionDigest,
      notes: notes,
      inKindResourceId: inKindResourceId,
    );
  }
}

/// A journal service whose [createEntry] fails while [failures] says so.
class _ScenarioBudgetJournalService extends OcptBudgetJournalService {
  /// The switches read on every write.
  final BudgetScenarioFailures failures;

  /// Class constructor
  const _ScenarioBudgetJournalService({required this.failures})
    : super(
        logger: const SilentLogger(),
        assetsService: const OcptAssetsService(logger: SilentLogger(), deviceId: _scenarioDeviceId),
        deviceId: _scenarioDeviceId,
      );

  /// Fail while the scenario asks for entry creations to fail, otherwise create the entry as the
  /// real service does.
  @override
  Future<String?> createEntry({
    required OcptProjectDatabase database,
    required DateTime date,
    required String label,
    String? posteId,
    String? resourceId,
    String? revenueId,
    String? shareId,
    String? commitmentId,
    String? personId,
    int debitCents = 0,
    int creditCents = 0,
    bool isTaxInclusive = true,
    int? vatRateBasisPoints,
  }) async {
    if (failures.failEntryCreation) {
      throw StateError("entry creation intentionally failed for the scenario");
    }

    return super.createEntry(
      database: database,
      date: date,
      label: label,
      posteId: posteId,
      resourceId: resourceId,
      revenueId: revenueId,
      shareId: shareId,
      commitmentId: commitmentId,
      personId: personId,
      debitCents: debitCents,
      creditCents: creditCents,
      isTaxInclusive: isTaxInclusive,
      vatRateBasisPoints: vatRateBasisPoints,
    );
  }
}

/// A projects manager handing the budget mode a quote and a journal service that fail on demand,
/// everything else being the real manager.
class BudgetScenarioProjectsManager extends OcptProjectsManager {
  /// The switches deciding which write fails.
  final BudgetScenarioFailures failures = BudgetScenarioFailures();

  /// The quote service, failing on demand.
  late final _quoteService = _ScenarioBudgetQuoteService(failures: failures);

  /// The journal service, failing on demand.
  late final _journalService = _ScenarioBudgetJournalService(failures: failures);

  /// Get the quote service the scenario holds.
  @override
  OcptBudgetQuoteService get budgetQuoteService => _quoteService;

  /// Get the journal service the scenario holds.
  @override
  OcptBudgetJournalService get budgetJournalService => _journalService;

  /// Class constructor
  BudgetScenarioProjectsManager({super.propertiesManager, super.appLanguageCode});
}

/// The shared set-up of the budget mode scenarios: the global managers, one temporary project per
/// scenario, the way a scenario mounts the mode, drives it and reads the database back.
class BudgetScenarioHarness {
  /// The preferences manager, backed by an in-memory store.
  late OcptPropertiesManager propertiesManager;

  /// The real projects manager, whose failing services are switched on through
  /// [BudgetScenarioProjectsManager.failures].
  late BudgetScenarioProjectsManager projectsManager;

  /// What the four exports of the mode were handed.
  final exportManager = BudgetRecordingExportManager();

  /// The router the mode navigates through.
  final routerManager = BudgetScenarioRouterManager();

  /// The folder holding the current scenario's project file.
  late Directory tempDir;

  /// The database of the open project.
  OcptProjectDatabase get database => projectsManager.currentProject!.database;

  /// Registers the global managers once for the whole file.
  Future<void> setUpAll() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();

    projectsManager = BudgetScenarioProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: () => "en",
    );
    await projectsManager.initLifeCycle();

    OcptGlobalManager.instance.managers
      ..registerSingleton<OcptPropertiesManager>(propertiesManager)
      ..registerSingleton<OcptProjectsManager>(projectsManager)
      ..registerSingleton<OcptRouterManager>(routerManager)
      ..registerSingleton<OcptExportManager>(exportManager);
  }

  /// Resets the preferences, then creates a fresh project.
  ///
  /// The in-memory preference store outlives a single scenario, so every preference the mode
  /// reads on entry is written back to its default here.
  Future<void> setUp() async {
    await propertiesManager.budgetRightDockFraction.store(OcptWorkspaceDock.rightDefaultFraction);
    await propertiesManager.budgetLastRightDockTab.store(OcptBudgetRightDockTab.inspector);

    exportManager.reset();
    projectsManager.failures.reset();
    routerManager
      ..pushAnswer = null
      ..pushCount = 0
      ..popCount = 0;

    tempDir = await Directory.systemTemp.createTemp("ocpt_budget_scenarios_");
    final result = await projectsManager.createProject(
      name: "My Movie",
      filePath: p.join(tempDir.path, "movie.ocpt"),
    );
    expect(result.status.isSuccess, isTrue);
  }

  /// Closes the project and removes its folder.
  Future<void> tearDown() async {
    await projectsManager.closeCurrentProject();
    await tempDir.delete(recursive: true);
  }

  /// Reads the live postes, with their lines, back from the database.
  Future<List<OcptBudgetPoste>> readPostes() =>
      projectsManager.budgetQuoteService.loadPostes(database: database, seed: const []);

  /// Reads the poste called [label] back from the database.
  Future<OcptBudgetPoste> readPoste(String label) async =>
      (await readPostes()).firstWhere((poste) => poste.label == label);

  /// Reads the live journal entries back from the database.
  Future<List<OcptBudgetEntry>> readEntries() =>
      projectsManager.budgetJournalService.loadEntries(database: database);

  /// Reads the live commitments back from the database.
  Future<List<OcptBudgetCommitment>> readCommitments() =>
      projectsManager.budgetJournalService.loadCommitments(database: database);

  /// Reads the live financing resources back from the database.
  Future<List<OcptBudgetResource>> readResources() =>
      projectsManager.budgetFinancingService.loadResources(database: database);

  /// Reads the live takings back from the database.
  Future<List<OcptBudgetRevenue>> readRevenues() =>
      projectsManager.budgetSharingService.loadRevenues(database: database);

  /// Reads the live shares back from the database.
  Future<List<OcptBudgetShare>> readShares() =>
      projectsManager.budgetSharingService.loadShares(database: database);

  /// Reads the live defrayals back from the database.
  Future<List<OcptBudgetAllowance>> readAllowances() =>
      projectsManager.budgetAllowancesService.loadAllowances(database: database);

  /// Creates a poste called [label], returning the id.
  Future<String> seedPoste(String label) async {
    final id = await projectsManager.budgetQuoteService.createPoste(
      database: database,
      label: label,
    );
    return id!;
  }

  /// Creates a line called [label] in poste [posteId], quoted [unitAmountCents] for one unit,
  /// returning the id.
  Future<String> seedLine(String posteId, String label, {int unitAmountCents = 10000}) async {
    final id = await projectsManager.budgetQuoteService.createLine(
      database: database,
      posteId: posteId,
      label: label,
      quantityMilli: const Value(1000),
      unitAmountCents: Value(unitAmountCents),
    );
    return id!;
  }

  /// Creates a commitment called [label] against poste [posteId], returning the id.
  Future<String> seedCommitment(
    String posteId,
    String label, {
    int amountCents = 5000,
    String? lineId,
  }) async {
    final id = await projectsManager.budgetJournalService.createCommitment(
      database: database,
      posteId: posteId,
      label: label,
      amountCents: amountCents,
      lineId: lineId,
    );
    return id!;
  }

  /// Creates a debit entry called [label] of [debitCents], returning the id.
  Future<String> seedDebit(
    String label,
    int debitCents, {
    String? posteId,
    String? commitmentId,
  }) async {
    final id = await projectsManager.budgetJournalService.createEntry(
      database: database,
      date: DateTime(2026),
      label: label,
      posteId: posteId,
      commitmentId: commitmentId,
      debitCents: debitCents,
    );
    return id!;
  }

  /// Creates a cash financing resource called [label] worth [amountCents], returning the id.
  Future<String> seedResource(String label, int amountCents) async {
    final id = await projectsManager.budgetFinancingService.createResource(
      database: database,
      label: label,
    );
    await projectsManager.budgetFinancingService.updateResource(
      database: database,
      resourceId: id!,
      amountCents: Value(amountCents),
    );
    return id;
  }

  /// Creates a taking called [label] worth [amountCents], returning the id.
  Future<String> seedRevenue(String label, int amountCents) async {
    final id = await projectsManager.budgetSharingService.createRevenue(
      database: database,
      date: DateTime(2026),
      label: label,
    );
    await projectsManager.budgetSharingService.updateRevenue(
      database: database,
      revenueId: id!,
      amountCents: Value(amountCents),
    );
    return id;
  }

  /// Creates a share called [label] taking [sharePermille] thousandths, returning the id.
  Future<String> seedShare(String label, {int sharePermille = 500}) async {
    final id = await projectsManager.budgetSharingService.createShare(
      database: database,
      label: label,
    );
    await projectsManager.budgetSharingService.updateShare(
      database: database,
      shareId: id!,
      sharePermille: Value(sharePermille),
    );
    return id;
  }

  /// Creates a free-standing defrayal called [label], returning the id.
  Future<String> seedAllowance(String label, {int quantityMilli = 2000}) async {
    final id = await projectsManager.budgetAllowancesService.createAllowance(
      database: database,
      personId: null,
      kind: OcptBudgetAllowanceKind.values.first,
      label: label,
      date: DateTime(2026),
      endDate: null,
      quantityMilli: quantityMilli,
      unitAmountMilliCents: 1000000,
      notes: "",
    );
    return id!;
  }

  /// Wraps [child] with the localization delegates, the theme, the navigator
  /// [BudgetScenarioRouterManager.pop] closes dialogs on, a scaffold, and the workspace bloc a
  /// production mode expects its page to provide.
  Widget wrap(Widget child) => MaterialApp(
    navigatorKey: _navigatorKey,
    theme: ocpt_theme.ocptTheme.lightThemeData,
    localizationsDelegates: const [
      Tr.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: Tr.delegate.supportedLocales,
    home: BlocProvider<OcptWorkspaceBloc>(
      create: (context) => OcptWorkspaceBloc(),
      child: Scaffold(body: child),
    ),
  );

  /// Sizes the test surface to [size] (wider than the compact breakpoint by default), mounts the
  /// budget mode and settles.
  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(1750, 1000),
    Widget mode = const OcptBudgetMode(),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(mode));
    await tester.pumpAndSettle();
  }

  /// Takes the mode out of the tree, which is what leaving it for another mode does, and settles.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  /// Reads the localizations of the mounted mode.
  Tr trOf(WidgetTester tester) => Tr.of(tester.element(find.byType(OcptBudgetMode)));

  /// Reaches the workspace bloc the scenario's scaffold provides to the mode.
  OcptWorkspaceBloc workspaceBlocOf(WidgetTester tester) =>
      tester.element(find.byType(Scaffold)).read<OcptWorkspaceBloc>();

  /// Lets the real event loop run, a few milliseconds at a time, until [isDone] holds, then
  /// settles.
  ///
  /// A version preview or restore reads and writes real files, which a fake-async pump never waits
  /// for: the loop hands the real clock over between two pumps, and gives up after five seconds so
  /// a scenario that never gets there fails on its next expectation instead of hanging.
  Future<void> pumpUntil(WidgetTester tester, bool Function() isDone) async {
    for (var attempt = 0; attempt < 500; attempt++) {
      await tester.pump();
      if (isDone()) {
        break;
      }
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    }
    await tester.pumpAndSettle();
  }

  /// Gives a write that real file I/O finishes outside the fake clock a bounded real time to land,
  /// pumping a frame between two checks without letting any fake time pass, so a running field-edit
  /// debounce cannot run out meanwhile; fails when [isWritten] still says no after about two
  /// seconds.
  Future<void> eventually(
    WidgetTester tester,
    Future<bool> Function() isWritten, {
    String? reason,
  }) async {
    var written = false;
    for (var attempt = 0; attempt < 100 && !written; attempt++) {
      await tester.pump();
      written = (await tester.runAsync(isWritten))!;
      if (!written) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      }
    }
    expect(written, isTrue, reason: reason);
  }

  /// Whether [target] is on screen right now.
  bool isShown(Finder target) => target.evaluate().isNotEmpty;

  /// Taps [target] and settles.
  Future<void> tap(WidgetTester tester, Finder target) async {
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  /// Taps [target] and pumps a single frame, so little fake time passes that a running field-edit
  /// debounce cannot run out under the tap.
  Future<void> tapQuickly(WidgetTester tester, Finder target) async {
    await tester.tap(target);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Taps [target], which opens a menu or a dialog, and lets that open without letting a running
  /// field-edit debounce out.
  Future<void> tapOpening(WidgetTester tester, Finder target) async {
    await tester.tap(target);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Types [text] into [field] and pumps one frame, leaving the field-edit debounce running.
  Future<void> type(WidgetTester tester, Finder field, String text) async {
    await tester.enterText(field, text);
    await tester.pump();
  }

  /// Lets the field-edit debounce run out, then settles.
  Future<void> letDebounceRun(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();
  }

  /// Taps the header control labelled [label], scoped to the header: a view's own title and the
  /// help panel reuse the same words.
  Future<void> tapHeader(WidgetTester tester, String label) => tap(
    tester,
    find.descendant(of: find.byType(OcptBudgetHeader), matching: find.text(label)).first,
  );

  /// Taps the header control labelled [label] without letting a running field-edit debounce out.
  Future<void> tapHeaderQuickly(WidgetTester tester, String label) => tapQuickly(
    tester,
    find.descendant(of: find.byType(OcptBudgetHeader), matching: find.text(label)).first,
  );

  /// Finds the text field of the detail panel field captioned [label], which a detail panel draws
  /// in capitals above its input.
  Finder fieldLabelled(String label) => find.descendant(
    of: find.ancestor(of: find.text(label.toUpperCase()), matching: find.byType(Column)).first,
    matching: find.byType(TextField),
  );

  /// Finds every text field currently on screen that accepts typing.
  Finder editableFields() =>
      find.byWidgetPredicate((widget) => widget is TextField && !widget.readOnly);

  /// Finds every text field currently on screen that refuses typing.
  Finder readOnlyFields() =>
      find.byWidgetPredicate((widget) => widget is TextField && widget.readOnly);

  /// Finds [target] inside the open dialog.
  Finder inDialog(Finder target) => find.descendant(of: find.byType(AlertDialog), matching: target);

  /// Confirms the question the mode put in a confirm dialog, tapping [confirmLabel].
  Future<void> confirmDialog(WidgetTester tester, String confirmLabel) async {
    expect(find.byType(OcptConfirmDialog), findsOneWidget);
    // The last one: a dialog whose title reads like its button lists the button after the title.
    await tap(
      tester,
      find.descendant(of: find.byType(OcptConfirmDialog), matching: find.text(confirmLabel)).last,
    );
  }

  /// Cancels the question the mode put in a confirm dialog, tapping [cancelLabel].
  Future<void> cancelDialog(WidgetTester tester, String cancelLabel) async {
    expect(find.byType(OcptConfirmDialog), findsOneWidget);
    await tap(
      tester,
      find.descendant(of: find.byType(OcptConfirmDialog), matching: find.text(cancelLabel)),
    );
    expect(find.byType(OcptConfirmDialog), findsNothing);
  }

  /// Finds the `⋮` menu level with the row naming [label]: a table draws a row's name and its menu
  /// as sibling subtrees, so only their height ties them together; [within] narrows where the row
  /// is looked for when its name also appears elsewhere, in the detail panel for one.
  Finder menuInRowOf(WidgetTester tester, String label, {Finder? within}) {
    final named = within == null
        ? find.text(label)
        : find.descendant(of: within, matching: find.text(label));
    final rowY = tester.getCenter(named.first).dy;
    final menus = find.byType(PopupMenuButton<String>);
    for (var index = 0; index < tester.widgetList(menus).length; index++) {
      final candidate = menus.at(index);
      if ((tester.getCenter(candidate).dy - rowY).abs() < 4) {
        return candidate;
      }
    }
    throw StateError("No menu found level with the row naming '$label'");
  }

  /// Opens the right dock from the toolbar when it is shut.
  Future<void> openRightDock(WidgetTester tester) async {
    final tr = trOf(tester);
    if (!isShown(find.byTooltip(tr.budgetRightDockCloseTooltip))) {
      await tap(tester, find.byTooltip(tr.workspaceToggleRightDockTooltip));
    }
  }
}
