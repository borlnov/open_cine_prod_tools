// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_committed_spending.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a wide, tall
/// enough band that both columns are drawn side by side with no scroll needed to find a cell.
Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 1400, height: 700, child: child)),
);

/// A minimal commitment, everything but what each test actually varies neutral.
OcptBudgetCommitment _commitment({
  required String id,
  DateTime? dueDate,
  String label = "Commitment",
  String posteId = "poste-1",
  int amountCents = 1000,
  bool isTaxInclusive = true,
  int? vatRateBasisPoints,
  OcptBudgetCommitmentStatus status = OcptBudgetCommitmentStatus.quoteAccepted,
  String? settledEntryId,
  String sortKey = "a0",
}) => OcptBudgetCommitment(
  id: id,
  dueDate: dueDate,
  label: label,
  posteId: posteId,
  amount: OcptMoney(
    amountCents: amountCents,
    isTaxInclusive: isTaxInclusive,
    vatRateBasisPoints: vatRateBasisPoints,
  ),
  status: status,
  settledEntryId: settledEntryId,
  sortKey: sortKey,
);

void main() {
  /// Pumps [OcptBudgetCommittedSpending] with every callback a no-op unless overridden.
  Future<void> pumpView(
    WidgetTester tester, {
    required List<OcptBudgetCommitment> commitments,
    List<OcptBudgetPoste> postes = const [],
    int openingBalanceCents = 0,
    int? defaultVatRateBasisPoints,
    bool isReadOnly = false,
    VoidCallback? onCommitmentCreationRequested,
    ValueChanged<OcptBudgetCommitment>? onCommitmentTapped,
    ValueChanged<OcptBudgetCommitment>? onCommitmentSettleRequested,
    ValueChanged<String>? onCommitmentUnsettleRequested,
    ValueChanged<String>? onCommitmentDeletionRequested,
  }) async {
    // The default test surface is narrower than `_ocptCommittedWrapWidth`, which would silently
    // switch every test onto the stacked layout instead of the side-by-side one this suite means
    // to exercise — widened here so the wrapping `SizedBox` below isn't itself clamped down.
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrap(
        OcptBudgetCommittedSpending(
          commitments: commitments,
          postes: postes,
          openingBalanceCents: openingBalanceCents,
          isSimplified: false,
          defaultVatRateBasisPoints: defaultVatRateBasisPoints,
          currencyCode: "EUR",
          isReadOnly: isReadOnly,
          onCommitmentCreationRequested: onCommitmentCreationRequested ?? () {},
          onCommitmentTapped: onCommitmentTapped ?? (_) {},
          onCommitmentSettleRequested: onCommitmentSettleRequested ?? (_) {},
          onCommitmentUnsettleRequested: onCommitmentUnsettleRequested ?? (_) {},
          onCommitmentDeletionRequested: onCommitmentDeletionRequested ?? (_) {},
        ),
      ),
    );
  }

  testWidgets("a project with no commitment at all shows the shared empty state", (tester) async {
    await pumpView(tester, commitments: const []);

    expect(find.byType(OcptWorkspaceEmptyMode), findsOneWidget);
  });

  testWidgets("an empty list still offers the action that fills it", (tester) async {
    var created = 0;

    await pumpView(
      tester,
      commitments: const [],
      onCommitmentCreationRequested: () => created++,
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetCommittedSpending)));
    await tester.tap(find.text(tr.budgetCommittedCreationAction));

    expect(created, 1);
  });

  testWidgets(
    "a settled commitment stays listed but is excluded from the outstanding total and the projection",
    (tester) async {
      final commitments = [
        _commitment(id: "c1", dueDate: DateTime(2026), amountCents: 5000, status: OcptBudgetCommitmentStatus.declared),
        _commitment(id: "c2", dueDate: DateTime(2026, 1, 2), amountCents: 2000, settledEntryId: "entry-1"),
      ];

      await pumpView(tester, commitments: commitments, openingBalanceCents: 10000);

      final tr = Tr.of(tester.element(find.byType(OcptBudgetCommittedSpending)));
      // Both rows are drawn — the settled one is history worth keeping.
      expect(find.text("Commitment"), findsNWidgets(2));
      expect(find.text(tr.budgetCommittedStatusSettledLabel), findsOneWidget);

      // The outstanding total counts only the unsettled 5000, not 7000.
      expect(find.text(ocptBudgetAmountLabel(5000, "EUR")), findsWidgets);
      expect(find.text(ocptBudgetAmountLabel(7000, "EUR")), findsNothing);

      // The projection only takes the unsettled 5000 out of the opening balance: 10000 - 5000 = 5000,
      // never 10000 - 7000 = 3000.
      expect(find.text(ocptBudgetAmountLabel(5000, "EUR")), findsWidgets);
      expect(find.text(ocptBudgetAmountLabel(3000, "EUR")), findsNothing);
    },
  );

  testWidgets("the projection's bars are scaled to the largest absolute balance in the list", (
    tester,
  ) async {
    final commitments = [
      _commitment(id: "c1", dueDate: DateTime(2026), amountCents: 2000),
      _commitment(id: "c2", dueDate: DateTime(2026, 1, 2), amountCents: 8000),
    ];

    // Opening balance 10000: after c1, balance is 8000; after c2, balance is 0.
    // Largest absolute balance in the list is 8000, so c1's own bar reads full (8000/8000 = 1.0)
    // and c2's own bar reads empty (0/8000 = 0.0).
    await pumpView(tester, commitments: commitments, openingBalanceCents: 10000);

    final bars = tester.widgetList<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).toList();
    // The dashboard's own KPI bars share the same widget type but this view draws only the
    // projection's own steps, one per commitment.
    expect(bars, hasLength(2));
    expect(bars[0].value, 1.0);
    expect(bars[1].value, 0.0);
  });

  testWidgets("a step whose balance has gone negative reads differently from one that hasn't", (
    tester,
  ) async {
    final commitments = [
      _commitment(id: "c1", dueDate: DateTime(2026), amountCents: 3000),
      _commitment(id: "c2", dueDate: DateTime(2026, 1, 2), amountCents: 5000),
    ];

    // Opening balance 4000: after c1, balance is 1000 (positive); after c2, balance is -4000
    // (negative).
    await pumpView(tester, commitments: commitments, openingBalanceCents: 4000);

    final theme = Theme.of(tester.element(find.byType(OcptBudgetCommittedSpending)));
    final positiveText = tester.widget<Text>(find.text(ocptBudgetAmountLabel(1000, "EUR")).last);
    final negativeText = tester.widget<Text>(find.text(ocptBudgetAmountLabel(-4000, "EUR")).last);

    expect(negativeText.style?.color, theme.colorScheme.error);
    expect(positiveText.style?.color, isNot(theme.colorScheme.error));
  });

  testWidgets(
    "a commitment that cannot be read tax-inclusive produces no step, but still counts towards the "
    "coverage read-out",
    (tester) async {
      final commitments = [
        _commitment(id: "c1", dueDate: DateTime(2026), amountCents: 2000),
        _commitment(id: "c2", dueDate: DateTime(2026, 1, 2), isTaxInclusive: false),
      ];

      await pumpView(tester, commitments: commitments, openingBalanceCents: 10000);

      final tr = Tr.of(tester.element(find.byType(OcptBudgetCommittedSpending)));
      // Only one of the two steps is drawn: the unreadable commitment produces none.
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      // The footer's own coverage read-out says so: 1 of the 2 outstanding commitments covers.
      expect(find.text(tr.budgetCommittedProjectionCoverageReadOut(1, 2)), findsOneWidget);
      // The outstanding total's own coverage read-out says the very same thing.
      expect(find.text(tr.budgetCommittedCoverageReadOut(1, 2)), findsOneWidget);
    },
  );

  testWidgets("an undated commitment is listed last and still lowers the projection", (tester) async {
    // Handed in already in the order `OcptBudgetJournalService.loadCommitments` would give them
    // (dated first, undated last) — this view never reorders its own input, so the undated one
    // stays last and its own bar is still the very last step of the projection.
    final commitments = [
      _commitment(id: "c1", dueDate: DateTime(2026), amountCents: 500),
      _commitment(id: "c2", amountCents: 1500),
    ];

    await pumpView(tester, commitments: commitments, openingBalanceCents: 5000);

    final tr = Tr.of(tester.element(find.byType(OcptBudgetCommittedSpending)));
    expect(find.text(tr.budgetCommittedNoDueDateLabel), findsWidgets);
    // The dated step alone: 5000 - 500 = 4500.
    expect(find.text(ocptBudgetAmountLabel(4500, "EUR")), findsOneWidget);
    // The undated commitment still takes its own 1500 out, last: 4500 - 1500 = 3000 — printed
    // twice, once as the last step's own balance and once as the footer's final balance, since the
    // undated commitment is indeed the last one taken out.
    expect(find.text(ocptBudgetAmountLabel(3000, "EUR")), findsNWidgets(2));
  });

  testWidgets("the projection with nothing outstanding shows the balance and nothing else", (
    tester,
  ) async {
    final commitments = [
      _commitment(id: "c1", amountCents: 4000, settledEntryId: "entry-1"),
    ];

    await pumpView(tester, commitments: commitments, openingBalanceCents: 9000);

    // No step is drawn (nothing outstanding), and the balance shown is the opening one, unchanged.
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text(ocptBudgetAmountLabel(9000, "EUR")), findsOneWidget);
  });

  testWidgets("withholds every writing affordance under a previewed version", (tester) async {
    var tapped = false;
    final commitments = [_commitment(id: "c1", dueDate: DateTime(2026))];

    await pumpView(
      tester,
      commitments: commitments,
      isReadOnly: true,
      onCommitmentCreationRequested: () => tapped = true,
      onCommitmentTapped: (_) => tapped = true,
      onCommitmentSettleRequested: (_) => tapped = true,
      onCommitmentUnsettleRequested: (_) => tapped = true,
      onCommitmentDeletionRequested: (_) => tapped = true,
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetCommittedSpending)));
    expect(find.text(tr.budgetCommittedCreationAction), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsNothing);

    await tester.tap(find.text("Commitment"));
    await tester.pumpAndSettle();
    expect(tapped, isFalse);
  });
}
