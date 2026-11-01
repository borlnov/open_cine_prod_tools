// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';
import 'dart:ui';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_cash_journal_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_financial_report_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_financial_report_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_financing_plan_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_financing_plan_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste_seed.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_quote_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_quote_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/types/ocpt_export_outcome.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_expenses_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_export_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_export_state.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// A minimal, arbitrary set of localized strings for the quote export — only the shape matters to
/// these tests, not the words themselves, mirroring `_callSheetLabels` in
/// `schedule_bloc_test.dart`.
const _quoteLabels = OcptBudgetQuoteLabels(
  fileNameSuffix: "quote",
  documentTitle: "Quote",
  versionLabel: "Version",
  lineLabelHeader: "Label",
  quantityHeader: "Quantity",
  unitPriceHeader: "Unit price",
  lineTotalHeader: "Total",
  posteSubtotalLabel: "Subtotal",
  projectTotalLabel: "Grand total",
  includingTaxCaption: "Including tax",
  excludingTaxCaption: "Excluding tax",
  noLinesLabel: "No line yet",
  emptyDocumentNote: "No poste yet",
  coverageReadOutTemplate: "{amount} · {coveredCount} of {totalCount} known",
  inKindLineMarker: "(in kind)",
);

/// A minimal, arbitrary set of localized strings for the financing plan export — mirrors
/// [_quoteLabels]' own doc comment.
const _financingPlanLabels = OcptBudgetFinancingPlanLabels(
  fileNameSuffix: "financing plan",
  documentTitle: "Financing plan",
  versionLabel: "Version",
  groupTitles: {},
  statusLabels: {},
  labelHeader: "Label",
  statusHeader: "Status",
  amountHeader: "Amount",
  receivedHeader: "Received",
  outstandingHeader: "Outstanding",
  groupSubtotalLabel: "Subtotal",
  projectTotalLabel: "Grand total",
  emptyDocumentNote: "No resource yet",
  balanceNeedsLabel: "Needs",
  balanceResourcesLabel: "Resources",
  balanceNoQuoteMessage: "No quote yet",
  balanceBalancedMessage: "Balanced",
  balanceShortfallMessageTemplate: "Short by {amount}",
  coverageReadOutTemplate: "{amount} · {coveredCount} of {totalCount} known",
);

/// A minimal, arbitrary set of localized strings for the cash journal export — mirrors
/// [_quoteLabels]' own doc comment.
const _cashJournalLabels = OcptBudgetCashJournalXlsxLabels(
  sheetName: "Cash journal",
  dateHeader: "Date",
  voucherHeader: "Voucher",
  labelHeader: "Label",
  posteHeader: "Poste",
  settlesHeader: "Settles",
  debitHeader: "Debit",
  creditHeader: "Credit",
  balanceHeader: "Balance",
  totalsRowLabel: "Total",
);

/// A minimal, arbitrary set of localized strings for the financial report export — mirrors
/// [_quoteLabels]' own doc comment.
const _financialReportLabels = OcptBudgetFinancialReportLabels(
  fileNameSuffix: "financial report",
  documentTitle: "Financial report",
  versionLabel: "Version",
  posteHeader: "Poste",
  quotedHeader: "Quoted",
  paidHeader: "Paid",
  committedHeader: "Committed",
  remainingHeader: "Remaining",
  varianceHeader: "Variance",
  projectTotalsLabel: "Grand total",
  offQuoteLabel: "Off quote",
  financingPlanTotalLabel: "Financing plan total",
  emptyDocumentNote: "No poste yet",
  coverageReadOutTemplate: "{amount} · {coveredCount} of {totalCount} known",
  balanceNeedsLabel: "Needs",
  balanceResourcesLabel: "Resources",
  balanceNoQuoteMessage: "No quote yet",
  balanceBalancedMessage: "Balanced",
  balanceShortfallMessageTemplate: "Short by {amount}",
);

/// A fake `OcptExportManager` recording the last call to each of the budget mode's four export
/// methods and returning a caller-chosen path (or throwing, or answering null to simulate a
/// cancelled save dialog) — mirrors `_FakeScheduleExportManager` in `schedule_bloc_test.dart`.
class _FakeBudgetExportManager extends OcptExportManager {
  /// The path [exportBudgetQuote] returns, or null to simulate a cancelled save dialog.
  final String? quoteResult;

