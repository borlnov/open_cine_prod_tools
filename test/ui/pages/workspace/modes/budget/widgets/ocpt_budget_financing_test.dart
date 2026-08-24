// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_revenue_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_selection.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financing.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a wide, tall
/// enough band that the whole tree, the footer and the coverage band lay out with no scroll needed
/// to find a cell.
Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 1400, height: 900, child: child)),
);

/// A minimal financing resource, everything but what each test actually varies neutral.
OcptBudgetResource _resource({
  required String id,
  OcptBudgetResourceGroupKind groupKind = OcptBudgetResourceGroupKind.subsidy,
  String label = "Resource",
  int amountCents = 10000,
  OcptBudgetResourceStatus status = OcptBudgetResourceStatus.pending,
  String notes = "",
}) => OcptBudgetResource(
  id: id,
  groupKind: groupKind,
  personId: null,
  label: label,
  amountCents: amountCents,
  status: status,
  isReimbursable: false,
  notes: notes,
  sortKey: "a0",
);

/// A minimal taking, everything but what each test actually varies neutral.
OcptBudgetRevenue _revenue({
  required String id,
  String label = "Festival prize",
  int amountCents = 10000,
  OcptBudgetRevenueStatus status = OcptBudgetRevenueStatus.expected,
  String notes = "",
}) => OcptBudgetRevenue(
  id: id,
  date: DateTime(2026, 3),
  label: label,
  amountCents: amountCents,
  status: status,
  notes: notes,
  sortKey: "a0",
);

/// A minimal journal entry, credited by default — a receipt naming [resourceId] or [revenueId].
OcptBudgetEntry _entry({
  required String id,
  String? resourceId,
  String? revenueId,
  int creditCents = 1000,
  String label = "Wire transfer",
}) => OcptBudgetEntry(
  id: id,
  date: DateTime(2026, 4),
  label: label,
  posteId: null,
  debitCents: 0,
  creditCents: creditCents,
  isTaxInclusive: true,
  vatRateBasisPoints: null,
  voucherNumber: "J-001",
  sortKey: "a0",
  resourceId: resourceId,
  revenueId: revenueId,
  shareId: null,
);

/// A poste priced at [amountCents], tax-inclusive — read tax-inclusive always by the coverage
/// band's own `needs` reading, so no VAT rate is needed for it to read as complete.
OcptBudgetPoste _poste({required String id, int amountCents = 100000}) => OcptBudgetPoste(
  id: id,
  code: "1",
  label: "Technical equipment",
  simpleLabel: null,
  estimateToCompleteCents: null,
  sortKey: "a0",
  lines: [
    OcptBudgetLine(
      id: "$id-line",
      posteId: id,
      label: "",
      quantityMilli: 1000,
      unit: "u",
      unitPrice: OcptMoney(amountCents: amountCents, isTaxInclusive: true, vatRateBasisPoints: null),
      elementId: null,
      provisionKey: null,
      provisionDigest: null,
      notes: "",
      sortKey: "a0",
    ),
  ],
);

