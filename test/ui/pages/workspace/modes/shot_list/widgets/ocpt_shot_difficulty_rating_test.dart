// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_difficulty_rating.dart';

/// Wraps [child] in a minimal app, no localization needed: the widget takes its label as plain
/// text.
Widget _wrapInApp(Widget child) =>
    MaterialApp(home: Scaffold(body: Align(alignment: Alignment.topLeft, child: child)));

void main() {
  testWidgets("shows the numeric value and fills dots up to it", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(OcptShotDifficultyRating(label: "Set", value: 2, onChanged: (_) {})),
    );

    expect(find.text("Set"), findsOneWidget);
    expect(find.text("2"), findsOneWidget);
  });

  testWidgets("clicking the n-th dot reports its value", (tester) async {
    int? reported;

    await tester.pumpWidget(
      _wrapInApp(
        OcptShotDifficultyRating(
          label: "Camera move",
          value: 0,
          onChanged: (value) => reported = value,
        ),
      ),
    );

    // Six dots (values 0-5), the label sits before them: the fourth dot (value 3) is the fifth
    // InkWell of the row.
    final dots = find.byType(InkWell);
    expect(dots, findsNWidgets(6));

    await tester.tap(dots.at(3));
    await tester.pump();

    expect(reported, 3);
  });
}
