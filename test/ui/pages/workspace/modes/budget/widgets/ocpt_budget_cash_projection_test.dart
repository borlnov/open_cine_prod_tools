// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cash_projection.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a band wide
/// enough that the card's own summary line never wraps.
Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 900, child: child)),
);

/// A minimal commitment, everything but what each test actually varies neutral.
OcptBudgetCommitment _commitment({
  required String id,
  DateTime? dueDate,
  String label = "Camera rental",
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
  lineId: null,
  sortKey: sortKey,
);

void main() {
  Future<Tr> pumpCard(
    WidgetTester tester, {
    required List<OcptBudgetCommitment> commitments,
    int openingBalanceCents = 0,
    int? defaultVatRateBasisPoints,
  }) async {
    await tester.pumpWidget(
      _wrap(
        OcptBudgetCashProjection(
          openingBalanceCents: openingBalanceCents,
          commitments: commitments,
          defaultVatRateBasisPoints: defaultVatRateBasisPoints,
          currencyCode: "EUR",
        ),
      ),
    );

    return Tr.of(tester.element(find.byType(OcptBudgetCashProjection)));
  }

  testWidgets("starts collapsed, showing only the opening and final balance", (tester) async {
    final commitments = [
      _commitment(id: "c1", dueDate: DateTime(2026), amountCents: 3000),
    ];

    final tr = await pumpCard(tester, commitments: commitments, openingBalanceCents: 10000);

    expect(
      find.text(
        tr.budgetCommittedProjectionCollapsedSummary(
          ocptBudgetAmountLabel(10000, "EUR"),
          ocptBudgetAmountLabel(7000, "EUR"),
        ),
      ),
      findsOneWidget,
    );
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text(tr.budgetCommittedProjectionHint), findsNothing);
  });

  testWidgets("expanding reveals the steps and collapsing hides them again", (tester) async {
    final commitments = [
      _commitment(id: "c1", dueDate: DateTime(2026), amountCents: 3000),
    ];

    final tr = await pumpCard(tester, commitments: commitments, openingBalanceCents: 10000);

    await tester.tap(find.byKey(const Key("ocptBudgetCashProjectionToggle")));
    await tester.pumpAndSettle();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text(tr.budgetCommittedProjectionHint), findsOneWidget);

    await tester.tap(find.byKey(const Key("ocptBudgetCashProjectionToggle")));
    await tester.pumpAndSettle();

    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets(
    "a settled commitment is excluded from the projection",
    (tester) async {
      final commitments = [
        _commitment(id: "c1", dueDate: DateTime(2026), amountCents: 5000),
        _commitment(id: "c2", dueDate: DateTime(2026, 1, 2), amountCents: 2000, settledEntryId: "entry-1"),
      ];

      final tr = await pumpCard(tester, commitments: commitments, openingBalanceCents: 10000);

      // Only the unsettled 5000 is taken out: 10000 - 5000 = 5000, never 10000 - 7000 = 3000.
      expect(
        find.text(
          tr.budgetCommittedProjectionCollapsedSummary(
            ocptBudgetAmountLabel(10000, "EUR"),
            ocptBudgetAmountLabel(5000, "EUR"),
          ),
        ),
        findsOneWidget,
      );
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
    await pumpCard(tester, commitments: commitments, openingBalanceCents: 10000);

    await tester.tap(find.byKey(const Key("ocptBudgetCashProjectionToggle")));
    await tester.pumpAndSettle();

    final bars = tester.widgetList<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).toList();
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
    await pumpCard(tester, commitments: commitments, openingBalanceCents: 4000);

    await tester.tap(find.byKey(const Key("ocptBudgetCashProjectionToggle")));
    await tester.pumpAndSettle();

    final theme = Theme.of(tester.element(find.byType(OcptBudgetCashProjection)));
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

      final tr = await pumpCard(tester, commitments: commitments, openingBalanceCents: 10000);

      await tester.tap(find.byKey(const Key("ocptBudgetCashProjectionToggle")));
      await tester.pumpAndSettle();

      // Only one of the two steps is drawn: the unreadable commitment produces none.
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text(tr.budgetCommittedProjectionCoverageReadOut(1, 2)), findsOneWidget);
    },
  );

  testWidgets("an undated commitment is listed last and still lowers the projection", (tester) async {
    final commitments = [
      _commitment(id: "c1", dueDate: DateTime(2026), amountCents: 500),
      _commitment(id: "c2", amountCents: 1500),
    ];

    final tr = await pumpCard(tester, commitments: commitments, openingBalanceCents: 5000);

    await tester.tap(find.byKey(const Key("ocptBudgetCashProjectionToggle")));
    await tester.pumpAndSettle();

    expect(find.text(tr.budgetCommittedNoDueDateLabel), findsOneWidget);
    // The dated step alone: 5000 - 500 = 4500.
    expect(find.text(ocptBudgetAmountLabel(4500, "EUR")), findsOneWidget);
  });
}
