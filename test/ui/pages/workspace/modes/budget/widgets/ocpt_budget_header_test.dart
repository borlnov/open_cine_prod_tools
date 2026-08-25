// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_view.dart';
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
    tester.view.physicalSize = const Size(2200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Pumps [OcptBudgetHeader] with every prop at a sensible default, overridable one at a time —
  /// [view] at [OcptBudgetView.costTracking], with every control's own callback recording nothing
  /// unless the test itself cares.
  Future<Tr> pumpHeader(
    WidgetTester tester, {
    OcptBudgetView view = OcptBudgetView.costTracking,
    ValueChanged<OcptBudgetView>? onViewSelected,
    bool isSimplified = false,
    ValueChanged<bool>? onSimplifiedChanged,
    OcptBudgetTaxBasis taxBasis = OcptBudgetTaxBasis.includingTax,
    ValueChanged<OcptBudgetTaxBasis>? onTaxBasisChanged,
    List<OcptBudgetPoste> postes = const [],
    String? filterPosteId,
    ValueChanged<String?>? onPosteFilterSelected,
    int alertCount = 0,
  }) async {
    await tester.pumpWidget(
      _wrap(
        OcptBudgetHeader(
          view: view,
          onViewSelected: onViewSelected ?? (_) {},
          isSimplified: isSimplified,
          onSimplifiedChanged: onSimplifiedChanged ?? (_) {},
          taxBasis: taxBasis,
          onTaxBasisChanged: onTaxBasisChanged ?? (_) {},
          postes: postes,
          filterPosteId: filterPosteId,
          onPosteFilterSelected: onPosteFilterSelected ?? (_) {},
          alertCount: alertCount,
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

    // Every control is still on screen, the last one included — the view switch, the simplified
    // switch, the tax-basis switch and the poste filter all honoured at
    // [OcptBudgetView.costTracking].
    expect(find.text(tr.budgetHeaderCostTrackingSegmentLabel), findsOneWidget);
    expect(find.text(tr.budgetHeaderSharingSegmentLabel), findsOneWidget);
    expect(find.text(tr.budgetHeaderSimplifiedSegmentLabel), findsOneWidget);
    expect(find.text(tr.budgetHeaderExcludingTaxSegmentLabel), findsOneWidget);
    expect(find.text(tr.budgetHeaderPosteFilterAllLabel), findsOneWidget);

    // And it is still tappable, which a clipped one would not be.
    await tester.tap(find.text(tr.budgetHeaderExcludingTaxSegmentLabel));
    expect(tester.takeException(), isNull);
  });

  group("the view switch", () {
    testWidgets("draws seven segments, in chip order", (tester) async {
      useWideWindow(tester);
      final tr = await pumpHeader(tester);

      final labels = [
        tr.budgetHeaderDashboardSegmentLabel,
        tr.budgetHeaderCostTrackingSegmentLabel,
        tr.budgetHeaderFinancingSegmentLabel,
        tr.budgetHeaderCashJournalSegmentLabel,
        tr.budgetHeaderCommittedSegmentLabel,
        tr.budgetHeaderRegieSegmentLabel,
        tr.budgetHeaderSharingSegmentLabel,
      ];
      for (final label in labels) {
        expect(find.text(label), findsOneWidget);
      }

      final positions = [
        for (final label in labels) tester.getCenter(find.text(label)).dx,
      ];
      expect(positions, orderedEquals(List<double>.from(positions)..sort()));
    });

    testWidgets("the active view's own chip is marked", (tester) async {
      useWideWindow(tester);
      final tr = await pumpHeader(tester, view: OcptBudgetView.committed);

      final segment = tester.widget<InkWell>(
        find.ancestor(
          of: find.text(tr.budgetHeaderCommittedSegmentLabel),
          matching: find.byType(InkWell),
        ),
      );
      // The active segment's own `InkWell.onTap` is null — it is already active, so tapping it
      // again reports nothing (`_OcptBudgetSwitchSegment`'s own doc comment).
      expect(segment.onTap, isNull);
    });

    testWidgets("clicking a segment reports that view, and only that view", (tester) async {
      useWideWindow(tester);
      final reported = <OcptBudgetView>[];
      final tr = await pumpHeader(tester, onViewSelected: reported.add);

      await tester.tap(find.text(tr.budgetHeaderFinancingSegmentLabel));

      expect(reported, [OcptBudgetView.financing]);
    });

    testWidgets("tapping the active chip reports nothing", (tester) async {
      useWideWindow(tester);
      var callCount = 0;
      final tr = await pumpHeader(tester, onViewSelected: (_) => callCount++);

      await tester.tap(find.text(tr.budgetHeaderCostTrackingSegmentLabel));

      expect(callCount, 0);
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

    testWidgets("offered on the cash journal too", (tester) async {
      useWideWindow(tester);
      final tr = await pumpHeader(tester, view: OcptBudgetView.cashJournal);

      expect(find.text(tr.budgetHeaderExcludingTaxSegmentLabel), findsOneWidget);
    });

    testWidgets("offered on the dashboard too, since its own KPI tiles read it", (tester) async {
      useWideWindow(tester);
      final tr = await pumpHeader(tester, view: OcptBudgetView.dashboard);

      expect(find.text(tr.budgetHeaderExcludingTaxSegmentLabel), findsOneWidget);
    });

    testWidgets("withheld outside the dashboard, the cost report and the cash journal", (
      tester,
    ) async {
      useWideWindow(tester);
      for (final view in [
        OcptBudgetView.financing,
        OcptBudgetView.committed,
        OcptBudgetView.regie,
        OcptBudgetView.sharing,
      ]) {
        final tr = await pumpHeader(tester, view: view);
        expect(find.text(tr.budgetHeaderExcludingTaxSegmentLabel), findsNothing, reason: "$view");
      }
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

    testWidgets("offered on the cost report, the cash journal and the committed spending", (
      tester,
    ) async {
      useWideWindow(tester);
      for (final view in [
        OcptBudgetView.costTracking,
        OcptBudgetView.cashJournal,
        OcptBudgetView.committed,
      ]) {
        final tr = await pumpHeader(tester, view: view);
        expect(find.text(tr.budgetHeaderSimplifiedSegmentLabel), findsOneWidget, reason: "$view");
      }
    });

    testWidgets("withheld — never disabled — on the dashboard, financing, régie and sharing", (
      tester,
    ) async {
      useWideWindow(tester);
      for (final view in [
        OcptBudgetView.dashboard,
        OcptBudgetView.financing,
        OcptBudgetView.regie,
        OcptBudgetView.sharing,
      ]) {
        final tr = await pumpHeader(tester, view: view);
        expect(find.text(tr.budgetHeaderSimplifiedSegmentLabel), findsNothing, reason: "$view");
      }
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

    testWidgets("offered at the cost report, reading Every poste while unfiltered", (
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

    testWidgets("offered on the committed spending too", (tester) async {
      useWideWindow(tester);
      final tr = await pumpHeader(tester, postes: [poste], view: OcptBudgetView.committed);

      expect(find.text(tr.budgetHeaderPosteFilterAllLabel), findsOneWidget);
    });

    testWidgets(
      "withheld outright — never captioned — on the dashboard, financing, régie and sharing",
      (tester) async {
        useWideWindow(tester);
        for (final view in [
          OcptBudgetView.dashboard,
          OcptBudgetView.financing,
          OcptBudgetView.regie,
          OcptBudgetView.sharing,
        ]) {
          final tr = await pumpHeader(tester, postes: [poste], view: view);
          expect(find.text(tr.budgetHeaderPosteFilterAllLabel), findsNothing, reason: "$view");
          expect(find.text("Interpretation"), findsNothing, reason: "$view");
        }
      },
    );
  });

  testWidgets("no breadcrumb and no sub-page menu is drawn anywhere", (tester) async {
    useWideWindow(tester);
    for (final view in OcptBudgetView.values) {
      await pumpHeader(tester, view: view);

      expect(find.byKey(const Key("ocptBudgetBreadcrumbAncestor")), findsNothing, reason: "$view");
      expect(find.byKey(const Key("ocptBudgetSubPageMenuButton")), findsNothing, reason: "$view");
      expect(find.text("›"), findsNothing, reason: "$view");
    }
  });

  group("the title and subtitle", () {
    testWidgets("name the view on screen, not the mode", (tester) async {
      useWideWindow(tester);

      var tr = await pumpHeader(tester, view: OcptBudgetView.dashboard);
      expect(find.text(tr.budgetHeaderDashboardTitle), findsOneWidget);
      expect(find.text(tr.budgetHeaderDashboardSubtitle), findsOneWidget);

      tr = await pumpHeader(tester);
      expect(find.text(tr.budgetHeaderTitle), findsOneWidget);
      expect(find.text(tr.budgetHeaderSubtitle), findsOneWidget);

      tr = await pumpHeader(tester, view: OcptBudgetView.cashJournal);
      expect(find.text(tr.budgetHeaderCashJournalTitle), findsOneWidget);
      expect(find.text(tr.budgetHeaderCashJournalSubtitle), findsOneWidget);

      tr = await pumpHeader(tester, view: OcptBudgetView.committed);
      expect(find.text(tr.budgetCommittedSectionTitle), findsWidgets);
      expect(find.text(tr.budgetHeaderCommittedSubtitle), findsOneWidget);

      tr = await pumpHeader(tester, view: OcptBudgetView.financing);
      expect(find.text(tr.budgetHeaderResourcesTitle), findsOneWidget);
      expect(find.text(tr.budgetHeaderFinancingSubtitle), findsOneWidget);

      tr = await pumpHeader(tester, view: OcptBudgetView.regie);
      expect(find.text(tr.budgetHeaderRegieTitle), findsWidgets);
      expect(find.text(tr.budgetHeaderRegieSubtitle), findsOneWidget);

      // The chip and the title happen to read the same word here, exactly as they do for régie.
      tr = await pumpHeader(tester, view: OcptBudgetView.sharing);
      expect(find.text(tr.budgetHeaderSharingTitle), findsWidgets);
      expect(find.text(tr.budgetHeaderSharingSubtitle), findsOneWidget);
    });
  });

  group("the alert count badge", () {
    testWidgets("nothing is drawn at all while the count is zero", (tester) async {
      useWideWindow(tester);
      await pumpHeader(tester);

      expect(find.byKey(const Key("ocptBudgetAlertCountBadge")), findsNothing);
    });

    testWidgets("a count of two is drawn as 2, on the dashboard segment", (tester) async {
      useWideWindow(tester);
      await pumpHeader(tester, alertCount: 2);

      expect(find.byKey(const Key("ocptBudgetAlertCountBadge")), findsOneWidget);
      expect(find.text("2"), findsOneWidget);
    });

    testWidgets("drawn whatever view is on screen — a whole-project fact", (tester) async {
      useWideWindow(tester);
      await pumpHeader(tester, view: OcptBudgetView.sharing, alertCount: 1);

      expect(find.byKey(const Key("ocptBudgetAlertCountBadge")), findsOneWidget);
      expect(find.text("1"), findsOneWidget);
    });
  });

  // The narrow-window case (title and subtitle shed, the controls kept) is
  // `OcptBudgetHeader`'s own `_ocptBudgetHeaderTitleMinWidth` threshold, argued in its class doc
  // comment; the wide-window tests above assert what survives it rather than the threshold itself,
  // since `flutter_test`'s own substituted test font renders these short labels far wider than any
  // real one does, which would make the threshold's own safety margin — comfortable against a real
  // font — read as flaky here.
}
