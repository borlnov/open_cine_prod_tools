// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_header.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve.
Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  /// Widens the test surface so the header's own title and subtitle are shown — see
  /// `OcptBudgetHeader`'s own `_ocptBudgetHeaderTitleMinWidth`.
  void useWideWindow(WidgetTester tester) {
    tester.view.physicalSize = const Size(1950, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets("a centre too narrow for one line wraps the controls rather than clipping them", (
    tester,
  ) async {
    // The width the right dock leaves the centre on a 1280 px window — the case that used to take
    // the tax-basis switch off the screen entirely, a plain Row clipping silently rather than
    // overflowing loudly in release.
    tester.view.physicalSize = const Size(700, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrap(
        OcptBudgetHeader(
          centreView: OcptBudgetCentreView.dashboard,
          onCentreViewSelected: (_) {},
          isSimplified: false,
          onSimplifiedChanged: (_) {},
          taxBasis: OcptBudgetTaxBasis.includingTax,
          onTaxBasisChanged: (_) {},
        ),
      ),
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetHeader)));

    // Every control is still on screen, the last one included.
    expect(find.text(tr.budgetHeaderDashboardSegmentLabel), findsOneWidget);
    expect(find.text(tr.budgetHeaderSharingSegmentLabel), findsOneWidget);
    expect(find.text(tr.budgetHeaderSimplifiedSegmentLabel), findsOneWidget);
    expect(find.text(tr.budgetHeaderExcludingTaxSegmentLabel), findsOneWidget);
    expect(find.text(tr.budgetHeaderIncludingTaxSegmentLabel), findsOneWidget);

    // And it is still tappable, which a clipped one would not be.
    await tester.tap(find.text(tr.budgetHeaderExcludingTaxSegmentLabel));
    expect(tester.takeException(), isNull);
  });

  testWidgets("tapping the Cost tracking chip reports the view it names", (tester) async {
    useWideWindow(tester);
    OcptBudgetCentreView? reported;

    await tester.pumpWidget(
      _wrap(
        OcptBudgetHeader(
          centreView: OcptBudgetCentreView.dashboard,
          onCentreViewSelected: (view) => reported = view,
          isSimplified: false,
          onSimplifiedChanged: (_) {},
          taxBasis: OcptBudgetTaxBasis.includingTax,
          onTaxBasisChanged: (_) {},
        ),
      ),
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetHeader)));
    await tester.tap(find.text(tr.budgetHeaderCostTrackingSegmentLabel));

    expect(reported, OcptBudgetCentreView.costTracking);
  });

  testWidgets("tapping the active chip reports nothing (it is already the current view)", (
    tester,
  ) async {
    useWideWindow(tester);
    var callCount = 0;

    await tester.pumpWidget(
      _wrap(
        OcptBudgetHeader(
          centreView: OcptBudgetCentreView.dashboard,
          onCentreViewSelected: (_) => callCount++,
          isSimplified: false,
          onSimplifiedChanged: (_) {},
          taxBasis: OcptBudgetTaxBasis.includingTax,
          onTaxBasisChanged: (_) {},
        ),
      ),
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetHeader)));
    await tester.tap(find.text(tr.budgetHeaderDashboardSegmentLabel));

    expect(callCount, 0);
  });

  testWidgets("tapping Detailed reports isSimplified false", (tester) async {
    useWideWindow(tester);
    bool? reported;

    await tester.pumpWidget(
      _wrap(
        OcptBudgetHeader(
          centreView: OcptBudgetCentreView.dashboard,
          onCentreViewSelected: (_) {},
          isSimplified: true,
          onSimplifiedChanged: (value) => reported = value,
          taxBasis: OcptBudgetTaxBasis.includingTax,
          onTaxBasisChanged: (_) {},
        ),
      ),
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetHeader)));
    await tester.tap(find.text(tr.budgetHeaderDetailedSegmentLabel));

    expect(reported, isFalse);
  });

  testWidgets("tapping Excl. tax reports the excluding-tax basis", (tester) async {
    useWideWindow(tester);
    OcptBudgetTaxBasis? reported;

    await tester.pumpWidget(
      _wrap(
        OcptBudgetHeader(
          centreView: OcptBudgetCentreView.dashboard,
          onCentreViewSelected: (_) {},
          isSimplified: false,
          onSimplifiedChanged: (_) {},
          taxBasis: OcptBudgetTaxBasis.includingTax,
          onTaxBasisChanged: (basis) => reported = basis,
        ),
      ),
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetHeader)));
    await tester.tap(find.text(tr.budgetHeaderExcludingTaxSegmentLabel));

    expect(reported, OcptBudgetTaxBasis.excludingTax);
  });

  testWidgets("the two trade-word chips read plainly under the simplified switch", (tester) async {
    useWideWindow(tester);

    /// Pumps the header on [view], simplified or not, and answers the words it drew.
    Future<Tr> pumpOn(OcptBudgetCentreView view, {required bool isSimplified}) async {
      await tester.pumpWidget(
        _wrap(
          OcptBudgetHeader(
            centreView: view,
            onCentreViewSelected: (_) {},
            isSimplified: isSimplified,
            onSimplifiedChanged: (_) {},
            taxBasis: OcptBudgetTaxBasis.includingTax,
            onTaxBasisChanged: (_) {},
          ),
        ),
      );

      return Tr.of(tester.element(find.byType(OcptBudgetHeader)));
    }

    var tr = await pumpOn(OcptBudgetCentreView.cashJournal, isSimplified: true);
    expect(find.text(tr.budgetHeaderCashJournalSimpleSegmentLabel), findsWidgets);
    // The trade word is gone from the chip and from the band's own title alike.
    expect(find.text(tr.budgetHeaderCashJournalSegmentLabel), findsNothing);
    expect(find.text(tr.budgetHeaderCashJournalTitle), findsNothing);

    tr = await pumpOn(OcptBudgetCentreView.committed, isSimplified: true);
    expect(find.text(tr.budgetHeaderCommittedSimpleSegmentLabel), findsWidgets);
    expect(find.text(tr.budgetHeaderCommittedSegmentLabel), findsNothing);

    // The other three chips carry one wording only: they already say the plain thing they are.
    expect(find.text(tr.budgetHeaderDashboardSegmentLabel), findsOneWidget);
    expect(find.text(tr.budgetHeaderCostTrackingSegmentLabel), findsOneWidget);
    expect(find.text(tr.budgetHeaderFinancingSegmentLabel), findsOneWidget);

    tr = await pumpOn(OcptBudgetCentreView.cashJournal, isSimplified: false);
    expect(find.text(tr.budgetHeaderCashJournalSegmentLabel), findsWidgets);
    expect(find.text(tr.budgetHeaderCashJournalSimpleSegmentLabel), findsNothing);
  });

  testWidgets("the title and subtitle name the view on screen, not the mode", (tester) async {
    useWideWindow(tester);

    /// Pumps the header on [view] and answers the words it drew.
    Future<Tr> pumpOn(OcptBudgetCentreView view) async {
      await tester.pumpWidget(
        _wrap(
          OcptBudgetHeader(
            centreView: view,
            onCentreViewSelected: (_) {},
            isSimplified: false,
            onSimplifiedChanged: (_) {},
            taxBasis: OcptBudgetTaxBasis.includingTax,
            onTaxBasisChanged: (_) {},
          ),
        ),
      );

      return Tr.of(tester.element(find.byType(OcptBudgetHeader)));
    }

    var tr = await pumpOn(OcptBudgetCentreView.dashboard);
    expect(find.text(tr.budgetHeaderDashboardTitle), findsOneWidget);
    expect(find.text(tr.budgetHeaderDashboardSubtitle), findsOneWidget);

    tr = await pumpOn(OcptBudgetCentreView.costTracking);
    expect(find.text(tr.budgetHeaderTitle), findsOneWidget);
    expect(find.text(tr.budgetHeaderSubtitle), findsOneWidget);

    // `findsWidgets`, not `findsOneWidget`: these two titles are word for word their own view
    // chip's label, which is drawn in the same band.
    tr = await pumpOn(OcptBudgetCentreView.cashJournal);
    expect(find.text(tr.budgetHeaderCashJournalTitle), findsWidgets);
    expect(find.text(tr.budgetHeaderCashJournalSubtitle), findsOneWidget);
    // The band must not go on announcing the nomenclature over a list of bank movements.
    expect(find.text(tr.budgetHeaderSubtitle), findsNothing);

    tr = await pumpOn(OcptBudgetCentreView.committed);
    expect(find.text(tr.budgetHeaderCommittedTitle), findsWidgets);
    expect(find.text(tr.budgetHeaderCommittedSubtitle), findsOneWidget);
    expect(find.text(tr.budgetHeaderSubtitle), findsNothing);

    tr = await pumpOn(OcptBudgetCentreView.financing);
    expect(find.text(tr.budgetHeaderFinancingTitle), findsWidgets);
    expect(find.text(tr.budgetHeaderFinancingSubtitle), findsOneWidget);
    expect(find.text(tr.budgetHeaderSubtitle), findsNothing);

    tr = await pumpOn(OcptBudgetCentreView.regie);
    expect(find.text(tr.budgetHeaderRegieTitle), findsWidgets);
    expect(find.text(tr.budgetHeaderRegieSubtitle), findsOneWidget);
    expect(find.text(tr.budgetHeaderSubtitle), findsNothing);
  });

  testWidgets("offers the Financing chip whatever the project holds", (tester) async {
    useWideWindow(tester);
    OcptBudgetCentreView? reported;

    await tester.pumpWidget(
      _wrap(
        OcptBudgetHeader(
          centreView: OcptBudgetCentreView.dashboard,
          onCentreViewSelected: (view) => reported = view,
          isSimplified: false,
          onSimplifiedChanged: (_) {},
          taxBasis: OcptBudgetTaxBasis.includingTax,
          onTaxBasisChanged: (_) {},
        ),
      ),
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetHeader)));
    await tester.tap(find.text(tr.budgetHeaderFinancingSegmentLabel));

    expect(reported, OcptBudgetCentreView.financing);
  });

  testWidgets("offers the Régie chip last, after Committed", (tester) async {
    useWideWindow(tester);
    OcptBudgetCentreView? reported;

    await tester.pumpWidget(
      _wrap(
        OcptBudgetHeader(
          centreView: OcptBudgetCentreView.dashboard,
          onCentreViewSelected: (view) => reported = view,
          isSimplified: false,
          onSimplifiedChanged: (_) {},
          taxBasis: OcptBudgetTaxBasis.includingTax,
          onTaxBasisChanged: (_) {},
        ),
      ),
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetHeader)));
    await tester.tap(find.text(tr.budgetHeaderRegieSegmentLabel));

    expect(reported, OcptBudgetCentreView.regie);

    // Régie's own chip sits to the right of Committed's — the header's own class doc comment
    // argues why, unlike Financing, this one segment does follow OcptBudgetCentreView's own order.
    final committedChipCentre = tester.getCenter(find.text(tr.budgetHeaderCommittedSegmentLabel));
    final regieChipCentre = tester.getCenter(find.text(tr.budgetHeaderRegieSegmentLabel));
    expect(regieChipCentre.dx, greaterThan(committedChipCentre.dx));
  });

  // The narrow-window case (title/subtitle shed, the three controls kept) is
  // `OcptBudgetHeader`'s own `_ocptBudgetHeaderTitleMinWidth` threshold, argued in its class doc
  // comment; not re-asserted here as a layout test, since `flutter_test`'s own substituted test
  // font renders these short labels far wider than any real one does, which would make the
  // threshold's own safety margin — comfortable against a real font — read as flaky here.
}
