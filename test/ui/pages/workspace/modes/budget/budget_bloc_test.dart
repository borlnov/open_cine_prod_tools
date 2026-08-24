// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/constants/ocpt_budget_cnc_postes.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_cash_journal_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_financial_report_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_financial_report_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_financing_plan_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_financing_plan_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste_seed.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_quote_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_quote_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_document.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_revenue_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_selection.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_state.dart';
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

  @override
  Future<String?> exportBudgetQuote({
    required OcptBudgetSnapshot snapshot,
    required Map<String, String> elementNameById,
    required OcptPageSetup pageSetup,
    required OcptBudgetTaxBasis taxBasis,
    required OcptBudgetQuoteLabels labels,
    required String projectName,
    required bool includeTitlePage,
    required String fileTypeLabel,
  }) async {
    lastQuoteSnapshot = snapshot;
    lastQuoteTaxBasis = taxBasis;

    if (quoteFails) {
      throw StateError("quote export intentionally failed for the test");
    }
    return quoteResult;
  }

  @override
  Future<String?> exportBudgetFinancingPlan({
    required OcptBudgetSnapshot snapshot,
    required OcptPageSetup pageSetup,
    required OcptBudgetFinancingPlanLabels labels,
    required String projectName,
    required bool includeTitlePage,
    required String fileTypeLabel,
  }) async {
    if (financingPlanFails) {
      throw StateError("financing plan export intentionally failed for the test");
    }
    return financingPlanResult;
  }

  @override
  Future<String?> exportBudgetCashJournalXlsx({
    required OcptBudgetSnapshot snapshot,
    required Map<String, String> linkLabelByEntryId,
    required OcptBudgetCashJournalXlsxLabels labels,
    required String projectName,
    required String fileTypeLabel,
  }) async {
    lastCashJournalLinkLabelByEntryId = linkLabelByEntryId;

    if (cashJournalFails) {
      throw StateError("cash journal export intentionally failed for the test");
    }
    return cashJournalResult;
  }

  @override
  Future<String?> exportBudgetFinancialReport({
    required OcptBudgetSnapshot snapshot,
    required OcptPageSetup pageSetup,
    required OcptBudgetFinancialReportLabels labels,
    required String projectName,
    required bool includeTitlePage,
    required String fileTypeLabel,
  }) async {
    if (financialReportFails) {
      throw StateError("financial report export intentionally failed for the test");
    }
    return financialReportResult;
  }
}

/// A router manager that only records the call: these bloc tests never navigate for real.
class _RecordingRouterManager extends OcptRouterManager {
  @override
  void pop<Y extends Object?>([Y? result]) {}
}

