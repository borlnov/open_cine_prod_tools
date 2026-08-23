// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
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
          postes: const [],
          filterPosteId: null,
          onPosteFilterSelected: (_) {},
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
          postes: const [],
          filterPosteId: null,
          onPosteFilterSelected: (_) {},
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
          postes: const [],
          filterPosteId: null,
          onPosteFilterSelected: (_) {},
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
          postes: const [],
          filterPosteId: null,
          onPosteFilterSelected: (_) {},
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
          postes: const [],
          filterPosteId: null,
          onPosteFilterSelected: (_) {},
        ),
      ),
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetHeader)));
    await tester.tap(find.text(tr.budgetHeaderExcludingTaxSegmentLabel));

    expect(reported, OcptBudgetTaxBasis.excludingTax);
  });

  testWidgets("no chip changes its wording under the simplified switch", (tester) async {
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
            postes: const [],
            filterPosteId: null,
            onPosteFilterSelected: (_) {},
          ),
        ),
      );

      return Tr.of(tester.element(find.byType(OcptBudgetHeader)));
    }

    // The cash journal's chip used to read `Spending` here and `Cash journal` there. It now says
    // one thing in both readings, and the band above it says the very same thing.
    for (final isSimplified in [true, false]) {
      final tr = await pumpOn(OcptBudgetCentreView.cashJournal, isSimplified: isSimplified);
      expect(find.text(tr.budgetHeaderCashJournalSegmentLabel), findsWidgets);
    }

    // The committed spending has no chip of its own at all — it is one half of `Planned`, and the
    // band names it by that chip joined to the sub-switch's own word for the half.
    for (final isSimplified in [true, false]) {
      final tr = await pumpOn(OcptBudgetCentreView.committed, isSimplified: isSimplified);
      expect(find.text(tr.budgetHeaderPlannedSegmentLabel), findsOneWidget);
      expect(
        find.text(tr.budgetHeaderPlannedTitle(tr.budgetPlannedOutgoingSegmentLabel)),
        findsOneWidget,
      );
    }

    final tr = await pumpOn(OcptBudgetCentreView.dashboard, isSimplified: true);
    expect(find.text(tr.budgetHeaderDashboardSegmentLabel), findsWidgets);
    expect(find.text(tr.budgetHeaderCostTrackingSegmentLabel), findsOneWidget);
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
            postes: const [],
            filterPosteId: null,
            onPosteFilterSelected: (_) {},
          ),
        ),
      );

      return Tr.of(tester.element(find.byType(OcptBudgetHeader)));
    }

    var tr = await pumpOn(OcptBudgetCentreView.dashboard);
    expect(find.text(tr.budgetHeaderDashboardTitle), findsOneWidget);
    expect(find.text(tr.budgetHeaderDashboardSubtitle), findsOneWidget);

    // `findsWidgets`, not `findsOneWidget`: from here down every title is word for word its own
    // view chip's label, which is drawn in the same band.
    tr = await pumpOn(OcptBudgetCentreView.costTracking);
    expect(find.text(tr.budgetHeaderTitle), findsWidgets);
    expect(find.text(tr.budgetHeaderSubtitle), findsOneWidget);

    tr = await pumpOn(OcptBudgetCentreView.cashJournal);
    expect(find.text(tr.budgetHeaderCashJournalTitle), findsWidgets);
    expect(find.text(tr.budgetHeaderCashJournalSubtitle), findsOneWidget);
    // The band must not go on announcing the nomenclature over a list of bank movements.
    expect(find.text(tr.budgetHeaderSubtitle), findsNothing);

    // The two halves of `Planned` are titled by that chip joined to the sub-switch's own word for
    // the half, so the band never says a third thing about a screen the chip already names.
    tr = await pumpOn(OcptBudgetCentreView.committed);
    expect(
      find.text(tr.budgetHeaderPlannedTitle(tr.budgetPlannedOutgoingSegmentLabel)),
      findsOneWidget,
    );
    expect(find.text(tr.budgetHeaderCommittedSubtitle), findsOneWidget);
    expect(find.text(tr.budgetHeaderSubtitle), findsNothing);

    tr = await pumpOn(OcptBudgetCentreView.financing);
    expect(
      find.text(tr.budgetHeaderPlannedTitle(tr.budgetPlannedIncomingSegmentLabel)),
      findsOneWidget,
    );
    expect(find.text(tr.budgetHeaderFinancingSubtitle), findsOneWidget);
    expect(find.text(tr.budgetHeaderSubtitle), findsNothing);

    tr = await pumpOn(OcptBudgetCentreView.regie);
    expect(find.text(tr.budgetHeaderRegieTitle), findsWidgets);
    expect(find.text(tr.budgetHeaderRegieSubtitle), findsOneWidget);
    expect(find.text(tr.budgetHeaderSubtitle), findsNothing);
  });

  testWidgets("the Planned chip lands on the financing plan", (tester) async {
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
          postes: const [],
          filterPosteId: null,
          onPosteFilterSelected: (_) {},
        ),
      ),
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetHeader)));
    await tester.tap(find.text(tr.budgetHeaderPlannedSegmentLabel));

    // One chip, two views: reached from elsewhere it lands on the financing plan, and the
    // sub-switch inside the view is what moves on to the committed spending.
    expect(reported, OcptBudgetCentreView.financing);
  });

  testWidgets("the Planned chip reads active on either of its two halves", (tester) async {
    useWideWindow(tester);
    OcptBudgetCentreView? reported;

    Future<Tr> pumpOn(OcptBudgetCentreView view) async {
      await tester.pumpWidget(
        _wrap(
          OcptBudgetHeader(
            centreView: view,
            onCentreViewSelected: (selected) => reported = selected,
            isSimplified: false,
            onSimplifiedChanged: (_) {},
            taxBasis: OcptBudgetTaxBasis.includingTax,
            onTaxBasisChanged: (_) {},
            postes: const [],
            filterPosteId: null,
            onPosteFilterSelected: (_) {},
          ),
        ),
      );

      return Tr.of(tester.element(find.byType(OcptBudgetHeader)));
    }

    // Standing on the committed spending, the chip is the active one: clicking it reports nothing,
    // exactly as clicking any already-active segment does, so a reader on one half is never thrown
    // back onto the other by the chip they are already under.
    final tr = await pumpOn(OcptBudgetCentreView.committed);
    await tester.tap(find.text(tr.budgetHeaderPlannedSegmentLabel));
    expect(reported, isNull);
  });

  testWidgets("offers the Régie chip last, after Planned", (tester) async {
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
          postes: const [],
          filterPosteId: null,
          onPosteFilterSelected: (_) {},
        ),
      ),
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetHeader)));
    await tester.tap(find.text(tr.budgetHeaderRegieSegmentLabel));

    expect(reported, OcptBudgetCentreView.regie);

    // Régie's own chip sits to the right of Planned's — the header's own class doc comment
    // argues why, unlike the cash journal, this one segment does follow OcptBudgetCentreView's own
    // order.
    final plannedChipCentre = tester.getCenter(find.text(tr.budgetHeaderPlannedSegmentLabel));
    final regieChipCentre = tester.getCenter(find.text(tr.budgetHeaderRegieSegmentLabel));
    expect(regieChipCentre.dx, greaterThan(plannedChipCentre.dx));
  });

  group("the poste filter", () {
    /// Pumps the header on [view], filtered onto [filterPosteId], and answers the words it drew.
    Future<Tr> pumpFilter(
      WidgetTester tester, {
      required OcptBudgetCentreView view,
      required String? filterPosteId,
      ValueChanged<String?>? onPosteFilterSelected,
    }) async {
      useWideWindow(tester);
      await tester.pumpWidget(
        _wrap(
          OcptBudgetHeader(
            centreView: view,
            onCentreViewSelected: (_) {},
            isSimplified: false,
            onSimplifiedChanged: (_) {},
            taxBasis: OcptBudgetTaxBasis.includingTax,
            onTaxBasisChanged: (_) {},
            postes: const [
              OcptBudgetPoste(
                id: "poste-1",
                code: "1",
                label: "Interpretation",
                simpleLabel: null,
                estimateToCompleteCents: null,
                sortKey: "a0",
                lines: [],
              ),
            ],
            filterPosteId: filterPosteId,
            onPosteFilterSelected: onPosteFilterSelected ?? (_) {},
          ),
        ),
      );

      return Tr.of(tester.element(find.byType(OcptBudgetHeader)));
    }

    testWidgets("reads Every poste while nothing is filtered", (tester) async {
      final tr = await pumpFilter(
        tester,
        view: OcptBudgetCentreView.cashJournal,
        filterPosteId: null,
      );

      expect(find.text(tr.budgetHeaderPosteFilterAllLabel), findsOneWidget);
      expect(find.text(tr.budgetHeaderPosteFilterNotHereCaption), findsNothing);
    });

    testWidgets("names the filtered poste, and offers to clear it", (tester) async {
      String? reported;
      var wasCalled = false;
      final tr = await pumpFilter(
        tester,
        view: OcptBudgetCentreView.cashJournal,
        filterPosteId: "poste-1",
        onPosteFilterSelected: (posteId) {
          reported = posteId;
          wasCalled = true;
        },
      );

      expect(find.text("Interpretation"), findsOneWidget);
      expect(find.text(tr.budgetHeaderPosteFilterNotHereCaption), findsNothing);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(wasCalled, isTrue);
      expect(reported, isNull);
    });

    testWidgets("says so on a view with no poste to narrow, keeping the name", (tester) async {
      // The filter really is still set — leaving this view brings it straight back — so hiding the
      // chip here would let an unfiltered view pass for a filtered one.
      final tr = await pumpFilter(
        tester,
        view: OcptBudgetCentreView.regie,
        filterPosteId: "poste-1",
      );

      expect(find.text("Interpretation"), findsOneWidget);
      expect(find.text(tr.budgetHeaderPosteFilterNotHereCaption), findsOneWidget);
    });
  });

  testWidgets("the chips read Quote, Planned, Cash flow, in that order", (tester) async {
    useWideWindow(tester);

    await tester.pumpWidget(
      _wrap(
        OcptBudgetHeader(
          centreView: OcptBudgetCentreView.dashboard,
          onCentreViewSelected: (_) {},
          isSimplified: false,
          onSimplifiedChanged: (_) {},
          taxBasis: OcptBudgetTaxBasis.includingTax,
          onTaxBasisChanged: (_) {},
          postes: const [],
          filterPosteId: null,
          onPosteFilterSelected: (_) {},
        ),
      ),
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetHeader)));
    final costTrackingCentre = tester.getCenter(find.text(tr.budgetHeaderCostTrackingSegmentLabel));
    final cashJournalCentre = tester.getCenter(find.text(tr.budgetHeaderCashJournalSegmentLabel));
    final plannedCentre = tester.getCenter(find.text(tr.budgetHeaderPlannedSegmentLabel));

    // The three read as the money's own life: what the film should cost, what is promised in
    // either direction, what has actually moved. Neither this order nor the enum's own is the
    // other: `committed` still sits between `cashJournal` and `financing` in `OcptBudgetCentreView`
    // itself, which is a stored preference's order and nothing else.
    expect(plannedCentre.dx, greaterThan(costTrackingCentre.dx));
    expect(cashJournalCentre.dx, greaterThan(plannedCentre.dx));
  });

  // The narrow-window case (title/subtitle shed, the three controls kept) is
  // `OcptBudgetHeader`'s own `_ocptBudgetHeaderTitleMinWidth` threshold, argued in its class doc
  // comment; not re-asserted here as a layout test, since `flutter_test`'s own substituted test
  // font renders these short labels far wider than any real one does, which would make the
  // threshold's own safety margin — comfortable against a real font — read as flaky here.
}
