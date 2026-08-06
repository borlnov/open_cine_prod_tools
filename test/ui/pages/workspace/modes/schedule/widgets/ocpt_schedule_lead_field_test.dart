// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_lead_field.dart';

/// Wraps [child] inside a `MaterialApp`/`Scaffold`, the minimal ambient theme a `TextField` needs.
Widget _wrapInApp(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets("a row's own lead shows its own figure, not the inherited one", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        const OcptScheduleLeadField(leadMinutes: 30, inheritedLeadMinutes: 90, isClearable: true, onChanged: null),
      ),
    );

    // Read-only rendering (`onChanged: null`): the row's own figure prints plain, never the
    // group's, since it is set.
    expect(find.text("30 min"), findsOneWidget);
    expect(find.text("90 min"), findsNothing);
  });

  testWidgets("a row with no lead of its own reads its group's, shown as inherited", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        const OcptScheduleLeadField(leadMinutes: null, inheritedLeadMinutes: 45, isClearable: true, onChanged: null),
      ),
    );

    final text = tester.widget<Text>(find.text("45 min"));
    expect(text.style?.fontStyle, FontStyle.italic);
  });

  testWidgets("an editable field with no own value shows the inherited figure as its hint", (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleLeadField(leadMinutes: null, inheritedLeadMinutes: 20, isClearable: true, onChanged: (_) {}),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, "");
    // The hint carries the unit too: unlike the suffix, Material only draws it while the field is
    // empty and unfocused, which is exactly when the hint alone speaks for the field.
    expect(field.decoration?.hintText, "20 min");
  });

  testWidgets("typing a figure and submitting reports it", (tester) async {
    int? reported;
    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleLeadField(leadMinutes: null, isClearable: true, onChanged: (value) => reported = value),
      ),
    );

    await tester.enterText(find.byType(TextField), "45");
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(reported, 45);
  });

  testWidgets("a negative figure is refused rather than reported", (tester) async {
    final reported = <int?>[];
    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleLeadField(leadMinutes: 30, isClearable: true, onChanged: reported.add),
      ),
    );

    await tester.enterText(find.byType(TextField), "-15");
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    // Nothing was reported, and the field reverted to its last valid figure — never a value
    // `ocptComputeSlotConvocations` would throw an `ArgumentError` over.
    expect(reported, isEmpty);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, "30");
  });

  testWidgets("a clearable field submitted empty reports null", (tester) async {
    final reported = <int?>[];
    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleLeadField(leadMinutes: 30, isClearable: true, onChanged: reported.add),
      ),
    );

    await tester.enterText(find.byType(TextField), "");
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(reported, [null]);
  });

  testWidgets("a non-clearable field submitted empty reverts instead of reporting anything", (
    tester,
  ) async {
    final reported = <int?>[];
    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleLeadField(leadMinutes: 60, isClearable: false, onChanged: reported.add),
      ),
    );

    await tester.enterText(find.byType(TextField), "");
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    // A group's own lead time is never cleared back to "unset" — the field snaps back to its own
    // figure instead of accepting the empty submission.
    expect(reported, isEmpty);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, "60");
  });

  testWidgets("submitting the very same figure again reports nothing", (tester) async {
    final reported = <int?>[];
    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleLeadField(leadMinutes: 30, isClearable: true, onChanged: reported.add),
      ),
    );

    await tester.enterText(find.byType(TextField), "30");
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(reported, isEmpty);
  });
}
