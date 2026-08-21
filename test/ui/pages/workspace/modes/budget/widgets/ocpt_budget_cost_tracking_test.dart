// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, and a wide enough
/// [Scaffold] that every column of the table is drawn.
Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 1400, height: 600, child: child)),
);

/// A quote line priced at 10.00 €, tax-inclusive, whose rate is known only when
/// `vatRateBasisPoints` is given.
OcptBudgetLine _line({required String id, required String posteId, int? vatRateBasisPoints}) =>
    OcptBudgetLine(
      id: id,
      posteId: posteId,
      label: "Line $id",
      quantityMilli: 1000,
      unit: "u",
      unitPrice: OcptMoney(
        amountCents: 1000,
        isTaxInclusive: true,
        vatRateBasisPoints: vatRateBasisPoints,
      ),
      elementId: null,
      notes: "",
      sortKey: "a0",
    );

void main() {
  testWidgets("the detailed header shows the poste code; the simplified one hides it and uses the "
      "simple label", (tester) async {
    final poste = OcptBudgetPoste(
      id: "poste-1",
      code: "7",
      label: "Technical equipment",
      simpleLabel: "Camera and lighting gear",
      sortKey: "a0",
      lines: [_line(id: "line-1", posteId: "poste-1", vatRateBasisPoints: 2000)],
    );

    await tester.pumpWidget(
      _wrap(
        OcptBudgetCostTracking(
          postes: [poste],
          selectedPosteId: null,
          isSimplified: false,
          taxBasis: OcptBudgetTaxBasis.includingTax,
          defaultVatRateBasisPoints: null,
          currencyCode: "EUR",
          isCashDataAvailable: false,
          paidCentsOf: (_) => 0,
          committedCentsOf: (_) => 0,
          isReadOnly: false,
          onPosteSelected: (_) {},
          onPosteCreationRequested: () {},
          onPosteReorderRequested: (_, {required moveUp}) {},
          onPosteDeletionRequested: (_) {},
        ),
      ),
    );

    expect(find.text("7"), findsOneWidget);
    expect(find.text("Technical equipment"), findsOneWidget);

    await tester.pumpWidget(
      _wrap(
        OcptBudgetCostTracking(
          postes: [poste],
          selectedPosteId: null,
          isSimplified: true,
          taxBasis: OcptBudgetTaxBasis.includingTax,
          defaultVatRateBasisPoints: null,
          currencyCode: "EUR",
          isCashDataAvailable: false,
          paidCentsOf: (_) => 0,
          committedCentsOf: (_) => 0,
          isReadOnly: false,
          onPosteSelected: (_) {},
          onPosteCreationRequested: () {},
          onPosteReorderRequested: (_, {required moveUp}) {},
          onPosteDeletionRequested: (_) {},
        ),
      ),
    );

    expect(find.text("7"), findsNothing);
    expect(find.text("Camera and lighting gear"), findsOneWidget);
  });

  testWidgets(
    "the total row reports how many postes its coverage reaches while a line carries no known "
    "rate, under the excluding-tax basis",
    (tester) async {
      final postes = [
        OcptBudgetPoste(
          id: "poste-1",
          code: "1",
          label: "Covered",
          simpleLabel: null,
          sortKey: "a0",
          lines: [_line(id: "line-1", posteId: "poste-1", vatRateBasisPoints: 2000)],
        ),
        OcptBudgetPoste(
          id: "poste-2",
          code: "2",
          label: "Uncovered",
          simpleLabel: null,
          sortKey: "a1",
          // No rate on this line, and none on the project either: its excluding-tax figure is
          // unknown, so this poste never counts as covered under that basis.
          lines: [_line(id: "line-2", posteId: "poste-2")],
        ),
      ];

      await tester.pumpWidget(
        _wrap(
          OcptBudgetCostTracking(
            postes: postes,
            selectedPosteId: null,
            isSimplified: false,
            taxBasis: OcptBudgetTaxBasis.excludingTax,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            isCashDataAvailable: false,
            paidCentsOf: (_) => 0,
            committedCentsOf: (_) => 0,
            isReadOnly: false,
            onPosteSelected: (_) {},
            onPosteCreationRequested: () {},
            onPosteReorderRequested: (_, {required moveUp}) {},
            onPosteDeletionRequested: (_) {},
          ),
        ),
      );

      final tr = Tr.of(tester.element(find.byType(OcptBudgetCostTracking)));
      // Poste 1's own 10.00 € tax-inclusive line, at 20 %, reads 8.33 € excluding tax
      // (1000 × 10000 / 12000, rounded) — the only poste this basis actually covers.
      final coveredAmount = ocptBudgetAmountLabel(833, "EUR");
      expect(
        find.text(tr.budgetCostTrackingCoverageReadOut(coveredAmount, 1, 2)),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    "withholds the creation footer and every row's own ⋮ menu while isReadOnly",
    (tester) async {
      const poste = OcptBudgetPoste(
        id: "poste-1",
        code: "1",
        label: "Poste one",
        simpleLabel: null,
        sortKey: "a0",
        lines: [],
      );

      await tester.pumpWidget(
        _wrap(
          OcptBudgetCostTracking(
            postes: [poste],
            selectedPosteId: null,
            isSimplified: false,
            taxBasis: OcptBudgetTaxBasis.includingTax,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            isCashDataAvailable: false,
            paidCentsOf: (_) => 0,
            committedCentsOf: (_) => 0,
            isReadOnly: true,
            onPosteSelected: (_) {},
            onPosteCreationRequested: () {},
            onPosteReorderRequested: (_, {required moveUp}) {},
            onPosteDeletionRequested: (_) {},
          ),
        ),
      );

      final tr = Tr.of(tester.element(find.byType(OcptBudgetCostTracking)));
      expect(find.text(tr.budgetPosteCreationAction), findsNothing);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
    },
  );
}