void main() {
  /// Pumps [OcptBudgetFinancing] with every callback a no-op unless overridden.
  Future<void> pumpView(
    WidgetTester tester, {
    List<OcptBudgetResource> resources = const [],
    List<OcptBudgetRevenue> revenues = const [],
    List<OcptBudgetEntry> entries = const [],
    List<OcptBudgetPoste> postes = const [],
    Map<String, OcptBudgetCoveredTotal> receivedByResourceId = const {},
    int Function(String resourceId)? receivedCentsOf,
    Map<String, OcptBudgetCoveredTotal> receivedByRevenueId = const {},
    OcptBudgetSelection? selection,
    Set<String> expandedNodeIds = const {},
    bool isReadOnly = false,
    ValueChanged<String>? onNodeExpansionToggled,
    ValueChanged<OcptBudgetResourceGroupKind>? onResourceCreationRequested,
    ValueChanged<String>? onResourceSelected,
    ValueChanged<OcptBudgetResource>? onResourceEditRequested,
    ValueChanged<OcptBudgetResource>? onResourceReceiptRequested,
    ValueChanged<OcptBudgetResource>? onResourceReceiptUndoRequested,
    ValueChanged<String>? onResourceDeletionRequested,
    VoidCallback? onRevenueCreationRequested,
    ValueChanged<String>? onRevenueSelected,
    ValueChanged<OcptBudgetRevenue>? onRevenueEditRequested,
    ValueChanged<OcptBudgetRevenue>? onRevenueReceiptRequested,
    void Function(String revenueId, {required bool moveUp})? onRevenueReorderRequested,
    ValueChanged<String>? onRevenueDeletionRequested,
    ValueChanged<String>? onReceiptSelected,
    VoidCallback? onExpensesRequested,
  }) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrap(
        OcptBudgetFinancing(
          resources: resources,
          revenues: revenues,
          entries: entries,
          postes: postes,
          defaultVatRateBasisPoints: null,
          receivedByResourceId: receivedByResourceId,
          receivedCentsOf: receivedCentsOf ?? (id) => receivedByResourceId[id]?.amountCents ?? 0,
          receivedByRevenueId: receivedByRevenueId,
          currencyCode: "EUR",
          selection: selection,
          expandedNodeIds: expandedNodeIds,
          isReadOnly: isReadOnly,
          onNodeExpansionToggled: onNodeExpansionToggled ?? (_) {},
          onResourceCreationRequested: onResourceCreationRequested ?? (_) {},
          onResourceSelected: onResourceSelected ?? (_) {},
          onResourceEditRequested: onResourceEditRequested ?? (_) {},
          onResourceReceiptRequested: onResourceReceiptRequested ?? (_) {},
          onResourceReceiptUndoRequested: onResourceReceiptUndoRequested ?? (_) {},
          onResourceDeletionRequested: onResourceDeletionRequested ?? (_) {},
          onRevenueCreationRequested: onRevenueCreationRequested ?? () {},
          onRevenueSelected: onRevenueSelected ?? (_) {},
          onRevenueEditRequested: onRevenueEditRequested ?? (_) {},
          onRevenueReceiptRequested: onRevenueReceiptRequested ?? (_) {},
          onRevenueReorderRequested: onRevenueReorderRequested ?? (_, {required moveUp}) {},
          onRevenueDeletionRequested: onRevenueDeletionRequested ?? (_) {},
          onReceiptSelected: onReceiptSelected ?? (_) {},
          onExpensesRequested: onExpensesRequested ?? () {},
        ),
      ),
    );
  }

  testWidgets("a project holding neither a resource nor a taking shows the empty state, with the "
      "column header and the creation footer still drawn", (tester) async {
    await pumpView(tester);

    final tr = Tr.of(tester.element(find.byType(OcptBudgetFinancing)));
    expect(find.byType(OcptWorkspaceEmptyMode), findsOneWidget);
    expect(find.text(tr.budgetFinancingColumnLabel.toUpperCase()), findsOneWidget);
    expect(find.text(tr.budgetFinancingCreationAction), findsOneWidget);
  });

  testWidgets("the three families draw in order, an empty family drawn not at all", (tester) async {
    await pumpView(
      tester,
      resources: [_resource(id: "r1"), _resource(id: "r2", groupKind: OcptBudgetResourceGroupKind.cash)],
      revenues: [_revenue(id: "v1")],
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetFinancing)));
    final subsidiesY = tester.getTopLeft(find.text(tr.budgetFinancingFamilySubsidiesLabel)).dy;
    final contributionsY = tester.getTopLeft(find.text(tr.budgetFinancingFamilyContributionsLabel)).dy;
    final takingsY = tester.getTopLeft(find.text(tr.budgetFinancingFamilyTakingsLabel)).dy;

    expect(subsidiesY, lessThan(contributionsY));
    expect(contributionsY, lessThan(takingsY));
  });

  testWidgets("an empty family draws no row at all", (tester) async {
    await pumpView(tester, resources: [_resource(id: "r1")]);

    final tr = Tr.of(tester.element(find.byType(OcptBudgetFinancing)));
    expect(find.text(tr.budgetFinancingFamilySubsidiesLabel), findsOneWidget);
    expect(find.text(tr.budgetFinancingFamilyContributionsLabel), findsNothing);
    expect(find.text(tr.budgetFinancingFamilyTakingsLabel), findsNothing);
  });

  testWidgets("a family's own aggregates sum its rows, known figures only", (tester) async {
    final resources = [
      _resource(id: "r1", groupKind: OcptBudgetResourceGroupKind.cash),
      _resource(id: "r2", groupKind: OcptBudgetResourceGroupKind.inKind, amountCents: 5000),
    ];

    await pumpView(
      tester,
      resources: resources,
      // Only r1 has anything received against it — r2 is in-kind and no entry names it, so its own
      // Rentré is null and must not turn the family's own sum into a smaller wrong figure.
      receivedByResourceId: {
        "r1": const OcptBudgetCoveredTotal(amountCents: 4000, coveredLineCount: 1, lineCount: 1),
      },
      expandedNodeIds: const {"contributions"},
    );

    // Promised: 10000 + 5000 = 15000. Received: 4000 (r2's own unknown figure excluded, not
    // zeroed). Outstanding: 6000 (10000 - 4000), r2's own excluded the same way. `Contributions`
    // being the only live family here, its own row and the total row beneath it read the very
    // same three figures, so each is found (at least) once rather than exactly once.
    expect(find.text(ocptBudgetAmountLabel(15000, "EUR")), findsWidgets);
    expect(find.text(ocptBudgetAmountLabel(4000, "EUR")), findsWidgets);
    expect(find.text(ocptBudgetAmountLabel(6000, "EUR")), findsWidgets);
  });

  testWidgets("expanding a family reveals its own resources; one with no receipt draws no twisty", (
    tester,
  ) async {
    final resource = _resource(id: "r1", label: "Regional grant");

    await pumpView(tester, resources: [resource]);
    expect(find.text("Regional grant"), findsNothing);

    await pumpView(tester, resources: [resource], expandedNodeIds: const {"subsidies"});
    expect(find.text("Regional grant"), findsOneWidget);
    // The family's own twisty points down; the resource has no receipt to expand onto, so there
    // is exactly one twisty on screen.
    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_right), findsNothing);
  });

  testWidgets("expanding a resource reveals its own receipts, collapsing hides them again", (
    tester,
  ) async {
    final resource = _resource(id: "r1", label: "Regional grant");
    final receipt = _entry(id: "e1", resourceId: "r1", creditCents: 4000, label: "First instalment");

    await pumpView(
      tester,
      resources: [resource],
      entries: [receipt],
      expandedNodeIds: const {"subsidies"},
    );
    expect(find.textContaining("First instalment"), findsNothing);

    await pumpView(
      tester,
      resources: [resource],
      entries: [receipt],
      expandedNodeIds: const {"subsidies", "r1"},
    );
    expect(find.textContaining("First instalment"), findsOneWidget);

    await pumpView(
      tester,
      resources: [resource],
      entries: [receipt],
      expandedNodeIds: const {"subsidies"},
    );
    expect(find.textContaining("First instalment"), findsNothing);
  });

  testWidgets(
    "an in-kind resource with no entry naming it reads em dashes on Rentré and Reste à venir",
    (tester) async {
      final resource = _resource(
        id: "r1",
        groupKind: OcptBudgetResourceGroupKind.inKind,
        amountCents: 5000,
      );

      await pumpView(tester, resources: [resource], expandedNodeIds: const {"contributions"});

      expect(find.text(ocptBudgetEmptyValue), findsWidgets);
    },
  );

  testWidgets("the same in-kind resource reads real figures once an entry names it, zero included", (
    tester,
  ) async {
    final resource = _resource(id: "r1", groupKind: OcptBudgetResourceGroupKind.inKind, amountCents: 5000);

    await pumpView(
      tester,
      resources: [resource],
      receivedByResourceId: {
        "r1": const OcptBudgetCoveredTotal(amountCents: 0, coveredLineCount: 1, lineCount: 1),
      },
      expandedNodeIds: const {"contributions"},
    );

    expect(find.text(ocptBudgetAmountLabel(0, "EUR")), findsWidgets);
    expect(find.text(ocptBudgetAmountLabel(5000, "EUR")), findsWidgets);
  });

  testWidgets("the Dossier badge reads the shipped word for a resource's own group", (tester) async {
    final resource = _resource(
      id: "r1",
      status: OcptBudgetResourceStatus.agreed,
    );

    await pumpView(tester, resources: [resource], expandedNodeIds: const {"subsidies"});

    final tr = Tr.of(tester.element(find.byType(OcptBudgetFinancing)));
    expect(find.text(tr.budgetFinancingStatusSubsidyAgreedLabel), findsOneWidget);
  });

  testWidgets("the Dossier badge reads the shipped word for a taking", (tester) async {
    final revenue = _revenue(id: "v1", status: OcptBudgetRevenueStatus.confirmed);

    await pumpView(tester, revenues: [revenue], expandedNodeIds: const {"takings"});

    final tr = Tr.of(tester.element(find.byType(OcptBudgetFinancing)));
    expect(find.text(ocptBudgetRevenueStatusLabel(tr, revenue.status)), findsOneWidget);
  });

  testWidgets("the total row states the family count and the three totals", (tester) async {
    await pumpView(
      tester,
      resources: [_resource(id: "r1"), _resource(id: "r2", groupKind: OcptBudgetResourceGroupKind.cash, amountCents: 5000)],
      revenues: [_revenue(id: "v1", amountCents: 2000)],
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetFinancing)));
    // Three families are drawn: subsidies, contributions, takings.
    expect(find.text(tr.budgetFinancingTotalRowLabel(3)), findsOneWidget);
    expect(find.text(ocptBudgetAmountLabel(17000, "EUR")), findsOneWidget);
  });

  testWidgets("the total row's own valued caption shows while the project holds an in-kind resource", (
    tester,
  ) async {
    await pumpView(
      tester,
      resources: [_resource(id: "r1", groupKind: OcptBudgetResourceGroupKind.inKind, amountCents: 3000)],
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetFinancing)));
    expect(find.text(tr.budgetFinancingValuedCaption(ocptBudgetAmountLabel(3000, "EUR"))), findsOneWidget);
  });

  testWidgets("the valued caption is absent while the project holds no in-kind resource", (tester) async {
    await pumpView(tester, resources: [_resource(id: "r1")]);

    // "valued" (lower case) appears in no other financing string — `Valued` (the in-kind status
    // word) is capitalised — so its absence here is the caption's own.
    expect(find.textContaining("valued"), findsNothing);
  });

  testWidgets("the creation footer offers all four gestures", (tester) async {
    OcptBudgetResourceGroupKind? pickedKind;
    var revenuePicked = false;

    await pumpView(
      tester,
      onResourceCreationRequested: (kind) => pickedKind = kind,
      onRevenueCreationRequested: () => revenuePicked = true,
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetFinancing)));
    await tester.tap(find.text(tr.budgetFinancingCreationAction));
    await tester.pumpAndSettle();

    expect(find.text(tr.budgetFinancingAddSubsidyAction), findsOneWidget);
    expect(find.text(tr.budgetFinancingAddCashAction), findsOneWidget);
    expect(find.text(tr.budgetFinancingAddInKindAction), findsOneWidget);
    expect(find.text(tr.budgetFinancingAddRevenueAction), findsOneWidget);

    await tester.tap(find.text(tr.budgetFinancingAddRevenueAction));
    await tester.pumpAndSettle();
    expect(revenuePicked, isTrue);

    await tester.tap(find.text(tr.budgetFinancingCreationAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.budgetFinancingAddCashAction));
    await tester.pumpAndSettle();
    expect(pickedKind, OcptBudgetResourceGroupKind.cash);
  });

  testWidgets("the coverage band states what's received and promised, and how much is missing", (
    tester,
  ) async {
    await pumpView(
      tester,
      postes: [_poste(id: "p1")],
      resources: [_resource(id: "r1", amountCents: 40000)],
      receivedByResourceId: {
        "r1": const OcptBudgetCoveredTotal(amountCents: 30000, coveredLineCount: 1, lineCount: 1),
      },
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetFinancing)));
    expect(find.text(tr.budgetFinancingCoverageTitle.toUpperCase()), findsOneWidget);
    expect(find.text(ocptBudgetAmountLabel(100000, "EUR")), findsOneWidget);
    expect(
      find.textContaining(
        tr.budgetFinancingCoverageReadOut(
          ocptBudgetAmountLabel(30000, "EUR"),
          ocptBudgetAmountLabel(10000, "EUR"),
        ),
      ),
      findsOneWidget,
    );
    // Promised (40000) plus received already counted once — missing is 100000 - 40000 = 60000.
    expect(
      find.textContaining(tr.budgetFinancingCoverageMissingReadOut(ocptBudgetAmountLabel(60000, "EUR"))),
      findsOneWidget,
    );
  });

  testWidgets("the coverage band states the plan covers the quote once it does", (tester) async {
    await pumpView(
      tester,
      postes: [_poste(id: "p1", amountCents: 40000)],
      resources: [_resource(id: "r1", amountCents: 40000)],
      receivedByResourceId: {
        "r1": const OcptBudgetCoveredTotal(amountCents: 40000, coveredLineCount: 1, lineCount: 1),
      },
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetFinancing)));
    expect(find.textContaining(tr.budgetFinancingCoverageCoveredReadOut), findsOneWidget);
  });

  testWidgets("the coverage band is withheld while the quote is empty", (tester) async {
    await pumpView(tester, resources: [_resource(id: "r1")]);

    final tr = Tr.of(tester.element(find.byType(OcptBudgetFinancing)));
    expect(find.text(tr.budgetFinancingCoverageTitle.toUpperCase()), findsNothing);
  });

  testWidgets("clicking a resource row selects it, and only that", (tester) async {
    final resource = _resource(id: "r1", label: "Regional grant");
    String? selected;

    await pumpView(
      tester,
      resources: [resource],
      expandedNodeIds: const {"subsidies"},
      onResourceSelected: (resourceId) => selected = resourceId,
    );

    await tester.tap(find.text("Regional grant"));

    expect(selected, "r1");
  });

  testWidgets("clicking a taking row selects it, and only that", (tester) async {
    final revenue = _revenue(id: "v1");
    String? selected;

    await pumpView(
      tester,
      revenues: [revenue],
      expandedNodeIds: const {"takings"},
      onRevenueSelected: (revenueId) => selected = revenueId,
    );

    await tester.tap(find.text("Festival prize"));

    expect(selected, "v1");
  });

  testWidgets("a receipt sub-row reports its own selection", (tester) async {
    final resource = _resource(id: "r1");
    final receipt = _entry(id: "e1", resourceId: "r1", creditCents: 4000);
    String? selected;

    await pumpView(
      tester,
      resources: [resource],
      entries: [receipt],
      expandedNodeIds: const {"subsidies", "r1"},
      onReceiptSelected: (receiptId) => selected = receiptId,
    );

    await tester.tap(find.textContaining("Wire transfer"));

    expect(selected, "e1");
  });

  testWidgets("a receipt sub-row highlights while its own entry is the current selection", (
    tester,
  ) async {
    final resource = _resource(id: "r1");
    final receipt = _entry(id: "e1", resourceId: "r1", creditCents: 4000);

    await pumpView(
      tester,
      resources: [resource],
      entries: [receipt],
      expandedNodeIds: const {"subsidies", "r1"},
      selection: const OcptBudgetReceiptSelection("e1"),
    );

    final coloredBox = tester.widget<ColoredBox>(
      find.ancestor(of: find.textContaining("Wire transfer"), matching: find.byType(ColoredBox)).first,
    );
    expect(coloredBox.color, isNot(Colors.transparent));
  });

  testWidgets("the ⋮ menu offers Record a receipt on a resource, reporting the resource it names", (
    tester,
  ) async {
    final resource = _resource(id: "r1", label: "Regional grant");
    OcptBudgetResource? receiptRequested;

    await pumpView(
      tester,
      resources: [resource],
      expandedNodeIds: const {"subsidies"},
      onResourceReceiptRequested: (resource) => receiptRequested = resource,
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetFinancing)));
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.budgetFinancingRecordReceiptAction));
    await tester.pumpAndSettle();

    expect(receiptRequested?.id, "r1");
  });

  testWidgets("the ⋮ menu offers Move up/Move down on a taking, withheld at its own end", (
    tester,
  ) async {
    final revenues = [_revenue(id: "v1"), _revenue(id: "v2")];
    String? moved;
    var movedUp = false;

    await pumpView(
      tester,
      revenues: revenues,
      expandedNodeIds: const {"takings"},
      onRevenueReorderRequested: (revenueId, {required moveUp}) {
        moved = revenueId;
        movedUp = moveUp;
      },
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetFinancing)));
    // The first taking's own menu offers no Move up at all.
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    expect(find.text(tr.budgetPosteMoveUpAction), findsNothing);
    expect(find.text(tr.budgetPosteMoveDownAction), findsOneWidget);
    await tester.tap(find.text(tr.budgetPosteMoveDownAction));
    await tester.pumpAndSettle();
    expect(moved, "v1");
    expect(movedUp, isFalse);
  });

  testWidgets("every writing affordance is withheld under a read-only preview", (tester) async {
    final resource = _resource(id: "r1", label: "Regional grant");
    final revenue = _revenue(id: "v1");

    await pumpView(
      tester,
      resources: [resource],
      revenues: [revenue],
      expandedNodeIds: const {"subsidies", "takings"},
      isReadOnly: true,
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetFinancing)));
    // Withheld, never merely disabled: the footer isn't drawn at all.
    expect(find.text(tr.budgetFinancingCreationAction), findsNothing);
    // No menu at all on either row: every one of its own entries would be withheld.
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });
}