  /// The path [exportBudgetFinancingPlan] returns, or null to simulate a cancelled save dialog.
  final String? financingPlanResult;

  /// The path [exportBudgetCashJournalXlsx] returns, or null to simulate a cancelled save dialog.
  final String? cashJournalResult;

  /// The path [exportBudgetFinancialReport] returns, or null to simulate a cancelled save dialog.
  final String? financialReportResult;

  /// Whether [exportBudgetQuote] throws, to exercise the bloc's export-failed path.
  final bool quoteFails;

  /// Whether [exportBudgetFinancingPlan] throws, to exercise the bloc's export-failed path.
  final bool financingPlanFails;

  /// Whether [exportBudgetCashJournalXlsx] throws, to exercise the bloc's export-failed path.
  final bool cashJournalFails;

  /// Whether [exportBudgetFinancialReport] throws, to exercise the bloc's export-failed path.
  final bool financialReportFails;

  /// The snapshot of the last [exportBudgetQuote] call.
  OcptBudgetSnapshot? lastQuoteSnapshot;

  /// The tax basis of the last [exportBudgetQuote] call.
  OcptBudgetTaxBasis? lastQuoteTaxBasis;

  /// The `linkLabelByEntryId` of the last [exportBudgetCashJournalXlsx] call.
  Map<String, String>? lastCashJournalLinkLabelByEntryId;

  /// Class constructor
  _FakeBudgetExportManager({
    this.quoteResult,
    this.financingPlanResult,
    this.cashJournalResult,
    this.financialReportResult,
    this.quoteFails = false,
    this.financingPlanFails = false,
    this.cashJournalFails = false,
    this.financialReportFails = false,
  }) : super(fileSelectorManager: const FileSelectorManager());

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
  }) async {
    lastQuoteSnapshot = snapshot;
    lastQuoteTaxBasis = taxBasis;

    if (quoteFails) {
      throw StateError("quote export intentionally failed for the test");
    }
    final result = quoteResult;
    return result == null ? null : OcptExportSaved(result);
  }

  @override
  Future<OcptExportOutcome?> exportBudgetFinancingPlan({
    required OcptBudgetSnapshot snapshot,
    required OcptPageSetup pageSetup,
    required OcptBudgetFinancingPlanLabels labels,
    required String projectName,
    required bool includeTitlePage,
    required String fileTypeLabel,
    Rect? shareAnchor,
  }) async {
    if (financingPlanFails) {
      throw StateError("financing plan export intentionally failed for the test");
    }
    final result = financingPlanResult;
    return result == null ? null : OcptExportSaved(result);
  }

  @override
  Future<OcptExportOutcome?> exportBudgetCashJournalXlsx({
    required OcptBudgetSnapshot snapshot,
    required Map<String, String> linkLabelByEntryId,
    required OcptBudgetCashJournalXlsxLabels labels,
    required String projectName,
    required String fileTypeLabel,
    Rect? shareAnchor,
  }) async {
    lastCashJournalLinkLabelByEntryId = linkLabelByEntryId;

    if (cashJournalFails) {
      throw StateError("cash journal export intentionally failed for the test");
    }
    final result = cashJournalResult;
    return result == null ? null : OcptExportSaved(result);
  }

  @override
  Future<OcptExportOutcome?> exportBudgetFinancialReport({
    required OcptBudgetSnapshot snapshot,
    required OcptPageSetup pageSetup,
    required OcptBudgetFinancialReportLabels labels,
    required String projectName,
    required bool includeTitlePage,
    required String fileTypeLabel,
    Rect? shareAnchor,
  }) async {
    if (financialReportFails) {
      throw StateError("financial report export intentionally failed for the test");
    }
    final result = financialReportResult;
    return result == null ? null : OcptExportSaved(result);
  }
}

/// A router manager that only records the call: these bloc tests never navigate for real.
class _RecordingRouterManager extends OcptRouterManager {
  @override
  void pop<Y extends Object?>([Y? result]) {}
}

/// A minimal, three-entry seed used by every test that isn't about the seeding path itself, so
/// their own assertions aren't drowned in ten postes.
const _smallSeed = [
  OcptBudgetPosteSeed(id: "seed-1", code: "1", label: "Poste one", simpleLabel: "P1"),
  OcptBudgetPosteSeed(id: "seed-2", code: "2", label: "Poste two", simpleLabel: "P2"),
  OcptBudgetPosteSeed(id: "seed-3", code: "3", label: "Poste three", simpleLabel: "P3"),
];

