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
import 'package:open_cine_prod_tools/models/ocpt_money.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_poste_inspector.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, and a wide, tall
/// enough [Scaffold] that every field of an expanded line card is drawn — wide enough, since the
/// `+ From breakdown` action joined `+ Add` on the quote lines title row, for both to fit beside
/// it with no overflow.
Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 520, height: 900, child: child)),
);

/// The one line every test below expands: priced at 12.50 €, tax-inclusive, overridden at 5.5 %.
const _line = OcptBudgetLine(
  id: "line-1",
  posteId: "poste-1",
  label: "Line one",
  quantityMilli: 1000,
  unit: "u",
  unitPrice: OcptMoney(
    amountCents: 1250,
    isTaxInclusive: true,
    vatRateBasisPoints: 550,
  ),
  elementId: null,
  notes: "",
  sortKey: "a0",
);

/// The poste every test below inspects, holding `_line` alone.
const _poste = OcptBudgetPoste(
  id: "poste-1",
  code: "1",
  label: "Poste one",
  simpleLabel: null,
  sortKey: "a0",
  lines: [_line],
);

/// A `fieldValueOf` reading every field straight off its own stored value — no pending edit ever
/// overrides it, which is all these tests need.
String _storedFieldValueOf(
  String targetId,
  OcptBudgetField field,
  String storedValue,
) => storedValue;

/// Builds a minimal journal entry against `poste-1`, everything but [id]/[debitCents]/
/// [creditCents]/[isTaxInclusive]/[vatRateBasisPoints] neutral.
OcptBudgetEntry _buildEntry({
  required String id,
  int debitCents = 0,
  int creditCents = 0,
  bool isTaxInclusive = true,
  int? vatRateBasisPoints,
}) => OcptBudgetEntry(
  id: id,
  date: DateTime(2026),
  label: "Entry $id",
  posteId: "poste-1",
  debitCents: debitCents,
  creditCents: creditCents,
  isTaxInclusive: isTaxInclusive,
  vatRateBasisPoints: vatRateBasisPoints,
  voucherNumber: "J-001",
  sortKey: "a0",
  resourceId: null,
);

