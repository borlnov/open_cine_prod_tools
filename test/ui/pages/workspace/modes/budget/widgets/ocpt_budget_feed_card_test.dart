// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_feed_card.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve.
Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 480, height: 400, child: child)),
);

/// Pumps [OcptBudgetFeedCard] with the neutral defaults every test but the one it varies wants —
/// every callback offered (non-null) unless a test overrides it, mirroring the previous
/// `ocpt_budget_dashboard_test.dart`'s own `_pumpDashboard`.
Future<Tr> _pumpFeedCard(
  WidgetTester tester, {
  int breakdownPricedElementCount = 3,
  int breakdownUnpricedElementCount = 2,
  int shootingDayCount = 12,
  int mealCount = 8,
  int buffetCount = 8,
  VoidCallback? onBreakdownFeedRequested = _noop,
  VoidCallback? onScheduleFeedRequested = _noop,
  VoidCallback? onCateringFeedRequested = _noop,
}) async {
  await tester.pumpWidget(
    _wrap(
      OcptBudgetFeedCard(
        breakdownPricedElementCount: breakdownPricedElementCount,
        breakdownUnpricedElementCount: breakdownUnpricedElementCount,
        shootingDayCount: shootingDayCount,
        mealCount: mealCount,
        buffetCount: buffetCount,
        onBreakdownFeedRequested: onBreakdownFeedRequested,
        onScheduleFeedRequested: onScheduleFeedRequested,
        onCateringFeedRequested: onCateringFeedRequested,
      ),
    ),
  );
  await tester.pumpAndSettle();

  return Tr.of(tester.element(find.byType(OcptBudgetFeedCard)));
}

/// A callback that does nothing — the default for a test not concerned with what a tap dispatches.
void _noop() {}

void main() {
  group("the three rows", () {
    testWidgets("each prints its own title and one-line reading", (tester) async {
      final tr = await _pumpFeedCard(tester);

      expect(find.text(tr.budgetDashboardFeedSectionTitle), findsOneWidget);
      expect(find.text(tr.budgetDashboardFeedBreakdownTitle), findsOneWidget);
      expect(find.text(tr.budgetDashboardFeedBreakdownReadOut(3, 5)), findsOneWidget);
      expect(find.text(tr.budgetDashboardFeedScheduleTitle), findsOneWidget);
      expect(find.text(tr.budgetDashboardFeedScheduleReadOut(12)), findsOneWidget);
      expect(find.text(tr.budgetDashboardFeedCateringTitle), findsOneWidget);
      expect(find.text(tr.budgetDashboardFeedCateringReadOut(8, 8)), findsOneWidget);
    });

    testWidgets("each reports its own click through its own callback", (tester) async {
      var breakdownRequested = false;
      var scheduleRequested = false;
      var cateringRequested = false;

      final tr = await _pumpFeedCard(
        tester,
        onBreakdownFeedRequested: () => breakdownRequested = true,
        onScheduleFeedRequested: () => scheduleRequested = true,
        onCateringFeedRequested: () => cateringRequested = true,
      );

      await tester.tap(find.text(tr.budgetDashboardFeedBreakdownTitle));
      await tester.tap(find.text(tr.budgetDashboardFeedScheduleTitle));
      await tester.tap(find.text(tr.budgetDashboardFeedCateringTitle));
      await tester.pumpAndSettle();

      expect(breakdownRequested, isTrue);
      expect(scheduleRequested, isTrue);
      expect(cateringRequested, isTrue);
    });
  });

  group("a null callback", () {
    testWidgets("withholds its own row whole, rather than drawing it inert", (tester) async {
      final tr = await _pumpFeedCard(tester, onCateringFeedRequested: null);

      expect(find.text(tr.budgetDashboardFeedBreakdownTitle), findsOneWidget);
      expect(find.text(tr.budgetDashboardFeedScheduleTitle), findsOneWidget);
      expect(find.text(tr.budgetDashboardFeedCateringTitle), findsNothing);
    });

    testWidgets("every row can be withheld at once, leaving only the section title", (tester) async {
      final tr = await _pumpFeedCard(
        tester,
        onBreakdownFeedRequested: null,
        onScheduleFeedRequested: null,
        onCateringFeedRequested: null,
      );

      expect(find.text(tr.budgetDashboardFeedSectionTitle), findsOneWidget);
      expect(find.text(tr.budgetDashboardFeedBreakdownTitle), findsNothing);
      expect(find.text(tr.budgetDashboardFeedScheduleTitle), findsNothing);
      expect(find.text(tr.budgetDashboardFeedCateringTitle), findsNothing);
    });
  });
}
