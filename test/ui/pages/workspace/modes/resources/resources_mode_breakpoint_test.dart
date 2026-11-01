// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'resources_mode_scenarios_test_doubles.dart';

/// Run the tests of the resources mode breakpoint.
void main() {
  final harness = ResourcesScenarioHarness();

  setUpAll(harness.setUpAll);
  setUp(harness.setUp);
  tearDown(harness.tearDown);

  testWidgets("a position label still waiting in its card is written when the window crosses the "
      "compact breakpoint", (tester) async {
    await harness.seedPerson("Alice");
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.tap(tester, find.text("Alice"));
    await harness.tap(tester, find.text(tr.resourcesAddPositionAction));

    await harness.type(tester, harness.fieldHinted(tr.resourcesPositionLabelHint), "Gaffer");
    tester.view.physicalSize = const Size(700, 1000);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();
    final person = (await harness.readPeople()).single;
    expect(person.positions.map((position) => position.customLabel), contains("Gaffer"));
  });
}
