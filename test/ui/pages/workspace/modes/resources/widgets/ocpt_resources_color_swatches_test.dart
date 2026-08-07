// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/constants/ocpt_coverage_palette.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_color_swatches.dart';

/// The label of the control opening the popover these tests pump.
const String _anchorLabel = "Pick";

void main() {
  /// The palette indices the pumped grid reported.
  late List<int> picks;

  setUp(() => picks = []);

  /// Pumps the grid exactly where the app puts it — inside a [MenuAnchor]'s `menuChildren`, which
  /// is the one place its layout is constrained the way it is — and opens the popover.
  Future<void> pumpOpenPopover(WidgetTester tester, {int currentColorIndex = 0}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: MenuAnchor(
              menuChildren: [
                OcptResourcesColorSwatches(
                  currentColorIndex: currentColorIndex,
                  onSelected: picks.add,
                ),
              ],
              builder: (context, controller, child) =>
                  TextButton(onPressed: controller.open, child: const Text(_anchorLabel)),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text(_anchorLabel));
    await tester.pumpAndSettle();
  }

  /// The [Finder] of the grid's swatches, in palette order.
  Finder swatches() => find.descendant(
    of: find.byType(OcptResourcesColorSwatches),
    matching: find.byType(InkWell),
  );

  testWidgets("the whole palette lays out inside a popover", (tester) async {
    // The regression this pins: a swatch used to be a `MenuItemButton`, whose label is an
    // `Expanded` inside a maximum-sized `Row`. The `Wrap` holding the grid gives its children an
    // unbounded width, so laying one out threw before a single swatch could be seen.
    await pumpOpenPopover(tester);

    expect(tester.takeException(), isNull);
    expect(swatches(), findsNWidgets(ocptCoveragePalette.length));
  });

  testWidgets("picking a swatch reports its index and closes the popover", (tester) async {
    await pumpOpenPopover(tester);

    await tester.tap(swatches().at(3));
    await tester.pumpAndSettle();

    expect(picks, [3]);
    expect(swatches(), findsNothing);
  });

  testWidgets("the swatch currently worn is the only one ringed", (tester) async {
    await pumpOpenPopover(tester, currentColorIndex: 5);

    final ringed = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(OcptResourcesColorSwatches),
            matching: find.byType(Container),
          ),
        )
        .where((container) => (container.decoration! as BoxDecoration).border != null);

    expect(ringed, hasLength(1));
    expect(
      (ringed.single.decoration! as BoxDecoration).color,
      Color(ocptCoveragePalette[5]),
    );
  });
}
