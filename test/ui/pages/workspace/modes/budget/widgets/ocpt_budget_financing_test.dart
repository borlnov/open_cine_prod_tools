// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financing.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a wide, tall
/// enough band that the whole KPI row and every group card lay out with no scroll needed to find a
/// cell.
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
  OcptBudgetResourceStatus status = OcptBudgetResourceStatus.applied,
  bool isReimbursable = false,
  String notes = "",
}) => OcptBudgetResource(
  id: id,
  groupKind: groupKind,
  label: label,
  amountCents: amountCents,
  status: status,
  isReimbursable: isReimbursable,
  notes: notes,
  sortKey: "a0",
);

void main() {
  /// Pumps [OcptBudgetFinancing] with every callback a no-op unless overridden, and
  /// [receivedCentsOf] reading [receivedByResourceId] the ordinary `?? 0` way unless overridden.
  Future<void> pumpView(
    WidgetTester tester, {
    required List<OcptBudgetResource> resources,
    Map<String, OcptBudgetCoveredTotal> receivedByResourceId = const {},
    String? selectedResourceId,
    bool isReadOnly = false,
    VoidCallback? onResourceCreationRequested,
    ValueChanged<String>? onResourceSelected,
    ValueChanged<OcptBudgetResource>? onResourceEditRequested,
    ValueChanged<OcptBudgetResource>? onResourceReceiptRequested,
    ValueChanged<String>? onResourceDeletionRequested,
  }) async {
    // The default test surface is narrower than the KPI row's own fixed-width cells plus its own
    // `+ Resource` action need to lay out side by side without overflowing.
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrap(
        OcptBudgetFinancing(
          resources: resources,
          receivedByResourceId: receivedByResourceId,
          receivedCentsOf: (resourceId) => receivedByResourceId[resourceId]?.amountCents ?? 0,
          currencyCode: "EUR",
          selectedResourceId: selectedResourceId,
          isReadOnly: isReadOnly,
          onResourceCreationRequested: onResourceCreationRequested ?? () {},
          onResourceSelected: onResourceSelected ?? (_) {},
          onResourceEditRequested: onResourceEditRequested ?? (_) {},
          onResourceReceiptRequested: onResourceReceiptRequested ?? (_) {},
          onResourceDeletionRequested: onResourceDeletionRequested ?? (_) {},
        ),
      ),
    );
  }

  testWidgets("a project with no resource at all shows the shared empty state", (tester) async {
    await pumpView(tester, resources: const []);

    expect(find.byType(OcptWorkspaceEmptyMode), findsOneWidget);
  });

  testWidgets("an empty plan still offers the action that starts it", (tester) async {
    var created = 0;

    await pumpView(tester, resources: const [], onResourceCreationRequested: () => created++);

    final tr = Tr.of(tester.element(find.byType(OcptBudgetFinancing)));
    await tester.tap(find.text(tr.budgetFinancingCreationAction));

    expect(created, 1);
  });

  testWidgets("a group with no resource of its own draws no card at all", (tester) async {
    final resources = [_resource(id: "r1")];

    await pumpView(tester, resources: resources);

    final tr = Tr.of(tester.element(find.byType(OcptBudgetFinancing)));
    expect(find.text(tr.budgetFinancingGroupSubsidyLabel), findsOneWidget);
    expect(find.text(tr.budgetFinancingGroupCashLabel), findsNothing);
    expect(find.text(tr.budgetFinancingGroupInKindLabel), findsNothing);
  });

  testWidgets(
    "an in-kind resource with no entry naming it prints the em dash on both received and outstanding",
    (tester) async {
      final resource = _resource(
        id: "r1",
        groupKind: OcptBudgetResourceGroupKind.inKind,
        amountCents: 5000,
      );

      await pumpView(tester, resources: [resource]);

      expect(find.text(ocptBudgetEmptyValue), findsNWidgets(2));
    },
  );

  testWidgets(
    "the same in-kind resource prints real figures once an entry names it, zero included",
    (tester) async {
      final resource = _resource(
        id: "r1",
        groupKind: OcptBudgetResourceGroupKind.inKind,
        amountCents: 5000,
      );

      await pumpView(
        tester,
        resources: [resource],
        receivedByResourceId: const {
          "r1": OcptBudgetCoveredTotal(amountCents: 0, coveredLineCount: 1, lineCount: 1),
        },
      );

      // Received reads the real zero, never the em dash, and outstanding reads the full amount.
      expect(find.text(ocptBudgetEmptyValue), findsNothing);
      expect(find.text(ocptBudgetAmountLabel(0, "EUR")), findsWidgets);
      expect(find.text(ocptBudgetAmountLabel(5000, "EUR")), findsWidgets);
    },
  );

  testWidgets("a subsidy or cash resource with no entry reads honest zero, never the em dash", (
    tester,
  ) async {
    final resource = _resource(id: "r1", amountCents: 5000);

    await pumpView(tester, resources: [resource]);

    expect(find.text(ocptBudgetEmptyValue), findsNothing);
    expect(find.text(ocptBudgetAmountLabel(0, "EUR")), findsWidgets);
  });

  testWidgets("a resource whose credits exceed its amount reads a negative outstanding", (
    tester,
  ) async {
    final resource = _resource(id: "r1", amountCents: 5000);

    await pumpView(
      tester,
      resources: [resource],
      receivedByResourceId: const {
        "r1": OcptBudgetCoveredTotal(amountCents: 8000, coveredLineCount: 1, lineCount: 1),
      },
    );

    final theme = Theme.of(tester.element(find.byType(OcptBudgetFinancing)));
    final outstandingText = tester.widget<Text>(find.text(ocptBudgetAmountLabel(-3000, "EUR")).last);

    expect(outstandingText.style?.color, theme.colorScheme.error);
  });

  testWidgets("clicking a row selects it, and only that", (tester) async {
    final resource = _resource(id: "r1", label: "Regional grant");
    String? selected;

    await pumpView(
      tester,
      resources: [resource],
      onResourceSelected: (resourceId) => selected = resourceId,
    );

    await tester.tap(find.text("Regional grant"));

    expect(selected, "r1");
  });

  testWidgets("the ⋮ menu's Delete entry asks through the callback rather than writing", (
    tester,
  ) async {
    final resource = _resource(id: "r1", label: "Regional grant");
    String? deletionRequested;

    await pumpView(
      tester,
      resources: [resource],
      onResourceDeletionRequested: (resourceId) => deletionRequested = resourceId,
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetFinancing)));
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.budgetCommittedDeleteAction));
    await tester.pumpAndSettle();

    // The widget only ever reports the id; nothing about the resource itself is drawn as removed
    // by this widget on its own — that is the mode's own job, through OcptConfirmDialog first.
    expect(deletionRequested, "r1");
    expect(find.text("Regional grant"), findsOneWidget);
  });

  testWidgets("the ⋮ menu offers Record a receipt, reporting the resource it names", (
    tester,
  ) async {
    final resource = _resource(id: "r1", label: "Regional grant");
    OcptBudgetResource? receiptRequested;

    await pumpView(
      tester,
      resources: [resource],
      onResourceReceiptRequested: (resource) => receiptRequested = resource,
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetFinancing)));
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.budgetFinancingRecordReceiptAction));
    await tester.pumpAndSettle();

    expect(receiptRequested?.id, "r1");
  });

  testWidgets("every writing affordance is withheld under a read-only preview", (tester) async {
    final resource = _resource(id: "r1", label: "Regional grant");

    await pumpView(tester, resources: [resource], isReadOnly: true);

    final tr = Tr.of(tester.element(find.byType(OcptBudgetFinancing)));
    // Withheld, never merely disabled: the action isn't drawn at all.
    expect(find.text(tr.budgetFinancingCreationAction), findsNothing);
    // No menu at all: every one of its own entries would be withheld.
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  testWidgets("the Cash KPI reports what has come in and what is still to come", (tester) async {
    final resources = [
      _resource(id: "r1"),
      _resource(id: "r2", groupKind: OcptBudgetResourceGroupKind.cash, amountCents: 5000),
      // An in-kind resource never counts towards the Cash KPI.
      _resource(id: "r3", groupKind: OcptBudgetResourceGroupKind.inKind, amountCents: 2000),
    ];

    await pumpView(
      tester,
      resources: resources,
      receivedByResourceId: const {
        "r1": OcptBudgetCoveredTotal(amountCents: 4000, coveredLineCount: 1, lineCount: 1),
      },
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetFinancing)));
    // Cash amount: 10000 + 5000 = 15000; received: 4000; outstanding: 11000.
    expect(
      find.text(
        tr.budgetFinancingCashCaption(
          ocptBudgetAmountLabel(4000, "EUR"),
          ocptBudgetAmountLabel(11000, "EUR"),
        ),
      ),
      findsOneWidget,
    );
  });
}
