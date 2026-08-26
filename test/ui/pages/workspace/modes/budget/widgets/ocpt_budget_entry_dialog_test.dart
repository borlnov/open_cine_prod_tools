// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_asset_ref.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry_wizard_result.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_allowance_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_entry_nature.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_revenue_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_entry_dialog.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_match.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';

/// A router manager whose [pop] only records the last call and its value — mirrors
/// `ocpt_project_version_create_dialog_test.dart`'s own instance of this pattern.
class _RecordingRouterManager extends OcptRouterManager {
  /// Whether [pop] was called.
  bool popped = false;

  /// The value [pop] was last called with.
  Object? poppedValue;

  @override
  void pop<Y extends Object?>([Y? result]) {
    popped = true;
    poppedValue = result;
  }
}

/// A file selector manager answering the picker with a file of its own, so a test never opens a
/// native dialog — mirrors `resources_bloc_test.dart`'s own `_StubFileSelectorManager`.
class _StubFileSelectorManager extends FileSelectorManager {
  /// The path the next pick answers with, or null to answer as a cancelled dialog does.
  final String? pickedPath;

  /// Class constructor
  const _StubFileSelectorManager({required this.pickedPath});

  /// Answers with [pickedPath] instead of opening the platform's own dialog.
  @override
  Future<ResultWithBoolStatus<XFile>> openSelector({
    required List<String> allowedExtensions,
    required String label,
    bool strictOnExtensions = true,
  }) async {
    final pickedPath = this.pickedPath;
    if (pickedPath == null) {
      return const ResultWithBoolStatus(status: BoolResultStatus.error);
    }

    return ResultWithBoolStatus(status: BoolResultStatus.success, value: XFile(pickedPath));
  }
}

/// A minimal voucher, everything but [path] neutral.
OcptAssetRef _receipt({String id = "asset-1", required String path}) => OcptAssetRef(
  id: id,
  kind: OcptAssetKind.receipt,
  path: path,
  label: "",
  addedAt: DateTime(2026, 1, 15),
  personId: null,
  locationId: null,
  elementId: null,
  budgetEntryId: "entry-1",
  validFrom: null,
  validUntil: null,
);

/// Registers [_StubFileSelectorManager] answering [pickedPath], so a `Attach`/`Replace` tap never
/// opens a native dialog.
Future<void> _registerFileSelector(String? pickedPath) async {
  final managers = globalGetIt();
  if (managers.isRegistered<FileSelectorManager>()) {
    await managers.unregister<FileSelectorManager>();
  }
  managers.registerSingleton<FileSelectorManager>(_StubFileSelectorManager(pickedPath: pickedPath));
}

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve in tests.
Widget _wrapWithLocalization(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: child,
);

/// A minimal poste, everything but [id]/[label] neutral.
OcptBudgetPoste _poste({required String id, required String label}) =>
    OcptBudgetPoste(id: id, code: "1", label: label, simpleLabel: null, estimateToCompleteCents: null, sortKey: "a0", lines: const []);

/// A minimal financing resource, everything but [id]/[label] neutral.
OcptBudgetResource _resource({required String id, required String label, int amountCents = 10000}) => OcptBudgetResource(
  id: id,
  groupKind: OcptBudgetResourceGroupKind.subsidy,
  personId: null,
  label: label,
  amountCents: amountCents,
  status: OcptBudgetResourceStatus.pending,
  isReimbursable: false,
  notes: "",
  sortKey: "a0",
);

/// A minimal taking, everything but [id]/[label]/[amountCents] neutral.
OcptBudgetRevenue _revenue({required String id, required String label, int amountCents = 10000}) => OcptBudgetRevenue(
  id: id,
  date: DateTime(2026, 3),
  label: label,
  amountCents: amountCents,
  status: OcptBudgetRevenueStatus.expected,
  notes: "",
  sortKey: "a0",
);

/// A minimal share, everything but [id]/[label] neutral.
OcptBudgetShare _share({required String id, required String label}) => OcptBudgetShare(
  id: id,
  personId: null,
  label: label,
  sharePermille: 100,
  reinvestPermille: 0,
  notes: "",
  sortKey: "a0",
);

/// A minimal, unsettled commitment against [posteId], everything but [id]/[label]/[amountCents]
/// neutral.
OcptBudgetCommitment _commitment({
  required String id,
  required String label,
  required String posteId,
  int amountCents = 10000,
  DateTime? dueDate,
}) => OcptBudgetCommitment(
  id: id,
  dueDate: dueDate,
  label: label,
  posteId: posteId,
  amount: OcptMoney(amountCents: amountCents, isTaxInclusive: true, vatRateBasisPoints: null),
  status: OcptBudgetCommitmentStatus.quoteAccepted,
  settledEntryId: null,
  lineId: null,
  sortKey: "a0",
);

