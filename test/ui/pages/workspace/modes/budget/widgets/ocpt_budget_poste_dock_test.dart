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
import 'package:open_cine_prod_tools/types/ocpt_budget_selection.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_poste_dock.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a band the
/// dock's own card can lay out in without wrapping.
Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 280, height: 700, child: child)),
);

/// A minimal poste quoted at [quotedCents] (a single line, quantity 1) — everything but what each
/// test actually varies neutral.
OcptBudgetPoste _poste({
  required String id,
  String code = "01",
  String label = "Poste",
  String? simpleLabel,
  int quotedCents = 10000,
}) => OcptBudgetPoste(
  id: id,
  code: code,
  label: label,
  simpleLabel: simpleLabel,
  sortKey: "a0",
  lines: [
    OcptBudgetLine(
      id: "$id-line",
      posteId: id,
      label: "Line",
      quantityMilli: 1000,
      unit: "u",
      unitPrice: OcptMoney(amountCents: quotedCents, isTaxInclusive: true, vatRateBasisPoints: null),
      elementId: null,
      provisionKey: null,
      provisionDigest: null,
      notes: "",
      sortKey: "a0",
    ),
  ],
  estimateToCompleteCents: null,
);

void main() {
  Future<Tr> pumpDock(
    WidgetTester tester, {
    required List<OcptBudgetPoste> postes,
    OcptBudgetSelection? selection,
    bool isSimplified = false,
    Map<String, int> paidCentsByPosteId = const {},
    Map<String, int> committedCentsByPosteId = const {},
    String? filterPosteId,
    ValueChanged<String>? onPosteFilterRequested,
    VoidCallback? onFilterClearRequested,
  }) async {
    await tester.pumpWidget(
      _wrap(
        OcptBudgetPosteDock(
          postes: postes,
          selection: selection,
          isSimplified: isSimplified,
          currencyCode: "EUR",
          paidCentsOf: (posteId) => paidCentsByPosteId[posteId] ?? 0,
          committedCentsOf: (posteId) => committedCentsByPosteId[posteId] ?? 0,
          filterPosteId: filterPosteId,
          onPosteSelected: (_) {},
          onPosteFilterRequested: onPosteFilterRequested,
          onFilterClearRequested: onFilterClearRequested,
        ),
      ),
    );

    return Tr.of(tester.element(find.byType(OcptBudgetPosteDock)));
  }

  testWidgets("prints the poste's own code in the detailed reading", (tester) async {
    final poste = _poste(id: "p1", code: "07");

    await pumpDock(tester, postes: [poste]);

    expect(find.text("07"), findsOneWidget);
  });

  testWidgets("hides the poste's own code in the simplified reading", (tester) async {
    final poste = _poste(id: "p1", code: "07");

    await pumpDock(tester, postes: [poste], isSimplified: true);

    expect(find.text("07"), findsNothing);
  });

  testWidgets("paints a poste within its quote in the within-strain colour", (tester) async {
    final poste = _poste(id: "p1");

    // 30 % paid, 20 % committed — 50 % consumed, within the quote.
    await pumpDock(
      tester,
      postes: [poste],
      paidCentsByPosteId: {"p1": 3000},
      committedCentsByPosteId: {"p1": 2000},
    );

    final context = tester.element(find.byType(OcptBudgetPosteDock));
    final expectedColor = ocptBudgetPosteStrainColor(context, OcptBudgetPosteStrain.within);

    final percentText = tester.widget<Text>(find.text("50%"));
    expect(percentText.style?.color, expectedColor);
  });

  testWidgets("paints a poste near its quote in the near-strain colour", (tester) async {
    final poste = _poste(id: "p1");

    // 60 % paid, 35 % committed — 95 % consumed, past the 90 % near threshold, not yet over.
    await pumpDock(
      tester,
      postes: [poste],
      paidCentsByPosteId: {"p1": 6000},
      committedCentsByPosteId: {"p1": 3500},
    );

    final context = tester.element(find.byType(OcptBudgetPosteDock));
    final expectedColor = ocptBudgetPosteStrainColor(context, OcptBudgetPosteStrain.near);

    final percentText = tester.widget<Text>(find.text("95%"));
    expect(percentText.style?.color, expectedColor);
  });

  testWidgets("paints a poste over its quote in the over-strain colour", (tester) async {
    final poste = _poste(id: "p1");

    // 80 % paid, 50 % committed — 130 % consumed, over the quote.
    await pumpDock(
      tester,
      postes: [poste],
      paidCentsByPosteId: {"p1": 8000},
      committedCentsByPosteId: {"p1": 5000},
    );

    final context = tester.element(find.byType(OcptBudgetPosteDock));
    final expectedColor = ocptBudgetPosteStrainColor(context, OcptBudgetPosteStrain.over);

    final percentText = tester.widget<Text>(find.text("130%"));
    expect(percentText.style?.color, expectedColor);
  });

  testWidgets("the footer totals Devis, Payé, Engagé and Reste over every poste", (tester) async {
    final postes = [
      _poste(id: "p1"),
      _poste(id: "p2", quotedCents: 5000),
    ];

    final tr = await pumpDock(
      tester,
      postes: postes,
      paidCentsByPosteId: {"p1": 3000, "p2": 1000},
      committedCentsByPosteId: {"p1": 2000, "p2": 500},
    );

    // Devis: 10000 + 5000 = 15000. Payé: 3000 + 1000 = 4000. Engagé: 2000 + 500 = 2500.
    // Reste: 15000 - 4000 - 2500 = 8500.
    expect(find.text(tr.budgetCostTrackingColumnQuote), findsOneWidget);
    expect(find.text(ocptBudgetAmountLabel(15000, "EUR")), findsOneWidget);
    expect(find.text(tr.budgetCostTrackingColumnPaid), findsOneWidget);
    expect(find.text(ocptBudgetAmountLabel(4000, "EUR")), findsOneWidget);
    expect(find.text(tr.budgetCostTrackingColumnCommitted), findsOneWidget);
    expect(find.text(ocptBudgetAmountLabel(2500, "EUR")), findsOneWidget);
    expect(find.text(tr.budgetCostTrackingColumnRemaining), findsOneWidget);
    expect(find.text(ocptBudgetAmountLabel(8500, "EUR")), findsOneWidget);
  });

  testWidgets("the Tout link is drawn only while a filter is set", (tester) async {
    final poste = _poste(id: "p1");

    final trUnfiltered = await pumpDock(
      tester,
      postes: [poste],
      onPosteFilterRequested: (_) {},
      onFilterClearRequested: () {},
    );
    expect(find.text(trUnfiltered.budgetPosteDockClearFilterLabel), findsNothing);

    final trFiltered = await pumpDock(
      tester,
      postes: [poste],
      filterPosteId: "p1",
      onPosteFilterRequested: (_) {},
      onFilterClearRequested: () {},
    );
    expect(find.text(trFiltered.budgetPosteDockClearFilterLabel), findsOneWidget);
  });

  testWidgets("a card's own ⋮ menu carries no filter entry while onPosteFilterRequested is null", (
    tester,
  ) async {
    final poste = _poste(id: "p1");

    await pumpDock(tester, postes: [poste]);

    expect(find.byType(PopupMenuButton<void>), findsNothing);
  });

  testWidgets("a card's own ⋮ menu carries the filter entry once onPosteFilterRequested is set", (
    tester,
  ) async {
    final poste = _poste(id: "p1");

    final tr = await pumpDock(tester, postes: [poste], onPosteFilterRequested: (_) {});

    expect(find.byType(PopupMenuButton<void>), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<void>));
    await tester.pumpAndSettle();

    expect(find.text(tr.budgetPosteDockFilterOnlyAction), findsOneWidget);
  });
}
