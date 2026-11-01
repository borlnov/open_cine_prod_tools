// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_new_outcome.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_covered_total.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_allowance_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_gesture.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_gesture_family.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_new_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_share_dialog.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';
import 'ocpt_budget_new_dialog_test_doubles.dart';

/// A minimal quote line, priced at [unitAmountCents] for [quantityMilli] thousandths of a unit —
/// everything but [id]/[posteId]/[label] neutral.
OcptBudgetLine _line({
  required String id,
  required String posteId,
  required String label,
  int quantityMilli = 1000,
  int unitAmountCents = 10000,
}) => OcptBudgetLine(
  id: id,
  posteId: posteId,
  label: label,
  quantityMilli: quantityMilli,
  unit: "",
  unitPrice: OcptMoney(
    amountCents: unitAmountCents,
    isTaxInclusive: true,
    vatRateBasisPoints: null,
  ),
  elementId: null,
  inKindResourceId: null,
  provisionKey: null,
  provisionDigest: null,
  notes: "",
  sortKey: "a0",
);

/// A minimal financing resource, everything but [id]/[label]/[amountCents] neutral.
OcptBudgetResource _resource({
  required String id,
  required String label,
  int amountCents = 100000,
}) => OcptBudgetResource(
  id: id,
  groupKind: OcptBudgetResourceGroupKind.cash,
  personId: null,
  label: label,
  amountCents: amountCents,
  status: OcptBudgetResourceStatus.pending,
  isReimbursable: false,
  notes: "",
  sortKey: "a0",
);