void main() {
  testWidgets(
    "an expanded line's own unit price field reads back exactly 12.50, whatever the "
    "header's own tax basis is",
    (tester) async {
      for (final basis in OcptBudgetTaxBasis.values) {
        await tester.pumpWidget(
          _wrap(
            OcptBudgetPosteInspector(
              poste: _poste,
              taxBasis: basis,
              defaultVatRateBasisPoints: null,
              currencyCode: "EUR",
              paidCents: 0,
              committedCents: 0,
              entries: const [],
              expandedLineId: _line.id,
              isReadOnly: false,
              fieldValueOf: _storedFieldValueOf,
              onFieldChanged: (_, __, ___) {},
              onLineExpanded: (_) {},
              onLineTaxInclusiveChanged: (_, {required isTaxInclusive}) {},
              onLineVatRateInheritedRequested: (_) {},
              onLineDeletionRequested: (_) {},
              onLineCreationRequested: () {},
              onLineFromElementRequested: () {},
              elementNameByElementId: const {},
            ),
          ),
        );

        final tr = Tr.of(tester.element(find.byType(OcptBudgetPosteInspector)));
        final field = find.widgetWithText(TextField, "12.50").evaluate();
        expect(
          field,
          isNotEmpty,
          reason:
              "the unit price field should read 12.50 under $basis (${tr.budgetLineUnitPriceFieldLabel})",
        );
      }
    },
  );

  testWidgets("the VAT rate's own Inherit action reports the line's id", (
    tester,
  ) async {
    String? reportedLineId;

    await tester.pumpWidget(
      _wrap(
        OcptBudgetPosteInspector(
          poste: _poste,
          taxBasis: OcptBudgetTaxBasis.includingTax,
          defaultVatRateBasisPoints: 2000,
          currencyCode: "EUR",
          paidCents: 0,
          committedCents: 0,
          entries: const [],
          expandedLineId: _line.id,
          isReadOnly: false,
          fieldValueOf: _storedFieldValueOf,
          onFieldChanged: (_, __, ___) {},
          onLineExpanded: (_) {},
          onLineTaxInclusiveChanged: (_, {required isTaxInclusive}) {},
          onLineVatRateInheritedRequested: (lineId) => reportedLineId = lineId,
          onLineDeletionRequested: (_) {},
          onLineCreationRequested: () {},
          onLineFromElementRequested: () {},
          elementNameByElementId: const {},
        ),
      ),
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetPosteInspector)));
    await tester.tap(find.text(tr.budgetLineVatRateInheritAction));

    expect(reportedLineId, _line.id);
  });

  testWidgets(
    "withholds +Add, Delete and every field's own write while isReadOnly",
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          OcptBudgetPosteInspector(
            poste: _poste,
            taxBasis: OcptBudgetTaxBasis.includingTax,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            paidCents: 0,
            committedCents: 0,
            entries: const [],
            expandedLineId: _line.id,
            isReadOnly: true,
            fieldValueOf: _storedFieldValueOf,
            onFieldChanged: null,
            onLineExpanded: (_) {},
            onLineTaxInclusiveChanged: null,
            onLineVatRateInheritedRequested: null,
            onLineDeletionRequested: null,
            onLineCreationRequested: null,
            onLineFromElementRequested: null,
            elementNameByElementId: const {},
          ),
        ),
      );

      final tr = Tr.of(tester.element(find.byType(OcptBudgetPosteInspector)));
      expect(find.text(tr.budgetLineCreationAction), findsNothing);
      expect(find.text(tr.budgetLineFromElementAction), findsNothing);
      expect(find.text(tr.budgetLineDeleteAction), findsNothing);
      expect(find.text(tr.budgetLineVatRateInheritAction), findsNothing);

      final priceField = tester.widget<TextField>(
        find.widgetWithText(TextField, "12.50"),
      );
      expect(priceField.readOnly, isTrue);
    },
  );

  testWidgets(
    "shows the empty hint while the poste has no related entry at all",
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          OcptBudgetPosteInspector(
            poste: _poste,
            taxBasis: OcptBudgetTaxBasis.includingTax,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            paidCents: 0,
            committedCents: 0,
            entries: const [],
            expandedLineId: null,
            isReadOnly: false,
            fieldValueOf: _storedFieldValueOf,
            onFieldChanged: (_, __, ___) {},
            onLineExpanded: (_) {},
            onLineTaxInclusiveChanged: (_, {required isTaxInclusive}) {},
            onLineVatRateInheritedRequested: (_) {},
            onLineDeletionRequested: (_) {},
            onLineCreationRequested: () {},
            onLineFromElementRequested: () {},
            elementNameByElementId: const {},
          ),
        ),
      );

      final tr = Tr.of(tester.element(find.byType(OcptBudgetPosteInspector)));
      expect(
        find.text(tr.budgetInspectorRelatedEntriesEmptyHint),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    "lists the poste's own related entries, telling a debit and a credit apart by "
    "colour",
    (tester) async {
      final debit = _buildEntry(id: "entry-debit", debitCents: 1200);
      final credit = _buildEntry(id: "entry-credit", creditCents: 800);

      await tester.pumpWidget(
        _wrap(
          OcptBudgetPosteInspector(
            poste: _poste,
            taxBasis: OcptBudgetTaxBasis.includingTax,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            paidCents: 0,
            committedCents: 0,
            entries: [debit, credit],
            expandedLineId: null,
            isReadOnly: false,
            fieldValueOf: _storedFieldValueOf,
            onFieldChanged: (_, __, ___) {},
            onLineExpanded: (_) {},
            onLineTaxInclusiveChanged: (_, {required isTaxInclusive}) {},
            onLineVatRateInheritedRequested: (_) {},
            onLineDeletionRequested: (_) {},
            onLineCreationRequested: () {},
            onLineFromElementRequested: () {},
            elementNameByElementId: const {},
          ),
        ),
      );

      final theme = Theme.of(
        tester.element(find.byType(OcptBudgetPosteInspector)),
      );
      final debitText = tester.widget<Text>(
        find.text(ocptBudgetAmountLabel(1200, "EUR")),
      );
      final creditText = tester.widget<Text>(
        find.text(ocptBudgetAmountLabel(800, "EUR")),
      );

      expect(debitText.style?.color, theme.colorScheme.error);
      expect(creditText.style?.color, theme.colorScheme.primary);
      expect(debitText.style?.color, isNot(creditText.style?.color));
    },
  );

  testWidgets(
    "an entry that cannot be read tax-inclusive prints the em dash, and the list says "
    "so beneath it",
    (tester) async {
      final unreadable = _buildEntry(
        id: "entry-unreadable",
        debitCents: 1000,
        isTaxInclusive: false,
      );

      await tester.pumpWidget(
        _wrap(
          OcptBudgetPosteInspector(
            poste: _poste,
            taxBasis: OcptBudgetTaxBasis.includingTax,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            paidCents: 0,
            committedCents: 0,
            entries: [unreadable],
            expandedLineId: null,
            isReadOnly: false,
            fieldValueOf: _storedFieldValueOf,
            onFieldChanged: (_, __, ___) {},
            onLineExpanded: (_) {},
            onLineTaxInclusiveChanged: (_, {required isTaxInclusive}) {},
            onLineVatRateInheritedRequested: (_) {},
            onLineDeletionRequested: (_) {},
            onLineCreationRequested: () {},
            onLineFromElementRequested: () {},
            elementNameByElementId: const {},
          ),
        ),
      );

      final tr = Tr.of(tester.element(find.byType(OcptBudgetPosteInspector)));
      expect(find.text(ocptBudgetEmptyValue), findsOneWidget);
      expect(
        find.text(tr.budgetInspectorRelatedEntriesCoverageReadOut(0, 1)),
        findsOneWidget,
      );
    },
  );

  testWidgets("+ From breakdown reports its own click while not read-only", (tester) async {
    var wasRequested = false;

    await tester.pumpWidget(
      _wrap(
        OcptBudgetPosteInspector(
          poste: _poste,
          taxBasis: OcptBudgetTaxBasis.includingTax,
          defaultVatRateBasisPoints: null,
          currencyCode: "EUR",
          paidCents: 0,
          committedCents: 0,
          entries: const [],
          expandedLineId: null,
          isReadOnly: false,
          fieldValueOf: _storedFieldValueOf,
          onFieldChanged: (_, __, ___) {},
          onLineExpanded: (_) {},
          onLineTaxInclusiveChanged: (_, {required isTaxInclusive}) {},
          onLineVatRateInheritedRequested: (_) {},
          onLineDeletionRequested: (_) {},
          onLineCreationRequested: () {},
          onLineFromElementRequested: () => wasRequested = true,
          elementNameByElementId: const {},
        ),
      ),
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetPosteInspector)));
    await tester.tap(find.text(tr.budgetLineFromElementAction));

    expect(wasRequested, isTrue);
  });

  testWidgets("a line that prices an element shows its own name quietly underneath", (
    tester,
  ) async {
    const pricedLine = OcptBudgetLine(
      id: "line-priced",
      posteId: "poste-1",
      label: "Camera package",
      quantityMilli: 1000,
      unit: "u",
      unitPrice: OcptMoney(amountCents: 5000, isTaxInclusive: true, vatRateBasisPoints: null),
      elementId: "element-1",
      notes: "",
      sortKey: "a1",
    );
    const poste = OcptBudgetPoste(
      id: "poste-1",
      code: "1",
      label: "Poste one",
      simpleLabel: null,
      sortKey: "a0",
      lines: [pricedLine],
    );

    await tester.pumpWidget(
      _wrap(
        OcptBudgetPosteInspector(
          poste: poste,
          taxBasis: OcptBudgetTaxBasis.includingTax,
          defaultVatRateBasisPoints: null,
          currencyCode: "EUR",
          paidCents: 0,
          committedCents: 0,
          entries: const [],
          expandedLineId: null,
          isReadOnly: false,
          fieldValueOf: _storedFieldValueOf,
          onFieldChanged: (_, __, ___) {},
          onLineExpanded: (_) {},
          onLineTaxInclusiveChanged: (_, {required isTaxInclusive}) {},
          onLineVatRateInheritedRequested: (_) {},
          onLineDeletionRequested: (_) {},
          onLineCreationRequested: () {},
          onLineFromElementRequested: () {},
          elementNameByElementId: const {"element-1": "Camera body"},
        ),
      ),
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetPosteInspector)));
    expect(find.text(tr.budgetLineFromElementReadOut("Camera body")), findsOneWidget);
  });
}