/// The seed the ten real CNC postes make, resolved without a `Tr` (the label text itself is never
/// read by these tests, only the ids and the count): the seeding path itself is what is under
/// test, so it is exercised against the very ids `OcptBudgetQuoteService` will actually seed in
/// the app.
final _realCncSeed = [
  for (final poste in ocptBudgetCncPostes)
    OcptBudgetPosteSeed(id: poste.id, code: poste.code, label: poste.code, simpleLabel: null),
];

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
    tempDir = await Directory.systemTemp.createTemp("ocpt_budget_bloc_test_");
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

  /// Builds a bloc wired to the test project, seeded with [seed] (defaulting to [_smallSeed]) and
  /// a fast field-edit debounce so tests don't have to wait out the real 2 s one.
  OcptBudgetBloc buildBloc({
    List<OcptBudgetPosteSeed> seed = _smallSeed,
    Duration fieldEditDebounce = const Duration(milliseconds: 10),
    OcptExportManager? exportManager,
  }) => OcptBudgetBloc(
    seed: seed,
    projectsManager: projectsManager,
    propertiesManager: propertiesManager,
    routerManager: _RecordingRouterManager(),
    exportManager: exportManager ?? _FakeBudgetExportManager(),
    fieldEditDebounce: fieldEditDebounce,
  );

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<OcptBudgetState> waitForState(
    OcptBudgetBloc bloc,
    bool Function(OcptBudgetState state) predicate,
  ) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  group("loading the quote", () {
    test("seeds the ten CNC postes on the first read of an empty project", () async {
      final bloc = buildBloc(seed: _realCncSeed);
      addTearDown(bloc.close);

      final state = await waitForState(bloc, (state) => !state.isLoading);

      expect(state.postes, hasLength(10));
      expect(state.postes.map((poste) => poste.id).toSet(), ocptBudgetCncPostes.map((c) => c.id).toSet());
    });

    test("reads the project's own currency and default VAT rate", () async {
      final project = projectsManager.currentProject!;
      await projectsManager.saveCurrentProjectCurrencyCode("USD");
      await projectsManager.saveCurrentProjectDefaultVatRateBasisPoints(2000);

      final bloc = buildBloc();
      addTearDown(bloc.close);

      final state = await waitForState(bloc, (state) => !state.isLoading);

      expect(state.currencyCode, "USD");
      expect(state.defaultVatRateBasisPoints, 2000);
      // The project variable is only read to force the settings write above onto the very
      // project the bloc reads; nothing further is asserted on it.
      expect(project.name, "My Movie");
    });

    test("re-seeding does not duplicate postes already deleted", () async {
      final project = projectsManager.currentProject!;
      final first = await projectsManager.budgetQuoteService.loadPostes(
        database: project.database,
        seed: _smallSeed,
      );
      await projectsManager.budgetQuoteService.deletePoste(
        database: project.database,
        posteId: first.first.id,
      );

      final bloc = buildBloc();
      addTearDown(bloc.close);
      final state = await waitForState(bloc, (state) => !state.isLoading);

      expect(state.postes, hasLength(_smallSeed.length - 1));
    });
  });

  group("creating a poste", () {
    test("appends an empty poste and selects it, opening the Inspector tab", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptBudgetPosteCreatedEvent());
      final state = await waitForState(bloc, (state) => state.selectedPosteId != null);

      expect(state.postes.last.label, "");
      expect(state.selectedPosteId, state.postes.last.id);
      expect(state.rightDockTab, OcptBudgetRightDockTab.inspector);
    });
  });

  group("reordering a poste", () {
    test("moves it to the new position", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final firstId = loaded.postes.first.id;

      bloc.add(OcptBudgetPosteReorderedEvent(posteId: firstId, newPosition: 2));
      final state = await waitForState(bloc, (state) => state.postes.last.id == firstId);

      expect(state.postes.last.id, firstId);
    });
  });

  group("deleting a poste", () {
    test("tombstones it, its own lines, and clears the selection when it was selected", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      bloc.add(OcptBudgetPosteSelectedEvent(posteId: posteId));
      await waitForState(bloc, (state) => state.selectedPosteId == posteId);

      bloc.add(OcptBudgetPosteDeletionConfirmedEvent(posteId: posteId));
      final state = await waitForState(bloc, (state) => state.postes.length < _smallSeed.length);

      expect(state.postes.any((poste) => poste.id == posteId), isFalse);
      expect(state.selectedPosteId, isNull);
    });
  });

  group("creating and deleting a quote line", () {
    test("creates an empty line inside the poste and selects it, then deletes it", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      bloc.add(OcptBudgetLineCreatedEvent(posteId: posteId));
      final loadedWithLine = await waitForState(bloc, (state) => state.postes.first.lines.isNotEmpty);
      final lineId = loadedWithLine.postes.firstWhere((poste) => poste.id == posteId).lines.single.id;
      final withLine = await waitForState(
        bloc,
        (state) => state.selection == OcptBudgetLineSelection(lineId),
      );
      expect(withLine.selection, OcptBudgetLineSelection(lineId));

      bloc.add(OcptBudgetLineDeletionConfirmedEvent(lineId: lineId));
      final withoutLine = await waitForState(
        bloc,
        (state) => state.postes.firstWhere((poste) => poste.id == posteId).lines.isEmpty,
      );

      expect(withoutLine.postes.firstWhere((poste) => poste.id == posteId).lines, isEmpty);
    });
  });

  group("typing into a field", () {
    test("debounces the write: a unit price typed as 12.50 reads back as 1250 cents", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      bloc.add(OcptBudgetLineCreatedEvent(posteId: posteId));
      final withLine = await waitForState(
        bloc,
        (state) => state.postes.firstWhere((poste) => poste.id == posteId).lines.isNotEmpty,
      );
      final lineId = withLine.postes.firstWhere((poste) => poste.id == posteId).lines.single.id;

      bloc.add(
        OcptBudgetFieldChangedEvent(
          targetId: lineId,
          field: OcptBudgetField.lineUnitAmount,
          rawValue: "12.50",
        ),
      );

      // Right after the keystroke, the field reads the pending edit back — the debounce hasn't
      // flushed yet.
      final pending = await waitForState(
        bloc,
        (state) => state.pendingFieldEdits[(lineId, OcptBudgetField.lineUnitAmount)] == "12.50",
      );
      expect(pending.fieldValueOf(lineId, OcptBudgetField.lineUnitAmount, ""), "12.50");

      final flushed = await waitForState(
        bloc,
        (state) => state.postes
            .firstWhere((poste) => poste.id == posteId)
            .lines
            .firstWhere((line) => line.id == lineId)
            .unitPrice
            .amountCents ==
            1250,
      );

      final line = flushed.postes.firstWhere((poste) => poste.id == posteId).lines.single;
      expect(line.unitPrice.amountCents, 1250);
      expect(flushed.pendingFieldEdits, isEmpty);
    });

    test("switching view writes what is still in the debounce, so the next view reads it", () async {
      // The defect this pins: an amount typed in the cost-tracking table and followed straight by a
      // click on another chip was still sitting in the debounce, so the view switched to drew the
      // figures from before it and only corrected itself two seconds later.
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      bloc.add(OcptBudgetLineCreatedEvent(posteId: posteId));
      final withLine = await waitForState(
        bloc,
        (state) => state.postes.firstWhere((poste) => poste.id == posteId).lines.isNotEmpty,
      );
      final lineId = withLine.postes.firstWhere((poste) => poste.id == posteId).lines.single.id;

      bloc.add(
        OcptBudgetFieldChangedEvent(
          targetId: lineId,
          field: OcptBudgetField.lineUnitAmount,
          rawValue: "12.50",
        ),
      );
      await waitForState(
        bloc,
        (state) => state.pendingFieldEdits[(lineId, OcptBudgetField.lineUnitAmount)] == "12.50",
      );

      // Switching document, well inside the debounce window, must write it rather than wait it out.
      bloc.add(const OcptBudgetDocumentSelectedEvent(document: OcptBudgetDocument.resources));

      // The flush emits the cleared edits first and reloads the snapshot after, so the state worth
      // waiting for is the one that carries the written figure, not merely an empty pending map.
      final switched = await waitForState(
        bloc,
        (state) =>
            state.document == OcptBudgetDocument.resources &&
            state.postes
                    .firstWhere((poste) => poste.id == posteId)
                    .lines
                    .single
                    .unitPrice
                    .amountCents ==
                1250,
      );

      expect(switched.pendingFieldEdits, isEmpty);
    });

    test("skips the write when the typed unit price does not parse, leaving the stored value alone", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      bloc.add(OcptBudgetLineCreatedEvent(posteId: posteId));
      final withLine = await waitForState(
        bloc,
        (state) => state.postes.firstWhere((poste) => poste.id == posteId).lines.isNotEmpty,
      );
      final lineId = withLine.postes.firstWhere((poste) => poste.id == posteId).lines.single.id;
      final storedBefore = withLine.postes
          .firstWhere((poste) => poste.id == posteId)
          .lines
          .single
          .unitPrice
          .amountCents;

      bloc.add(
        OcptBudgetFieldChangedEvent(
          targetId: lineId,
          field: OcptBudgetField.lineUnitAmount,
          rawValue: "not a number",
        ),
      );
      final flushed = await waitForState(bloc, (state) => state.pendingFieldEdits.isEmpty);

      final line = flushed.postes.firstWhere((poste) => poste.id == posteId).lines.single;
      expect(line.unitPrice.amountCents, storedBefore);
    });
  });

  group("a line's tax basis", () {
    test("is written immediately, never through the field-edit debounce", () async {
      final bloc = buildBloc(fieldEditDebounce: const Duration(seconds: 30));
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      bloc.add(OcptBudgetLineCreatedEvent(posteId: posteId));
      final withLine = await waitForState(
        bloc,
        (state) => state.postes.firstWhere((poste) => poste.id == posteId).lines.isNotEmpty,
      );
      final lineId = withLine.postes.firstWhere((poste) => poste.id == posteId).lines.single.id;

      bloc.add(OcptBudgetLineTaxInclusiveChangedEvent(lineId: lineId, isTaxInclusive: false));
      final state = await waitForState(
        bloc,
        (state) => !state.postes
            .firstWhere((poste) => poste.id == posteId)
            .lines
            .single
            .unitPrice
            .isTaxInclusive,
      );

      expect(
        state.postes.firstWhere((poste) => poste.id == posteId).lines.single.unitPrice.isTaxInclusive,
        isFalse,
      );
    });
  });

  group("a line's VAT rate override", () {
    test("the Inherit action clears it back to null immediately", () async {
      final bloc = buildBloc(fieldEditDebounce: const Duration(seconds: 30));
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;
      final project = projectsManager.currentProject!;

      bloc.add(OcptBudgetLineCreatedEvent(posteId: posteId));
      final withLine = await waitForState(
        bloc,
        (state) => state.postes.firstWhere((poste) => poste.id == posteId).lines.isNotEmpty,
      );
      final lineId = withLine.postes.firstWhere((poste) => poste.id == posteId).lines.single.id;

      await projectsManager.budgetQuoteService.updateLine(
        database: project.database,
        lineId: lineId,
        vatRateBasisPoints: const drift.Value(550),
      );

      // The write above went straight through the service, bypassing the bloc, so its own cached
      // state hasn't caught up yet — its line still (stale) reads a null override, exactly the
      // value the Inherit action is about to produce for real. Reloading first, and waiting for
      // the override to actually show up as 550, is what keeps the assertion below honest: without
      // it, `waitForState` would resolve against this stale cached `null` the instant the Inherit
      // event is dispatched, never actually waiting for its own reload to land.
      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(
        bloc,
        (state) => state.postes
            .firstWhere((poste) => poste.id == posteId)
            .lines
            .single
            .unitPrice
            .vatRateBasisPoints ==
            550,
      );

      bloc.add(OcptBudgetLineVatRateInheritedRequestedEvent(lineId: lineId));
      final state = await waitForState(
        bloc,
        (state) => state.postes
            .firstWhere((poste) => poste.id == posteId)
            .lines
            .single
            .unitPrice
            .vatRateBasisPoints ==
            null,
      );

      expect(
        state.postes.firstWhere((poste) => poste.id == posteId).lines.single.unitPrice.vatRateBasisPoints,
        isNull,
      );
    });
  });

  group("a poste's estimate to complete", () {
    test("a typed figure debounces the write: 12.50 reads back as 1250 cents", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      bloc.add(
        OcptBudgetFieldChangedEvent(
          targetId: posteId,
          field: OcptBudgetField.posteEstimateToComplete,
          rawValue: "12.50",
        ),
      );

      // Right after the keystroke, the field reads the pending edit back — the debounce hasn't
      // flushed yet.
      final pending = await waitForState(
        bloc,
        (state) => state.pendingFieldEdits[(posteId, OcptBudgetField.posteEstimateToComplete)] ==
            "12.50",
      );
      expect(pending.fieldValueOf(posteId, OcptBudgetField.posteEstimateToComplete, ""), "12.50");

      final flushed = await waitForState(
        bloc,
        (state) =>
            state.postes.firstWhere((poste) => poste.id == posteId).estimateToCompleteCents == 1250,
      );

      expect(
        flushed.postes.firstWhere((poste) => poste.id == posteId).estimateToCompleteCents,
        1250,
      );
      expect(flushed.pendingFieldEdits, isEmpty);
    });

    test(
      "skips the write when the typed figure does not parse, leaving the stored value alone",
      () async {
        final bloc = buildBloc();
        addTearDown(bloc.close);
        final loaded = await waitForState(bloc, (state) => !state.isLoading);
        final posteId = loaded.postes.first.id;
        final storedBefore = loaded.postes
            .firstWhere((poste) => poste.id == posteId)
            .estimateToCompleteCents;

        bloc.add(
          OcptBudgetFieldChangedEvent(
            targetId: posteId,
            field: OcptBudgetField.posteEstimateToComplete,
            rawValue: "not a number",
          ),
        );
        final flushed = await waitForState(bloc, (state) => state.pendingFieldEdits.isEmpty);

        expect(
          flushed.postes.firstWhere((poste) => poste.id == posteId).estimateToCompleteCents,
          storedBefore,
        );
      },
    );

    test("skips the write on an empty submission too, never writing zero", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;
      final storedBefore = loaded.postes
          .firstWhere((poste) => poste.id == posteId)
          .estimateToCompleteCents;

      bloc.add(
        OcptBudgetFieldChangedEvent(
          targetId: posteId,
          field: OcptBudgetField.posteEstimateToComplete,
          rawValue: "",
        ),
      );
      final flushed = await waitForState(bloc, (state) => state.pendingFieldEdits.isEmpty);

      expect(
        flushed.postes.firstWhere((poste) => poste.id == posteId).estimateToCompleteCents,
        storedBefore,
      );
    });

    test("the Derive again action clears it back to null immediately", () async {
      final bloc = buildBloc(fieldEditDebounce: const Duration(seconds: 30));
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;
      final project = projectsManager.currentProject!;

      await projectsManager.budgetQuoteService.updatePoste(
        database: project.database,
        posteId: posteId,
        estimateToCompleteCents: const drift.Value(5000),
      );

      // The write above went straight through the service, bypassing the bloc, so its own cached
      // state hasn't caught up yet — see the mirrored VAT-rate test above for why reloading first,
      // and waiting for the typed figure to actually show up, is what keeps the assertion below
      // honest.
      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(
        bloc,
        (state) =>
            state.postes.firstWhere((poste) => poste.id == posteId).estimateToCompleteCents == 5000,
      );

      bloc.add(OcptBudgetPosteEstimateToCompleteDerivedRequestedEvent(posteId: posteId));
      final state = await waitForState(
        bloc,
        (state) =>
            state.postes.firstWhere((poste) => poste.id == posteId).estimateToCompleteCents == null,
      );

      expect(
        state.postes.firstWhere((poste) => poste.id == posteId).estimateToCompleteCents,
        isNull,
      );
    });
  });

  group("the right dock", () {
    test("persists the fraction and the last tab", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptBudgetRightDockFractionChangedEvent(fraction: 0.3));
      await waitForState(bloc, (state) => state.rightDockFraction == 0.3);
      expect(await propertiesManager.budgetRightDockFraction.load(), 0.3);

      bloc.add(const OcptBudgetRightDockTabSelectedEvent(tab: OcptBudgetRightDockTab.versions));
      await waitForState(bloc, (state) => state.rightDockTab == OcptBudgetRightDockTab.versions);
      expect(await propertiesManager.budgetLastRightDockTab.load(), OcptBudgetRightDockTab.versions);
    });
  });

  group("the cash journal", () {
    test("loads its entries, and paidCentsOf reflects a poste that has actually been paid", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;
      final otherPosteId = loaded.postes[1].id;
      final project = projectsManager.currentProject!;

      await projectsManager.budgetJournalService.createEntry(
        database: project.database,
        date: DateTime(2026),
        label: "Camera rental",
        posteId: posteId,
        debitCents: 5000,
      );

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      final state = await waitForState(bloc, (state) => state.entries.isNotEmpty);

      expect(state.entries, hasLength(1));
      expect(state.paidCentsOf(posteId), 5000);
      // A poste with no entry against it reads a real zero, not a hole.
      expect(state.paidCentsOf(otherPosteId), 0);
    });
  });

  group("creating a cash-journal entry", () {
    test("a taking named as still to be made is created, and the entry names it", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(
        OcptBudgetEntryCreationConfirmedEvent(
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026, 6),
            label: "Festival prize paid",
            posteId: null,
            resourceId: null,
            revenueId: null,
            shareId: null,
            newRevenue: OcptBudgetRevenueFormFields(
              date: DateTime(2026, 5),
              label: "Clermont-Ferrand — grand prix",
              amountCents: 200000,
              status: OcptBudgetRevenueStatus.expected,
              notes: "",
            ),
            isDebit: false,
            amountCents: 200000,
            isTaxInclusive: true,
            vatRateBasisPoints: null,
            voucherNumber: null,
            pickedReceiptPath: null,
            isReceiptDetached: false,
          ),
        ),
      );
      final state = await waitForState(bloc, (state) => state.entries.isNotEmpty);

      // The taking is written exactly as the sharing view would have written it — every field,
      // not just the label the journal needed to name it by.
      expect(state.revenues, hasLength(1));
      final revenue = state.revenues.single;
      expect(revenue.label, "Clermont-Ferrand — grand prix");
      expect(revenue.date, DateTime(2026, 5));
      expect(revenue.amountCents, 200000);

      // And the movement points at it, so the sharing view reads the money as actually received
      // rather than as an unattached credit.
      expect(state.entries.single.revenueId, revenue.id);
    });

    test("writes the typed amount onto debitCents when isDebit is true", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      bloc.add(
        OcptBudgetEntryCreationConfirmedEvent(
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026, 3),
            label: "Camera rental",
            posteId: posteId,
            resourceId: null,
            revenueId: null,
            shareId: null,
            isDebit: true,
            amountCents: 5000,
            isTaxInclusive: true,
            vatRateBasisPoints: null,
            voucherNumber: null,
            pickedReceiptPath: null,
            isReceiptDetached: false,
          ),
        ),
      );
      final state = await waitForState(bloc, (state) => state.entries.isNotEmpty);

      expect(state.entries, hasLength(1));
      final entry = state.entries.single;
      expect(entry.label, "Camera rental");
      expect(entry.posteId, posteId);
      expect(entry.debitCents, 5000);
      expect(entry.creditCents, 0);
      // The service mints its own voucher number rather than reading the (null) one submitted.
      expect(entry.voucherNumber, "J-001");
    });

    test("writes the typed amount onto creditCents when isDebit is false", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(
        OcptBudgetEntryCreationConfirmedEvent(
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026, 3, 2),
            label: "Grant received",
            posteId: null,
            resourceId: null,
            revenueId: null,
            shareId: null,
            isDebit: false,
            amountCents: 20000,
            isTaxInclusive: true,
            vatRateBasisPoints: null,
            voucherNumber: null,
            pickedReceiptPath: null,
            isReceiptDetached: false,
          ),
        ),
      );
      final state = await waitForState(bloc, (state) => state.entries.isNotEmpty);

      final entry = state.entries.single;
      expect(entry.debitCents, 0);
      expect(entry.creditCents, 20000);
      expect(entry.posteId, isNull);
    });
  });

  group("an entry's own voucher", () {
    test("a fresh pick on creation is referenced against the new entry", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      bloc.add(
        OcptBudgetEntryCreationConfirmedEvent(
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026, 3),
            label: "Camera rental",
            posteId: posteId,
            resourceId: null,
            revenueId: null,
            shareId: null,
            isDebit: true,
            amountCents: 5000,
            isTaxInclusive: true,
            vatRateBasisPoints: null,
            voucherNumber: null,
            pickedReceiptPath: "/tmp/receipt.pdf",
            isReceiptDetached: false,
          ),
        ),
      );
      final state = await waitForState(
        bloc,
        (state) => state.entries.isNotEmpty && state.receiptsByEntryId.isNotEmpty,
      );

      final entry = state.entries.single;
      expect(state.receiptsByEntryId[entry.id]?.path, "/tmp/receipt.pdf");
    });

    test("a fresh pick on an edit replaces whatever the entry already referenced", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;
      final project = projectsManager.currentProject!;

      final entryId = await projectsManager.budgetJournalService.createEntry(
        database: project.database,
        date: DateTime(2026),
        label: "Original",
        posteId: posteId,
        debitCents: 1000,
      );
      await projectsManager.budgetJournalService.setEntryReceipt(
        database: project.database,
        entryId: entryId!,
        path: "/tmp/first.pdf",
      );

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.receiptsByEntryId.isNotEmpty);

      bloc.add(
        OcptBudgetEntryUpdateConfirmedEvent(
          entryId: entryId,
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026),
            label: "Original",
            posteId: posteId,
            resourceId: null,
            revenueId: null,
            shareId: null,
            isDebit: true,
            amountCents: 1000,
            isTaxInclusive: true,
            vatRateBasisPoints: null,
            voucherNumber: null,
            pickedReceiptPath: "/tmp/second.pdf",
            isReceiptDetached: false,
          ),
        ),
      );
      final state = await waitForState(
        bloc,
        (state) => state.receiptsByEntryId[entryId]?.path == "/tmp/second.pdf",
      );

      expect(state.receiptsByEntryId, hasLength(1));
    });

    test("the dialog's own Detach action drops the reference on an edit", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;
      final project = projectsManager.currentProject!;

      final entryId = await projectsManager.budgetJournalService.createEntry(
        database: project.database,
        date: DateTime(2026),
        label: "Original",
        posteId: posteId,
        debitCents: 1000,
      );
      await projectsManager.budgetJournalService.setEntryReceipt(
        database: project.database,
        entryId: entryId!,
        path: "/tmp/receipt.pdf",
      );

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.receiptsByEntryId.isNotEmpty);

      bloc.add(
        OcptBudgetEntryUpdateConfirmedEvent(
          entryId: entryId,
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026),
            label: "Original",
            posteId: posteId,
            resourceId: null,
            revenueId: null,
            shareId: null,
            isDebit: true,
            amountCents: 1000,
            isTaxInclusive: true,
            vatRateBasisPoints: null,
            voucherNumber: null,
            pickedReceiptPath: null,
            isReceiptDetached: true,
          ),
        ),
      );
      final state = await waitForState(bloc, (state) => state.receiptsByEntryId.isEmpty);

      expect(state.receiptsByEntryId, isEmpty);
    });

    test("settling a commitment can reference a voucher on the fresh entry it creates", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;
      final project = projectsManager.currentProject!;

      final commitmentId = await projectsManager.budgetJournalService.createCommitment(
        database: project.database,
        posteId: posteId,
        label: "Camera deposit",
        amountCents: 5000,
      );
      expect(commitmentId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.commitments.isNotEmpty);

      bloc.add(
        OcptBudgetCommitmentSettlementConfirmedEvent(
          commitmentId: commitmentId!,
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026, 4),
            label: "Camera deposit",
            posteId: posteId,
            resourceId: null,
            revenueId: null,
            shareId: null,
            isDebit: true,
            amountCents: 5000,
            isTaxInclusive: true,
            vatRateBasisPoints: null,
            voucherNumber: null,
            pickedReceiptPath: "/tmp/invoice.pdf",
            isReceiptDetached: false,
          ),
        ),
      );
      final state = await waitForState(
        bloc,
        (state) => state.commitments.single.isSettled && state.receiptsByEntryId.isNotEmpty,
      );

      final settledEntry = state.entries.single;
      expect(state.receiptsByEntryId[settledEntry.id]?.path, "/tmp/invoice.pdf");
    });
  });

  group("editing a cash-journal entry", () {
    test("writes every field back, the voucher number included", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;
      final otherPosteId = loaded.postes[1].id;
      final project = projectsManager.currentProject!;

      final entryId = await projectsManager.budgetJournalService.createEntry(
        database: project.database,
        date: DateTime(2026),
        label: "Original",
        posteId: posteId,
        debitCents: 1000,
      );
      expect(entryId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.entries.isNotEmpty);

      bloc.add(
        OcptBudgetEntryUpdateConfirmedEvent(
          entryId: entryId!,
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026, 2, 2),
            label: "Renamed",
            posteId: otherPosteId,
            resourceId: null,
            revenueId: null,
            shareId: null,
            isDebit: false,
            amountCents: 750,
            isTaxInclusive: false,
            vatRateBasisPoints: 2000,
            voucherNumber: "J-999",
            pickedReceiptPath: null,
            isReceiptDetached: false,
          ),
        ),
      );
      final state = await waitForState(bloc, (state) => state.entries.single.label == "Renamed");

      final entry = state.entries.single;
      expect(entry.posteId, otherPosteId);
      expect(entry.debitCents, 0);
      expect(entry.creditCents, 750);
      expect(entry.isTaxInclusive, isFalse);
      expect(entry.vatRateBasisPoints, 2000);
      expect(entry.voucherNumber, "J-999");
    });
  });

  group("deleting a cash-journal entry", () {
    test("tombstones it", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;
      final project = projectsManager.currentProject!;

      final entryId = await projectsManager.budgetJournalService.createEntry(
        database: project.database,
        date: DateTime(2026),
        label: "To be deleted",
        posteId: posteId,
        debitCents: 500,
      );
      expect(entryId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.entries.isNotEmpty);

      bloc.add(OcptBudgetEntryDeletionConfirmedEvent(entryId: entryId!));
      final state = await waitForState(bloc, (state) => state.entries.isEmpty);

      expect(state.entries, isEmpty);
    });
  });

  group("the mode's own poste filter", () {
    test("selecting a poste filters nothing, and filtering selects nothing", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;
      final otherPosteId = loaded.postes[1].id;

      // The two used to be one field, which is how a click in the quote came to narrow the cash
      // journal without anything saying so.
      bloc.add(OcptBudgetPosteSelectedEvent(posteId: posteId));
      final selected = await waitForState(bloc, (state) => state.selectedPosteId == posteId);
      expect(selected.filterPosteId, isNull);

      bloc.add(OcptBudgetPosteFilterSelectedEvent(posteId: otherPosteId));
      final filtered = await waitForState(bloc, (state) => state.filterPosteId == otherPosteId);
      expect(filtered.selectedPosteId, posteId);
    });

    test("a null poste clears the filter", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      bloc.add(OcptBudgetPosteFilterSelectedEvent(posteId: posteId));
      await waitForState(bloc, (state) => state.filterPosteId == posteId);

      bloc.add(const OcptBudgetPosteFilterSelectedEvent(posteId: null));
      final state = await waitForState(bloc, (state) => state.filterPosteId == null);

      expect(state.filterPosteId, isNull);
    });

    test("a poste naming no live poste is ignored", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      bloc.add(OcptBudgetPosteFilterSelectedEvent(posteId: posteId));
      await waitForState(bloc, (state) => state.filterPosteId == posteId);

      bloc.add(const OcptBudgetPosteFilterSelectedEvent(posteId: "no-such-poste"));
      await pumpEventQueue();

      expect(bloc.state.filterPosteId, posteId);
    });

    test("deleting the filtered poste clears the filter", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      bloc.add(OcptBudgetPosteFilterSelectedEvent(posteId: posteId));
      await waitForState(bloc, (state) => state.filterPosteId == posteId);

      bloc.add(OcptBudgetPosteDeletionConfirmedEvent(posteId: posteId));
      final state = await waitForState(
        bloc,
        (state) => state.postes.every((poste) => poste.id != posteId),
      );

      expect(state.filterPosteId, isNull);
    });
  });

  group("promoting a quote line into a commitment", () {
    test("the commitment names the line it came from, and the line stays put", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      bloc.add(OcptBudgetLineCreatedEvent(posteId: posteId));
      final withLine = await waitForState(bloc, (state) => state.postes.first.lines.isNotEmpty);
      final lineId = withLine.postes.first.lines.single.id;

      bloc.add(
        OcptBudgetCommitmentCreationConfirmedEvent(
          lineId: lineId,
          fields: OcptBudgetCommitmentFormFields(
            dueDate: DateTime(2026, 6),
            label: "Camera deposit",
            posteId: posteId,
            amountCents: 145000,
            isTaxInclusive: true,
            vatRateBasisPoints: null,
            status: OcptBudgetCommitmentStatus.quoteAccepted,
          ),
        ),
      );
      final state = await waitForState(bloc, (state) => state.commitments.isNotEmpty);

      expect(state.commitments.single.lineId, lineId);
      // A promotion, not a move: the estimate stays, which is what makes comparing it with what
      // is actually owed possible at all.
      expect(state.postes.first.lines.map((line) => line.id), [lineId]);
    });

    test("a commitment typed from scratch names no line", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(
        OcptBudgetCommitmentCreationConfirmedEvent(
          fields: OcptBudgetCommitmentFormFields(
            dueDate: null,
            label: "Insurance",
            posteId: loaded.postes.first.id,
            amountCents: 5000,
            isTaxInclusive: true,
            vatRateBasisPoints: null,
            status: OcptBudgetCommitmentStatus.quoteAccepted,
          ),
        ),
      );
      final state = await waitForState(bloc, (state) => state.commitments.isNotEmpty);

      expect(state.commitments.single.lineId, isNull);
    });
  });

  group("creating a commitment", () {
    test("writes every field, defaulting settledEntryId to null", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      bloc.add(
        OcptBudgetCommitmentCreationConfirmedEvent(
          fields: OcptBudgetCommitmentFormFields(
            dueDate: DateTime(2026, 6),
            label: "Camera deposit",
            posteId: posteId,
            amountCents: 5000,
            isTaxInclusive: true,
            vatRateBasisPoints: null,
            status: OcptBudgetCommitmentStatus.quoteAccepted,
          ),
        ),
      );
      final state = await waitForState(bloc, (state) => state.commitments.isNotEmpty);

      expect(state.commitments, hasLength(1));
      final commitment = state.commitments.single;
      expect(commitment.label, "Camera deposit");
      expect(commitment.posteId, posteId);
      expect(commitment.amount.amountCents, 5000);
      expect(commitment.status, OcptBudgetCommitmentStatus.quoteAccepted);
      expect(commitment.isSettled, isFalse);
    });
  });

  group("editing a commitment", () {
    test("writes every field back, never the poste", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;
      final project = projectsManager.currentProject!;

      final commitmentId = await projectsManager.budgetJournalService.createCommitment(
        database: project.database,
        posteId: posteId,
        label: "Original",
        amountCents: 1000,
      );
      expect(commitmentId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.commitments.isNotEmpty);

      bloc.add(
        OcptBudgetCommitmentUpdateConfirmedEvent(
          commitmentId: commitmentId!,
          fields: OcptBudgetCommitmentFormFields(
            dueDate: DateTime(2026, 3),
            label: "Renamed",
            posteId: posteId,
            amountCents: 750,
            isTaxInclusive: false,
            vatRateBasisPoints: 2000,
            status: OcptBudgetCommitmentStatus.invoiceReceived,
          ),
        ),
      );
      final state = await waitForState(bloc, (state) => state.commitments.single.label == "Renamed");

      final commitment = state.commitments.single;
      expect(commitment.posteId, posteId);
      expect(commitment.amount.amountCents, 750);
      expect(commitment.amount.isTaxInclusive, isFalse);
      expect(commitment.amount.vatRateBasisPoints, 2000);
      expect(commitment.status, OcptBudgetCommitmentStatus.invoiceReceived);
    });
  });

  group("deleting a commitment", () {
    test("tombstones it", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;
      final project = projectsManager.currentProject!;

      final commitmentId = await projectsManager.budgetJournalService.createCommitment(
        database: project.database,
        posteId: posteId,
        label: "To be deleted",
        amountCents: 500,
      );
      expect(commitmentId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.commitments.isNotEmpty);

      bloc.add(OcptBudgetCommitmentDeletionConfirmedEvent(commitmentId: commitmentId!));
      final state = await waitForState(bloc, (state) => state.commitments.isEmpty);

      expect(state.commitments, isEmpty);
    });
  });

  group("settling a commitment", () {
    test("creates a debit entry and links it as settledEntryId", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;
      final project = projectsManager.currentProject!;

      final commitmentId = await projectsManager.budgetJournalService.createCommitment(
        database: project.database,
        posteId: posteId,
        label: "Camera deposit",
        amountCents: 5000,
      );
      expect(commitmentId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.commitments.isNotEmpty);

      bloc.add(
        OcptBudgetCommitmentSettlementConfirmedEvent(
          commitmentId: commitmentId!,
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026, 4),
            label: "Camera deposit",
            posteId: posteId,
            resourceId: null,
            revenueId: null,
            shareId: null,
            isDebit: true,
            amountCents: 5000,
            isTaxInclusive: true,
            vatRateBasisPoints: null,
            voucherNumber: null,
            pickedReceiptPath: null,
            isReceiptDetached: false,
          ),
        ),
      );
      final state = await waitForState(bloc, (state) => state.commitments.single.isSettled);

      expect(state.entries, hasLength(1));
      final entry = state.entries.single;
      expect(entry.debitCents, 5000);
      expect(entry.creditCents, 0);
      final commitment = state.commitments.single;
      expect(commitment.settledEntryId, entry.id);
      // Settled, it no longer counts as committed against the poste.
      expect(state.committedCentsOf(posteId), 0);
    });
  });

  group("unsettling a commitment", () {
    test("clears the link but leaves the journal entry alone", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;
      final project = projectsManager.currentProject!;

      final commitmentId = await projectsManager.budgetJournalService.createCommitment(
        database: project.database,
        posteId: posteId,
        label: "Camera deposit",
        amountCents: 5000,
      );
      expect(commitmentId, isNotNull);
      final entryId = await projectsManager.budgetJournalService.createEntry(
        database: project.database,
        date: DateTime(2026, 4),
        label: "Camera deposit",
        posteId: posteId,
        debitCents: 5000,
      );
      expect(entryId, isNotNull);
      await projectsManager.budgetJournalService.updateCommitment(
        database: project.database,
        commitmentId: commitmentId!,
        settledEntryId: drift.Value(entryId),
      );

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.commitments.isNotEmpty && state.commitments.single.isSettled);

      bloc.add(OcptBudgetCommitmentUnsettleRequestedEvent(commitmentId: commitmentId));
      final state = await waitForState(bloc, (state) => !state.commitments.single.isSettled);

      expect(state.commitments.single.settledEntryId, isNull);
      // The journal entry itself is untouched.
      expect(state.entries, hasLength(1));
      expect(state.entries.single.id, entryId);
    });
  });

  group("the financing plan", () {
    test("loads every live resource alongside the quote", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final project = projectsManager.currentProject!;

      final resourceId = await projectsManager.budgetFinancingService.createResource(
        database: project.database,
        label: "Regional grant",
      );
      expect(resourceId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      final state = await waitForState(bloc, (state) => state.resources.isNotEmpty);

      expect(state.resources, hasLength(1));
      expect(state.resources.single.label, "Regional grant");
      expect(state.resourceCount, 1);
    });
  });

  group("selecting a resource", () {
    test("highlights it, ignoring an id naming no live resource", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final project = projectsManager.currentProject!;
      final resourceId = await projectsManager.budgetFinancingService.createResource(
        database: project.database,
        label: "Regional grant",
      );
      expect(resourceId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.resources.isNotEmpty);

      bloc.add(const OcptBudgetResourceSelectedEvent(resourceId: "gone"));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.selectedResourceId, isNull);

      bloc.add(OcptBudgetResourceSelectedEvent(resourceId: resourceId!));
      final state = await waitForState(bloc, (state) => state.selectedResourceId != null);
      expect(state.selectedResourceId, resourceId);
    });
  });

  group("creating a resource", () {
    test("writes every field and selects it", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(
        const OcptBudgetResourceCreationConfirmedEvent(
          fields: OcptBudgetResourceFormFields(
            groupKind: OcptBudgetResourceGroupKind.inKind,
            personId: null,
            label: "Camera loan",
            amountCents: 250000,
            status: OcptBudgetResourceStatus.agreed,
            isReimbursable: false,
            notes: "Lent by the lab",
          ),
        ),
      );
      final state = await waitForState(bloc, (state) => state.selectedResourceId != null);

      expect(state.resources, hasLength(1));
      final resource = state.resources.single;
      expect(resource.groupKind, OcptBudgetResourceGroupKind.inKind);
      expect(resource.label, "Camera loan");
      expect(resource.amountCents, 250000);
      expect(resource.status, OcptBudgetResourceStatus.agreed);
      expect(resource.notes, "Lent by the lab");
      expect(state.selectedResourceId, resource.id);
    });
  });

  group("editing a resource", () {
    test("writes every field back", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final project = projectsManager.currentProject!;
      final resourceId = await projectsManager.budgetFinancingService.createResource(
        database: project.database,
        label: "Original",
      );
      expect(resourceId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.resources.isNotEmpty);

      bloc.add(
        OcptBudgetResourceUpdateConfirmedEvent(
          resourceId: resourceId!,
          fields: const OcptBudgetResourceFormFields(
            groupKind: OcptBudgetResourceGroupKind.cash,
            personId: null,
            label: "Renamed",
            amountCents: 500,
            status: OcptBudgetResourceStatus.confirmed,
            isReimbursable: true,
            notes: "Repaid before the split",
          ),
        ),
      );
      final state = await waitForState(bloc, (state) => state.resources.single.label == "Renamed");

      final resource = state.resources.single;
      expect(resource.groupKind, OcptBudgetResourceGroupKind.cash);
      expect(resource.amountCents, 500);
      expect(resource.status, OcptBudgetResourceStatus.confirmed);
      expect(resource.isReimbursable, isTrue);
      expect(resource.notes, "Repaid before the split");
    });
  });

  group("deleting a resource", () {
    test("tombstones it, and clears the selection when it was selected", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final project = projectsManager.currentProject!;
      final resourceId = await projectsManager.budgetFinancingService.createResource(
        database: project.database,
        label: "To be deleted",
      );
      expect(resourceId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.resources.isNotEmpty);
      bloc.add(OcptBudgetResourceSelectedEvent(resourceId: resourceId!));
      await waitForState(bloc, (state) => state.selectedResourceId == resourceId);

      bloc.add(OcptBudgetResourceDeletionConfirmedEvent(resourceId: resourceId));
      final state = await waitForState(bloc, (state) => state.resources.isEmpty);

      expect(state.resources, isEmpty);
      expect(state.selectedResourceId, isNull);
    });
  });

  group("an entry naming a resource", () {
    test("writes resourceId, and it shows up in receivedByResourceId once credited", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final project = projectsManager.currentProject!;
      final resourceId = await projectsManager.budgetFinancingService.createResource(
        database: project.database,
        label: "Regional grant",
      );
      expect(resourceId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.resources.isNotEmpty);

      bloc.add(
        OcptBudgetEntryCreationConfirmedEvent(
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026, 3),
            label: "Grant instalment",
            posteId: null,
            resourceId: resourceId,
            revenueId: null,
            shareId: null,
            isDebit: false,
            amountCents: 5000,
            isTaxInclusive: true,
            vatRateBasisPoints: null,
            voucherNumber: null,
            pickedReceiptPath: null,
            isReceiptDetached: false,
          ),
        ),
      );
      final state = await waitForState(bloc, (state) => state.entries.isNotEmpty);

      expect(state.entries.single.resourceId, resourceId);
      expect(state.receivedByResourceId[resourceId]?.amountCents, 5000);
      expect(state.receivedCentsOf(resourceId!), 5000);
    });

    test("an edit can also name a resource, wiring it the very same way", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final project = projectsManager.currentProject!;
      final resourceId = await projectsManager.budgetFinancingService.createResource(
        database: project.database,
        label: "Regional grant",
      );
      expect(resourceId, isNotNull);
      final entryId = await projectsManager.budgetJournalService.createEntry(
        database: project.database,
        date: DateTime(2026, 3),
        label: "Grant instalment",
        creditCents: 5000,
      );
      expect(entryId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.entries.isNotEmpty && state.resources.isNotEmpty);

      bloc.add(
        OcptBudgetEntryUpdateConfirmedEvent(
          entryId: entryId!,
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026, 3),
            label: "Grant instalment",
            posteId: null,
            resourceId: resourceId,
            revenueId: null,
            shareId: null,
            isDebit: false,
            amountCents: 5000,
            isTaxInclusive: true,
            vatRateBasisPoints: null,
            voucherNumber: "J-001",
            pickedReceiptPath: null,
            isReceiptDetached: false,
          ),
        ),
      );
      final state = await waitForState(
        bloc,
        (state) => state.entries.single.resourceId == resourceId,
      );

      expect(state.receivedCentsOf(resourceId!), 5000);
    });
  });

  group("the revenue sharing", () {
    test("loads every live revenue and share alongside the quote", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final project = projectsManager.currentProject!;

      final revenueId = await projectsManager.budgetSharingService.createRevenue(
        database: project.database,
        date: DateTime(2026, 3),
        label: "Festival prize",
      );
      final shareId = await projectsManager.budgetSharingService.createShare(
        database: project.database,
        label: "Production",
      );
      expect(revenueId, isNotNull);
      expect(shareId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      final state = await waitForState(
        bloc,
        (state) => state.revenues.isNotEmpty && state.shares.isNotEmpty,
      );

      expect(state.revenues, hasLength(1));
      expect(state.revenues.single.label, "Festival prize");
      expect(state.revenueCount, 1);
      expect(state.shares, hasLength(1));
      expect(state.shares.single.label, "Production");
      expect(state.shareCount, 1);
    });
  });

  group("selecting a revenue", () {
    test("highlights it, ignoring an id naming no live revenue", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final project = projectsManager.currentProject!;
      final revenueId = await projectsManager.budgetSharingService.createRevenue(
        database: project.database,
        date: DateTime(2026, 3),
        label: "Festival prize",
      );
      expect(revenueId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.revenues.isNotEmpty);

      bloc.add(const OcptBudgetRevenueSelectedEvent(revenueId: "gone"));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.selectedRevenueId, isNull);

      bloc.add(OcptBudgetRevenueSelectedEvent(revenueId: revenueId!));
      final state = await waitForState(bloc, (state) => state.selectedRevenueId != null);
      expect(state.selectedRevenueId, revenueId);
    });

    test("opens the Inspector tab, mirroring selecting a resource", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final project = projectsManager.currentProject!;
      final revenueId = await projectsManager.budgetSharingService.createRevenue(
        database: project.database,
        date: DateTime(2026, 3),
        label: "Festival prize",
      );
      expect(revenueId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.revenues.isNotEmpty);

      bloc.add(OcptBudgetRevenueSelectedEvent(revenueId: revenueId!));
      final state = await waitForState(
        bloc,
        (state) => state.rightDockTab == OcptBudgetRightDockTab.inspector,
      );
      expect(state.selection, OcptBudgetRevenueSelection(revenueId));
    });
  });

  group("creating a revenue", () {
    test("writes every field and selects it", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(
        OcptBudgetRevenueCreationConfirmedEvent(
          fields: OcptBudgetRevenueFormFields(
            date: DateTime(2026, 3),
            label: "Festival prize",
            amountCents: 250000,
            status: OcptBudgetRevenueStatus.confirmed,
            notes: "Announced at the closing ceremony",
          ),
        ),
      );
      final state = await waitForState(bloc, (state) => state.selectedRevenueId != null);

      expect(state.revenues, hasLength(1));
      final revenue = state.revenues.single;
      expect(revenue.label, "Festival prize");
      expect(revenue.amountCents, 250000);
      expect(revenue.status, OcptBudgetRevenueStatus.confirmed);
      expect(revenue.notes, "Announced at the closing ceremony");
      expect(state.selectedRevenueId, revenue.id);
    });
  });

  group("editing a revenue", () {
    test("writes every field back", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final project = projectsManager.currentProject!;
      final revenueId = await projectsManager.budgetSharingService.createRevenue(
        database: project.database,
        date: DateTime(2026, 3),
        label: "Original",
      );
      expect(revenueId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.revenues.isNotEmpty);

      bloc.add(
        OcptBudgetRevenueUpdateConfirmedEvent(
          revenueId: revenueId!,
          fields: OcptBudgetRevenueFormFields(
            date: DateTime(2026, 4),
            label: "Renamed",
            amountCents: 500,
            status: OcptBudgetRevenueStatus.invoiced,
            notes: "Billed",
          ),
        ),
      );
      final state = await waitForState(bloc, (state) => state.revenues.single.label == "Renamed");

      final revenue = state.revenues.single;
      expect(revenue.amountCents, 500);
      expect(revenue.status, OcptBudgetRevenueStatus.invoiced);
      expect(revenue.notes, "Billed");
    });
  });

  group("reordering a revenue", () {
    test("moves it to the new position", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final project = projectsManager.currentProject!;
      final firstId = await projectsManager.budgetSharingService.createRevenue(
        database: project.database,
        date: DateTime(2026, 3),
        label: "First",
      );
      await projectsManager.budgetSharingService.createRevenue(
        database: project.database,
        date: DateTime(2026, 3),
        label: "Second",
      );
      expect(firstId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.revenues.length == 2);

      bloc.add(OcptBudgetRevenueReorderedEvent(revenueId: firstId!, newPosition: 1));
      final state = await waitForState(bloc, (state) => state.revenues.last.id == firstId);

      expect(state.revenues.last.id, firstId);
    });
  });

  group("deleting a revenue", () {
    test("tombstones it, and clears the selection when it was selected", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final project = projectsManager.currentProject!;
      final revenueId = await projectsManager.budgetSharingService.createRevenue(
        database: project.database,
        date: DateTime(2026, 3),
        label: "To be deleted",
      );
      expect(revenueId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.revenues.isNotEmpty);
      bloc.add(OcptBudgetRevenueSelectedEvent(revenueId: revenueId!));
      await waitForState(bloc, (state) => state.selectedRevenueId == revenueId);

      bloc.add(OcptBudgetRevenueDeletionConfirmedEvent(revenueId: revenueId));
      final state = await waitForState(bloc, (state) => state.revenues.isEmpty);

      expect(state.revenues, isEmpty);
      expect(state.selectedRevenueId, isNull);
    });
  });

  group("an entry naming a revenue", () {
    test("writes revenueId, and it shows up in receivedByRevenueId once credited", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final project = projectsManager.currentProject!;
      final revenueId = await projectsManager.budgetSharingService.createRevenue(
        database: project.database,
        date: DateTime(2026, 3),
        label: "Festival prize",
      );
      expect(revenueId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.revenues.isNotEmpty);

      bloc.add(
        OcptBudgetEntryCreationConfirmedEvent(
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026, 3),
            label: "Prize received",
            posteId: null,
            resourceId: null,
            revenueId: revenueId,
            shareId: null,
            isDebit: false,
            amountCents: 5000,
            isTaxInclusive: true,
            vatRateBasisPoints: null,
            voucherNumber: null,
            pickedReceiptPath: null,
            isReceiptDetached: false,
          ),
        ),
      );
      final state = await waitForState(bloc, (state) => state.entries.isNotEmpty);

      expect(state.entries.single.revenueId, revenueId);
      expect(state.receivedByRevenueId[revenueId]?.amountCents, 5000);
      expect(state.receivedRevenueCentsOf(revenueId!), 5000);
    });
  });

  group("selecting a share", () {
    test("highlights it, ignoring an id naming no live share", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final project = projectsManager.currentProject!;
      final shareId = await projectsManager.budgetSharingService.createShare(
        database: project.database,
        label: "Production",
      );
      expect(shareId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.shares.isNotEmpty);

      bloc.add(const OcptBudgetShareSelectedEvent(shareId: "gone"));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.selectedShareId, isNull);

      bloc.add(OcptBudgetShareSelectedEvent(shareId: shareId!));
      final state = await waitForState(bloc, (state) => state.selectedShareId != null);
      expect(state.selectedShareId, shareId);
    });
  });

  group("creating a share", () {
    test("writes every field and selects it", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(
        const OcptBudgetShareCreationConfirmedEvent(
          fields: OcptBudgetShareFormFields(
            personId: null,
            label: "Director",
            sharePermille: 300,
            reinvestPermille: 100,
            notes: "Agreed by contract",
          ),
        ),
      );
      final state = await waitForState(bloc, (state) => state.selectedShareId != null);

      expect(state.shares, hasLength(1));
      final share = state.shares.single;
      expect(share.label, "Director");
      expect(share.sharePermille, 300);
      expect(share.reinvestPermille, 100);
      expect(share.notes, "Agreed by contract");
      expect(state.selectedShareId, share.id);
    });
  });

  group("editing a share", () {
    test("writes every field back", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final project = projectsManager.currentProject!;
      final shareId = await projectsManager.budgetSharingService.createShare(
        database: project.database,
        label: "Original",
      );
      expect(shareId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.shares.isNotEmpty);

      bloc.add(
        OcptBudgetShareUpdateConfirmedEvent(
          shareId: shareId!,
          fields: const OcptBudgetShareFormFields(
            personId: null,
            label: "Renamed",
            sharePermille: 600,
            reinvestPermille: 500,
            notes: "Renegotiated",
          ),
        ),
      );
      final state = await waitForState(bloc, (state) => state.shares.single.label == "Renamed");

      final share = state.shares.single;
      expect(share.sharePermille, 600);
      expect(share.reinvestPermille, 500);
      expect(share.notes, "Renegotiated");
    });
  });

  group("reordering a share", () {
    test("moves it to the new position", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final project = projectsManager.currentProject!;
      final firstId = await projectsManager.budgetSharingService.createShare(
        database: project.database,
        label: "First",
      );
      await projectsManager.budgetSharingService.createShare(
        database: project.database,
        label: "Second",
      );
      expect(firstId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.shares.length == 2);

      bloc.add(OcptBudgetShareReorderedEvent(shareId: firstId!, newPosition: 1));
      final state = await waitForState(bloc, (state) => state.shares.last.id == firstId);

      expect(state.shares.last.id, firstId);
    });
  });

  group("deleting a share", () {
    test("tombstones it, and clears the selection when it was selected", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final project = projectsManager.currentProject!;
      final shareId = await projectsManager.budgetSharingService.createShare(
        database: project.database,
        label: "To be deleted",
      );
      expect(shareId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.shares.isNotEmpty);
      bloc.add(OcptBudgetShareSelectedEvent(shareId: shareId!));
      await waitForState(bloc, (state) => state.selectedShareId == shareId);

      bloc.add(OcptBudgetShareDeletionConfirmedEvent(shareId: shareId));
      final state = await waitForState(bloc, (state) => state.shares.isEmpty);

      expect(state.shares, isEmpty);
      expect(state.selectedShareId, isNull);
    });
  });

  group("an entry naming a share", () {
    test("writes shareId, and it shows up in paidByShareId once debited", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final project = projectsManager.currentProject!;
      final shareId = await projectsManager.budgetSharingService.createShare(
        database: project.database,
        label: "Production",
      );
      expect(shareId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.shares.isNotEmpty);

      bloc.add(
        OcptBudgetEntryCreationConfirmedEvent(
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026, 3),
            label: "Payout",
            posteId: null,
            resourceId: null,
            revenueId: null,
            shareId: shareId,
            isDebit: true,
            amountCents: 5000,
            isTaxInclusive: true,
            vatRateBasisPoints: null,
            voucherNumber: null,
            pickedReceiptPath: null,
            isReceiptDetached: false,
          ),
        ),
      );
      final state = await waitForState(bloc, (state) => state.entries.isNotEmpty);

      expect(state.entries.single.shareId, shareId);
      expect(state.paidByShareId[shareId]?.amountCents, 5000);
      expect(state.paidShareCentsOf(shareId!), 5000);
    });
  });

  group("the catering pass", () {
    test("loads the schedule, the roles, the people and the prices, and computes the pass", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final project = projectsManager.currentProject!;

      final personId = await projectsManager.peopleService.createPerson(database: project.database);
      expect(personId, isNotNull);
      await projectsManager.peopleService.updatePerson(
        database: project.database,
        personId: personId!,
        commuteKmMilli: const drift.Value(10000),
      );

      final locationId = await projectsManager.locationsService.createLocation(
        database: project.database,
        name: "Studio A",
      );
      expect(locationId, isNotNull);

      final dayId = await projectsManager.scheduleService.createDay(
        database: project.database,
        date: DateTime(2026, 3),
      );
      expect(dayId, isNotNull);

      final scheduleSnapshot = await projectsManager.scheduleService.loadSchedule(
        database: project.database,
      );
      final slotId = scheduleSnapshot.slotsByDayId[dayId]!.single.id;
      await projectsManager.scheduleService.updateSlot(
        database: project.database,
        slotId: slotId,
        locationId: drift.Value(locationId),
      );
      await projectsManager.scheduleService.addSlotCrewMember(
        database: project.database,
        slotId: slotId,
        personId: personId,
      );

      await projectsManager.saveCurrentProjectMealPriceCents(1200);
      await projectsManager.saveCurrentProjectSnackPriceCents(400);

      // A mileage scale, there to pre-fill a defrayal somebody types — never to deduce one.
      await projectsManager.budgetFinancingService.createMileageRate(
        database: project.database,
        label: "Car",
      );

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      // Waits for the crew count itself, not merely for a day to exist: the bloc's own initial
      // load (fired at construction, before any of the writes above) races these very writes, and
      // a state it emits mid-way through them would still make `regieDays` non-empty on its own.
      final state = await waitForState(
        bloc,
        (state) => state.regieDays.isNotEmpty && state.regieDays.single.crewCount == 1,
      );

      expect(state.regieDays.single.dayId, dayId);
      expect(state.regieDays.single.crewCount, 1);
      expect(state.regieDays.single.headCount, 1);
      expect(state.regieDays.single.cost.isComplete, isTrue);
      expect(state.regieDecorNameByDayId[dayId], "Studio A");

      // The person's own commute is loaded and the mileage scales with it — both there to
      // pre-fill a defrayal somebody types — and nothing is deduced from either: a production that
      // has written no defrayal is defraying nobody.
      expect(state.allowances, isEmpty);
      expect(state.people.map((person) => person.id), contains(personId));
      expect(state.mileageRates, hasLength(1));
    });
  });

  group("the breakdown link", () {
    test(
      "loads the elements catalogue and derives how many are priced and how many are not",
      () async {
        final bloc = buildBloc();
        addTearDown(bloc.close);
        final project = projectsManager.currentProject!;

        final pricedElementId = await projectsManager.elementsService.createElement(
          database: project.database,
          name: "Camera body",
          category: OcptElementCategory.camera,
          sourceKind: OcptElementSourceKind.owned,
        );
        expect(pricedElementId, isNotNull);
        final unpricedElementId = await projectsManager.elementsService.createElement(
          database: project.database,
          name: "Dolly",
          category: OcptElementCategory.specialEquipment,
          sourceKind: OcptElementSourceKind.toBuy,
        );
        expect(unpricedElementId, isNotNull);

        final loaded = await waitForState(bloc, (state) => state.elements.length == 2);
        final posteId = loaded.postes.first.id;

        bloc.add(
          OcptBudgetLineCreatedFromElementEvent(posteId: posteId, elementId: pricedElementId!),
        );

        final state = await waitForState(
          bloc,
          (state) => state.elementLinkCounts.pricedCount == 1,
        );

        expect(state.elementLinkCounts.unpricedCount, 1);
        expect(state.unpricedElements.map((element) => element.id), [unpricedElementId]);
      },
    );

    test("a fresh line seeds its label and unit price from the element's own cost", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final project = projectsManager.currentProject!;

      final elementId = await projectsManager.elementsService.createElement(
        database: project.database,
        name: "Camera body",
        category: OcptElementCategory.camera,
        sourceKind: OcptElementSourceKind.owned,
      );
      expect(elementId, isNotNull);
      await projectsManager.elementsService.updateElement(
        database: project.database,
        elementId: elementId!,
        cost: const drift.Value(5000),
      );

      final loaded = await waitForState(bloc, (state) => state.elements.length == 1);
      final posteId = loaded.postes.first.id;

      bloc.add(OcptBudgetLineCreatedFromElementEvent(posteId: posteId, elementId: elementId));

      final state = await waitForState(
        bloc,
        (state) => state.postes.any((poste) => poste.lines.any((line) => line.elementId == elementId)),
      );
      final line = state.postes
          .expand((poste) => poste.lines)
          .firstWhere((line) => line.elementId == elementId);

      expect(line.label, "Camera body");
      expect(line.unitPrice.amountCents, 5000);
    });

    test(
      "an element with no cost seeds no unit price, the line left at the ordinary default",
      () async {
        final bloc = buildBloc();
        addTearDown(bloc.close);
        final project = projectsManager.currentProject!;

        final elementId = await projectsManager.elementsService.createElement(
          database: project.database,
          name: "Dolly",
          category: OcptElementCategory.specialEquipment,
          sourceKind: OcptElementSourceKind.toBuy,
        );
        expect(elementId, isNotNull);

        final loaded = await waitForState(bloc, (state) => state.elements.length == 1);
        final posteId = loaded.postes.first.id;

        bloc.add(OcptBudgetLineCreatedFromElementEvent(posteId: posteId, elementId: elementId!));

        final state = await waitForState(
          bloc,
          (state) => state.postes.any((poste) => poste.lines.any((line) => line.elementId == elementId)),
        );
        final line = state.postes
            .expand((poste) => poste.lines)
            .firstWhere((line) => line.elementId == elementId);

        expect(line.unitPrice.amountCents, 0);
      },
    );
  });

  group("exporting the quote", () {
    test("hands the snapshot and the tax basis to the manager and raises the succeeded notice", () async {
      final exportManager = _FakeBudgetExportManager(quoteResult: "/tmp/quote.pdf");
      final bloc = buildBloc(exportManager: exportManager);
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(
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
      final state = await waitForState(bloc, (state) => state.ioNotice != null);

      expect(exportManager.lastQuoteSnapshot, isNotNull);
      expect(exportManager.lastQuoteTaxBasis, OcptBudgetTaxBasis.excludingTax);
      expect(state.ioNotice?.kind, OcptBudgetIoNoticeKind.fileExportSucceeded);
      expect(state.ioNotice?.path, "/tmp/quote.pdf");

      await bloc.close();
    });

    test("is a silent no-op when the save dialog is cancelled", () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(
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

      expect(bloc.state.ioNotice, isNull);

      await bloc.close();
    });

    test("raises the failed notice when the export throws", () async {
      final bloc = buildBloc(exportManager: _FakeBudgetExportManager(quoteFails: true));
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(
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
      final state = await waitForState(bloc, (state) => state.ioNotice != null);

      expect(state.ioNotice?.kind, OcptBudgetIoNoticeKind.exportFailed);

      await bloc.close();
    });
  });

  group("exporting the financing plan", () {
    test("hands the snapshot to the manager and raises the succeeded notice", () async {
      final exportManager = _FakeBudgetExportManager(financingPlanResult: "/tmp/financing.pdf");
      final bloc = buildBloc(exportManager: exportManager);
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(
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
      final state = await waitForState(bloc, (state) => state.ioNotice != null);

      expect(state.ioNotice?.kind, OcptBudgetIoNoticeKind.fileExportSucceeded);
      expect(state.ioNotice?.path, "/tmp/financing.pdf");

      await bloc.close();
    });

    test("is a silent no-op when the save dialog is cancelled", () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(
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

      expect(bloc.state.ioNotice, isNull);

      await bloc.close();
    });

    test("raises the failed notice when the export throws", () async {
      final bloc = buildBloc(exportManager: _FakeBudgetExportManager(financingPlanFails: true));
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(
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
      final state = await waitForState(bloc, (state) => state.ioNotice != null);

      expect(state.ioNotice?.kind, OcptBudgetIoNoticeKind.exportFailed);

      await bloc.close();
    });
  });

  group("exporting the cash journal", () {
    test("hands the link labels to the manager and raises the succeeded notice", () async {
      final exportManager = _FakeBudgetExportManager(cashJournalResult: "/tmp/journal.xlsx");
      final bloc = buildBloc(exportManager: exportManager);
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(
        const OcptBudgetCashJournalExportRequestedEvent(
          labels: _cashJournalLabels,
          linkLabelByEntryId: {"entry-1": "Regional grant"},
          fileTypeLabel: "Excel workbook",
        ),
      );
      final state = await waitForState(bloc, (state) => state.ioNotice != null);

      expect(exportManager.lastCashJournalLinkLabelByEntryId, {"entry-1": "Regional grant"});
      expect(state.ioNotice?.kind, OcptBudgetIoNoticeKind.fileExportSucceeded);
      expect(state.ioNotice?.path, "/tmp/journal.xlsx");

      await bloc.close();
    });

    test("is a silent no-op when the save dialog is cancelled", () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(
        const OcptBudgetCashJournalExportRequestedEvent(
          labels: _cashJournalLabels,
          linkLabelByEntryId: {},
          fileTypeLabel: "Excel workbook",
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.ioNotice, isNull);

      await bloc.close();
    });

    test("raises the failed notice when the export throws", () async {
      final bloc = buildBloc(exportManager: _FakeBudgetExportManager(cashJournalFails: true));
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(
        const OcptBudgetCashJournalExportRequestedEvent(
          labels: _cashJournalLabels,
          linkLabelByEntryId: {},
          fileTypeLabel: "Excel workbook",
        ),
      );
      final state = await waitForState(bloc, (state) => state.ioNotice != null);

      expect(state.ioNotice?.kind, OcptBudgetIoNoticeKind.exportFailed);

      await bloc.close();
    });
  });

  group("exporting the financial report", () {
    test("hands the snapshot to the manager and raises the succeeded notice", () async {
      final exportManager = _FakeBudgetExportManager(financialReportResult: "/tmp/report.pdf");
      final bloc = buildBloc(exportManager: exportManager);
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(
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
      final state = await waitForState(bloc, (state) => state.ioNotice != null);

      expect(state.ioNotice?.kind, OcptBudgetIoNoticeKind.fileExportSucceeded);
      expect(state.ioNotice?.path, "/tmp/report.pdf");

      await bloc.close();
    });

    test("is a silent no-op when the save dialog is cancelled", () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(
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

      expect(bloc.state.ioNotice, isNull);

      await bloc.close();
    });

    test("raises the failed notice when the export throws", () async {
      final bloc = buildBloc(exportManager: _FakeBudgetExportManager(financialReportFails: true));
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(
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
      final state = await waitForState(bloc, (state) => state.ioNotice != null);

      expect(state.ioNotice?.kind, OcptBudgetIoNoticeKind.exportFailed);

      await bloc.close();
    });
  });

  group("toggling the expenses tree's own expansion", () {
    test("expands a node it did not hold, and collapses one it did — independently of any "
        "other node", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptBudgetRowExpansionToggledEvent(nodeId: "poste-1"));
      final firstExpanded = await waitForState(
        bloc,
        (state) => state.expandedNodeIds.contains("poste-1"),
      );
      expect(firstExpanded.expandedNodeIds, {"poste-1"});

      bloc.add(const OcptBudgetRowExpansionToggledEvent(nodeId: "line-1"));
      final bothExpanded = await waitForState(
        bloc,
        (state) => state.expandedNodeIds.contains("line-1"),
      );
      expect(bothExpanded.expandedNodeIds, {"poste-1", "line-1"});

      bloc.add(const OcptBudgetRowExpansionToggledEvent(nodeId: "poste-1"));
      final onlyLineLeft = await waitForState(
        bloc,
        (state) => !state.expandedNodeIds.contains("poste-1"),
      );
      expect(onlyLineLeft.expandedNodeIds, {"line-1"});
    });

    test("is not persisted across a fresh load — every bloc starts with nothing expanded",
        () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final state = await waitForState(bloc, (state) => !state.isLoading);

      expect(state.expandedNodeIds, isEmpty);
    });
  });

  group("selecting a quote line, a commitment or an entry", () {
    test("selecting a line names it in the selection and opens the Inspector", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      bloc.add(OcptBudgetLineCreatedEvent(posteId: posteId));
      final withLine = await waitForState(bloc, (state) => state.postes.first.lines.isNotEmpty);
      final lineId = withLine.postes.first.lines.single.id;

      // A poste selection first, so the switch away from it is what this test actually proves.
      bloc.add(OcptBudgetPosteSelectedEvent(posteId: loaded.postes.last.id));
      await waitForState(bloc, (state) => state.selectedPosteId == loaded.postes.last.id);

      bloc.add(OcptBudgetLineSelectedEvent(lineId: lineId));
      final state = await waitForState(
        bloc,
        (state) => state.selection == OcptBudgetLineSelection(lineId),
      );

      expect(state.selection, OcptBudgetLineSelection(lineId));
      expect(state.rightDockTab, OcptBudgetRightDockTab.inspector);
    });

    test("a line id naming no live line is ignored", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptBudgetLineSelectedEvent(lineId: "gone"));
      // Nothing to wait for: give the bloc a beat to (not) react, then assert it never did.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.selection, isNull);
    });

    test("deleting a selected line clears the selection on the next snapshot", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      bloc.add(OcptBudgetLineCreatedEvent(posteId: posteId));
      final withLine = await waitForState(bloc, (state) => state.postes.first.lines.isNotEmpty);
      final lineId = withLine.postes.first.lines.single.id;
      await waitForState(bloc, (state) => state.selection == OcptBudgetLineSelection(lineId));

      bloc.add(OcptBudgetLineDeletionConfirmedEvent(lineId: lineId));
      final state = await waitForState(
        bloc,
        (state) => state.postes.firstWhere((poste) => poste.id == posteId).lines.isEmpty,
      );

      expect(state.selection, isNull);
    });

    test("selecting a commitment names it in the selection and opens the Inspector", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      bloc.add(
        OcptBudgetCommitmentCreationConfirmedEvent(
          fields: OcptBudgetCommitmentFormFields(
            dueDate: null,
            label: "Insurance",
            posteId: posteId,
            amountCents: 12000,
            isTaxInclusive: true,
            vatRateBasisPoints: null,
            status: OcptBudgetCommitmentStatus.quoteAccepted,
          ),
        ),
      );
      final withCommitment = await waitForState(bloc, (state) => state.commitments.isNotEmpty);
      final commitmentId = withCommitment.commitments.single.id;

      bloc.add(OcptBudgetCommitmentSelectedEvent(commitmentId: commitmentId));
      final state = await waitForState(
        bloc,
        (state) => state.selection == OcptBudgetCommitmentSelection(commitmentId),
      );

      expect(state.selection, OcptBudgetCommitmentSelection(commitmentId));
      expect(state.rightDockTab, OcptBudgetRightDockTab.inspector);
    });

    test("a commitment id naming no live commitment is ignored", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptBudgetCommitmentSelectedEvent(commitmentId: "gone"));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.selection, isNull);
    });

    test("selecting an entry names it in the selection and opens the Inspector", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      bloc.add(
        OcptBudgetEntryCreationConfirmedEvent(
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026, 3),
            label: "Camera rental",
            posteId: posteId,
            resourceId: null,
            revenueId: null,
            shareId: null,
            isDebit: true,
            amountCents: 5000,
            isTaxInclusive: true,
            vatRateBasisPoints: null,
            voucherNumber: null,
            pickedReceiptPath: null,
            isReceiptDetached: false,
          ),
        ),
      );
      final withEntry = await waitForState(bloc, (state) => state.entries.isNotEmpty);
      final entryId = withEntry.entries.single.id;

      bloc.add(OcptBudgetEntrySelectedEvent(entryId: entryId));
      final state = await waitForState(
        bloc,
        (state) => state.selection == OcptBudgetEntrySelection(entryId),
      );

      expect(state.selection, OcptBudgetEntrySelection(entryId));
      expect(state.rightDockTab, OcptBudgetRightDockTab.inspector);
    });

    test("an entry id naming no live entry is ignored", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptBudgetEntrySelectedEvent(entryId: "gone"));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.selection, isNull);
    });

    test("selecting a receipt names the same entry in the selection and opens the Inspector", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      bloc.add(
        OcptBudgetEntryCreationConfirmedEvent(
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026, 3),
            label: "Camera rental",
            posteId: posteId,
            resourceId: null,
            revenueId: null,
            shareId: null,
            isDebit: true,
            amountCents: 5000,
            isTaxInclusive: true,
            vatRateBasisPoints: null,
            voucherNumber: null,
            pickedReceiptPath: null,
            isReceiptDetached: false,
          ),
        ),
      );
      final withEntry = await waitForState(bloc, (state) => state.entries.isNotEmpty);
      final entryId = withEntry.entries.single.id;

      bloc.add(OcptBudgetReceiptSelectedEvent(receiptId: entryId));
      final state = await waitForState(
        bloc,
        (state) => state.selection == OcptBudgetReceiptSelection(entryId),
      );

      expect(state.selection, OcptBudgetReceiptSelection(entryId));
      expect(state.rightDockTab, OcptBudgetRightDockTab.inspector);
    });

    test("a receipt id naming no live entry is ignored", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptBudgetReceiptSelectedEvent(receiptId: "gone"));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.selection, isNull);
    });

    test("a selected receipt is dropped once its own entry is deleted", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      bloc.add(
        OcptBudgetEntryCreationConfirmedEvent(
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026, 3),
            label: "Camera rental",
            posteId: posteId,
            resourceId: null,
            revenueId: null,
            shareId: null,
            isDebit: true,
            amountCents: 5000,
            isTaxInclusive: true,
            vatRateBasisPoints: null,
            voucherNumber: null,
            pickedReceiptPath: null,
            isReceiptDetached: false,
          ),
        ),
      );
      final withEntry = await waitForState(bloc, (state) => state.entries.isNotEmpty);
      final entryId = withEntry.entries.single.id;

      bloc.add(OcptBudgetReceiptSelectedEvent(receiptId: entryId));
      await waitForState(bloc, (state) => state.selection == OcptBudgetReceiptSelection(entryId));

      bloc.add(OcptBudgetEntryDeletionConfirmedEvent(entryId: entryId));
      final state = await waitForState(bloc, (state) => state.entries.isEmpty);

      expect(state.selection, isNull);
    });
  });
}
