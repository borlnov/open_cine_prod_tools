// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tools_view.dart';
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
  /// Widens the test surface — `flutter_test`'s own substituted test font renders these short
  /// labels far wider than any real one does, which would make the narrow-window wrapping case
  /// below read as flaky at the default 800×600 test surface.
  void useWideWindow(WidgetTester tester) {
    tester.view.physicalSize = const Size(2200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Pumps [OcptBudgetHeader] with every prop at a sensible default, overridable one at a time —
  /// [view] at [OcptBudgetView.expenses], with every control's own callback recording nothing
  /// unless the test itself cares.
  Future<Tr> pumpHeader(
    WidgetTester tester, {
    OcptBudgetView view = OcptBudgetView.expenses,
    ValueChanged<OcptBudgetView>? onViewSelected,
    OcptBudgetToolsView toolsView = OcptBudgetToolsView.cashFlow,
    ValueChanged<OcptBudgetToolsView>? onToolsViewSelected,
    bool isSimplified = false,
    ValueChanged<bool>? onSimplifiedChanged,
    OcptBudgetTaxBasis taxBasis = OcptBudgetTaxBasis.includingTax,
    ValueChanged<OcptBudgetTaxBasis>? onTaxBasisChanged,
    List<OcptBudgetPoste> postes = const [],
    String? filterPosteId,
    VoidCallback? onPosteFilterCleared,
    int alertCount = 0,
  }) async {
    await tester.pumpWidget(
      _wrap(
        OcptBudgetHeader(
          view: view,
          onViewSelected: onViewSelected ?? (_) {},
          toolsView: toolsView,
          onToolsViewSelected: onToolsViewSelected ?? (_) {},
          isSimplified: isSimplified,
          onSimplifiedChanged: onSimplifiedChanged ?? (_) {},
          taxBasis: taxBasis,
          onTaxBasisChanged: onTaxBasisChanged ?? (_) {},
          postes: postes,
          filterPosteId: filterPosteId,
          onPosteFilterCleared: onPosteFilterCleared ?? () {},
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
    // switch and the tax-basis switch all honoured at [OcptBudgetView.expenses].
    expect(find.text(tr.budgetHeaderExpensesSegmentLabel), findsOneWidget);
    expect(find.text(tr.budgetHeaderToolsSegmentLabel), findsOneWidget);
    expect(find.text(tr.budgetHeaderSimplifiedSegmentLabel), findsOneWidget);
    expect(find.text(tr.budgetHeaderExcludingTaxSegmentLabel), findsOneWidget);

    // And it is still tappable, which a clipped one would not be.
    await tester.tap(find.text(tr.budgetHeaderExcludingTaxSegmentLabel));
    expect(tester.takeException(), isNull);
  });

  group("the view switch", () {
    testWidgets("draws four segments, in chip order", (tester) async {
      useWideWindow(tester);
      final tr = await pumpHeader(tester);

      final labels = [
        tr.budgetHeaderDashboardSegmentLabel,
        tr.budgetHeaderExpensesSegmentLabel,
        tr.budgetHeaderResourcesSegmentLabel,
        tr.budgetHeaderToolsSegmentLabel,
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
      final tr = await pumpHeader(tester, view: OcptBudgetView.resources);

      final segment = tester.widget<InkWell>(
        find.ancestor(
          of: find.text(tr.budgetHeaderResourcesSegmentLabel),
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

      await tester.tap(find.text(tr.budgetHeaderResourcesSegmentLabel));

      expect(reported, [OcptBudgetView.resources]);
    });

    testWidgets("tapping the active chip reports nothing", (tester) async {
      useWideWindow(tester);
      var callCount = 0;
      final tr = await pumpHeader(tester, onViewSelected: (_) => callCount++);

      await tester.tap(find.text(tr.budgetHeaderExpensesSegmentLabel));

      expect(callCount, 0);
    });
  });

  group("the tools drawer switch", () {
    testWidgets("draws only while the tools chip is active", (tester) async {
      useWideWindow(tester);
      var tr = await pumpHeader(tester);
      expect(find.text(tr.budgetHeaderCashFlowSegmentLabel), findsNothing);

      tr = await pumpHeader(tester, view: OcptBudgetView.tools);
      expect(find.text(tr.budgetHeaderCashFlowSegmentLabel), findsOneWidget);
      expect(find.text(tr.budgetHeaderRegieSegmentLabel), findsOneWidget);
      expect(find.text(tr.budgetHeaderSharingSegmentLabel), findsOneWidget);
    });

    testWidgets("the active page's own segment is marked", (tester) async {
      useWideWindow(tester);
      final tr = await pumpHeader(
        tester,
        view: OcptBudgetView.tools,
        toolsView: OcptBudgetToolsView.regie,
      );

      final segment = tester.widget<InkWell>(
        find.ancestor(
          of: find.text(tr.budgetHeaderRegieSegmentLabel),
          matching: find.byType(InkWell),
        ),
      );
      expect(segment.onTap, isNull);
    });

    testWidgets("clicking a segment reports that page, and only that page", (tester) async {
      useWideWindow(tester);
      final reported = <OcptBudgetToolsView>[];
      final tr = await pumpHeader(
        tester,
        view: OcptBudgetView.tools,
        onToolsViewSelected: reported.add,
      );

      await tester.tap(find.text(tr.budgetHeaderSharingSegmentLabel));

      expect(reported, [OcptBudgetToolsView.sharing]);
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

    testWidgets("offered on the tools drawer's own cash flow page too", (tester) async {
      useWideWindow(tester);
      final tr = await pumpHeader(tester, view: OcptBudgetView.tools);

      expect(find.text(tr.budgetHeaderExcludingTaxSegmentLabel), findsOneWidget);
    });

    testWidgets("offered on the dashboard too, since its own KPI tiles read it", (tester) async {
      useWideWindow(tester);
      final tr = await pumpHeader(tester, view: OcptBudgetView.dashboard);

      expect(find.text(tr.budgetHeaderExcludingTaxSegmentLabel), findsOneWidget);
    });

    testWidgets(
      "withheld outside the dashboard, expenses and the tools drawer's own cash flow page",
      (tester) async {
        useWideWindow(tester);
        final tr = await pumpHeader(tester, view: OcptBudgetView.resources);
        expect(find.text(tr.budgetHeaderExcludingTaxSegmentLabel), findsNothing);

        for (final toolsView in [OcptBudgetToolsView.regie, OcptBudgetToolsView.sharing]) {
          final tr = await pumpHeader(tester, view: OcptBudgetView.tools, toolsView: toolsView);
          expect(
            find.text(tr.budgetHeaderExcludingTaxSegmentLabel),
            findsNothing,
            reason: "$toolsView",
          );
        }
      },
    );
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

    testWidgets("offered on expenses alone", (tester) async {
      useWideWindow(tester);
      final tr = await pumpHeader(tester);
      expect(find.text(tr.budgetHeaderSimplifiedSegmentLabel), findsOneWidget);
    });

    testWidgets(
      "withheld — never disabled — on the dashboard, resources and every page of the tools "
      "drawer",
      (tester) async {
        useWideWindow(tester);
        var tr = await pumpHeader(tester, view: OcptBudgetView.dashboard);
        expect(find.text(tr.budgetHeaderSimplifiedSegmentLabel), findsNothing);

        tr = await pumpHeader(tester, view: OcptBudgetView.resources);
        expect(find.text(tr.budgetHeaderSimplifiedSegmentLabel), findsNothing);

        for (final toolsView in OcptBudgetToolsView.values) {
          final tr = await pumpHeader(tester, view: OcptBudgetView.tools, toolsView: toolsView);
          expect(
            find.text(tr.budgetHeaderSimplifiedSegmentLabel),
            findsNothing,
            reason: "$toolsView",
          );
        }
      },
    );
  });

  group("the poste filter tag", () {
    final poste = const OcptBudgetPoste(
      id: "poste-1",
      code: "1",
      label: "Interpretation",
      simpleLabel: null,
      estimateToCompleteCents: null,
      sortKey: "a0",
      lines: [],
    );

    testWidgets("draws nothing at all while unfiltered", (tester) async {
      useWideWindow(tester);
      await pumpHeader(tester, postes: [poste]);

      expect(find.text("Interpretation"), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets("names the filtered poste, and offers to clear it", (tester) async {
      useWideWindow(tester);
      var wasCalled = false;
      await pumpHeader(
        tester,
        postes: [poste],
        filterPosteId: "poste-1",
        onPosteFilterCleared: () => wasCalled = true,
      );

      expect(find.text("Interpretation"), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(wasCalled, isTrue);
    });

    testWidgets(
      "stands on every route, whether or not it is honoured there",
      (tester) async {
        useWideWindow(tester);
        for (final view in OcptBudgetView.values) {
          await pumpHeader(tester, postes: [poste], filterPosteId: "poste-1", view: view);
          expect(find.text("Interpretation"), findsOneWidget, reason: "$view");
        }
      },
    );

    testWidgets("draws nothing while filterPosteId names no live poste", (tester) async {
      useWideWindow(tester);
      await pumpHeader(tester, postes: [poste], filterPosteId: "gone");

      expect(find.text("Interpretation"), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing);
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
      await pumpHeader(
        tester,
        view: OcptBudgetView.tools,
        toolsView: OcptBudgetToolsView.sharing,
        alertCount: 1,
      );

      expect(find.byKey(const Key("ocptBudgetAlertCountBadge")), findsOneWidget);
      expect(find.text("1"), findsOneWidget);
    });
  });
}
