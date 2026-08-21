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

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a
/// [width]×[height] band — wide enough by default that every column of the table is drawn with
/// no horizontal scroll at all; a test of the scrolling pane itself passes a narrower [width].
Widget _wrap(Widget child, {double width = 1400, double height = 600}) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: width, height: height, child: child)),
);

/// The scrolling pane's own horizontal [SingleChildScrollView] — the vertical one, wrapping the
/// whole two-pane [Row], is the only other [SingleChildScrollView] in the tree, so filtering on
/// [Axis.horizontal] picks this one out uniquely.
final Finder _amountsPaneScrollFinder = find.byWidgetPredicate(
  (widget) => widget is SingleChildScrollView && widget.scrollDirection == Axis.horizontal,
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

  testWidgets(
    "the poste label stays visible after the amounts pane is scrolled to its own far right",
    (tester) async {
      const poste = OcptBudgetPoste(
        id: "poste-1",
        code: "1",
        label: "Artistic rights and costumes",
        simpleLabel: null,
        sortKey: "a0",
        lines: [],
      );

      // Narrower than the pinned pane's own floor (44 + 220) plus the six fixed-width amount
      // columns and the menu column (108 × 6 + 36) combined — the regression this table's split
      // into two panes exists to fix: before it, a table this narrow scrolled the `Poste` column
      // itself out of view along with the amounts.
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
          width: 620,
        ),
      );

      expect(_amountsPaneScrollFinder, findsOneWidget);
      await tester.drag(_amountsPaneScrollFinder, const Offset(-2000, 0));
      await tester.pumpAndSettle();

      expect(find.text("Artistic rights and costumes"), findsOneWidget);
    },
  );

  testWidgets(
    "selecting a poste highlights it in both the pinned pane and the scrolling pane",
    (tester) async {
      const postes = [
        OcptBudgetPoste(
          id: "poste-1",
          code: "1",
          label: "Poste one",
          simpleLabel: null,
          sortKey: "a0",
          lines: [],
        ),
        OcptBudgetPoste(
          id: "poste-2",
          code: "2",
          label: "Poste two",
          simpleLabel: null,
          sortKey: "a1",
          lines: [],
        ),
      ];

      await tester.pumpWidget(
        _wrap(
          OcptBudgetCostTracking(
            postes: postes,
            selectedPosteId: "poste-1",
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

      // One `ColoredBox` per pane per row (`_OcptCostTrackingIdentityRow`,
      // `_OcptCostTrackingAmountsRow`) — exactly two of the four painted here (two postes, two
      // panes) leave the selected poste's own transparent default.
      final highlightedCount = tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .where((box) => box.color != Colors.transparent)
          .length;

      expect(highlightedCount, 2);
    },
  );

  testWidgets(
    "simplified mode drops the N° column and narrows the pinned pane by that column's own width",
    (tester) async {
      const poste = OcptBudgetPoste(
        id: "poste-1",
        code: "1",
        label: "Poste one",
        simpleLabel: "Simple",
        sortKey: "a0",
        lines: [],
      );

      Widget buildTable({required bool isSimplified}) => OcptBudgetCostTracking(
        postes: [poste],
        selectedPosteId: null,
        isSimplified: isSimplified,
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
      );

      // Narrow enough that the `Poste` column sits at its own floor in both modes, so the pinned
      // pane's own width changes by exactly the `N°` column's width rather than the `Poste`
      // column silently absorbing the difference (which it does the moment there is room to
      // spare).
      await tester.pumpWidget(_wrap(buildTable(isSimplified: false), width: 620));
      final detailedAmountsPaneLeftEdge = tester.getTopLeft(_amountsPaneScrollFinder).dx;

      await tester.pumpWidget(_wrap(buildTable(isSimplified: true), width: 620));
      final simplifiedAmountsPaneLeftEdge = tester.getTopLeft(_amountsPaneScrollFinder).dx;

      expect(find.text("1"), findsNothing);
      expect(find.text("Simple"), findsOneWidget);
      // 44 px — `_ocptCostTrackingNumberColumnWidth` in the widget file, the `N°` column's own
      // fixed width.
      expect(detailedAmountsPaneLeftEdge - simplifiedAmountsPaneLeftEdge, 44);
    },
  );
}