/// A minimal defrayal, everything but [id]/[label]/its own figure neutral — priced at
/// [amountCents] exactly (one unit at that price).
OcptBudgetAllowance _allowance({required String id, required String label, int amountCents = 10000}) => OcptBudgetAllowance(
  id: id,
  personId: null,
  kind: OcptBudgetAllowanceKind.other,
  label: label,
  date: DateTime(2026, 3),
  endDate: null,
  quantityMilli: 1000,
  unitAmountMilliCents: amountCents * 1000,
  notes: "",
  sortKey: "a0",
);

/// A minimal existing entry, its debit or credit set by whichever of [debitCents]/[creditCents] is
/// non-zero.
OcptBudgetEntry _existingEntry({
  String id = "entry-1",
  DateTime? date,
  String label = "Camera rental",
  String? posteId,
  String? resourceId,
  String? revenueId,
  String? shareId,
  int debitCents = 0,
  int creditCents = 0,
  bool isTaxInclusive = true,
  int? vatRateBasisPoints,
  String voucherNumber = "J-007",
}) => OcptBudgetEntry(
  id: id,
  date: date ?? DateTime(2026, 1, 15),
  label: label,
  posteId: posteId,
  debitCents: debitCents,
  creditCents: creditCents,
  isTaxInclusive: isTaxInclusive,
  vatRateBasisPoints: vatRateBasisPoints,
  voucherNumber: voucherNumber,
  sortKey: "a0",
  resourceId: resourceId,
  revenueId: revenueId,
  shareId: shareId,
);