/// A minimal person, everything but [id]/[firstName] neutral.
OcptPerson _person({required String id, required String firstName}) => OcptPerson(
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

/// A minimal defrayal owed to [personId], priced at [quantityMilli] thousandths of a unit at
/// [unitAmountMilliCents] thousandths of a cent each, everything else neutral.
OcptBudgetAllowance _allowance({
  required String id,
  String? personId,
  int quantityMilli = 1000,
  int unitAmountMilliCents = 100000,
}) => OcptBudgetAllowance(
  id: id,
  personId: personId,
  kind: OcptBudgetAllowanceKind.other,
  label: "",
  date: null,
  endDate: null,
  quantityMilli: quantityMilli,
  unitAmountMilliCents: unitAmountMilliCents,
  notes: "",
  sortKey: "a0",
);

/// Run the tests of the budget new dialog outcome variants.
void main() {
  late RecordingRouterManager routerManager;

  setUpAll(() {
    OcptGlobalManager.instance;
  });

  setUp(() async {
    final managers = globalGetIt();
    if (managers.isRegistered<OcptRouterManager>()) {
      await managers.unregister<OcptRouterManager>();
    }
    routerManager = RecordingRouterManager();
    managers.registerSingleton<OcptRouterManager>(routerManager);
  });

  /// Pumps [OcptBudgetNewDialog] directly (no `.show`).
  Future<Tr> pumpDialog(
    WidgetTester tester, {
    OcptBudgetGestureFamily? promotedFamily,
    Set<OcptBudgetGesture>? allowedGestures,
    String? filterLabel,
    OcptBudgetGesture? initialGesture,
    OcptBudgetEntryFormFields? entryPrefill,
    bool offersLettrage = true,
    List<OcptBudgetPoste> postes = const [],
    List<OcptBudgetResource> resources = const [],
    List<OcptBudgetRevenue> revenues = const [],
    List<OcptBudgetShare> shares = const [],
    List<OcptPerson> people = const [],
    List<OcptBudgetCommitment> commitments = const [],
    List<OcptElement> unpricedElements = const [],
    List<OcptBudgetAllowance> allowances = const [],
    Map<String, OcptBudgetCoveredTotal> receivedByResourceId = const {},
    Map<String, OcptBudgetCoveredTotal> reimbursedByPersonId = const {},
  }) async {
    await tester.pumpWidget(
      wrap(
        OcptBudgetNewDialog(
          promotedFamily: promotedFamily,
          allowedGestures: allowedGestures,
          filterLabel: filterLabel,
          initialGesture: initialGesture,
          entryPrefill: entryPrefill,
          offersLettrage: offersLettrage,
          postes: postes,
          resources: resources,
          revenues: revenues,
          shares: shares,
          people: people,
          unpricedElements: unpricedElements,
          commitments: commitments,
          entries: const [],
          allowances: allowances,
          mileageRates: const [],
          receivedByResourceId: receivedByResourceId,
          receivedByRevenueId: const {},
          reimbursedByPersonId: reimbursedByPersonId,
          currencyCode: "EUR",
          defaultVatRateBasisPoints: null,
          isSimplified: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    return Tr.of(tester.element(find.byType(OcptBudgetNewDialog)));
  }

  group("every outcome variant reaches the mode correctly", () {
    testWidgets("addQuoteLine pops OcptBudgetNewLineOutcome naming the poste and the typing", (
      tester,
    ) async {
      final tr = await pumpDialog(
        tester,
        initialGesture: OcptBudgetGesture.addQuoteLine,
        postes: [testPoste(id: "p1", label: "Camera")],
      );

      await tester.tap(find.byKey(const Key("ocptBudgetNewContinueButton")));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Camera"));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key("ocptBudgetNewAttachmentContinueButton")));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, tr.budgetLineLabelFieldLabel),
        "Camera hire",
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, tr.budgetLineQuantityFieldLabel),
        "5",
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, tr.budgetLineUnitPriceFieldLabel),
        "120",
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key("ocptBudgetNewSaveButton")));
      await tester.pumpAndSettle();

      final outcome = routerManager.poppedValue! as OcptBudgetNewLineOutcome;
      expect(outcome.posteId, "p1");
      expect(outcome.fields.label, "Camera hire");
      expect(outcome.fields.quantityMilli, 5000);
      expect(outcome.fields.unitAmountCents, 12000);
    });

    testWidgets("commitSpend pops OcptBudgetNewCommitmentOutcome naming the line picked", (
      tester,
    ) async {
      await pumpDialog(
        tester,
        initialGesture: OcptBudgetGesture.commitSpend,
        postes: [
          testPoste(
            id: "p1",
            label: "Camera",
            lines: [_line(id: "l1", posteId: "p1", label: "Zoom lens")],
          ),
        ],
      );

      await tester.tap(find.byKey(const Key("ocptBudgetNewContinueButton")));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Camera"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Zoom lens"));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key("ocptBudgetNewAttachmentContinueButton")));
      await tester.pumpAndSettle();

      // Step 2's own line already fills the form's label and amount — nothing left to type.
      await tester.tap(find.byKey(const Key("ocptBudgetNewSaveButton")));
      await tester.pumpAndSettle();

      final outcome = routerManager.poppedValue! as OcptBudgetNewCommitmentOutcome;
      expect(outcome.lineId, "l1");
      expect(outcome.fields.posteId, "p1");
      expect(outcome.fields.label, "Zoom lens");
    });

    testWidgets("planSubsidy pops a resource outcome pinned to the subsidy group kind", (
      tester,
    ) async {
      final tr = await pumpDialog(tester, initialGesture: OcptBudgetGesture.planSubsidy);

      // planSubsidy attaches to nothing, so step 1 (already pre-selected) still has to be
      // confirmed before step 3's own form draws.
      await tester.tap(find.byKey(const Key("ocptBudgetNewContinueButton")));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
        "Région subvention",
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, tr.budgetEntryDialogAmountFieldLabel),
        "5000",
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key("ocptBudgetNewSaveButton")));
      await tester.pumpAndSettle();

      final outcome = routerManager.poppedValue! as OcptBudgetNewResourceOutcome;
      expect(outcome.fields.groupKind, OcptBudgetResourceGroupKind.subsidy);
      expect(outcome.fields.label, "Région subvention");
    });

    testWidgets("planTaking pops OcptBudgetNewRevenueOutcome", (tester) async {
      final tr = await pumpDialog(tester, initialGesture: OcptBudgetGesture.planTaking);

      await tester.tap(find.byKey(const Key("ocptBudgetNewContinueButton")));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
        "Festival prize",
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, tr.budgetEntryDialogAmountFieldLabel),
        "1000",
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key("ocptBudgetNewSaveButton")));
      await tester.pumpAndSettle();

      final outcome = routerManager.poppedValue! as OcptBudgetNewRevenueOutcome;
      expect(outcome.fields.label, "Festival prize");
      expect(outcome.fields.amountCents, 100000);
    });

    testWidgets("defrayPerson pops OcptBudgetNewAllowanceOutcome", (tester) async {
      final tr = await pumpDialog(tester, initialGesture: OcptBudgetGesture.defrayPerson);

      await tester.tap(find.byKey(const Key("ocptBudgetNewContinueButton")));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, tr.budgetAllowanceDialogQuantityFieldLabel),
        "3",
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, tr.budgetAllowanceDialogUnitPriceFieldLabel),
        "10",
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key("ocptBudgetNewSaveButton")));
      await tester.pumpAndSettle();

      final outcome = routerManager.poppedValue! as OcptBudgetNewAllowanceOutcome;
      expect(outcome.fields.quantityMilli, 3000);
      expect(outcome.fields.unitAmountMilliCents, 1000000);
    });

    testWidgets("addSharingParticipant pops OcptBudgetNewShareOutcome", (tester) async {
      final tr = await pumpDialog(tester, initialGesture: OcptBudgetGesture.addSharingParticipant);

      await tester.tap(find.byKey(const Key("ocptBudgetNewContinueButton")));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
        "Co-producer",
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key("ocptBudgetNewSaveButton")));
      await tester.pumpAndSettle();

      final outcome = routerManager.poppedValue! as OcptBudgetNewShareOutcome;
      expect(outcome.fields.label, "Co-producer");
    });

    testWidgets("recordExpense with nothing to reconcile against pops a plain wizard result", (
      tester,
    ) async {
      await pumpDialog(
        tester,
        initialGesture: OcptBudgetGesture.recordExpense,
        postes: [testPoste(id: "p1", label: "Camera")],
      );

      await tester.tap(find.byKey(const Key("ocptBudgetNewContinueButton")));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Camera"));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key("ocptBudgetNewAttachmentContinueButton")));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key("ocptBudgetNewLabelField")), "Rushes hard drive");
      await tester.enterText(find.byKey(const Key("ocptBudgetNewAmountField")), "45.00");
      await tester.pumpAndSettle();

      // No commitments, entries or resources were given, so nothing was ever offered to
      // reconcile against — the strip itself never drew.
      expect(find.byKey(const Key("ocptBudgetNewLettrageNone")), findsNothing);

      await tester.tap(find.byKey(const Key("ocptBudgetNewSaveButton")));
      await tester.pumpAndSettle();

      final outcome = routerManager.poppedValue! as OcptBudgetEntryWizardResult;
      expect(outcome.acceptedSuggestion, isNull);
      expect(outcome.fields.posteId, "p1");
    });
  });

  group("recording a taking mints its own from one amount and label", () {
    testWidgets("goes straight to the form and carries a to-be-made taking", (tester) async {
      final tr = await pumpDialog(tester, initialGesture: OcptBudgetGesture.recordTakingReceipt);

      // Two steps, not three: no taking to pick, so step 1 goes straight to the money form.
      expect(find.text(tr.budgetNewStepLabel(1, 2)), findsOneWidget);
      await tester.tap(find.byKey(const Key("ocptBudgetNewContinueButton")));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key("ocptBudgetNewAmountField")), "10");
      await tester.enterText(find.byKey(const Key("ocptBudgetNewLabelField")), "Festival prize");
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key("ocptBudgetNewSaveButton")));
      await tester.pumpAndSettle();

      final outcome = routerManager.poppedValue! as OcptBudgetEntryWizardResult;
      expect(outcome.acceptedSuggestion, isNull);
      // A credit naming no existing taking, carrying a to-be-made one built from the same figures.
      expect(outcome.fields.isDebit, isFalse);
      expect(outcome.fields.revenueId, isNull);
      final newRevenue = outcome.fields.newRevenue;
      expect(newRevenue, isNotNull);
      expect(newRevenue!.label, "Festival prize");
      // The taking is minted at exactly the amount received — one value typed once, not twice.
      expect(newRevenue.amountCents, outcome.fields.amountCents);
      expect(newRevenue.amountCents, greaterThan(0));
    });
  });

  group("step 2 closes the dead end for a missing object", () {
    testWidgets("a missing participant is created inline, without leaving the wizard", (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final tr = await pumpDialog(tester, initialGesture: OcptBudgetGesture.payParticipantShare);

      await tester.tap(find.byKey(const Key("ocptBudgetNewContinueButton")));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key("ocptBudgetNewCreateShareChoice")));
      await tester.pumpAndSettle();

      expect(find.byType(OcptBudgetShareDialog), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
        "Co-producer",
      );
      await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
      await tester.pumpAndSettle();

      expect(find.byType(OcptBudgetShareDialog), findsNothing);
      expect(find.byType(OcptBudgetNewDialog), findsOneWidget);
      expect(find.byKey(const Key("ocptBudgetNewPendingShareChoice")), findsOneWidget);
      expect(find.text(tr.budgetNewWillCreateLabel("Co-producer")), findsOneWidget);
      expect(find.text(tr.budgetNewStepLabel(2, 3)), findsOneWidget);
    });
  });

  group("step 2's own escape answers", () {
    testWidgets("recordExpense's own Hors devis answer leaves the poste unset", (tester) async {
      await pumpDialog(
        tester,
        initialGesture: OcptBudgetGesture.recordExpense,
        postes: [testPoste(id: "p1", label: "Camera")],
      );

      await tester.tap(find.byKey(const Key("ocptBudgetNewContinueButton")));
      await tester.pumpAndSettle();

      // The very same wording the expenses table itself uses for an entry naming no poste — not a
      // generic "no poste" of the wizard's own invention.
      final tr = Tr.of(tester.element(find.byType(OcptBudgetNewDialog)));
      expect(find.text(tr.budgetCostTrackingOffQuoteLabel), findsOneWidget);

      await tester.tap(find.byKey(const Key("ocptBudgetNewOffQuoteChoice")));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key("ocptBudgetNewAttachmentContinueButton")));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key("ocptBudgetNewLabelField")), "Taxi");
      await tester.enterText(find.byKey(const Key("ocptBudgetNewAmountField")), "20.00");
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key("ocptBudgetNewSaveButton")));
      await tester.pumpAndSettle();

      final outcome = routerManager.poppedValue! as OcptBudgetEntryWizardResult;
      expect(outcome.fields.posteId, isNull);
    });

    testWidgets("commitSpend's own Aucune answer hangs the commitment off the poste, no line", (
      tester,
    ) async {
      final tr = await pumpDialog(
        tester,
        initialGesture: OcptBudgetGesture.commitSpend,
        postes: [
          testPoste(
            id: "p1",
            label: "Camera",
            lines: [_line(id: "l1", posteId: "p1", label: "Zoom lens")],
          ),
        ],
      );

      await tester.tap(find.byKey(const Key("ocptBudgetNewContinueButton")));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Camera"));
      await tester.pumpAndSettle();

      expect(find.text(tr.budgetNewNoLineAnswer), findsOneWidget);

      await tester.tap(find.byKey(const Key("ocptBudgetNewNoLineChoice")));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key("ocptBudgetNewAttachmentContinueButton")));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
        "Zoom lens repair",
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, tr.budgetEntryDialogAmountFieldLabel),
        "150",
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key("ocptBudgetNewSaveButton")));
      await tester.pumpAndSettle();

      final outcome = routerManager.poppedValue! as OcptBudgetNewCommitmentOutcome;
      expect(outcome.lineId, isNull);
      expect(outcome.fields.posteId, "p1");
    });
  });

  testWidgets("step 2's own resource row states what is promised, received and outstanding", (
    tester,
  ) async {
    final tr = await pumpDialog(
      tester,
      initialGesture: OcptBudgetGesture.recordFinancingReceipt,
      resources: [_resource(id: "r1", label: "Région subvention", amountCents: 500000)],
      receivedByResourceId: const {
        "r1": OcptBudgetCoveredTotal(amountCents: 150000, coveredLineCount: 1, lineCount: 1),
      },
    );

    await tester.tap(find.byKey(const Key("ocptBudgetNewContinueButton")));
    await tester.pumpAndSettle();

    final expectedHint = tr.budgetNewResourceChoiceHint(
      ocptBudgetAmountLabel(500000, "EUR"),
      ocptBudgetAmountLabel(150000, "EUR"),
      // The one computed figure: 500000 - 150000 = 350000, never read off a stored column.
      ocptBudgetAmountLabel(350000, "EUR"),
    );
    expect(find.text(expectedHint), findsOneWidget);
  });

  testWidgets("step 2's own person row states what is advanced, reimbursed and owed", (
    tester,
  ) async {
    final tr = await pumpDialog(
      tester,
      initialGesture: OcptBudgetGesture.reimbursePerson,
      people: [_person(id: "p1", firstName: "Alex")],
      allowances: [_allowance(id: "a1", personId: "p1")],
      reimbursedByPersonId: const {
        "p1": OcptBudgetCoveredTotal(amountCents: 40, coveredLineCount: 1, lineCount: 1),
      },
    );

    await tester.tap(find.byKey(const Key("ocptBudgetNewContinueButton")));
    await tester.pumpAndSettle();

    final expectedHint = tr.budgetNewPersonChoiceHint(
      ocptBudgetAmountLabel(100, "EUR"),
      ocptBudgetAmountLabel(40, "EUR"),
      // The one computed figure: 100 - 40 = 60, never read off a stored column.
      ocptBudgetAmountLabel(60, "EUR"),
    );
    expect(find.text(expectedHint), findsOneWidget);
  });

  testWidgets("a contextual shortcut lands on the form, trail a summary alone, no way back", (
    tester,
  ) async {
    final poste = testPoste(id: "p1", label: "Camera");
    final prefill = OcptBudgetEntryFormFields(
      date: DateTime(2026, 1, 5),
      label: "Zoom lens repair",
      posteId: "p1",
      resourceId: null,
      revenueId: null,
      shareId: null,
      isDebit: true,
      amountCents: 15000,
      isTaxInclusive: true,
      vatRateBasisPoints: null,
      voucherNumber: null,
      pickedReceiptPath: null,
      isReceiptDetached: false,
    );

    final tr = await pumpDialog(
      tester,
      initialGesture: OcptBudgetGesture.recordExpense,
      entryPrefill: prefill,
      postes: [poste],
    );

    // Landed straight on the form step — recordExpense takes 3 steps, and this is the third,
    // step 1 and step 2 both already answered by the shortcut.
    expect(find.text(tr.budgetNewStepLabel(3, 3)), findsOneWidget);
    // The trail recalls the poste step 2 would have asked, but offers no way back to a step the
    // reader never chose, and the form's own first action is `Cancel`, not `Back`.
    expect(find.textContaining("Camera"), findsWidgets);
    expect(find.byKey(const Key("ocptBudgetNewChangeGestureLink")), findsNothing);
    expect(find.byKey(const Key("ocptBudgetNewFormBackButton")), findsNothing);
    expect(find.byKey(const Key("ocptBudgetNewFormCancelButton")), findsOneWidget);
    // The form itself opened pre-filled, not blank.
    expect(find.text("Zoom lens repair"), findsOneWidget);
  });

  testWidgets("the form's Cancel closes the wizard whole, returning no outcome", (tester) async {
    final prefill = OcptBudgetEntryFormFields(
      date: DateTime(2026, 1, 5),
      label: "Zoom lens repair",
      posteId: "p1",
      resourceId: null,
      revenueId: null,
      shareId: null,
      isDebit: true,
      amountCents: 15000,
      isTaxInclusive: true,
      vatRateBasisPoints: null,
      voucherNumber: null,
      pickedReceiptPath: null,
      isReceiptDetached: false,
    );

    await pumpDialog(
      tester,
      initialGesture: OcptBudgetGesture.recordExpense,
      entryPrefill: prefill,
      postes: [testPoste(id: "p1", label: "Camera")],
    );

    await tester.tap(find.byKey(const Key("ocptBudgetNewFormCancelButton")));
    await tester.pumpAndSettle();

    // The wizard popped, and with no outcome — exactly a cancellation, never a step surfaced
    // behind the form. (The recording router only records the pop; it mounts no route to remove.)
    expect(routerManager.popped, isTrue);
    expect(routerManager.poppedValue, isNull);
  });

  group("the wizard shell answers ocptIsCompactWidth", () {
    testWidgets(
      "renders full-screen at a compact width — the default test surface included — and the "
      "wizard still runs end to end",
      (tester) async {
        // No explicit surface override: the default 800×600 test surface is itself below
        // `ocptCompactWidthBreakpoint` (816), so this is also what every other test in this file
        // has been exercising all along.
        final tr = await pumpDialog(tester, initialGesture: OcptBudgetGesture.recordTakingReceipt);

        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(AppBar), findsOneWidget);
        expect(find.byKey(const Key("ocptBudgetNewFullscreenCloseButton")), findsOneWidget);
        expect(
          find.byWidgetPredicate((widget) => widget is SizedBox && widget.width == 520),
          findsNothing,
        );

        // Two steps, not three: no taking to pick, so step 1 goes straight to the money form —
        // the wizard's own step navigation and its `Save` still work inside the full-screen shell.
        expect(find.text(tr.budgetNewStepLabel(1, 2)), findsOneWidget);
        await tester.tap(find.byKey(const Key("ocptBudgetNewContinueButton")));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key("ocptBudgetNewAmountField")), "10");
        await tester.enterText(find.byKey(const Key("ocptBudgetNewLabelField")), "Festival prize");
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key("ocptBudgetNewSaveButton")));
        await tester.pumpAndSettle();

        final outcome = routerManager.poppedValue! as OcptBudgetEntryWizardResult;
        expect(outcome.fields.newRevenue?.label, "Festival prize");
      },
    );

    testWidgets(
      "the full-screen shell's close action cancels the whole wizard, exactly as Cancel already "
      "does",
      (tester) async {
        await pumpDialog(tester);

        await tester.tap(find.byKey(const Key("ocptBudgetNewFullscreenCloseButton")));
        await tester.pumpAndSettle();

        expect(routerManager.popped, isTrue);
        expect(routerManager.poppedValue, isNull);
      },
    );

    testWidgets("stays an AlertDialog above the compact breakpoint", (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpDialog(tester, initialGesture: OcptBudgetGesture.recordTakingReceipt);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byKey(const Key("ocptBudgetNewFullscreenCloseButton")), findsNothing);
      expect(
        find.byWidgetPredicate((widget) => widget is SizedBox && widget.width == 520),
        findsOneWidget,
      );

      // The wizard still runs end to end above the breakpoint too.
      await tester.tap(find.byKey(const Key("ocptBudgetNewContinueButton")));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key("ocptBudgetNewAmountField")), "10");
      await tester.enterText(find.byKey(const Key("ocptBudgetNewLabelField")), "Festival prize");
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key("ocptBudgetNewSaveButton")));
      await tester.pumpAndSettle();

      final outcome = routerManager.poppedValue! as OcptBudgetEntryWizardResult;
      expect(outcome.fields.newRevenue?.label, "Festival prize");
    });
  });
}
