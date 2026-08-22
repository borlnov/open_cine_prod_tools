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
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_entry_dialog.dart';

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
    OcptBudgetPoste(id: id, code: "1", label: label, simpleLabel: null, sortKey: "a0", lines: const []);

/// A minimal financing resource, everything but [id]/[label] neutral.
OcptBudgetResource _resource({required String id, required String label}) => OcptBudgetResource(
  id: id,
  groupKind: OcptBudgetResourceGroupKind.subsidy,
  label: label,
  amountCents: 10000,
  status: OcptBudgetResourceStatus.applied,
  isReimbursable: false,
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
  resourceId: null,
  revenueId: null,
  shareId: null,
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

  /// Pumps [OcptBudgetEntryDialog] directly (no `.show`), creating a new entry unless [existing] is
  /// given.
  Future<Tr> pumpDialog(
    WidgetTester tester, {
    OcptBudgetEntry? existing,
    OcptAssetRef? existingReceipt,
    List<OcptBudgetPoste> postes = const [],
    List<OcptBudgetResource> resources = const [],
    int? defaultVatRateBasisPoints,
    bool isSimplified = false,
  }) async {
    await tester.pumpWidget(
      _wrapWithLocalization(
        OcptBudgetEntryDialog(
          existing: existing,
          existingReceipt: existingReceipt,
          postes: postes,
          resources: resources,
          currencyCode: "EUR",
          defaultVatRateBasisPoints: defaultVatRateBasisPoints,
          isSimplified: isSimplified,
        ),
      ),
    );
    await tester.pumpAndSettle();

    return Tr.of(tester.element(find.byType(OcptBudgetEntryDialog)));
  }

  testWidgets("refuses to submit a blank label, and nothing is popped", (tester) async {
    final tr = await pumpDialog(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogAmountFieldLabel),
      "12.50",
    );
    await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
    await tester.pumpAndSettle();

    expect(find.text(tr.budgetEntryDialogLabelRequiredError), findsOneWidget);
    expect(routerManager.popped, isFalse);
  });

  testWidgets("an empty VAT field pops with a null override, meaning inherit", (tester) async {
    final tr = await pumpDialog(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
      "Camera rental",
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogAmountFieldLabel),
      "12.50",
    );
    await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isTrue);
    final fields = routerManager.poppedValue! as OcptBudgetEntryFormFields;
    expect(fields.vatRateBasisPoints, isNull);
    expect(fields.label, "Camera rental");
    expect(fields.amountCents, 1250);
    // Creating a new entry defaults to a debit ("I paid").
    expect(fields.isDebit, isTrue);
    // Creating a new entry offers no voucher field at all: the service mints one instead.
    expect(fields.voucherNumber, isNull);
  });

  testWidgets("editing an existing entry pre-fills every field and preserves the amount to the cent", (
    tester,
  ) async {
    final existing = _existingEntry(creditCents: 1250, vatRateBasisPoints: 550);
    final tr = await pumpDialog(tester, existing: existing);

    expect(find.widgetWithText(TextFormField, "Camera rental"), findsOneWidget);
    expect(find.widgetWithText(TextFormField, "12.50"), findsOneWidget);
    expect(find.widgetWithText(TextFormField, "J-007"), findsOneWidget);

    await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isTrue);
    final fields = routerManager.poppedValue! as OcptBudgetEntryFormFields;
    expect(fields.amountCents, 1250);
    // The entry was a credit (money that came in), so the direction round-trips as such.
    expect(fields.isDebit, isFalse);
    expect(fields.vatRateBasisPoints, 550);
    expect(fields.voucherNumber, "J-007");
  });

  testWidgets("creating offers a muted voucher-number hint rather than an editable field", (
    tester,
  ) async {
    final tr = await pumpDialog(tester);

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

  testWidgets("the direction choice reads as I paid / I received under the simplified header", (
    tester,
  ) async {
    final tr = await pumpDialog(tester, isSimplified: true);

    expect(find.text(tr.budgetEntryDialogPaidOption), findsOneWidget);
    expect(find.text(tr.budgetEntryDialogReceivedOption), findsOneWidget);
    expect(find.text(tr.budgetEntryDialogDebitOption), findsNothing);
    expect(find.text(tr.budgetEntryDialogCreditOption), findsNothing);
  });

  testWidgets("the poste picker offers an explicit no-poste choice alongside every live poste", (
    tester,
  ) async {
    final poste = _poste(id: "poste-1", label: "Camera");
    final tr = await pumpDialog(tester, postes: [poste]);

    expect(find.text(tr.budgetCashJournalNoPosteLabel), findsOneWidget);

    // The Poste picker is the first of the dialog's four DropdownButtonFormField<String?>s
    // (Poste, Resource, Taking, Participant, in that order).
    await tester.tap(find.byType(DropdownButtonFormField<String?>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text("Camera").last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
      "Zoom lens",
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogAmountFieldLabel),
      "10",
    );
    await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
    await tester.pumpAndSettle();

    final fields = routerManager.poppedValue! as OcptBudgetEntryFormFields;
    expect(fields.posteId, "poste-1");
  });

  group("the resource picker", () {
    testWidgets("offers an explicit no-resource choice alongside every live resource, defaulting to null", (
      tester,
    ) async {
      final resource = _resource(id: "resource-1", label: "Regional grant");
      final tr = await pumpDialog(tester, resources: [resource]);

      expect(find.text(tr.budgetEntryDialogNoResourceLabel), findsOneWidget);

      // The Resource picker is the second of the dialog's four DropdownButtonFormField<String?>s —
      // see the comment above.
      await tester.tap(find.byType(DropdownButtonFormField<String?>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Regional grant").last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
        "Grant instalment",
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, tr.budgetEntryDialogAmountFieldLabel),
        "10",
      );
      await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
      await tester.pumpAndSettle();

      final fields = routerManager.poppedValue! as OcptBudgetEntryFormFields;
      expect(fields.resourceId, "resource-1");
    });

    testWidgets("submitting with no pick reports a null resourceId, the normal case", (tester) async {
      final resource = _resource(id: "resource-1", label: "Regional grant");
      final tr = await pumpDialog(tester, resources: [resource]);

      await tester.enterText(
        find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
        "Camera rental",
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, tr.budgetEntryDialogAmountFieldLabel),
        "10",
      );
      await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
      await tester.pumpAndSettle();

      final fields = routerManager.poppedValue! as OcptBudgetEntryFormFields;
      expect(fields.resourceId, isNull);
    });

    testWidgets("a prefill naming a resource round-trips it on Save", (tester) async {
      final resource = _resource(id: "resource-1", label: "Regional grant");

      await tester.pumpWidget(
        _wrapWithLocalization(
          OcptBudgetEntryDialog(
            existing: null,
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
            postes: const [],
            resources: [resource],
            currencyCode: "EUR",
            defaultVatRateBasisPoints: null,
            isSimplified: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final tr = Tr.of(tester.element(find.byType(OcptBudgetEntryDialog)));

      await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
      await tester.pumpAndSettle();

      final fields = routerManager.poppedValue! as OcptBudgetEntryFormFields;
      expect(fields.resourceId, "resource-1");
      expect(fields.isDebit, isFalse);
      expect(fields.amountCents, 5000);
    });
  });

  testWidgets("cancelling pops with nothing", (tester) async {
    final tr = await pumpDialog(tester);

    await tester.tap(find.text(tr.budgetEntryDialogCancelAction));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isTrue);
    expect(routerManager.poppedValue, isNull);
  });

  group("the receipt field", () {
    testWidgets("creating a new entry with no receipt shows the empty hint and an Attach action", (
      tester,
    ) async {
      final tr = await pumpDialog(tester);

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

      await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
      await tester.pumpAndSettle();

      final fields = routerManager.poppedValue! as OcptBudgetEntryFormFields;
      expect(fields.isReceiptDetached, isTrue);
      expect(fields.pickedReceiptPath, isNull);
    });

    testWidgets("picking a receipt through the native selector attaches it, and Save reports it", (
      tester,
    ) async {
      await _registerFileSelector("/tmp/nouvelle-facture.pdf");
      final tr = await pumpDialog(tester);

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
      await tester.enterText(
        find.widgetWithText(TextFormField, tr.budgetEntryDialogAmountFieldLabel),
        "10",
      );
      await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
      await tester.pumpAndSettle();

      final fields = routerManager.poppedValue! as OcptBudgetEntryFormFields;
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

      await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
      await tester.pumpAndSettle();

      final fields = routerManager.poppedValue! as OcptBudgetEntryFormFields;
      expect(fields.pickedReceiptPath, isNull);
      expect(fields.isReceiptDetached, isFalse);
    });
  });
}