void main() {
  late _RecordingRouterManager routerManager;

  setUpAll(() {
    OcptGlobalManager.instance;
  });

  setUp(() async {
    final managers = globalGetIt();
    if (managers.isRegistered<OcptRouterManager>()) {
      await managers.unregister<OcptRouterManager>();
    }

    routerManager = _RecordingRouterManager();
    managers.registerSingleton<OcptRouterManager>(routerManager);

    // Answers a `Attach`/`Replace` tap as a cancelled dialog by default; a test picking a receipt
    // overrides it through `_registerFileSelector`.
    await _registerFileSelector(null);
  });

  /// Pumps [OcptBudgetEntryDialog] directly (no `.show`).
  Future<Tr> pumpDialog(
    WidgetTester tester, {
    OcptBudgetEntry? existing,
    OcptBudgetEntryFormFields? prefill,
    OcptBudgetEntryNature? initialNature,
    OcptAssetRef? existingReceipt,
    List<OcptBudgetPoste> postes = const [],
    List<OcptBudgetResource> resources = const [],
    List<OcptBudgetRevenue> revenues = const [],
    List<OcptBudgetShare> shares = const [],
    List<OcptBudgetCommitment> commitments = const [],
    List<OcptBudgetAllowance> allowances = const [],
    Map<String, OcptBudgetCoveredTotal> receivedByResourceId = const {},
    Map<String, OcptBudgetCoveredTotal> receivedByRevenueId = const {},
    int? defaultVatRateBasisPoints,
    bool isSimplified = false,
  }) async {
    await tester.pumpWidget(
      _wrapWithLocalization(
        OcptBudgetEntryDialog(
          existing: existing,
          prefill: prefill,
          initialNature: initialNature,
          existingReceipt: existingReceipt,
          postes: postes,
          resources: resources,
          revenues: revenues,
          shares: shares,
          commitments: commitments,
          allowances: allowances,
          receivedByResourceId: receivedByResourceId,
          receivedByRevenueId: receivedByRevenueId,
          currencyCode: "EUR",
          defaultVatRateBasisPoints: defaultVatRateBasisPoints,
          isSimplified: isSimplified,
        ),
      ),
    );
    await tester.pumpAndSettle();

    return Tr.of(tester.element(find.byType(OcptBudgetEntryDialog)));
  }

  /// Pumps the dialog and, when it opened on step 1, immediately advances to step 2 — every test
  /// about the form itself uses this rather than [pumpDialog] directly.
  Future<Tr> pumpDialogAtStep2(
    WidgetTester tester, {
    OcptBudgetEntryNature initialNature = OcptBudgetEntryNature.expense,
    OcptBudgetEntry? existing,
    OcptBudgetEntryFormFields? prefill,
    OcptAssetRef? existingReceipt,
    List<OcptBudgetPoste> postes = const [],
    List<OcptBudgetResource> resources = const [],
    List<OcptBudgetRevenue> revenues = const [],
    List<OcptBudgetShare> shares = const [],
    List<OcptBudgetCommitment> commitments = const [],
    List<OcptBudgetAllowance> allowances = const [],
    Map<String, OcptBudgetCoveredTotal> receivedByResourceId = const {},
    Map<String, OcptBudgetCoveredTotal> receivedByRevenueId = const {},
    int? defaultVatRateBasisPoints,
    bool isSimplified = false,
  }) async {
    final tr = await pumpDialog(
      tester,
      existing: existing,
      prefill: prefill,
      initialNature: initialNature,
      existingReceipt: existingReceipt,
      postes: postes,
      resources: resources,
      revenues: revenues,
      shares: shares,
      commitments: commitments,
      allowances: allowances,
      receivedByResourceId: receivedByResourceId,
      receivedByRevenueId: receivedByRevenueId,
      defaultVatRateBasisPoints: defaultVatRateBasisPoints,
      isSimplified: isSimplified,
    );

    final continueButton = find.byKey(const Key("ocptBudgetEntryWizardContinueButton"));
    if (continueButton.evaluate().isNotEmpty) {
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
    }

    return tr;
  }

  group("step 1", () {
    testWidgets("draws five cards, Continuer withheld until one is picked", (tester) async {
      final tr = await pumpDialog(tester);

      for (final label in [
        tr.budgetEntryNatureExpenseLabel,
        tr.budgetEntryNatureFinancingLabel,
        tr.budgetEntryNatureRevenueLabel,
        tr.budgetEntryNaturePayoutLabel,
        tr.budgetEntryNatureOtherLabel,
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }

      final continueButton = tester.widget<FilledButton>(
        find.byKey(const Key("ocptBudgetEntryWizardContinueButton")),
      );
      expect(continueButton.onPressed, isNull);

      await tester.tap(find.text(tr.budgetEntryNatureExpenseLabel));
      await tester.pumpAndSettle();

      final afterPick = tester.widget<FilledButton>(
        find.byKey(const Key("ocptBudgetEntryWizardContinueButton")),
      );
      expect(afterPick.onPressed, isNotNull);
    });

    testWidgets("Annuler pops with nothing", (tester) async {
      await pumpDialog(tester);

      await tester.tap(find.byKey(const Key("ocptBudgetEntryWizardCancelButton")));
      await tester.pumpAndSettle();

      expect(routerManager.popped, isTrue);
      expect(routerManager.poppedValue, isNull);
    });

    testWidgets("initialNature preselects a card, one click reaches step 2", (tester) async {
      await pumpDialog(tester, initialNature: OcptBudgetEntryNature.payout);

      await tester.tap(find.byKey(const Key("ocptBudgetEntryWizardContinueButton")));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key("ocptBudgetEntryWizardSaveButton")), findsOneWidget);
    });
  });

  group("each nature", () {
    testWidgets("expense fixes a debit and asks for the quote poste alone", (tester) async {
      final tr = await pumpDialogAtStep2(tester);

      expect(find.text(tr.budgetEntryDialogDebitOption), findsNothing);
      expect(find.text(tr.budgetEntryDialogPosteFieldLabel), findsOneWidget);
      expect(find.text(tr.budgetEntryDialogResourceFieldLabel), findsNothing);
      expect(find.text(tr.budgetEntryDialogRevenueFieldLabel), findsNothing);
      expect(find.text(tr.budgetEntryDialogShareFieldLabel), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
        "Camera rental",
      );
      await tester.enterText(find.byKey(const Key("ocptBudgetEntryWizardAmountField")), "10");
      await tester.tap(find.byKey(const Key("ocptBudgetEntryWizardSaveButton")));
      await tester.pumpAndSettle();

      final fields = (routerManager.poppedValue! as OcptBudgetEntryWizardResult).fields;
      expect(fields.isDebit, isTrue);
    });

    testWidgets("financing fixes a credit and asks for the resource alone", (tester) async {
      final tr = await pumpDialogAtStep2(tester, initialNature: OcptBudgetEntryNature.financing);

      expect(find.text(tr.budgetEntryDialogDebitOption), findsNothing);
      expect(find.text(tr.budgetEntryDialogResourceFieldLabel), findsOneWidget);
      expect(find.text(tr.budgetEntryDialogPosteFieldLabel), findsNothing);
      expect(find.text(tr.budgetEntryDialogRevenueFieldLabel), findsNothing);
      expect(find.text(tr.budgetEntryDialogShareFieldLabel), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
        "Grant instalment",
      );
      await tester.enterText(find.byKey(const Key("ocptBudgetEntryWizardAmountField")), "10");
      await tester.tap(find.byKey(const Key("ocptBudgetEntryWizardSaveButton")));
      await tester.pumpAndSettle();

      final fields = (routerManager.poppedValue! as OcptBudgetEntryWizardResult).fields;
      expect(fields.isDebit, isFalse);
    });

    testWidgets("revenue fixes a credit and asks for the taking alone", (tester) async {
      final tr = await pumpDialogAtStep2(tester, initialNature: OcptBudgetEntryNature.revenue);

      expect(find.text(tr.budgetEntryDialogDebitOption), findsNothing);
      expect(find.text(tr.budgetEntryDialogRevenueFieldLabel), findsOneWidget);
      expect(find.text(tr.budgetEntryDialogPosteFieldLabel), findsNothing);
      expect(find.text(tr.budgetEntryDialogResourceFieldLabel), findsNothing);
      expect(find.text(tr.budgetEntryDialogShareFieldLabel), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
        "Festival prize",
      );
      await tester.enterText(find.byKey(const Key("ocptBudgetEntryWizardAmountField")), "10");
      await tester.tap(find.byKey(const Key("ocptBudgetEntryWizardSaveButton")));
      await tester.pumpAndSettle();

      final fields = (routerManager.poppedValue! as OcptBudgetEntryWizardResult).fields;
      expect(fields.isDebit, isFalse);
    });

    testWidgets("payout fixes a debit and asks for the participant alone", (tester) async {
      final tr = await pumpDialogAtStep2(tester, initialNature: OcptBudgetEntryNature.payout);

      expect(find.text(tr.budgetEntryDialogDebitOption), findsNothing);
      expect(find.text(tr.budgetEntryDialogShareFieldLabel), findsOneWidget);
      expect(find.text(tr.budgetEntryDialogPosteFieldLabel), findsNothing);
      expect(find.text(tr.budgetEntryDialogResourceFieldLabel), findsNothing);
      expect(find.text(tr.budgetEntryDialogRevenueFieldLabel), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
        "Producer's share",
      );
      await tester.enterText(find.byKey(const Key("ocptBudgetEntryWizardAmountField")), "10");
      await tester.tap(find.byKey(const Key("ocptBudgetEntryWizardSaveButton")));
      await tester.pumpAndSettle();

      final fields = (routerManager.poppedValue! as OcptBudgetEntryWizardResult).fields;
      expect(fields.isDebit, isTrue);
    });

    testWidgets(
      "other is the only nature still asking the direction, and offers an optional poste",
      (tester) async {
        final tr = await pumpDialogAtStep2(tester, initialNature: OcptBudgetEntryNature.other);

        expect(find.text(tr.budgetEntryDialogDebitOption), findsOneWidget);
        expect(find.text(tr.budgetEntryDialogPosteFieldLabel), findsOneWidget);
        expect(find.text(tr.budgetEntryDialogResourceFieldLabel), findsNothing);
        expect(find.text(tr.budgetEntryDialogRevenueFieldLabel), findsNothing);
        expect(find.text(tr.budgetEntryDialogShareFieldLabel), findsNothing);

        // Defaults to a debit, and the choice is actually reachable — scrolled into view first,
        // it sits at the very bottom of the form.
        final creditOption = find.text(tr.budgetEntryDialogCreditOption);
        await tester.ensureVisible(creditOption);
        await tester.pumpAndSettle();
        await tester.tap(creditOption);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
          "Bank correction",
        );
        await tester.enterText(find.byKey(const Key("ocptBudgetEntryWizardAmountField")), "10");
        await tester.tap(find.byKey(const Key("ocptBudgetEntryWizardSaveButton")));
        await tester.pumpAndSettle();

        final fields = (routerManager.poppedValue! as OcptBudgetEntryWizardResult).fields;
        expect(fields.isDebit, isFalse);
      },
    );

    testWidgets("the direction choice reads as I paid / I received under the simplified header", (
      tester,
    ) async {
      final tr = await pumpDialogAtStep2(
        tester,
        initialNature: OcptBudgetEntryNature.other,
        isSimplified: true,
      );

      expect(find.text(tr.budgetEntryDialogPaidOption), findsOneWidget);
      expect(find.text(tr.budgetEntryDialogReceivedOption), findsOneWidget);
      expect(find.text(tr.budgetEntryDialogDebitOption), findsNothing);
      expect(find.text(tr.budgetEntryDialogCreditOption), findsNothing);
    });
  });

  group("editing infers the nature from what the entry already names", () {
    testWidgets("a poste opens step 2 directly, recalled as I paid for something", (
      tester,
    ) async {
      final existing = _existingEntry(posteId: "poste-1", debitCents: 500);
      final tr = await pumpDialog(
        tester,
        existing: existing,
        postes: [_poste(id: "poste-1", label: "Camera")],
      );

      expect(find.byKey(const Key("ocptBudgetEntryWizardContinueButton")), findsNothing);
      expect(find.text(tr.budgetEntryNatureExpenseLabel), findsOneWidget);
      expect(find.text(tr.budgetEntryDialogPosteFieldLabel), findsOneWidget);
    });

    testWidgets("a resource opens step 2 directly, recalled as I received a financing", (
      tester,
    ) async {
      final existing = _existingEntry(resourceId: "resource-1", creditCents: 500);
      final tr = await pumpDialog(
        tester,
        existing: existing,
        resources: [_resource(id: "resource-1", label: "Regional grant")],
      );

      expect(find.byKey(const Key("ocptBudgetEntryWizardContinueButton")), findsNothing);
      expect(find.text(tr.budgetEntryNatureFinancingLabel), findsOneWidget);
      expect(find.text(tr.budgetEntryDialogResourceFieldLabel), findsOneWidget);
    });

    testWidgets("a taking opens step 2 directly, recalled as the film earned money", (
      tester,
    ) async {
      final existing = _existingEntry(revenueId: "revenue-1", creditCents: 500);
      final tr = await pumpDialog(
        tester,
        existing: existing,
        revenues: [_revenue(id: "revenue-1", label: "Festival prize")],
      );

      expect(find.byKey(const Key("ocptBudgetEntryWizardContinueButton")), findsNothing);
      expect(find.text(tr.budgetEntryNatureRevenueLabel), findsOneWidget);
      expect(find.text(tr.budgetEntryDialogRevenueFieldLabel), findsOneWidget);
    });

    testWidgets("a share opens step 2 directly, recalled as I paid out someone's share", (
      tester,
    ) async {
      final existing = _existingEntry(shareId: "share-1", debitCents: 500);
      final tr = await pumpDialog(
        tester,
        existing: existing,
        shares: [_share(id: "share-1", label: "Producer")],
      );

      expect(find.byKey(const Key("ocptBudgetEntryWizardContinueButton")), findsNothing);
      expect(find.text(tr.budgetEntryNaturePayoutLabel), findsOneWidget);
      expect(find.text(tr.budgetEntryDialogShareFieldLabel), findsOneWidget);
    });

    testWidgets(
      "naming nothing opens step 2 directly, recalled as Autre mouvement, its own direction "
      "reachable",
      (tester) async {
        final existing = _existingEntry(creditCents: 500);
        final tr = await pumpDialog(tester, existing: existing);

        expect(find.byKey(const Key("ocptBudgetEntryWizardContinueButton")), findsNothing);
        expect(find.text(tr.budgetEntryNatureOtherLabel), findsOneWidget);
        expect(find.text(tr.budgetEntryDialogDebitOption), findsOneWidget);
      },
    );
  });

  group("a prefill", () {
    testWidgets("naming a resource skips step 1 straight to step 2", (tester) async {
      final resource = _resource(id: "resource-1", label: "Regional grant");
      final tr = await pumpDialog(
        tester,
        resources: [resource],
        prefill: OcptBudgetEntryFormFields(
          date: DateTime(2026, 3),
          label: "Grant instalment",
          posteId: null,
          resourceId: "resource-1",
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
      );

      expect(find.byKey(const Key("ocptBudgetEntryWizardContinueButton")), findsNothing);
      expect(find.text(tr.budgetEntryNatureFinancingLabel), findsOneWidget);

      await tester.tap(find.byKey(const Key("ocptBudgetEntryWizardSaveButton")));
      await tester.pumpAndSettle();

      final fields = (routerManager.poppedValue! as OcptBudgetEntryWizardResult).fields;
      expect(fields.resourceId, "resource-1");
      expect(fields.isDebit, isFalse);
      expect(fields.amountCents, 5000);
    });

    testWidgets("naming no link at all opens step 1, initialNature already selected", (
      tester,
    ) async {
      await pumpDialog(
        tester,
        initialNature: OcptBudgetEntryNature.payout,
        prefill: OcptBudgetEntryFormFields(
          date: DateTime(2026, 3),
          label: "",
          posteId: null,
          resourceId: null,
          revenueId: null,
          shareId: null,
          isDebit: true,
          amountCents: 0,
          isTaxInclusive: true,
          vatRateBasisPoints: null,
          voucherNumber: null,
          pickedReceiptPath: null,
          isReceiptDetached: false,
        ),
      );

      final continueButton = tester.widget<FilledButton>(
        find.byKey(const Key("ocptBudgetEntryWizardContinueButton")),
      );
      expect(continueButton.onPressed, isNotNull);
    });
  });

  group("the link back to step 1", () {
    testWidgets("the header's own changer link returns to step 1, values kept", (tester) async {
      final tr = await pumpDialogAtStep2(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
        "Half-typed",
      );

      await tester.tap(find.byKey(const Key("ocptBudgetEntryWizardChangeNatureLink")));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key("ocptBudgetEntryWizardContinueButton")), findsOneWidget);

      await tester.tap(find.byKey(const Key("ocptBudgetEntryWizardContinueButton")));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, "Half-typed"), findsOneWidget);
    });

    testWidgets("Retour, at the bottom of step 2, does the very same thing", (tester) async {
      await pumpDialogAtStep2(tester);

      await tester.tap(find.byKey(const Key("ocptBudgetEntryWizardBackButton")));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key("ocptBudgetEntryWizardContinueButton")), findsOneWidget);
    });
  });

  group("the poste field", () {
    testWidgets("left unanswered reads Hors devis, never nothing at all", (tester) async {
      final poste = _poste(id: "poste-1", label: "Camera");
      final tr = await pumpDialogAtStep2(
        tester,
        postes: [poste],
      );

      expect(find.text(tr.budgetCostTrackingOffQuoteLabel), findsOneWidget);
    });

    testWidgets("picking a poste round-trips it on Save", (tester) async {
      final poste = _poste(id: "poste-1", label: "Camera");
      final tr = await pumpDialogAtStep2(
        tester,
        postes: [poste],
      );

      await tester.tap(find.byKey(const Key("ocptBudgetEntryWizardPosteField")));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Camera").last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
        "Zoom lens",
      );
      await tester.enterText(find.byKey(const Key("ocptBudgetEntryWizardAmountField")), "10");
      await tester.tap(find.byKey(const Key("ocptBudgetEntryWizardSaveButton")));
      await tester.pumpAndSettle();

      final fields = (routerManager.poppedValue! as OcptBudgetEntryWizardResult).fields;
      expect(fields.posteId, "poste-1");
    });
  });

  group("the reconciliation strip", () {
    testWidgets("is absent while editing an existing entry", (tester) async {
      final commitment = _commitment(id: "commitment-1", label: "Camera deposit", posteId: "poste-1", amountCents: 1000);
      final existing = _existingEntry(label: "Camera deposit", debitCents: 1000);
      await pumpDialog(tester, existing: existing, commitments: [commitment]);

      await tester.enterText(find.byKey(const Key("ocptBudgetEntryWizardAmountField")), "10.00");
      await tester.pumpAndSettle();

      expect(find.byKey(const Key("ocptBudgetEntryWizardAcceptButton")), findsNothing);
    });

    testWidgets(
      "matches a commitment on amount and wording, badges it Committed, and C'est ça reports it",
      (tester) async {
        final commitment = _commitment(
          id: "commitment-1",
          label: "Atelier Verrier",
          posteId: "poste-1",
          amountCents: 25000,
        );
        final tr = await pumpDialogAtStep2(
          tester,
          commitments: [commitment],
        );

        expect(find.byKey(const Key("ocptBudgetEntryWizardAcceptButton")), findsNothing);

        await tester.enterText(
          find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
          "Atelier Verrier",
        );
        await tester.enterText(find.byKey(const Key("ocptBudgetEntryWizardAmountField")), "250.00");
        await tester.pumpAndSettle();

        expect(find.text(tr.budgetEntryWizardMatchBadgeCommitment), findsOneWidget);

        await tester.tap(find.byKey(const Key("ocptBudgetEntryWizardAcceptButton")));
        await tester.pumpAndSettle();

        final result = routerManager.poppedValue! as OcptBudgetEntryWizardResult;
        expect(result.acceptedSuggestion?.kind, OcptBudgetMatchCandidateKind.commitment);
        expect(result.acceptedSuggestion?.candidateId, "commitment-1");
        // The plain draft, naming nothing — enrichment is `budget_mode.dart`'s own job.
        expect(result.fields.posteId, isNull);
        expect(result.fields.amountCents, 25000);
      },
    );

    testWidgets("matches a defrayal on amount and wording, badged Defrayal", (tester) async {
      final allowance = _allowance(id: "allowance-1", label: "Taxi", amountCents: 4000);
      final tr = await pumpDialogAtStep2(
        tester,
        allowances: [allowance],
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
        "Taxi",
      );
      await tester.enterText(find.byKey(const Key("ocptBudgetEntryWizardAmountField")), "40.00");
      await tester.pumpAndSettle();

      expect(find.text(tr.budgetEntryWizardMatchBadgeDefrayal), findsOneWidget);

      await tester.tap(find.byKey(const Key("ocptBudgetEntryWizardAcceptButton")));
      await tester.pumpAndSettle();

      final result = routerManager.poppedValue! as OcptBudgetEntryWizardResult;
      expect(result.acceptedSuggestion?.kind, OcptBudgetMatchCandidateKind.defrayal);
      expect(result.acceptedSuggestion?.candidateId, "allowance-1");
    });

    testWidgets("matches a resource still short, badged Financing, on a credit", (tester) async {
      final resource = _resource(id: "resource-1", label: "Regional grant", amountCents: 4000);
      final tr = await pumpDialogAtStep2(
        tester,
        initialNature: OcptBudgetEntryNature.financing,
        resources: [resource],
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
        "Regional grant",
      );
      await tester.enterText(find.byKey(const Key("ocptBudgetEntryWizardAmountField")), "40.00");
      await tester.pumpAndSettle();

      expect(find.text(tr.budgetEntryWizardMatchBadgeResource), findsOneWidget);

      await tester.tap(find.byKey(const Key("ocptBudgetEntryWizardAcceptButton")));
      await tester.pumpAndSettle();

      final result = routerManager.poppedValue! as OcptBudgetEntryWizardResult;
      expect(result.acceptedSuggestion?.kind, OcptBudgetMatchCandidateKind.resource);
      expect(result.acceptedSuggestion?.candidateId, "resource-1");
    });

    testWidgets("matches a taking still short, badged Takings, on a credit", (tester) async {
      final revenue = _revenue(id: "revenue-1", label: "Festival prize", amountCents: 4000);
      final tr = await pumpDialogAtStep2(
        tester,
        initialNature: OcptBudgetEntryNature.revenue,
        revenues: [revenue],
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
        "Festival prize",
      );
      await tester.enterText(find.byKey(const Key("ocptBudgetEntryWizardAmountField")), "40.00");
      await tester.pumpAndSettle();

      expect(find.text(tr.budgetEntryWizardMatchBadgeRevenue), findsOneWidget);

      await tester.tap(find.byKey(const Key("ocptBudgetEntryWizardAcceptButton")));
      await tester.pumpAndSettle();

      final result = routerManager.poppedValue! as OcptBudgetEntryWizardResult;
      expect(result.acceptedSuggestion?.kind, OcptBudgetMatchCandidateKind.revenue);
      expect(result.acceptedSuggestion?.candidateId, "revenue-1");
    });

    testWidgets("nothing agreeing on amount, date or wording is offered at all", (tester) async {
      final commitment = _commitment(id: "commitment-1", label: "Camera deposit", posteId: "poste-1", amountCents: 1000);
      final tr = await pumpDialogAtStep2(
        tester,
        commitments: [commitment],
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
        "Something else entirely",
      );
      await tester.enterText(find.byKey(const Key("ocptBudgetEntryWizardAmountField")), "999.00");
      await tester.pumpAndSettle();

      expect(find.byKey(const Key("ocptBudgetEntryWizardAcceptButton")), findsNothing);
    });
  });

  testWidgets("refuses to submit a blank label, and nothing is popped", (tester) async {
    final tr = await pumpDialogAtStep2(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogAmountFieldLabel),
      "12.50",
    );
    await tester.tap(find.byKey(const Key("ocptBudgetEntryWizardSaveButton")));
    await tester.pumpAndSettle();

    expect(find.text(tr.budgetEntryDialogLabelRequiredError), findsOneWidget);
    expect(routerManager.popped, isFalse);
  });

  testWidgets("an empty VAT field pops with a null override, meaning inherit", (tester) async {
    final tr = await pumpDialogAtStep2(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
      "Camera rental",
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogAmountFieldLabel),
      "12.50",
    );
    await tester.tap(find.byKey(const Key("ocptBudgetEntryWizardSaveButton")));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isTrue);
    final fields = (routerManager.poppedValue! as OcptBudgetEntryWizardResult).fields;
    expect(fields.vatRateBasisPoints, isNull);
    expect(fields.label, "Camera rental");
    expect(fields.amountCents, 1250);
    // `expense` fixes a debit.
    expect(fields.isDebit, isTrue);
    // Creating a new entry offers no voucher field at all: the service mints one instead.
    expect(fields.voucherNumber, isNull);
  });

  testWidgets("editing an existing entry pre-fills every field and preserves the amount to the cent", (
    tester,
  ) async {
    final existing = _existingEntry(creditCents: 1250, vatRateBasisPoints: 550);
    await pumpDialog(tester, existing: existing);

    expect(find.widgetWithText(TextFormField, "Camera rental"), findsOneWidget);
    expect(find.widgetWithText(TextFormField, "12.50"), findsOneWidget);
    expect(find.widgetWithText(TextFormField, "J-007"), findsOneWidget);

    await tester.tap(find.byKey(const Key("ocptBudgetEntryWizardSaveButton")));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isTrue);
    final fields = (routerManager.poppedValue! as OcptBudgetEntryWizardResult).fields;
    expect(fields.amountCents, 1250);
    // The entry was a credit (money that came in); naming nothing, its nature reads `other`,
    // which keeps the direction reachable and round-tripping as it was.
    expect(fields.isDebit, isFalse);
    expect(fields.vatRateBasisPoints, 550);
    expect(fields.voucherNumber, "J-007");
  });

  testWidgets("creating offers a muted voucher-number hint rather than an editable field", (
    tester,
  ) async {
    final tr = await pumpDialogAtStep2(tester);

    expect(find.text(tr.budgetEntryDialogVoucherAutoHint), findsOneWidget);
    expect(find.widgetWithText(TextFormField, "J-007"), findsNothing);
  });

  testWidgets("editing offers an editable voucher-number field instead of the auto-mint hint", (
    tester,
  ) async {
    final existing = _existingEntry(debitCents: 500);
    final tr = await pumpDialog(tester, existing: existing);

    expect(find.text(tr.budgetEntryDialogVoucherAutoHint), findsNothing);
    expect(find.widgetWithText(TextFormField, "J-007"), findsOneWidget);
  });

  group("the resource picker", () {
    testWidgets("offers an explicit no-resource choice alongside every live resource, defaulting to null", (
      tester,
    ) async {
      final resource = _resource(id: "resource-1", label: "Regional grant");
      final tr = await pumpDialogAtStep2(
        tester,
        initialNature: OcptBudgetEntryNature.financing,
        resources: [resource],
      );

      expect(find.text(tr.budgetEntryDialogNoResourceLabel), findsOneWidget);

      await tester.tap(find.byKey(const Key("ocptBudgetEntryWizardResourceField")));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Regional grant").last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
        "Grant instalment",
      );
      await tester.enterText(find.byKey(const Key("ocptBudgetEntryWizardAmountField")), "10");
      await tester.tap(find.byKey(const Key("ocptBudgetEntryWizardSaveButton")));
      await tester.pumpAndSettle();

      final fields = (routerManager.poppedValue! as OcptBudgetEntryWizardResult).fields;
      expect(fields.resourceId, "resource-1");
    });

    testWidgets("submitting with no pick reports a null resourceId, the normal case", (tester) async {
      final resource = _resource(id: "resource-1", label: "Regional grant");
      final tr = await pumpDialogAtStep2(
        tester,
        initialNature: OcptBudgetEntryNature.financing,
        resources: [resource],
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
        "Camera rental",
      );
      await tester.enterText(find.byKey(const Key("ocptBudgetEntryWizardAmountField")), "10");
      await tester.tap(find.byKey(const Key("ocptBudgetEntryWizardSaveButton")));
      await tester.pumpAndSettle();

      final fields = (routerManager.poppedValue! as OcptBudgetEntryWizardResult).fields;
      expect(fields.resourceId, isNull);
    });
  });

  testWidgets("cancelling step 1 pops with nothing", (tester) async {
    await pumpDialog(tester);

    await tester.tap(find.byKey(const Key("ocptBudgetEntryWizardCancelButton")));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isTrue);
    expect(routerManager.poppedValue, isNull);
  });

  group("the receipt field", () {
    testWidgets("creating a new entry with no receipt shows the empty hint and an Attach action", (
      tester,
    ) async {
      final tr = await pumpDialogAtStep2(tester);

      expect(find.text(tr.budgetEntryDialogReceiptEmptyHint), findsOneWidget);
      expect(find.text(tr.budgetEntryDialogReceiptAttachAction), findsOneWidget);
      expect(find.text(tr.budgetEntryDialogReceiptReplaceAction), findsNothing);
    });

    testWidgets("editing an entry with a receipt shows its own file line and a Replace action", (
      tester,
    ) async {
      final existing = _existingEntry(debitCents: 500);
      final tr = await pumpDialog(
        tester,
        existing: existing,
        existingReceipt: _receipt(path: "/tmp/facture.pdf"),
      );

      expect(find.text("facture.pdf"), findsOneWidget);
      expect(find.text(tr.budgetEntryDialogReceiptReplaceAction), findsOneWidget);
      expect(find.text(tr.budgetEntryDialogReceiptEmptyHint), findsNothing);
    });

    testWidgets("its own Detach action drops the reference, and Save reports it", (tester) async {
      final existing = _existingEntry(debitCents: 500);
      final tr = await pumpDialog(
        tester,
        existing: existing,
        existingReceipt: _receipt(path: "/tmp/facture.pdf"),
      );

      // The remove control is an `IconButton` with a tooltip rather than visible text — reused
      // straight off `OcptAssetFileLine`, so it is located by that tooltip. Scrolled into view
      // first: the extra fields this dialog now carries push it below the default test surface.
      final removeFinder = find.byTooltip(tr.resourcesRemoveDocumentTooltip);
      await tester.ensureVisible(removeFinder);
      await tester.pumpAndSettle();
      await tester.tap(removeFinder);
      await tester.pumpAndSettle();

      expect(find.text(tr.budgetEntryDialogReceiptEmptyHint), findsOneWidget);
      expect(find.text("facture.pdf"), findsNothing);

      await tester.tap(find.byKey(const Key("ocptBudgetEntryWizardSaveButton")));
      await tester.pumpAndSettle();

      final fields = (routerManager.poppedValue! as OcptBudgetEntryWizardResult).fields;
      expect(fields.isReceiptDetached, isTrue);
      expect(fields.pickedReceiptPath, isNull);
    });

    testWidgets("picking a receipt through the native selector attaches it, and Save reports it", (
      tester,
    ) async {
      await _registerFileSelector("/tmp/nouvelle-facture.pdf");
      final tr = await pumpDialogAtStep2(tester);

      final attachFinder = find.text(tr.budgetEntryDialogReceiptAttachAction);
      await tester.ensureVisible(attachFinder);
      await tester.pumpAndSettle();
      await tester.tap(attachFinder);
      await tester.pumpAndSettle();

      expect(find.text("nouvelle-facture.pdf"), findsOneWidget);
      expect(find.text(tr.budgetEntryDialogReceiptReplaceAction), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
        "Camera rental",
      );
      await tester.enterText(find.byKey(const Key("ocptBudgetEntryWizardAmountField")), "10");
      await tester.tap(find.byKey(const Key("ocptBudgetEntryWizardSaveButton")));
      await tester.pumpAndSettle();

      final fields = (routerManager.poppedValue! as OcptBudgetEntryWizardResult).fields;
      expect(fields.pickedReceiptPath, "/tmp/nouvelle-facture.pdf");
      expect(fields.isReceiptDetached, isFalse);
    });

    testWidgets("cancelling the native selector leaves whatever was referenced alone", (
      tester,
    ) async {
      await _registerFileSelector(null);
      final existing = _existingEntry(debitCents: 500);
      final tr = await pumpDialog(
        tester,
        existing: existing,
        existingReceipt: _receipt(path: "/tmp/facture.pdf"),
      );

      final replaceFinder = find.text(tr.budgetEntryDialogReceiptReplaceAction);
      await tester.ensureVisible(replaceFinder);
      await tester.pumpAndSettle();
      await tester.tap(replaceFinder);
      await tester.pumpAndSettle();

      expect(find.text("facture.pdf"), findsOneWidget);

      await tester.tap(find.byKey(const Key("ocptBudgetEntryWizardSaveButton")));
      await tester.pumpAndSettle();

      final fields = (routerManager.poppedValue! as OcptBudgetEntryWizardResult).fields;
      expect(fields.pickedReceiptPath, isNull);
      expect(fields.isReceiptDetached, isFalse);
    });
  });
}
