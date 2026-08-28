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
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_revenue_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
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
OcptBudgetPoste _poste({required String id, required String label}) => OcptBudgetPoste(
  id: id,
  code: "1",
  label: label,
  simpleLabel: null,
  estimateToCompleteCents: null,
  sortKey: "a0",
  lines: const [],
);

/// A minimal financing resource, everything but [id]/[label] neutral.
OcptBudgetResource _resource({required String id, required String label}) => OcptBudgetResource(
  id: id,
  groupKind: OcptBudgetResourceGroupKind.subsidy,
  personId: null,
  label: label,
  amountCents: 10000,
  status: OcptBudgetResourceStatus.pending,
  isReimbursable: false,
  notes: "",
  sortKey: "a0",
);

/// A minimal taking, everything but [id]/[label] neutral.
OcptBudgetRevenue _revenue({required String id, required String label}) => OcptBudgetRevenue(
  id: id,
  date: DateTime(2026, 3),
  label: label,
  amountCents: 10000,
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

/// A minimal person, everything but [id]/[firstName] neutral — mirrors
/// `ocpt_budget_regie_test.dart`'s own `_buildPerson`.
OcptPerson _person({required String id, String firstName = ""}) => OcptPerson(
  id: id,
  firstName: firstName,
  lastName: "",
  email: "",
  phone: "",
  addressLine1: "",
  addressLine2: "",
  postalCode: "",
  city: "",
  region: "",
  country: "",
  colorIndex: 0,
  birthDate: null,
  minorNotes: "",
  maxDailyPresenceMinutes: null,
  isTransportAutonomous: null,
  accommodationNotes: "",
  travelNotes: "",
  dietaryNotes: "",
  allergies: "",
  measurementHeight: "",
  measurementChest: "",
  measurementWaist: "",
  measurementHips: "",
  sizeTop: "",
  sizeBottom: "",
  sizeShoes: "",
  hmcNotes: "",
  imageRightsStatus: OcptImageRightsStatus.notApplicable,
  imageRightsDate: null,
  imageRightsAssetId: null,
  imageRightsDocument: null,
  photoAssetId: null,
  photo: null,
  notes: "",
  commuteKmMilli: null,
  mileageRateId: null,
  positions: const [],
  skills: const [],
  unavailabilities: const [],
);

/// A minimal existing entry, its debit or credit set by whichever of [debitCents]/[creditCents] is
/// non-zero, naming at most one of [posteId]/[resourceId]/[revenueId]/[shareId]/[personId].
OcptBudgetEntry _existingEntry({
  String id = "entry-1",
  DateTime? date,
  String label = "Camera rental",
  String? posteId,
  String? resourceId,
  String? revenueId,
  String? shareId,
  String? personId,
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
  commitmentId: null,
  personId: personId,
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

  /// Pumps [OcptBudgetEntryDialog] directly (no `.show`), [existing] defaulting to a plain debit
  /// naming a poste — this dialog now only ever edits, so [existing] is never null.
  Future<Tr> pumpDialog(
    WidgetTester tester, {
    OcptBudgetEntry? existing,
    OcptAssetRef? existingReceipt,
    List<OcptBudgetPoste> postes = const [],
    List<OcptBudgetResource> resources = const [],
    List<OcptBudgetRevenue> revenues = const [],
    List<OcptBudgetShare> shares = const [],
    List<OcptPerson> people = const [],
    int? defaultVatRateBasisPoints,
    bool isSimplified = false,
  }) async {
    await tester.pumpWidget(
      _wrapWithLocalization(
        OcptBudgetEntryDialog(
          existing: existing ?? _existingEntry(debitCents: 5000),
          existingReceipt: existingReceipt,
          postes: postes,
          resources: resources,
          revenues: revenues,
          shares: shares,
          people: people,
          currencyCode: "EUR",
          defaultVatRateBasisPoints: defaultVatRateBasisPoints,
          isSimplified: isSimplified,
        ),
      ),
    );
    await tester.pumpAndSettle();

    return Tr.of(tester.element(find.byType(OcptBudgetEntryDialog)));
  }

  group("opening on the one screen it now has", () {
    testWidgets("draws the edit title, straight to the form, no step counter", (tester) async {
      final tr = await pumpDialog(tester);

      expect(find.text(tr.budgetEntryDialogEditTitle), findsOneWidget);
      expect(find.byKey(const Key("ocptBudgetEntryWizardSaveButton")), findsOneWidget);
      // Nothing left of the retired step 1: no nature cards, no `Continuer`, no step label.
      expect(find.text(tr.budgetEntryNatureExpenseLabel), findsNothing);
      expect(find.byKey(const Key("ocptBudgetEntryWizardContinueButton")), findsNothing);
    });

    testWidgets("pre-fills date, label and amount from the entry being edited", (tester) async {
      await pumpDialog(
        tester,
        existing: _existingEntry(
          date: DateTime(2026, 4, 2),
          label: "Steadicam hire",
          posteId: "poste-1",
          debitCents: 45000,
        ),
        postes: [_poste(id: "poste-1", label: "Camera")],
      );

      expect(find.widgetWithText(TextFormField, "Steadicam hire"), findsOneWidget);
      expect(find.widgetWithText(TextFormField, "450.00"), findsOneWidget);
    });

    testWidgets("Annuler pops with nothing", (tester) async {
      final tr = await pumpDialog(tester);

      await tester.tap(find.text(tr.budgetEntryDialogCancelAction));
      await tester.pumpAndSettle();

      expect(routerManager.popped, isTrue);
      expect(routerManager.poppedValue, isNull);
    });
  });

  group("the nature is read once, silently, off whichever link is set", () {
    testWidgets("a poste alone draws Poste du devis and no other link field", (tester) async {
      final tr = await pumpDialog(
        tester,
        existing: _existingEntry(posteId: "poste-1", debitCents: 5000),
        postes: [_poste(id: "poste-1", label: "Camera")],
      );

      expect(find.text(tr.budgetEntryDialogPosteFieldLabel), findsOneWidget);
      expect(find.text(tr.budgetEntryDialogResourceFieldLabel), findsNothing);
      expect(find.text(tr.budgetEntryDialogRevenueFieldLabel), findsNothing);
      expect(find.text(tr.budgetEntryDialogShareFieldLabel), findsNothing);
      expect(find.text(tr.budgetEntryDialogPersonFieldLabel), findsNothing);
      // `expense`'s own direction is fixed: no direction choice drawn at all.
      expect(find.text(tr.budgetEntryDialogDirectionFieldLabel), findsNothing);
    });

    testWidgets("a resource alone draws Ressource", (tester) async {
      final tr = await pumpDialog(
        tester,
        existing: _existingEntry(resourceId: "r1", creditCents: 5000),
        resources: [_resource(id: "r1", label: "Regional grant")],
      );

      expect(find.text(tr.budgetEntryDialogResourceFieldLabel), findsOneWidget);
      expect(find.text(tr.budgetEntryDialogPosteFieldLabel), findsNothing);
    });

    testWidgets("a taking alone draws Recette", (tester) async {
      final tr = await pumpDialog(
        tester,
        existing: _existingEntry(revenueId: "v1", creditCents: 5000),
        revenues: [_revenue(id: "v1", label: "Festival prize")],
      );

      expect(find.text(tr.budgetEntryDialogRevenueFieldLabel), findsOneWidget);
    });

    testWidgets("a share alone draws Participant", (tester) async {
      final tr = await pumpDialog(
        tester,
        existing: _existingEntry(shareId: "s1", debitCents: 5000),
        shares: [_share(id: "s1", label: "Co-producer")],
      );

      expect(find.text(tr.budgetEntryDialogShareFieldLabel), findsOneWidget);
    });

    testWidgets(
      "a person alone draws Personne — reachable now, unlike before this milestone",
      (tester) async {
        final tr = await pumpDialog(
          tester,
          existing: _existingEntry(personId: "p1", debitCents: 5000),
          people: [_person(id: "p1", firstName: "Alex")],
        );

        expect(find.text(tr.budgetEntryDialogPersonFieldLabel), findsOneWidget);
        expect(find.text("Alex"), findsOneWidget);
      },
    );

    testWidgets("naming nothing at all reads as other, and draws the direction choice", (
      tester,
    ) async {
      final tr = await pumpDialog(tester, existing: _existingEntry(debitCents: 5000));

      expect(find.text(tr.budgetEntryDialogPosteFieldLabel), findsOneWidget);
      // Drawn upper-cased, like every other bare field label of this dialog.
      expect(find.text(tr.budgetEntryDialogDirectionFieldLabel.toUpperCase()), findsOneWidget);
    });
  });

  group("saving", () {
    testWidgets("pops with the fields typed, including the retyped voucher number", (
      tester,
    ) async {
      await pumpDialog(
        tester,
        existing: _existingEntry(posteId: "poste-1", debitCents: 5000, voucherNumber: "J-001"),
        postes: [_poste(id: "poste-1", label: "Camera")],
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, "J-001"),
        "J-002",
      );
      await tester.tap(find.byKey(const Key("ocptBudgetEntryWizardSaveButton")));
      await tester.pumpAndSettle();

      expect(routerManager.popped, isTrue);
      final fields = routerManager.poppedValue! as OcptBudgetEntryFormFields;
      expect(fields.voucherNumber, "J-002");
      expect(fields.posteId, "poste-1");
      expect(fields.isDebit, isTrue);
      expect(fields.amountCents, 5000);
    });

    testWidgets("is refused while the label is blank", (tester) async {
      final tr = await pumpDialog(tester);

      // "Camera rental" is `_existingEntry`'s own default label.
      await tester.enterText(find.widgetWithText(TextFormField, "Camera rental"), "");
      await tester.tap(find.byKey(const Key("ocptBudgetEntryWizardSaveButton")));
      await tester.pumpAndSettle();

      expect(routerManager.popped, isFalse);
      expect(find.text(tr.budgetEntryDialogLabelRequiredError), findsOneWidget);
    });

    testWidgets("is refused while the amount does not parse", (tester) async {
      await pumpDialog(tester);

      await tester.enterText(
        find.byKey(const Key("ocptBudgetEntryWizardAmountField")),
        "not a number",
      );
      await tester.tap(find.byKey(const Key("ocptBudgetEntryWizardSaveButton")));
      await tester.pumpAndSettle();

      expect(routerManager.popped, isFalse);
    });
  });

  group("the voucher", () {
    testWidgets("is always offered and always editable — no auto-mint hint, this dialog only "
        "ever edits", (tester) async {
      final tr = await pumpDialog(tester);

      expect(find.text(tr.budgetEntryDialogVoucherAutoHint), findsNothing);
      expect(find.text(tr.budgetEntryDialogVoucherFieldLabel), findsOneWidget);
    });
  });

  group("the receipt", () {
    testWidgets("shows the existing voucher and offers Replace", (tester) async {
      final tr = await pumpDialog(
        tester,
        existingReceipt: _receipt(path: "/tmp/invoice.pdf"),
      );

      expect(find.text(tr.budgetEntryDialogReceiptReplaceAction), findsOneWidget);
      expect(find.text(tr.budgetEntryDialogReceiptEmptyHint), findsNothing);
    });

    testWidgets("shows the empty hint and offers Attach while none is referenced", (tester) async {
      final tr = await pumpDialog(tester);

      expect(find.text(tr.budgetEntryDialogReceiptEmptyHint), findsOneWidget);
      expect(find.text(tr.budgetEntryDialogReceiptAttachAction), findsOneWidget);
    });

    testWidgets("attaching a fresh file carries its path through Enregistrer", (tester) async {
      await _registerFileSelector("/tmp/fresh-receipt.pdf");
      await pumpDialog(tester, postes: [_poste(id: "poste-1", label: "Camera")]);

      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key("ocptBudgetEntryWizardSaveButton")));
      await tester.pumpAndSettle();

      final fields = routerManager.poppedValue! as OcptBudgetEntryFormFields;
      expect(fields.pickedReceiptPath, "/tmp/fresh-receipt.pdf");
      expect(fields.isReceiptDetached, isFalse);
    });

    testWidgets("Retirer marks the existing voucher detached", (tester) async {
      await pumpDialog(tester, existingReceipt: _receipt(path: "/tmp/invoice.pdf"));

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key("ocptBudgetEntryWizardSaveButton")));
      await tester.pumpAndSettle();

      final fields = routerManager.poppedValue! as OcptBudgetEntryFormFields;
      expect(fields.isReceiptDetached, isTrue);
      expect(fields.pickedReceiptPath, isNull);
    });
  });

  group("the taking picker's own inline creation", () {
    testWidgets("New taking… still opens the revenue dialog, unchanged from before this "
        "milestone", (tester) async {
      final tr = await pumpDialog(
        tester,
        existing: _existingEntry(revenueId: "v1", creditCents: 5000),
        revenues: [_revenue(id: "v1", label: "Festival prize")],
      );

      await tester.tap(find.byType(DropdownButtonFormField<String?>).last);
      await tester.pumpAndSettle();
      expect(find.text(tr.budgetEntryDialogNewRevenueAction), findsOneWidget);
    });
  });
}
