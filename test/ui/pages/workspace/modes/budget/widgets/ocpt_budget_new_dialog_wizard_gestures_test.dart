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
import 'package:open_cine_prod_tools/models/ocpt_budget_new_outcome.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_scene_element_link.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_covered_total.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_gesture.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_gesture_family.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_new_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_resource_dialog.dart';
import 'ocpt_budget_new_dialog_test_doubles.dart';

/// A minimal, unsettled commitment against [posteId], everything but [id]/[label]/[amountCents]
/// neutral.
OcptBudgetCommitment _commitment({
  required String id,
  required String label,
  required String posteId,
  int amountCents = 10000,
}) => OcptBudgetCommitment(
  id: id,
  dueDate: null,
  label: label,
  posteId: posteId,
  amount: OcptMoney(amountCents: amountCents, isTaxInclusive: true, vatRateBasisPoints: null),
  status: OcptBudgetCommitmentStatus.quoteAccepted,
  lineId: null,
  sortKey: "a0",
);

/// A minimal breakdown element, appearing in [sceneCount] scenes, everything else neutral.
OcptElement _element({required String id, required String name, int sceneCount = 1}) => OcptElement(
  id: id,
  category: OcptElementCategory.prop,
  subCategory: "",
  name: name,
  code: "",
  quantity: "1",
  sourceKind: OcptElementSourceKind.toBuy,
  status: OcptElementStatus.toFind,
  ownerPersonId: null,
  ownerNotes: "",
  broughtByPersonId: null,
  storageNotes: "",
  isSecured: false,
  isReadyForShoot: false,
  isReturned: false,
  cost: null,
  purposeNotes: "",
  notes: "",
  photoAssetId: null,
  photo: null,
  sceneLinks: [
    for (var i = 0; i < sceneCount; i++)
      OcptSceneElementLink(id: "link-$id-$i", sceneId: "scene-$i", quantity: "1", notes: ""),
  ],
  roleLinks: const [],
);

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

  group("the + New wizard filters its gestures by the view it opened from", () {
    // The expenses route's own filter: everything that makes money go out, transverse to the
    // families — the quote's three, the four debits and the free-direction `Autre mouvement`.
    final spends = {
      OcptBudgetGesture.addQuoteLine,
      OcptBudgetGesture.addQuoteLinesFromBreakdown,
      OcptBudgetGesture.commitSpend,
      OcptBudgetGesture.recordExpense,
      OcptBudgetGesture.reimbursePerson,
      OcptBudgetGesture.payParticipantShare,
      OcptBudgetGesture.repayContribution,
      OcptBudgetGesture.recordOtherMovement,
    };

    testWidgets("shows only the families with an offered gesture", (tester) async {
      final tr = await pumpDialog(
        tester,
        promotedFamily: OcptBudgetGestureFamily.quote,
        allowedGestures: spends,
        filterLabel: "Expenses",
        initialGesture: OcptBudgetGesture.addQuoteLine,
      );

      // The tag names the filter, and only the spending families draw a heading.
      expect(find.text(tr.budgetNewGestureFilterTag("Expenses")), findsOneWidget);
      expect(find.text(tr.budgetNewFamilyQuoteLabel), findsOneWidget);
      expect(find.text(tr.budgetNewFamilyCashMovementLabel), findsOneWidget);
      expect(find.text(tr.budgetNewFamilyFinancingPlanLabel), findsNothing);
      expect(find.text(tr.budgetNewFamilyRevenueSharingLabel), findsNothing);

      // A bringing-in gesture is withheld; a spending one is offered.
      expect(find.text(tr.budgetNewGestureRecordFinancingReceiptLabel), findsNothing);
      expect(find.text(tr.budgetNewGestureRecordExpenseLabel), findsOneWidget);
    });

    testWidgets("Show all lifts the filter and reveals every family, tag gone", (tester) async {
      final tr = await pumpDialog(
        tester,
        promotedFamily: OcptBudgetGestureFamily.quote,
        allowedGestures: spends,
        filterLabel: "Expenses",
        initialGesture: OcptBudgetGesture.addQuoteLine,
      );

      expect(find.text(tr.budgetNewFamilyRevenueSharingLabel), findsNothing);

      await tester.tap(find.byKey(const Key("ocptBudgetNewShowAllGesturesButton")));
      await tester.pumpAndSettle();

      expect(find.text(tr.budgetNewFamilyRevenueSharingLabel), findsOneWidget);
      expect(find.text(tr.budgetNewFamilyFinancingPlanLabel), findsOneWidget);
      expect(find.byKey(const Key("ocptBudgetNewShowAllGesturesButton")), findsNothing);
    });

    testWidgets("with no filter every family is shown and no tag is drawn", (tester) async {
      final tr = await pumpDialog(tester);

      expect(find.byKey(const Key("ocptBudgetNewShowAllGesturesButton")), findsNothing);
      expect(find.text(tr.budgetNewFamilyRevenueSharingLabel), findsOneWidget);
      expect(find.text(tr.budgetNewFamilyFinancingPlanLabel), findsOneWidget);
    });
  });

  group("the step counter always tells the truth", () {
    testWidgets("reads sur 2 for a gesture that attaches to nothing", (tester) async {
      final tr = await pumpDialog(tester, initialGesture: OcptBudgetGesture.planTaking);

      expect(
        ocptBudgetGestureStepCountOf(OcptBudgetGesture.planTaking),
        2,
        reason: "planTaking attaches to nothing",
      );
      expect(find.text(tr.budgetNewStepLabel(1, 2)), findsOneWidget);

      await tester.tap(find.byKey(const Key("ocptBudgetNewContinueButton")));
      await tester.pumpAndSettle();

      // Straight to the form — no attachment step for a gesture with nothing to attach to.
      expect(find.text(tr.budgetNewStepLabel(2, 2)), findsOneWidget);
    });

    testWidgets("reads sur 3 for a gesture that attaches to something", (tester) async {
      final tr = await pumpDialog(
        tester,
        initialGesture: OcptBudgetGesture.recordExpense,
        postes: [testPoste(id: "p1", label: "Camera")],
      );

      expect(find.text(tr.budgetNewStepLabel(1, 3)), findsOneWidget);

      await tester.tap(find.byKey(const Key("ocptBudgetNewContinueButton")));
      await tester.pumpAndSettle();
      expect(find.text(tr.budgetNewStepLabel(2, 3)), findsOneWidget);

      await tester.tap(find.byKey(const Key("ocptBudgetNewOffQuoteChoice")));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key("ocptBudgetNewAttachmentContinueButton")));
      await tester.pumpAndSettle();
      expect(find.text(tr.budgetNewStepLabel(3, 3)), findsOneWidget);
    });
  });

  testWidgets("the current route's own document is promoted to the top of step 1", (tester) async {
    final tr = await pumpDialog(tester, promotedFamily: OcptBudgetGestureFamily.allowances);

    final allowancesY = tester.getTopLeft(find.text(tr.budgetNewFamilyAllowancesLabel)).dy;
    final quoteY = tester.getTopLeft(find.text(tr.budgetNewFamilyQuoteLabel)).dy;

    // `allowances` is not the natural first family (`quote` is), so its own heading sitting
    // above `quote`'s own proves the promotion moved it, rather than it already being first.
    expect(allowancesY, lessThan(quoteY));
  });

  testWidgets("Retour preserves both the attachment already answered and what step 3 held", (
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

    await tester.enterText(find.byKey(const Key("ocptBudgetNewLabelField")), "Rushes");
    await tester.tap(find.byKey(const Key("ocptBudgetNewFormBackButton")));
    await tester.pumpAndSettle();

    // Back on step 2: the poste answered before is still answered, `Continuer` needs no further
    // tap to be enabled.
    final continueButton = tester.widget<FilledButton>(
      find.byKey(const Key("ocptBudgetNewAttachmentContinueButton")),
    );
    expect(continueButton.onPressed, isNotNull);

    await tester.tap(find.byKey(const Key("ocptBudgetNewAttachmentContinueButton")));
    await tester.pumpAndSettle();

    // Forward again on step 3: what was typed before Retour is still there.
    expect(find.text("Rushes"), findsOneWidget);
  });

  testWidgets(
    "step 2's own trailing row creates a missing financing resource without leaving the wizard",
    (tester) async {
      await pumpDialog(tester, initialGesture: OcptBudgetGesture.recordFinancingReceipt);

      await tester.tap(find.byKey(const Key("ocptBudgetNewContinueButton")));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key("ocptBudgetNewCreateResourceChoice")));
      await tester.pumpAndSettle();

      expect(find.byType(OcptBudgetResourceDialog), findsOneWidget);
    },
  );

  group("an in-kind contribution is reachable", () {
    testWidgets("planContribution's own step 3 offers cash and in-kind, not subsidy", (
      tester,
    ) async {
      final tr = await pumpDialog(
        tester,
        initialGesture: OcptBudgetGesture.planContribution,
        postes: [testPoste(id: "p1", label: "Camera")],
      );

      // planContribution attaches to nothing, so step 1 (with the gesture already pre-selected)
      // still has to be confirmed before step 3's own form draws.
      await tester.tap(find.byKey(const Key("ocptBudgetNewContinueButton")));
      await tester.pumpAndSettle();

      expect(find.text(tr.budgetFinancingGroupSubsidyLabel), findsNothing);
      expect(find.text(tr.budgetFinancingGroupCashLabel), findsOneWidget);
      expect(find.text(tr.budgetFinancingGroupInKindLabel), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), "Camera lent");
      await tester.tap(find.text(tr.budgetFinancingGroupInKindLabel));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(1), "500");
      await tester.pumpAndSettle();

      // Toggling into in-kind has drawn the `Poste` picker, now required before `Save` succeeds.
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Camera").last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key("ocptBudgetNewSaveButton")));
      await tester.pumpAndSettle();

      final outcome = routerManager.poppedValue! as OcptBudgetNewResourceOutcome;
      expect(outcome.fields.groupKind, OcptBudgetResourceGroupKind.inKind);
      expect(outcome.fields.posteId, "p1");
    });

    testWidgets(
      "step 2's own trailing create-resource row offers cash and in-kind too, not subsidy",
      (tester) async {
        await pumpDialog(tester, initialGesture: OcptBudgetGesture.recordFinancingReceipt);

        await tester.tap(find.byKey(const Key("ocptBudgetNewContinueButton")));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key("ocptBudgetNewCreateResourceChoice")));
        await tester.pumpAndSettle();

        final tr = Tr.of(tester.element(find.byType(OcptBudgetResourceDialog)));
        expect(find.text(tr.budgetFinancingGroupSubsidyLabel), findsNothing);
        expect(find.text(tr.budgetFinancingGroupCashLabel), findsOneWidget);
        expect(find.text(tr.budgetFinancingGroupInKindLabel), findsOneWidget);
      },
    );
  });

  testWidgets("commitSpend's own step 3 does not ask the poste a second time", (tester) async {
    final tr = await pumpDialog(
      tester,
      initialGesture: OcptBudgetGesture.commitSpend,
      postes: [testPoste(id: "p1", label: "Camera")],
    );

    await tester.tap(find.byKey(const Key("ocptBudgetNewContinueButton")));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Camera"));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key("ocptBudgetNewNoLineChoice")));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key("ocptBudgetNewAttachmentContinueButton")));
    await tester.pumpAndSettle();

    // Step 2 already answered which poste this commitment prices — asking again on step 3 would
    // be the very redundancy this wizard exists to remove.
    expect(find.text(tr.budgetEntryDialogPosteFieldLabel), findsNothing);
  });

  group("the breakdown selector counts out loud", () {
    testWidgets("its own button names how many lines it will create", (tester) async {
      final tr = await pumpDialog(
        tester,
        initialGesture: OcptBudgetGesture.addQuoteLinesFromBreakdown,
        postes: [testPoste(id: "p1", label: "Set dressing")],
        unpricedElements: [
          _element(id: "e1", name: "Vintage phone", sceneCount: 3),
          _element(id: "e2", name: "Rostrum", sceneCount: 2),
        ],
      );

      // The breakdown gesture no longer asks a poste up front: Continue lands straight on the
      // selector, where a poste is picked per element instead.
      await tester.tap(find.byKey(const Key("ocptBudgetNewContinueButton")));
      await tester.pumpAndSettle();

      // Nothing picked yet: the button is withheld (disabled), never invites a click that would
      // create zero lines.
      var createButton = tester.widget<FilledButton>(
        find.byKey(const Key("ocptBudgetNewCreateLinesButton")),
      );
      expect(createButton.onPressed, isNull);

      await tester.tap(find.byKey(const Key("ocptBudgetNewBreakdownCheckbox-e1")));
      await tester.pumpAndSettle();
      expect(find.text(tr.budgetNewCreateLinesAction(1)), findsOneWidget);

      await tester.tap(find.byKey(const Key("ocptBudgetNewBreakdownCheckbox-e2")));
      await tester.pumpAndSettle();
      expect(find.text(tr.budgetNewCreateLinesAction(2)), findsOneWidget);

      // Checked, but filed under no poste yet: the button stays withheld until every row resolves
      // one.
      createButton = tester.widget<FilledButton>(
        find.byKey(const Key("ocptBudgetNewCreateLinesButton")),
      );
      expect(createButton.onPressed, isNull);

      // `File all under` files every checked row under the one poste at once.
      await tester.tap(find.byKey(const Key("ocptBudgetNewBreakdownSetAllPoste")));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Set dressing").last);
      await tester.pumpAndSettle();

      createButton = tester.widget<FilledButton>(
        find.byKey(const Key("ocptBudgetNewCreateLinesButton")),
      );
      expect(createButton.onPressed, isNotNull);

      await tester.tap(find.byKey(const Key("ocptBudgetNewCreateLinesButton")));
      await tester.pumpAndSettle();

      final outcome = routerManager.poppedValue! as OcptBudgetNewLinesFromBreakdownOutcome;
      expect(outcome.lines, hasLength(2));
      // Every line was filed under the poste `File all under` named.
      expect(outcome.lines.every((line) => line.posteId == "p1"), isTrue);
      // The suggested quantity is the scene count, in thousandths — a suggestion, corrected
      // nowhere in this test, but read back verbatim here.
      expect(outcome.lines.firstWhere((line) => line.elementId == "e1").quantityMilli, 3000);
    });

    testWidgets("files each element under the poste chosen for its own row", (tester) async {
      await pumpDialog(
        tester,
        initialGesture: OcptBudgetGesture.addQuoteLinesFromBreakdown,
        postes: [
          testPoste(id: "p1", label: "Set dressing"),
          testPoste(id: "p2", label: "Transport"),
        ],
        unpricedElements: [
          _element(id: "e1", name: "Vintage phone", sceneCount: 3),
          _element(id: "e2", name: "Rostrum", sceneCount: 2),
        ],
      );

      await tester.tap(find.byKey(const Key("ocptBudgetNewContinueButton")));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key("ocptBudgetNewBreakdownCheckbox-e1")));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key("ocptBudgetNewBreakdownCheckbox-e2")));
      await tester.pumpAndSettle();

      // e1 goes to Set dressing, e2 to Transport — two elements of one selection, two postes.
      await tester.tap(find.byKey(const Key("ocptBudgetNewBreakdownPoste-e1")));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Set dressing").last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key("ocptBudgetNewBreakdownPoste-e2")));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Transport").last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key("ocptBudgetNewCreateLinesButton")));
      await tester.pumpAndSettle();

      final outcome = routerManager.poppedValue! as OcptBudgetNewLinesFromBreakdownOutcome;
      expect(outcome.lines.firstWhere((line) => line.elementId == "e1").posteId, "p1");
      expect(outcome.lines.firstWhere((line) => line.elementId == "e2").posteId, "p2");
    });
  });

  group("the lettrage strip", () {
    testWidgets("offers every ranked candidate, not only the first, and Aucun besides", (
      tester,
    ) async {
      await pumpDialog(
        tester,
        initialGesture: OcptBudgetGesture.recordExpense,
        postes: [testPoste(id: "p1", label: "Camera")],
        commitments: [
          _commitment(id: "c1", label: "Atelier Verrier", posteId: "p1", amountCents: 25000),
          _commitment(id: "c2", label: "Atelier Verrier bis", posteId: "p1", amountCents: 25000),
        ],
      );

      await tester.tap(find.byKey(const Key("ocptBudgetNewContinueButton")));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key("ocptBudgetNewOffQuoteChoice")));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key("ocptBudgetNewAttachmentContinueButton")));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key("ocptBudgetNewLabelField")), "Atelier Verrier");
      await tester.enterText(find.byKey(const Key("ocptBudgetNewAmountField")), "250.00");
      await tester.pumpAndSettle();

      // Both commitments match on amount; the second is reachable too, not just the top one.
      expect(find.byKey(const Key("ocptBudgetNewLettrageCandidate0")), findsOneWidget);
      expect(find.byKey(const Key("ocptBudgetNewLettrageCandidate1")), findsOneWidget);
      expect(find.byKey(const Key("ocptBudgetNewLettrageNone")), findsOneWidget);

      // Picking the second candidate, then saving, settles that one rather than the first —
      // proposing without letting a reader pick a different one would be silent, not honest.
      final secondCandidate = find.byKey(const Key("ocptBudgetNewLettrageCandidate1"));
      await tester.ensureVisible(secondCandidate);
      await tester.pumpAndSettle();
      await tester.tap(secondCandidate);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key("ocptBudgetNewSaveButton")));
      await tester.pumpAndSettle();

      final outcome = routerManager.poppedValue! as OcptBudgetEntryWizardResult;
      expect(outcome.acceptedSuggestion?.candidateId, "c2");
    });

    testWidgets("Aucun is a real answer — saving with it accepts no suggestion at all", (
      tester,
    ) async {
      await pumpDialog(
        tester,
        initialGesture: OcptBudgetGesture.recordExpense,
        postes: [testPoste(id: "p1", label: "Camera")],
        commitments: [
          _commitment(id: "c1", label: "Atelier Verrier", posteId: "p1", amountCents: 25000),
        ],
      );

      await tester.tap(find.byKey(const Key("ocptBudgetNewContinueButton")));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key("ocptBudgetNewOffQuoteChoice")));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key("ocptBudgetNewAttachmentContinueButton")));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key("ocptBudgetNewLabelField")), "Atelier Verrier");
      await tester.enterText(find.byKey(const Key("ocptBudgetNewAmountField")), "250.00");
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key("ocptBudgetNewLettrageNone")));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key("ocptBudgetNewSaveButton")));
      await tester.pumpAndSettle();

      final outcome = routerManager.poppedValue! as OcptBudgetEntryWizardResult;
      expect(outcome.acceptedSuggestion, isNull);
    });

    testWidgets("nothing is pre-selected: saving untouched reconciles against no one", (
      tester,
    ) async {
      await pumpDialog(
        tester,
        initialGesture: OcptBudgetGesture.recordExpense,
        postes: [testPoste(id: "p1", label: "Camera")],
        commitments: [
          _commitment(id: "c1", label: "Atelier Verrier", posteId: "p1", amountCents: 25000),
        ],
      );

      await tester.tap(find.byKey(const Key("ocptBudgetNewContinueButton")));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key("ocptBudgetNewOffQuoteChoice")));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key("ocptBudgetNewAttachmentContinueButton")));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key("ocptBudgetNewLabelField")), "Atelier Verrier");
      await tester.enterText(find.byKey(const Key("ocptBudgetNewAmountField")), "250.00");
      await tester.pumpAndSettle();

      // A same-amount candidate is on offer, but reconciliation is opt-in — saving without
      // touching the strip records the movement as its own gesture says, settling no one.
      expect(find.byKey(const Key("ocptBudgetNewLettrageCandidate0")), findsOneWidget);
      await tester.tap(find.byKey(const Key("ocptBudgetNewSaveButton")));
      await tester.pumpAndSettle();

      final outcome = routerManager.poppedValue! as OcptBudgetEntryWizardResult;
      expect(outcome.acceptedSuggestion, isNull);
    });

    testWidgets("offersLettrage false withholds the strip even where a candidate would match", (
      tester,
    ) async {
      // The direct pay of a quote line opens the wizard exactly this way — pre-filled on step 3
      // with the line's own label and amount, offersLettrage off. A commitment sharing that
      // amount would ordinarily be offered; here the strip is withheld whole.
      final prefill = OcptBudgetEntryFormFields(
        date: DateTime(2026, 1, 5),
        label: "Atelier Verrier",
        posteId: "p1",
        resourceId: null,
        revenueId: null,
        shareId: null,
        isDebit: true,
        amountCents: 25000,
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
        offersLettrage: false,
        postes: [testPoste(id: "p1", label: "Camera")],
        commitments: [
          _commitment(id: "c1", label: "Atelier Verrier", posteId: "p1", amountCents: 25000),
        ],
      );

      // Landed on the form with the matching amount typed, yet no strip and no candidate row.
      expect(find.text(tr.budgetNewLettrageTitle), findsNothing);
      expect(find.byKey(const Key("ocptBudgetNewLettrageCandidate0")), findsNothing);
      expect(find.byKey(const Key("ocptBudgetNewLettrageNone")), findsNothing);
    });
  });

  group("the dashboard's own case", () {
    testWidgets("nothing is pre-selected and Continuer is withheld until a card is picked", (
      tester,
    ) async {
      await pumpDialog(tester);

      var continueButton = tester.widget<FilledButton>(
        find.byKey(const Key("ocptBudgetNewContinueButton")),
      );
      expect(continueButton.onPressed, isNull);

      final card = find.byKey(Key("ocptBudgetNewGestureCard-${OcptBudgetGesture.planTaking.name}"));
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();

      continueButton = tester.widget<FilledButton>(
        find.byKey(const Key("ocptBudgetNewContinueButton")),
      );
      expect(continueButton.onPressed, isNotNull);
    });
  });
}
