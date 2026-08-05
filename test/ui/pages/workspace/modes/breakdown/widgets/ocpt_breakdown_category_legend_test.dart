// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_category_legend.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_legend.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a sized box
/// standing in for the `OcptWorkspaceDock` column the legend sits in.
Widget _wrapInApp(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 280, height: 600, child: child)),
);

void main() {
  const propEntry = OcptBreakdownLegendEntry(
    kind: OcptBreakdownTargetKind.element,
    category: OcptElementCategory.prop,
    color: 0xFFFFD166,
    count: 3,
  );
  const roleEntry = OcptBreakdownLegendEntry(
    kind: OcptBreakdownTargetKind.role,
    category: null,
    color: 0xFF9B8AFB,
    count: 2,
  );

  /// Pumps the legend with [hiddenKeys] hidden, returning the (live) lists every toggle and `Show
  /// all` click is recorded into — mutable, so a caller can `tester.tap` after this returns and
  /// still observe what landed.
  Future<(List<OcptBreakdownLegendKey> toggled, List<void> showAllClicks)> pumpLegend(
    WidgetTester tester, {
    List<OcptBreakdownLegendEntry> entries = const [propEntry, roleEntry],
    Set<OcptBreakdownLegendKey> hiddenKeys = const {},
  }) async {
    final toggled = <OcptBreakdownLegendKey>[];
    final showAllClicks = <void>[];

    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownCategoryLegend(
          entries: entries,
          hiddenKeys: hiddenKeys,
          onEntryToggled: toggled.add,
          onShowAllRequested: () => showAllClicks.add(null),
        ),
      ),
    );
    await tester.pumpAndSettle();

    return (toggled, showAllClicks);
  }

  testWidgets("lists one row per entry, with its label and count", (tester) async {
    await pumpLegend(tester);

    final tr = Tr.of(tester.element(find.byType(OcptBreakdownCategoryLegend)));
    expect(find.text(tr.breakdownLegendTitle), findsOneWidget);
    expect(find.text(tr.resourcesElementCategoryProp), findsOneWidget);
    expect(find.text(tr.breakdownTargetKindRoleLabel), findsOneWidget);
    expect(find.text("3"), findsOneWidget);
    expect(find.text("2"), findsOneWidget);
  });

  testWidgets("an empty target list shows no row and no `Show all` action", (tester) async {
    await pumpLegend(tester, entries: const []);

    final tr = Tr.of(tester.element(find.byType(OcptBreakdownCategoryLegend)));
    expect(find.text(tr.breakdownLegendShowAllAction), findsNothing);
  });

  testWidgets("clicking a row reports its key", (tester) async {
    final (toggled, _) = await pumpLegend(tester);
    final tr = Tr.of(tester.element(find.byType(OcptBreakdownCategoryLegend)));

    await tester.tap(find.text(tr.resourcesElementCategoryProp));
    await tester.pump();

    expect(toggled, [(OcptBreakdownTargetKind.element, OcptElementCategory.prop)]);
  });

  testWidgets("`Show all` only appears while something is hidden", (tester) async {
    await pumpLegend(tester);
    final tr = Tr.of(tester.element(find.byType(OcptBreakdownCategoryLegend)));
    expect(find.text(tr.breakdownLegendShowAllAction), findsNothing);

    await pumpLegend(
      tester,
      hiddenKeys: {(OcptBreakdownTargetKind.element, OcptElementCategory.prop)},
    );
    expect(find.text(tr.breakdownLegendShowAllAction), findsOneWidget);
  });

  testWidgets("clicking `Show all` reports it", (tester) async {
    final (_, showAllClicks) = await pumpLegend(
      tester,
      hiddenKeys: {(OcptBreakdownTargetKind.element, OcptElementCategory.prop)},
    );
    final tr = Tr.of(tester.element(find.byType(OcptBreakdownCategoryLegend)));

    await tester.tap(find.text(tr.breakdownLegendShowAllAction));
    await tester.pump();

    expect(showAllClicks, hasLength(1));
  });

  testWidgets("a hidden entry's row is dimmed", (tester) async {
    await pumpLegend(
      tester,
      hiddenKeys: {(OcptBreakdownTargetKind.element, OcptElementCategory.prop)},
    );

    final opacities = tester.widgetList<Opacity>(find.byType(Opacity)).map((o) => o.opacity).toList();
    expect(opacities, contains(lessThan(1)));
    expect(opacities, contains(1));
  });
}
