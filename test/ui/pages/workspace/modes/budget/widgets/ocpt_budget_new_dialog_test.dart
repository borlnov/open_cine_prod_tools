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
import 'package:open_cine_prod_tools/models/ocpt_scene_element_link.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_allowance_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_gesture.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_new_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_resource_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_share_dialog.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';

/// The navigator [_wrap] mounts, so [_RecordingRouterManager.pop] can close a dialog opened through
/// `showDialog` (step 2's own trailing create row) on top of the wizard itself — mirrors
/// `budget_mode_test.dart`'s own instance of this pattern.
final _navigatorKey = GlobalKey<NavigatorState>();

/// A router manager whose [pop] records the last call and its value — mirrors
/// `ocpt_budget_entry_dialog_test.dart`'s own instance of this pattern — **and** pops
/// [_navigatorKey]'s own navigator when there is a route left to pop, so a nested dialog's own
/// `Save` actually closes it and resolves the `Future` the wizard awaits it through. The wizard
/// itself is pumped as the app's home content rather than pushed as a route, so its own top-level
/// `pop` finds nothing left to pop and only records, exactly as every other test here already
/// relies on.
class _RecordingRouterManager extends OcptRouterManager {
  bool popped = false;
  Object? poppedValue;

  @override
  void pop<Y extends Object?>([Y? result]) {
    popped = true;
    poppedValue = result;

    final navigator = _navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop(result);
    }
  }
}

/// Wraps [child] with the localization delegates and [_navigatorKey] so [Tr.of] lookups resolve in
/// tests and a nested dialog can be popped.
Widget _wrap(Widget child) => MaterialApp(
  navigatorKey: _navigatorKey,
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: child,
);

/// A minimal poste, everything but [id]/[label]/[lines] neutral.
OcptBudgetPoste _poste({
  required String id,
  required String label,
  List<OcptBudgetLine> lines = const [],
}) => OcptBudgetPoste(
  id: id,
  code: "1",
  label: label,
  simpleLabel: null,
  estimateToCompleteCents: null,
  sortKey: "a0",
  lines: lines,
);

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
  unitPrice: OcptMoney(amountCents: unitAmountCents, isTaxInclusive: true, vatRateBasisPoints: null),
  elementId: null,
  provisionKey: null,
  provisionDigest: null,
  notes: "",
  sortKey: "a0",
);

/// A minimal financing resource, everything but [id]/[label]/[amountCents] neutral.
OcptBudgetResource _resource({required String id, required String label, int amountCents = 100000}) =>
    OcptBudgetResource(
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
    Set<OcptBudgetGesture>? allowedGestures,
    String? filterLabel,
    OcptBudgetGesture? initialGesture,
    OcptBudgetEntryFormFields? entryPrefill,
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
      _wrap(
        OcptBudgetNewDialog(
          promotedFamily: promotedFamily,
          allowedGestures: allowedGestures,
          filterLabel: filterLabel,
          initialGesture: initialGesture,
          entryPrefill: entryPrefill,
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
      expect(
        outcome.lines.firstWhere((line) => line.elementId == "e1").quantityMilli,
        3000,
      );
    });

    testWidgets("files each element under the poste chosen for its own row", (tester) async {
      await pumpDialog(
        tester,
        initialGesture: OcptBudgetGesture.addQuoteLinesFromBreakdown,
        postes: [
          _poste(id: "p1", label: "Set dressing"),
          _poste(id: "p2", label: "Transport"),
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

  group("the dashboard's own case", () {
    testWidgets(
      "nothing is pre-selected and Continuer is withheld until a card is picked",
      (tester) async {
        await pumpDialog(tester);

        var continueButton = tester.widget<FilledButton>(
          find.byKey(const Key("ocptBudgetNewContinueButton")),
        );
        expect(continueButton.onPressed, isNull);

        final card = find.byKey(
          Key("ocptBudgetNewGestureCard-${OcptBudgetGesture.planTaking.name}"),
        );
        await tester.ensureVisible(card);
        await tester.pumpAndSettle();
        await tester.tap(card);
        await tester.pumpAndSettle();

        continueButton = tester.widget<FilledButton>(
          find.byKey(const Key("ocptBudgetNewContinueButton")),
        );
        expect(continueButton.onPressed, isNotNull);
      },
    );
  });

  group("every outcome variant reaches the mode correctly", () {
    testWidgets(
      "addQuoteLine pops OcptBudgetNewLineOutcome naming the poste and the typing",
      (tester) async {
        final tr = await pumpDialog(
          tester,
          initialGesture: OcptBudgetGesture.addQuoteLine,
          postes: [_poste(id: "p1", label: "Camera")],
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
      },
    );

    testWidgets("commitSpend pops OcptBudgetNewCommitmentOutcome naming the line picked", (
      tester,
    ) async {
      await pumpDialog(
        tester,
        initialGesture: OcptBudgetGesture.commitSpend,
        postes: [
          _poste(
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

    testWidgets(
      "recordExpense with nothing to reconcile against pops a plain wizard result",
      (tester) async {
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

        await tester.enterText(
          find.byKey(const Key("ocptBudgetNewLabelField")),
          "Rushes hard drive",
        );
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
      },
    );
  });

  group("recording a taking mints its own from one amount and label", () {
    testWidgets("goes straight to the form and carries a to-be-made taking", (tester) async {
      final tr = await pumpDialog(
        tester,
        initialGesture: OcptBudgetGesture.recordTakingReceipt,
      );

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
    testWidgets(
      "a missing participant is created inline, without leaving the wizard",
      (tester) async {
        tester.view.physicalSize = const Size(900, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final tr = await pumpDialog(
          tester,
          initialGesture: OcptBudgetGesture.payParticipantShare,
        );

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
      },
    );
  });

  group("step 2's own escape answers", () {
    testWidgets("recordExpense's own Hors devis answer leaves the poste unset", (tester) async {
      await pumpDialog(
        tester,
        initialGesture: OcptBudgetGesture.recordExpense,
        postes: [_poste(id: "p1", label: "Camera")],
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

    testWidgets(
      "commitSpend's own Aucune answer hangs the commitment off the poste, no line",
      (tester) async {
        final tr = await pumpDialog(
          tester,
          initialGesture: OcptBudgetGesture.commitSpend,
          postes: [
            _poste(
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
      },
    );
  });

  testWidgets(
    "step 2's own resource row states what is promised, received and outstanding",
    (tester) async {
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
    },
  );

  testWidgets(
    "step 2's own person row states what is advanced, reimbursed and owed",
    (tester) async {
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
    },
  );

  testWidgets(
    "a contextual shortcut lands directly on the form, trail intact, step counter honest",
    (tester) async {
      final poste = _poste(id: "p1", label: "Camera");
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
      // The trail recalls the poste step 2 would have asked, and still offers a way back to it.
      expect(find.textContaining("Camera"), findsWidgets);
      expect(find.byKey(const Key("ocptBudgetNewChangeGestureLink")), findsOneWidget);
      // The form itself opened pre-filled, not blank.
      expect(find.text("Zoom lens repair"), findsOneWidget);
    },
  );
}
