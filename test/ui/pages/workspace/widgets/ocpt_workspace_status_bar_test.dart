// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_status_bar.dart';

/// Five synthetic counters, ordered from most to least essential, mirroring the screenplay
/// status bar's own pages/scenes/characters/words/signs order and 3-entry non-droppable floor.
const _counters = [
  "42 pages",
  "10 scenes",
  "6 characters",
  "8640 words",
  "51200 signs",
];

const _trailingText = "Saved 2 min ago";

/// Builds the status bar under test, constrained to [width] so the narrow-width degradation
/// tests can force a tight layout, and widens the test surface well past [width] first (the
/// default 800x600 test surface would otherwise clamp a wide bar before it gets the chance to
/// show every counter).
///
/// The bar's `trailing` slot is styled with the same `labelSmall` text style its own summary
/// uses: this mirrors how the real screenplay status bar always keeps its `trailing` slot
/// (`OcptEditorSavedTimeSegment`) in that same style, so the degradation decision (measured
/// against `trailingText` in that style) and what's actually rendered never disagree on size.
Future<void> _pumpStatusBar(
  WidgetTester tester, {
  required double width,
  int nonDroppableCount = 3,
}) async {
  tester.view.physicalSize = Size(width + 200, 600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: Builder(
            builder: (context) => OcptWorkspaceStatusBar(
              counters: _counters,
              nonDroppableCount: nonDroppableCount,
              trailingText: _trailingText,
              trailing: Text(
                _trailingText,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets("a wide status bar shows every counter and the trailing widget", (tester) async {
    await _pumpStatusBar(tester, width: 1100);

    for (final counter in _counters) {
      expect(find.textContaining(counter), findsOneWidget);
    }
    expect(find.text(_trailingText), findsOneWidget);
  });

  testWidgets(
    "narrowing the status bar drops the last droppable counter first, keeping the rest",
    (tester) async {
      await _pumpStatusBar(tester, width: 850);

      expect(find.textContaining("42 pages"), findsOneWidget);
      expect(find.textContaining("10 scenes"), findsOneWidget);
      expect(find.textContaining("6 characters"), findsOneWidget);
      expect(find.textContaining("8640 words"), findsOneWidget);
      expect(find.textContaining("51200 signs"), findsNothing);
      expect(find.text(_trailingText), findsOneWidget);
    },
  );

  testWidgets(
    "narrowing the status bar further drops down to the non-droppable floor and never below it",
    (tester) async {
      await _pumpStatusBar(tester, width: 650);

      expect(find.textContaining("42 pages"), findsOneWidget);
      expect(find.textContaining("10 scenes"), findsOneWidget);
      expect(find.textContaining("6 characters"), findsOneWidget);
      expect(find.textContaining("8640 words"), findsNothing);
      expect(find.textContaining("51200 signs"), findsNothing);
      // The trailing widget always renders, however narrow the bar gets: only the counters
      // summary degrades.
      expect(find.text(_trailingText), findsOneWidget);
    },
  );
}
