// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_centre_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_header.dart';

/// The width the header is pumped at — wide enough that every element (the switch, the 260 px
/// search field, the hint and the progress label/bar) fits without dropping anything, which the
/// header's own layout does not attempt in the first place (unlike the status bar's own
/// narrow-width degradation).
const double _headerWidth = 1100;

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a band
/// [_headerWidth] wide. Widens the test surface well past that first — the default 800×600 test
/// surface would otherwise clamp the header before it gets the chance to show every element.
Widget _wrapInApp(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: _headerWidth, height: 80, child: child),
    ),
  ),
);

void main() {
  /// Pumps the header, recording every reported view selection and query change.
  Future<(List<OcptBreakdownCentreView> views, List<String> queries)> pumpHeader(
    WidgetTester tester, {
    OcptBreakdownCentreView centreView = OcptBreakdownCentreView.script,
    String searchQuery = "",
    int taggedTargetCount = 3,
    int doneSceneCount = 1,
    int sceneCount = 4,
  }) async {
    tester.view.physicalSize = const Size(_headerWidth + 200, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final views = <OcptBreakdownCentreView>[];
    final queries = <String>[];

    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownHeader(
          centreView: centreView,
          onCentreViewSelected: views.add,
          searchQuery: searchQuery,
          onSearchQueryChanged: queries.add,
          taggedTargetCount: taggedTargetCount,
          doneSceneCount: doneSceneCount,
          sceneCount: sceneCount,
        ),
      ),
    );
    await tester.pumpAndSettle();

    return (views, queries);
  }

  testWidgets("shows the script hint while the script view is active", (tester) async {
    await pumpHeader(tester);
    final tr = Tr.of(tester.element(find.byType(OcptBreakdownHeader)));

    expect(find.text(tr.breakdownHeaderScriptSegmentLabel), findsOneWidget);
    expect(find.text(tr.breakdownHeaderRecapSegmentLabel), findsOneWidget);
    expect(find.text(tr.breakdownHeaderScriptHint), findsOneWidget);
    expect(find.text(tr.breakdownHeaderRecapHint), findsNothing);
  });

  testWidgets("shows the recap hint while the recap view is active", (tester) async {
    await pumpHeader(tester, centreView: OcptBreakdownCentreView.recap);
    final tr = Tr.of(tester.element(find.byType(OcptBreakdownHeader)));

    expect(find.text(tr.breakdownHeaderRecapHint), findsOneWidget);
    expect(find.text(tr.breakdownHeaderScriptHint), findsNothing);
  });

  testWidgets("clicking the Recap segment reports it", (tester) async {
    final (views, _) = await pumpHeader(tester);
    final tr = Tr.of(tester.element(find.byType(OcptBreakdownHeader)));

    await tester.tap(find.text(tr.breakdownHeaderRecapSegmentLabel));
    await tester.pump();

    expect(views, [OcptBreakdownCentreView.recap]);
  });

  testWidgets("clicking the already-active segment reports nothing", (tester) async {
    final (views, _) = await pumpHeader(tester);
    final tr = Tr.of(tester.element(find.byType(OcptBreakdownHeader)));

    await tester.tap(find.text(tr.breakdownHeaderScriptSegmentLabel));
    await tester.pump();

    expect(views, isEmpty);
  });

  testWidgets("typing into the search field reports it", (tester) async {
    final (_, queries) = await pumpHeader(tester);

    await tester.enterText(find.byType(TextField), "Peugeot");
    await tester.pump();

    expect(queries, ["Peugeot"]);
  });

  testWidgets("the clear button only shows once the query is non-empty, and reports an empty one",
      (tester) async {
    final (_, queries) = await pumpHeader(tester, searchQuery: "Peugeot");
    final tr = Tr.of(tester.element(find.byType(OcptBreakdownHeader)));

    expect(find.byTooltip(tr.breakdownHeaderSearchClearTooltip), findsOneWidget);

    await tester.tap(find.byTooltip(tr.breakdownHeaderSearchClearTooltip));
    await tester.pump();

    expect(queries, [""]);
  });

  testWidgets("no clear button shows while the query is empty", (tester) async {
    await pumpHeader(tester);
    final tr = Tr.of(tester.element(find.byType(OcptBreakdownHeader)));

    expect(find.byTooltip(tr.breakdownHeaderSearchClearTooltip), findsNothing);
  });

  testWidgets("shows the tagged and scenes-done progress label", (tester) async {
    await pumpHeader(tester, taggedTargetCount: 7, doneSceneCount: 2, sceneCount: 5);
    final tr = Tr.of(tester.element(find.byType(OcptBreakdownHeader)));

    expect(
      find.text("${tr.breakdownStatsTagged(7)} · ${tr.breakdownHeaderScenesProgressLabel(2, 5)}"),
      findsOneWidget,
    );
  });

  testWidgets("the progress bar fills to done/total", (tester) async {
    await pumpHeader(tester);

    final track = tester.widget<Container>(
      find.ancestor(
        of: find.byType(FractionallySizedBox),
        matching: find.byType(Container),
      ),
    );
    final fill = tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox));

    expect((track.decoration! as BoxDecoration).borderRadius, isNotNull);
    expect(fill.widthFactor, closeTo(0.25, 0.0001));
  });

  testWidgets("the progress bar is empty while there is no scene at all", (tester) async {
    await pumpHeader(tester, doneSceneCount: 0, sceneCount: 0);

    final fill = tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox));

    expect(fill.widthFactor, 0);
  });
}
