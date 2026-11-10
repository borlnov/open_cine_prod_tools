// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_minute_field.dart';

/// Wrap [child] in the minimal app a text field needs.
Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Run the tests of the schedule minute field.
void main() {
  testWidgets("a time typed but not submitted is reported once when the field leaves the tree", (
    tester,
  ) async {
    final reported = <int?>[];

    await tester.pumpWidget(
      _wrap(
        OcptScheduleMinuteField(
          minute: 480,
          isClearable: false,
          emptyHint: "--:--",
          onChanged: reported.add,
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), "09:30");
    await tester.pump();
    expect(reported, isEmpty);

    await tester.pumpWidget(_wrap(const SizedBox.shrink()));
    await tester.pumpAndSettle();

    expect(reported, [570]);
  });

  testWidgets("a field that was not edited reports nothing when it leaves the tree", (
    tester,
  ) async {
    final reported = <int?>[];

    await tester.pumpWidget(
      _wrap(
        OcptScheduleMinuteField(
          minute: 480,
          isClearable: false,
          emptyHint: "--:--",
          onChanged: reported.add,
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();

    await tester.pumpWidget(_wrap(const SizedBox.shrink()));
    await tester.pumpAndSettle();

    expect(reported, isEmpty);
  });
}