void main() {
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_budget_export_bloc_test_test_");
    projectsManager = OcptProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: () => "en",
    );
    await projectsManager.initLifeCycle();

    final result = await projectsManager.createProject(
      name: "My Movie",
      filePath: p.join(tempDir.path, "movie.ocpt"),
    );
    expect(result.status.isSuccess, isTrue);
  });

  tearDown(() async {
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Builds the mode bloc wired to the test project, seeded with [seed] (defaulting to [_smallSeed]).
  OcptBudgetBloc buildBloc({List<OcptBudgetPosteSeed> seed = _smallSeed}) => OcptBudgetBloc(
    seed: seed,
    projectsManager: projectsManager,
    propertiesManager: propertiesManager,
    routerManager: _RecordingRouterManager(),
    exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
  );

  /// Builds the export bloc of [modeBloc], exporting through [exportManager] (a cancelled save
  /// dialog by default, so no test ever reaches a native one).
  OcptBudgetExportBloc buildExportBloc(
    OcptBudgetBloc modeBloc, {
    OcptExportManager? exportManager,
  }) {
    final bloc = OcptBudgetExportBloc(
      modeBloc: modeBloc,
      projectsManager: projectsManager,
      exportManager: exportManager ?? _FakeBudgetExportManager(),
    );
    addTearDown(bloc.close);
    return bloc;
  }

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<S> waitForState<S>(BlocBase<S> bloc, bool Function(S state) predicate) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  group("exporting the quote", () {
    test(
      "hands the snapshot and the tax basis to the manager and raises the succeeded notice",
      () async {
        final exportManager = _FakeBudgetExportManager(quoteResult: "/tmp/quote.pdf");
        final bloc = buildBloc();
        final exportBloc = buildExportBloc(bloc, exportManager: exportManager);
        await waitForState(bloc, (state) => !state.isLoading);

        exportBloc.add(
          const OcptBudgetQuoteExportRequestedEvent(
            options: OcptBudgetQuoteExportOptions(
              format: OcptPageFormat.usLetter,
              margins: FountainPageMargins.standard(),
              includeTitlePage: true,
              taxBasis: OcptBudgetTaxBasis.excludingTax,
            ),
            labels: _quoteLabels,
            elementNameById: {},
            fileTypeLabel: "PDF document",
          ),
        );
        final state = await waitForState(exportBloc, (state) => state.ioNotice != null);

        expect(exportManager.lastQuoteSnapshot, isNotNull);
        expect(exportManager.lastQuoteTaxBasis, OcptBudgetTaxBasis.excludingTax);
        expect(state.ioNotice?.kind, OcptBudgetIoNoticeKind.fileExportSucceeded);
        expect(state.ioNotice?.path, "/tmp/quote.pdf");

        await exportBloc.close();

        await bloc.close();
      },
    );

    test("is a silent no-op when the save dialog is cancelled", () async {
      final bloc = buildBloc();
      final exportBloc = buildExportBloc(bloc);
      await waitForState(bloc, (state) => !state.isLoading);

      exportBloc.add(
        const OcptBudgetQuoteExportRequestedEvent(
          options: OcptBudgetQuoteExportOptions(
            format: OcptPageFormat.usLetter,
            margins: FountainPageMargins.standard(),
            includeTitlePage: true,
            taxBasis: OcptBudgetTaxBasis.includingTax,
          ),
          labels: _quoteLabels,
          elementNameById: {},
          fileTypeLabel: "PDF document",
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(exportBloc.state.ioNotice, isNull);

      await exportBloc.close();

      await bloc.close();
    });

    test("raises the failed notice when the export throws", () async {
      final bloc = buildBloc();
      final exportBloc = buildExportBloc(
        bloc,
        exportManager: _FakeBudgetExportManager(quoteFails: true),
      );
      await waitForState(bloc, (state) => !state.isLoading);

      exportBloc.add(
        const OcptBudgetQuoteExportRequestedEvent(
          options: OcptBudgetQuoteExportOptions(
            format: OcptPageFormat.usLetter,
            margins: FountainPageMargins.standard(),
            includeTitlePage: true,
            taxBasis: OcptBudgetTaxBasis.includingTax,
          ),
          labels: _quoteLabels,
          elementNameById: {},
          fileTypeLabel: "PDF document",
        ),
      );
      final state = await waitForState(exportBloc, (state) => state.ioNotice != null);

      expect(state.ioNotice?.kind, OcptBudgetIoNoticeKind.exportFailed);

      await exportBloc.close();

      await bloc.close();
    });
  });

  group("exporting the financing plan", () {
    test("hands the snapshot to the manager and raises the succeeded notice", () async {
      final exportManager = _FakeBudgetExportManager(financingPlanResult: "/tmp/financing.pdf");
      final bloc = buildBloc();
      final exportBloc = buildExportBloc(bloc, exportManager: exportManager);
      await waitForState(bloc, (state) => !state.isLoading);

      exportBloc.add(
        const OcptBudgetFinancingPlanExportRequestedEvent(
          options: OcptBudgetFinancingPlanExportOptions(
            format: OcptPageFormat.usLetter,
            margins: FountainPageMargins.standard(),
            includeTitlePage: true,
          ),
          labels: _financingPlanLabels,
          fileTypeLabel: "PDF document",
        ),
      );
      final state = await waitForState(exportBloc, (state) => state.ioNotice != null);

      expect(state.ioNotice?.kind, OcptBudgetIoNoticeKind.fileExportSucceeded);
      expect(state.ioNotice?.path, "/tmp/financing.pdf");

      await exportBloc.close();

      await bloc.close();
    });

    test("is a silent no-op when the save dialog is cancelled", () async {
      final bloc = buildBloc();
      final exportBloc = buildExportBloc(bloc);
      await waitForState(bloc, (state) => !state.isLoading);

      exportBloc.add(
        const OcptBudgetFinancingPlanExportRequestedEvent(
          options: OcptBudgetFinancingPlanExportOptions(
            format: OcptPageFormat.usLetter,
            margins: FountainPageMargins.standard(),
            includeTitlePage: true,
          ),
          labels: _financingPlanLabels,
          fileTypeLabel: "PDF document",
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(exportBloc.state.ioNotice, isNull);

      await exportBloc.close();

      await bloc.close();
    });

    test("raises the failed notice when the export throws", () async {
      final bloc = buildBloc();
      final exportBloc = buildExportBloc(
        bloc,
        exportManager: _FakeBudgetExportManager(financingPlanFails: true),
      );
      await waitForState(bloc, (state) => !state.isLoading);

      exportBloc.add(
        const OcptBudgetFinancingPlanExportRequestedEvent(
          options: OcptBudgetFinancingPlanExportOptions(
            format: OcptPageFormat.usLetter,
            margins: FountainPageMargins.standard(),
            includeTitlePage: true,
          ),
          labels: _financingPlanLabels,
          fileTypeLabel: "PDF document",
        ),
      );
      final state = await waitForState(exportBloc, (state) => state.ioNotice != null);

      expect(state.ioNotice?.kind, OcptBudgetIoNoticeKind.exportFailed);

      await exportBloc.close();

      await bloc.close();
    });
  });

  group("exporting the cash journal", () {
    test("hands the link labels to the manager and raises the succeeded notice", () async {
      final exportManager = _FakeBudgetExportManager(cashJournalResult: "/tmp/journal.xlsx");
      final bloc = buildBloc();
      final exportBloc = buildExportBloc(bloc, exportManager: exportManager);
      await waitForState(bloc, (state) => !state.isLoading);

      exportBloc.add(
        const OcptBudgetCashJournalExportRequestedEvent(
          labels: _cashJournalLabels,
          linkLabelByEntryId: {"entry-1": "Regional grant"},
          fileTypeLabel: "Excel workbook",
        ),
      );
      final state = await waitForState(exportBloc, (state) => state.ioNotice != null);

      expect(exportManager.lastCashJournalLinkLabelByEntryId, {"entry-1": "Regional grant"});
      expect(state.ioNotice?.kind, OcptBudgetIoNoticeKind.fileExportSucceeded);
      expect(state.ioNotice?.path, "/tmp/journal.xlsx");

      await exportBloc.close();

      await bloc.close();
    });

    test("is a silent no-op when the save dialog is cancelled", () async {
      final bloc = buildBloc();
      final exportBloc = buildExportBloc(bloc);
      await waitForState(bloc, (state) => !state.isLoading);

      exportBloc.add(
        const OcptBudgetCashJournalExportRequestedEvent(
          labels: _cashJournalLabels,
          linkLabelByEntryId: {},
          fileTypeLabel: "Excel workbook",
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(exportBloc.state.ioNotice, isNull);

      await exportBloc.close();

      await bloc.close();
    });

    test("raises the failed notice when the export throws", () async {
      final bloc = buildBloc();
      final exportBloc = buildExportBloc(
        bloc,
        exportManager: _FakeBudgetExportManager(cashJournalFails: true),
      );
      await waitForState(bloc, (state) => !state.isLoading);

      exportBloc.add(
        const OcptBudgetCashJournalExportRequestedEvent(
          labels: _cashJournalLabels,
          linkLabelByEntryId: {},
          fileTypeLabel: "Excel workbook",
        ),
      );
      final state = await waitForState(exportBloc, (state) => state.ioNotice != null);

      expect(state.ioNotice?.kind, OcptBudgetIoNoticeKind.exportFailed);

      await exportBloc.close();

      await bloc.close();
    });
  });

  group("exporting the financial report", () {
    test("hands the snapshot to the manager and raises the succeeded notice", () async {
      final exportManager = _FakeBudgetExportManager(financialReportResult: "/tmp/report.pdf");
      final bloc = buildBloc();
      final exportBloc = buildExportBloc(bloc, exportManager: exportManager);
      await waitForState(bloc, (state) => !state.isLoading);

      exportBloc.add(
        const OcptBudgetFinancialReportExportRequestedEvent(
          options: OcptBudgetFinancialReportExportOptions(
            format: OcptPageFormat.usLetter,
            margins: FountainPageMargins.standard(),
            includeTitlePage: true,
          ),
          labels: _financialReportLabels,
          fileTypeLabel: "PDF document",
        ),
      );
      final state = await waitForState(exportBloc, (state) => state.ioNotice != null);

      expect(state.ioNotice?.kind, OcptBudgetIoNoticeKind.fileExportSucceeded);
      expect(state.ioNotice?.path, "/tmp/report.pdf");

      await exportBloc.close();

      await bloc.close();
    });

    test("is a silent no-op when the save dialog is cancelled", () async {
      final bloc = buildBloc();
      final exportBloc = buildExportBloc(bloc);
      await waitForState(bloc, (state) => !state.isLoading);

      exportBloc.add(
        const OcptBudgetFinancialReportExportRequestedEvent(
          options: OcptBudgetFinancialReportExportOptions(
            format: OcptPageFormat.usLetter,
            margins: FountainPageMargins.standard(),
            includeTitlePage: true,
          ),
          labels: _financialReportLabels,
          fileTypeLabel: "PDF document",
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(exportBloc.state.ioNotice, isNull);

      await exportBloc.close();

      await bloc.close();
    });

    test("raises the failed notice when the export throws", () async {
      final bloc = buildBloc();
      final exportBloc = buildExportBloc(
        bloc,
        exportManager: _FakeBudgetExportManager(financialReportFails: true),
      );
      await waitForState(bloc, (state) => !state.isLoading);

      exportBloc.add(
        const OcptBudgetFinancialReportExportRequestedEvent(
          options: OcptBudgetFinancialReportExportOptions(
            format: OcptPageFormat.usLetter,
            margins: FountainPageMargins.standard(),
            includeTitlePage: true,
          ),
          labels: _financialReportLabels,
          fileTypeLabel: "PDF document",
        ),
      );
      final state = await waitForState(exportBloc, (state) => state.ioNotice != null);

      expect(state.ioNotice?.kind, OcptBudgetIoNoticeKind.exportFailed);

      await exportBloc.close();

      await bloc.close();
    });
  });

  test("an export first writes a typed edit, so the document holds it", () async {
    final exportManager = _FakeBudgetExportManager(quoteResult: "/tmp/quote.pdf");
    final bloc = buildBloc();
    final exportBloc = buildExportBloc(bloc, exportManager: exportManager);
    final expensesBloc = OcptBudgetExpensesBloc(
      modeBloc: bloc,
      projectsManager: projectsManager,
      fieldEditDebounce: const Duration(days: 1),
    );
    addTearDown(expensesBloc.close);
    addTearDown(bloc.close);
    final loaded = await waitForState(bloc, (state) => !state.isLoading);
    final posteId = loaded.postes.first.id;

    expensesBloc.add(
      OcptBudgetFieldChangedEvent(
        targetId: posteId,
        field: OcptBudgetField.posteLabel,
        rawValue: "Typed before the export",
      ),
    );
    await waitForState(expensesBloc, (state) => state.pendingFieldEdits.isNotEmpty);

    exportBloc.add(
      const OcptBudgetQuoteExportRequestedEvent(
        options: OcptBudgetQuoteExportOptions(
          format: OcptPageFormat.usLetter,
          margins: FountainPageMargins.standard(),
          includeTitlePage: true,
          taxBasis: OcptBudgetTaxBasis.includingTax,
        ),
        labels: _quoteLabels,
        elementNameById: {},
        fileTypeLabel: "PDF document",
      ),
    );
    await waitForState(exportBloc, (state) => state.ioNotice != null);

    expect(
      exportManager.lastQuoteSnapshot!.postes.firstWhere((poste) => poste.id == posteId).label,
      "Typed before the export",
    );
  });

  group("the events of the export bloc", () {
    /// The name of each event of the export hierarchy: the switch names every one, so an event
    /// added to the hierarchy does not compile until this list, and the test below, know it.
    String nameOf(OcptBudgetExportEvent event) => switch (event) {
      OcptBudgetQuoteExportRequestedEvent() => "quote",
      OcptBudgetFinancingPlanExportRequestedEvent() => "financing plan",
      OcptBudgetCashJournalExportRequestedEvent() => "cash journal",
      OcptBudgetFinancialReportExportRequestedEvent() => "financial report",
      OcptBudgetIoNoticeDismissedEvent() => "dismiss",
    };

    test("every event of its hierarchy has a handler", () async {
      final bloc = buildBloc();
      final exportBloc = buildExportBloc(
        bloc,
        exportManager: _FakeBudgetExportManager(
          quoteResult: "/tmp/quote.pdf",
          financingPlanResult: "/tmp/financing.pdf",
          cashJournalResult: "/tmp/journal.xlsx",
          financialReportResult: "/tmp/report.pdf",
        ),
      );
      addTearDown(bloc.close);
      await waitForState(bloc, (state) => !state.isLoading);

      const events = <OcptBudgetExportEvent>[
        OcptBudgetQuoteExportRequestedEvent(
          options: OcptBudgetQuoteExportOptions(
            format: OcptPageFormat.usLetter,
            margins: FountainPageMargins.standard(),
            includeTitlePage: true,
            taxBasis: OcptBudgetTaxBasis.includingTax,
          ),
          labels: _quoteLabels,
          elementNameById: {},
          fileTypeLabel: "PDF document",
        ),
        OcptBudgetFinancingPlanExportRequestedEvent(
          options: OcptBudgetFinancingPlanExportOptions(
            format: OcptPageFormat.usLetter,
            margins: FountainPageMargins.standard(),
            includeTitlePage: true,
          ),
          labels: _financingPlanLabels,
          fileTypeLabel: "PDF document",
        ),
        OcptBudgetCashJournalExportRequestedEvent(
          labels: _cashJournalLabels,
          linkLabelByEntryId: {},
          fileTypeLabel: "Excel workbook",
        ),
        OcptBudgetFinancialReportExportRequestedEvent(
          options: OcptBudgetFinancialReportExportOptions(
            format: OcptPageFormat.usLetter,
            margins: FountainPageMargins.standard(),
            includeTitlePage: true,
          ),
          labels: _financialReportLabels,
          fileTypeLabel: "PDF document",
        ),
        OcptBudgetIoNoticeDismissedEvent(),
      ];
      expect(events.map(nameOf).toSet(), hasLength(5), reason: "one event per name");

      // An event nobody handles is ignored silently, so each is proven by its effect: an export
      // leaves a notice carrying the path its manager answered, and the dismissal takes it away.
      for (final (index, path) in const [
        (0, "/tmp/quote.pdf"),
        (1, "/tmp/financing.pdf"),
        (2, "/tmp/journal.xlsx"),
        (3, "/tmp/report.pdf"),
      ]) {
        exportBloc.add(events[index]);
        final exported = await waitForState(exportBloc, (state) => state.ioNotice != null);
        expect(exported.ioNotice!.path, path);

        exportBloc.add(events[4]);
        await waitForState(exportBloc, (state) => state.ioNotice == null);
      }
    });

    test("is registered with the mode as a flusher, without any widget having read it", () async {
      final bloc = buildBloc();
      buildExportBloc(bloc);
      addTearDown(bloc.close);
      await waitForState(bloc, (state) => !state.isLoading);

      expect(bloc.pendingWritesFlusherCount, 1);
    });
  });
}
