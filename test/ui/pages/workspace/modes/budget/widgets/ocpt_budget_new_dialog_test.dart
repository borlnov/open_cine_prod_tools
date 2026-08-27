// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_new_outcome.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';
import 'package:open_cine_prod_tools/models/ocpt_scene_element_link.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_gesture.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_new_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_resource_dialog.dart';

/// A router manager whose [pop] only records the last call and its value — mirrors
/// `ocpt_budget_entry_dialog_test.dart`'s own instance of this pattern.
class _RecordingRouterManager extends OcptRouterManager {
  bool popped = false;
  Object? poppedValue;

  @override
  void pop<Y extends Object?>([Y? result]) {
    popped = true;
    poppedValue = result;
  }
}

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve in tests.
Widget _wrap(Widget child) => MaterialApp(
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
  });

  /// Pumps [OcptBudgetNewDialog] directly (no `.show`).
  Future<Tr> pumpDialog(
    WidgetTester tester, {
    OcptBudgetGestureFamily? promotedFamily,
    OcptBudgetGesture? initialGesture,
    List<OcptBudgetPoste> postes = const [],
    List<OcptBudgetCommitment> commitments = const [],
    List<OcptElement> unpricedElements = const [],
  }) async {
    await tester.pumpWidget(
      _wrap(
        OcptBudgetNewDialog(
          promotedFamily: promotedFamily,
          initialGesture: initialGesture,
          postes: postes,
          resources: const [],
          revenues: const [],
          shares: const [],
          people: const [],
          unpricedElements: unpricedElements,
          commitments: commitments,
          entries: const [],
          allowances: const [],
          mileageRates: const [],
          receivedByResourceId: const {},
          receivedByRevenueId: const {},
          currencyCode: "EUR",
          defaultVatRateBasisPoints: null,
          isSimplified: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    return Tr.of(tester.element(find.byType(OcptBudgetNewDialog)));
  }

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
        postes: [_poste(id: "p1", label: "Camera")],
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

  testWidgets("the current route's own document is promoted to the top of step 1", (
    tester,
  ) async {
    final tr = await pumpDialog(tester, promotedFamily: OcptBudgetGestureFamily.allowances);

    final allowancesY = tester
        .getTopLeft(find.text(tr.budgetNewFamilyAllowancesLabel))
        .dy;
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
      postes: [_poste(id: "p1", label: "Camera")],
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
      final tr = await pumpDialog(tester, initialGesture: OcptBudgetGesture.planContribution);

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

      await tester.tap(find.byKey(const Key("ocptBudgetNewSaveButton")));
      await tester.pumpAndSettle();

      final outcome = routerManager.poppedValue! as OcptBudgetNewResourceOutcome;
      expect(outcome.fields.groupKind, OcptBudgetResourceGroupKind.inKind);
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
      postes: [_poste(id: "p1", label: "Camera")],
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
        postes: [_poste(id: "p1", label: "Set dressing")],
        unpricedElements: [
          _element(id: "e1", name: "Vintage phone", sceneCount: 3),
          _element(id: "e2", name: "Rostrum", sceneCount: 2),
        ],
      );

      await tester.tap(find.byKey(const Key("ocptBudgetNewContinueButton")));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Set dressing"));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key("ocptBudgetNewAttachmentContinueButton")));
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

      createButton = tester.widget<FilledButton>(
        find.byKey(const Key("ocptBudgetNewCreateLinesButton")),
      );
      expect(createButton.onPressed, isNotNull);

      await tester.tap(find.byKey(const Key("ocptBudgetNewCreateLinesButton")));
      await tester.pumpAndSettle();

      final outcome = routerManager.poppedValue! as OcptBudgetNewLinesFromBreakdownOutcome;
      expect(outcome.posteId, "p1");
      expect(outcome.lines, hasLength(2));
      // The suggested quantity is the scene count, in thousandths — a suggestion, corrected
      // nowhere in this test, but read back verbatim here.
      expect(
        outcome.lines.firstWhere((line) => line.elementId == "e1").quantityMilli,
        3000,
      );
    });
  });

  group("the lettrage strip", () {
    testWidgets("offers every ranked candidate, not only the first, and Aucun besides", (
      tester,
    ) async {
      await pumpDialog(
        tester,
        initialGesture: OcptBudgetGesture.recordExpense,
        postes: [_poste(id: "p1", label: "Camera")],
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

      await tester.enterText(
        find.byKey(const Key("ocptBudgetNewLabelField")),
        "Atelier Verrier",
      );
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
        postes: [_poste(id: "p1", label: "Camera")],
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

      await tester.enterText(
        find.byKey(const Key("ocptBudgetNewLabelField")),
        "Atelier Verrier",
      );
      await tester.enterText(find.byKey(const Key("ocptBudgetNewAmountField")), "250.00");
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key("ocptBudgetNewLettrageNone")));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key("ocptBudgetNewSaveButton")));
      await tester.pumpAndSettle();

      final outcome = routerManager.poppedValue! as OcptBudgetEntryWizardResult;
      expect(outcome.acceptedSuggestion, isNull);
    });
  });
}
