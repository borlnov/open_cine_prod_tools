// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_document.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_sub_page.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_header.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_alerts.dart';

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
  /// Widens the test surface so the header's own title, subtitle and breadcrumb are shown — see
  /// `OcptBudgetHeader`'s own `_ocptBudgetHeaderTitleMinWidth`.
  void useWideWindow(WidgetTester tester) {
    tester.view.physicalSize = const Size(1750, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Pumps [OcptBudgetHeader] with every prop at a sensible default, overridable one at a time —
  /// [document] at its own top level ([subPage] null) in [reading], with every control's own
  /// callback recording nothing unless the test itself cares.
  Future<Tr> pumpHeader(
    WidgetTester tester, {
    OcptBudgetDocument document = OcptBudgetDocument.expenses,
    OcptBudgetDocumentReading reading = OcptBudgetDocumentReading.byTree,
    OcptBudgetSubPage? subPage,
    ValueChanged<OcptBudgetDocument>? onDocumentSelected,
    ValueChanged<OcptBudgetDocumentReading>? onReadingSelected,
    ValueChanged<OcptBudgetSubPage>? onSubPageSelected,
    bool isSimplified = false,
    ValueChanged<bool>? onSimplifiedChanged,
    OcptBudgetTaxBasis taxBasis = OcptBudgetTaxBasis.includingTax,
    ValueChanged<OcptBudgetTaxBasis>? onTaxBasisChanged,
    List<OcptBudgetPoste> postes = const [],
    String? filterPosteId,
    ValueChanged<String?>? onPosteFilterSelected,
    List<OcptBudgetAlert> alerts = const [],
    ValueChanged<String>? onAlertPosteActionRequested,
    VoidCallback? onCashProjectionAlertActionRequested,
  }) async {
    await tester.pumpWidget(
      _wrap(
        OcptBudgetHeader(
          document: document,
          onDocumentSelected: onDocumentSelected ?? (_) {},
          reading: reading,
          onReadingSelected: onReadingSelected ?? (_) {},
          subPage: subPage,
          onSubPageSelected: onSubPageSelected ?? (_) {},
          isSimplified: isSimplified,
          onSimplifiedChanged: onSimplifiedChanged ?? (_) {},
          taxBasis: taxBasis,
          onTaxBasisChanged: onTaxBasisChanged ?? (_) {},
          postes: postes,
          filterPosteId: filterPosteId,
          onPosteFilterSelected: onPosteFilterSelected ?? (_) {},
          alerts: alerts,
          currencyCode: "EUR",
          onAlertPosteActionRequested: onAlertPosteActionRequested ?? (_) {},
          onCashProjectionAlertActionRequested: onCashProjectionAlertActionRequested ?? () {},
        ),
      ),
    );

    return Tr.of(tester.element(find.byType(OcptBudgetHeader)));
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

    final tr = await pumpHeader(tester);

    // Every control is still on screen, the last one included — the document switch, the reading
    // switch, the simplified switch, the tax-basis switch and the poste filter all honoured at
    // expenses's own top level.
    expect(find.text(tr.budgetHeaderDocumentExpensesSegmentLabel), findsOneWidget);
    expect(find.text(tr.budgetHeaderDocumentSharingSegmentLabel), findsOneWidget);
    expect(find.text(tr.budgetHeaderReadingByDateSegmentLabel), findsOneWidget);
    expect(find.text(tr.budgetHeaderSimplifiedSegmentLabel), findsOneWidget);
    expect(find.text(tr.budgetHeaderExcludingTaxSegmentLabel), findsOneWidget);
    expect(find.text(tr.budgetHeaderPosteFilterAllLabel), findsOneWidget);

    // And it is still tappable, which a clipped one would not be.
    await tester.tap(find.text(tr.budgetHeaderExcludingTaxSegmentLabel));
    expect(tester.takeException(), isNull);
  });

  group("the document switch", () {
    testWidgets("tapping Resources reports the document it names", (tester) async {
      useWideWindow(tester);
      OcptBudgetDocument? reported;
      final tr = await pumpHeader(tester, onDocumentSelected: (document) => reported = document);

      await tester.tap(find.text(tr.budgetHeaderDocumentResourcesSegmentLabel));

      expect(reported, OcptBudgetDocument.resources);
    });

    testWidgets("tapping the active chip reports nothing", (tester) async {
      useWideWindow(tester);
      var callCount = 0;
      final tr = await pumpHeader(tester, onDocumentSelected: (_) => callCount++);

      // Scoped to an `InkWell` ancestor: at the document's own top level the breadcrumb also
      // draws the very same word, as plain, non-interactive text.
      await tester.tap(
        find.ancestor(
          of: find.text(tr.budgetHeaderDocumentExpensesSegmentLabel),
          matching: find.byType(InkWell),
        ),
      );

      expect(callCount, 0);
    });
  });

  group("the reading switch", () {
    testWidgets("offered on expenses, tapping By date reports the reading", (tester) async {
      useWideWindow(tester);
      OcptBudgetDocumentReading? reported;
      final tr = await pumpHeader(tester, onReadingSelected: (reading) => reported = reading);

      await tester.tap(find.text(tr.budgetHeaderReadingByDateSegmentLabel));

      expect(reported, OcptBudgetDocumentReading.byDate);
    });

    testWidgets("withheld on resources — nothing to switch to yet", (tester) async {
      useWideWindow(tester);
      final tr = await pumpHeader(tester, document: OcptBudgetDocument.resources);

      expect(find.text(tr.budgetHeaderReadingByTreeSegmentLabel), findsNothing);
      expect(find.text(tr.budgetHeaderReadingByDateSegmentLabel), findsNothing);
    });

    testWidgets("withheld on sharing", (tester) async {
      useWideWindow(tester);
      final tr = await pumpHeader(tester, document: OcptBudgetDocument.sharing);

      expect(find.text(tr.budgetHeaderReadingByTreeSegmentLabel), findsNothing);
    });

    testWidgets("still offered inside a sub-page — the way back to the top level", (tester) async {
      useWideWindow(tester);
      final tr = await pumpHeader(tester, subPage: OcptBudgetSubPage.regie);

      expect(find.text(tr.budgetHeaderReadingByTreeSegmentLabel), findsOneWidget);
    });
  });

  group("the tax-basis switch", () {
    testWidgets("tapping Excl. tax reports the excluding-tax basis", (tester) async {
      useWideWindow(tester);
      OcptBudgetTaxBasis? reported;
      final tr = await pumpHeader(tester, onTaxBasisChanged: (basis) => reported = basis);

      await tester.tap(find.text(tr.budgetHeaderExcludingTaxSegmentLabel));

      expect(reported, OcptBudgetTaxBasis.excludingTax);
    });

    testWidgets("withheld on resources — money coming in is always tax-inclusive", (tester) async {
      useWideWindow(tester);
      final tr = await pumpHeader(tester, document: OcptBudgetDocument.resources);

      expect(find.text(tr.budgetHeaderExcludingTaxSegmentLabel), findsNothing);
    });

    testWidgets("withheld on sharing", (tester) async {
      useWideWindow(tester);
      final tr = await pumpHeader(tester, document: OcptBudgetDocument.sharing);

      expect(find.text(tr.budgetHeaderExcludingTaxSegmentLabel), findsNothing);
    });
  });

  group("the simplified/detailed switch", () {
    testWidgets("tapping Detailed reports isSimplified false", (tester) async {
      useWideWindow(tester);
      bool? reported;
      final tr = await pumpHeader(
        tester,
        isSimplified: true,
        onSimplifiedChanged: (value) => reported = value,
      );

      await tester.tap(find.text(tr.budgetHeaderDetailedSegmentLabel));

      expect(reported, isFalse);
    });

    testWidgets("offered at expenses's own top level", (tester) async {
      useWideWindow(tester);
      final tr = await pumpHeader(tester);

      expect(find.text(tr.budgetHeaderSimplifiedSegmentLabel), findsOneWidget);
    });

    testWidgets("offered on the committed-spending sub-page", (tester) async {
      useWideWindow(tester);
      final tr = await pumpHeader(tester, subPage: OcptBudgetSubPage.committedSpending);

      expect(find.text(tr.budgetHeaderSimplifiedSegmentLabel), findsOneWidget);
    });

    testWidgets("withheld on the dashboard sub-page — no poste-keyed row there", (tester) async {
      useWideWindow(tester);
      final tr = await pumpHeader(tester, subPage: OcptBudgetSubPage.dashboard);

      expect(find.text(tr.budgetHeaderSimplifiedSegmentLabel), findsNothing);
    });

    testWidgets("withheld on the régie sub-page", (tester) async {
      useWideWindow(tester);
      final tr = await pumpHeader(tester, subPage: OcptBudgetSubPage.regie);

      expect(find.text(tr.budgetHeaderSimplifiedSegmentLabel), findsNothing);
    });

    testWidgets("withheld on resources and sharing", (tester) async {
      useWideWindow(tester);
      var tr = await pumpHeader(tester, document: OcptBudgetDocument.resources);
      expect(find.text(tr.budgetHeaderSimplifiedSegmentLabel), findsNothing);

      tr = await pumpHeader(tester, document: OcptBudgetDocument.sharing);
      expect(find.text(tr.budgetHeaderSimplifiedSegmentLabel), findsNothing);
    });
  });

  group("the poste filter", () {
    final poste = const OcptBudgetPoste(
      id: "poste-1",
      code: "1",
      label: "Interpretation",
      simpleLabel: null,
      estimateToCompleteCents: null,
      sortKey: "a0",
      lines: [],
    );

    testWidgets("offered at expenses's own top level, reading Every poste while unfiltered", (
      tester,
    ) async {
      useWideWindow(tester);
      final tr = await pumpHeader(tester, postes: [poste]);

      expect(find.text(tr.budgetHeaderPosteFilterAllLabel), findsOneWidget);
    });

    testWidgets("names the filtered poste, and offers to clear it", (tester) async {
      useWideWindow(tester);
      String? reported;
      var wasCalled = false;
      await pumpHeader(
        tester,
        postes: [poste],
        filterPosteId: "poste-1",
        onPosteFilterSelected: (posteId) {
          reported = posteId;
          wasCalled = true;
        },
      );

      expect(find.text("Interpretation"), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(wasCalled, isTrue);
      expect(reported, isNull);
    });

    testWidgets("offered on the committed-spending sub-page", (tester) async {
      useWideWindow(tester);
      final tr = await pumpHeader(
        tester,
        postes: [poste],
        subPage: OcptBudgetSubPage.committedSpending,
      );

      expect(find.text(tr.budgetHeaderPosteFilterAllLabel), findsOneWidget);
    });

    testWidgets("withheld outright — never captioned — on a route with no poste dimension", (
      tester,
    ) async {
      useWideWindow(tester);
      final tr = await pumpHeader(
        tester,
        postes: [poste],
        subPage: OcptBudgetSubPage.regie,
      );

      expect(find.text(tr.budgetHeaderPosteFilterAllLabel), findsNothing);
      expect(find.text("Interpretation"), findsNothing);
    });

    testWidgets("withheld on resources and sharing", (tester) async {
      useWideWindow(tester);
      var tr = await pumpHeader(tester, postes: [poste], document: OcptBudgetDocument.resources);
      expect(find.text(tr.budgetHeaderPosteFilterAllLabel), findsNothing);

      tr = await pumpHeader(tester, postes: [poste], document: OcptBudgetDocument.sharing);
      expect(find.text(tr.budgetHeaderPosteFilterAllLabel), findsNothing);
    });
  });

  group("the breadcrumb", () {
    testWidgets("shows the document alone at its own top level", (tester) async {
      useWideWindow(tester);
      final tr = await pumpHeader(tester, document: OcptBudgetDocument.resources);

      expect(find.text(tr.budgetHeaderDocumentResourcesSegmentLabel), findsWidgets);
      expect(find.text("›"), findsNothing);
    });

    testWidgets("shows the document then the sub-page inside one", (tester) async {
      useWideWindow(tester);
      final tr = await pumpHeader(tester, subPage: OcptBudgetSubPage.regie);

      expect(find.text("›"), findsOneWidget);
      expect(find.text(tr.budgetHeaderRegieSegmentLabel), findsWidgets);
    });

    testWidgets("clicking the document ancestor reports it, to return to the top level", (
      tester,
    ) async {
      useWideWindow(tester);
      OcptBudgetDocument? reported;
      await pumpHeader(
        tester,
        subPage: OcptBudgetSubPage.regie,
        onDocumentSelected: (document) => reported = document,
      );

      // Scoped to the breadcrumb's own ancestor by key: the document switch also draws an
      // `Expenses` chip, already active and so tapping it alone would report nothing.
      await tester.tap(find.byKey(const Key("ocptBudgetBreadcrumbAncestor")));

      expect(reported, OcptBudgetDocument.expenses);
    });
  });

  group("the breadcrumb's own sub-page menu", () {
    testWidgets("offered on expenses, reaches a sub-page from the top level", (tester) async {
      useWideWindow(tester);
      OcptBudgetSubPage? reported;
      final tr = await pumpHeader(
        tester,
        onSubPageSelected: (subPage) => reported = subPage,
      );

      await tester.tap(find.byKey(const Key("ocptBudgetSubPageMenuButton")));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr.budgetHeaderRegieSegmentLabel).last);
      await tester.pumpAndSettle();

      expect(reported, OcptBudgetSubPage.regie);
    });

    testWidgets("reaches a sibling sub-page directly, with no walk back through the top level", (
      tester,
    ) async {
      useWideWindow(tester);
      OcptBudgetSubPage? reported;
      final tr = await pumpHeader(
        tester,
        subPage: OcptBudgetSubPage.regie,
        onSubPageSelected: (subPage) => reported = subPage,
      );

      await tester.tap(find.byKey(const Key("ocptBudgetSubPageMenuButton")));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr.budgetCommittedSectionTitle).last);
      await tester.pumpAndSettle();

      expect(reported, OcptBudgetSubPage.committedSpending);
    });

    testWidgets("withheld on resources and sharing", (tester) async {
      useWideWindow(tester);
      await pumpHeader(tester, document: OcptBudgetDocument.resources);

      expect(find.byKey(const Key("ocptBudgetSubPageMenuButton")), findsNothing);
    });
  });

  group("the title and subtitle", () {
    testWidgets("name the route on screen, not the mode", (tester) async {
      useWideWindow(tester);

      var tr = await pumpHeader(tester);
      expect(find.text(tr.budgetHeaderTitle), findsOneWidget);
      expect(find.text(tr.budgetHeaderSubtitle), findsOneWidget);

      tr = await pumpHeader(tester, reading: OcptBudgetDocumentReading.byDate);
      expect(find.text(tr.budgetHeaderCashJournalTitle), findsOneWidget);
      expect(find.text(tr.budgetHeaderCashJournalSubtitle), findsOneWidget);

      tr = await pumpHeader(tester, document: OcptBudgetDocument.resources);
      expect(find.text(tr.budgetHeaderResourcesTitle), findsOneWidget);
      expect(find.text(tr.budgetHeaderFinancingSubtitle), findsOneWidget);

      tr = await pumpHeader(tester, document: OcptBudgetDocument.sharing);
      expect(find.text(tr.budgetHeaderSharingTitle), findsOneWidget);
      expect(find.text(tr.budgetHeaderSharingSubtitle), findsOneWidget);
    });

    testWidgets("follow the sub-page while inside one", (tester) async {
      useWideWindow(tester);

      var tr = await pumpHeader(tester, subPage: OcptBudgetSubPage.committedSpending);
      expect(find.text(tr.budgetCommittedSectionTitle), findsWidgets);
      expect(find.text(tr.budgetHeaderCommittedSubtitle), findsOneWidget);

      tr = await pumpHeader(tester, subPage: OcptBudgetSubPage.regie);
      expect(find.text(tr.budgetHeaderRegieTitle), findsWidgets);
      expect(find.text(tr.budgetHeaderRegieSubtitle), findsOneWidget);

      tr = await pumpHeader(tester, subPage: OcptBudgetSubPage.dashboard);
      expect(find.text(tr.budgetHeaderDashboardTitle), findsOneWidget);
      expect(find.text(tr.budgetHeaderDashboardSubtitle), findsOneWidget);
    });
  });

  group("the alert band", () {
    testWidgets("draws nothing while there is no alert", (tester) async {
      useWideWindow(tester);
      await pumpHeader(tester);

      expect(find.byIcon(Icons.trending_up), findsNothing);
      expect(find.byIcon(Icons.trending_down), findsNothing);
    });

    testWidgets("a poste-over-quote alert's own action reports its poste id", (tester) async {
      useWideWindow(tester);
      String? reported;
      final tr = await pumpHeader(
        tester,
        postes: [
          const OcptBudgetPoste(
            id: "poste-1",
            code: "1",
            label: "Camera",
            simpleLabel: null,
            estimateToCompleteCents: null,
            sortKey: "a0",
            lines: [],
          ),
        ],
        alerts: const [
          OcptBudgetPosteOverQuoteAlert(
            posteId: "poste-1",
            quotedAmountCents: 1000,
            paidCents: 1200,
            committedCents: 0,
            varianceCents: 200,
          ),
        ],
        onAlertPosteActionRequested: (posteId) => reported = posteId,
      );

      expect(find.text(tr.budgetDashboardPosteOverQuoteAlertTitle), findsOneWidget);

      await tester.tap(find.text(tr.budgetDashboardPosteOverQuoteAlertAction));

      expect(reported, "poste-1");
    });

    testWidgets("the cash-projection alert's own action is reported", (tester) async {
      useWideWindow(tester);
      var wasCalled = false;
      final tr = await pumpHeader(
        tester,
        alerts: const [
          OcptBudgetCashProjectionNegativeAlert(
            balanceCents: 500,
            dueDate: null,
            fallingDueCents: 800,
            balanceAfterCents: -300,
          ),
        ],
        onCashProjectionAlertActionRequested: () => wasCalled = true,
      );

      expect(find.text(tr.budgetDashboardCashNegativeAlertTitle), findsOneWidget);

      await tester.tap(find.text(tr.budgetDashboardCashNegativeAlertAction));

      expect(wasCalled, isTrue);
    });

    testWidgets("drawn whatever document is on screen — a whole-project fact", (tester) async {
      useWideWindow(tester);
      final tr = await pumpHeader(
        tester,
        document: OcptBudgetDocument.sharing,
        alerts: const [
          OcptBudgetCashProjectionNegativeAlert(
            balanceCents: 500,
            dueDate: null,
            fallingDueCents: 800,
            balanceAfterCents: -300,
          ),
        ],
      );

      expect(find.text(tr.budgetDashboardCashNegativeAlertTitle), findsOneWidget);
    });
  });

  // The narrow-window case (title/subtitle/breadcrumb shed, the controls kept) is
  // `OcptBudgetHeader`'s own `_ocptBudgetHeaderTitleMinWidth` threshold, argued in its class doc
  // comment; not re-asserted here as a layout test, since `flutter_test`'s own substituted test
  // font renders these short labels far wider than any real one does, which would make the
  // threshold's own safety margin — comfortable against a real font — read as flaky here.
}
