// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_group.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_groups_band.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve.
Widget _wrapInApp(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 640, height: 400, child: child)),
);

void main() {
  const groupA = OcptShootingDayGroup(id: "group-1", shootingDayId: "day-1", label: "Figuration", leadMinutes: 90);
  const groupB = OcptShootingDayGroup(
    id: "group-2",
    shootingDayId: "day-1",
    label: "Équipe technique",
    leadMinutes: 30,
  );

  Widget buildBand({
    required bool isReadOnly,
    List<OcptShootingDayGroup> groups = const [],
    Map<String, int> memberCountByGroupId = const {},
    void Function(String groupId, String rawValue)? onLabelChanged,
    void Function(String groupId, int leadMinutes)? onLeadChanged,
    VoidCallback? onGroupAdded,
    ValueChanged<String>? onGroupDeletionRequested,
  }) => OcptScheduleGroupsBand(
    groups: groups,
    memberCountByGroupId: memberCountByGroupId,
    labelValueOf: (groupId) => groups.firstWhere((group) => group.id == groupId).label,
    onLabelChanged: isReadOnly ? null : (onLabelChanged ?? (_, _) {}),
    onLeadChanged: isReadOnly ? null : (onLeadChanged ?? (_, _) {}),
    onGroupAdded: isReadOnly ? null : (onGroupAdded ?? () {}),
    onGroupDeletionRequested: isReadOnly ? null : (onGroupDeletionRequested ?? (_) {}),
  );

  testWidgets("a day with no group shows the band's own empty hint and its `+ Group` control", (
    tester,
  ) async {
    await tester.pumpWidget(_wrapInApp(buildBand(isReadOnly: false)));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleGroupsBand)));
    expect(find.text(tr.scheduleGroupsEmptyHint), findsOneWidget);
    expect(find.text(tr.scheduleAddGroupAction), findsOneWidget);
  });

  testWidgets("the band lists every group with its label, lead time and member count", (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapInApp(
        buildBand(
          isReadOnly: false,
          groups: [groupA, groupB],
          memberCountByGroupId: {"group-1": 3},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleGroupsBand)));
    expect(find.text("Figuration"), findsOneWidget);
    expect(find.text("Équipe technique"), findsOneWidget);
    // Both lead fields are editable (the band is not read-only here), so their own figures are the
    // fields' current text rather than a single "90 min" `Text` widget.
    expect(
      find.byWidgetPredicate((widget) => widget is TextField && widget.controller?.text == "90"),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate((widget) => widget is TextField && widget.controller?.text == "30"),
      findsOneWidget,
    );
    expect(find.text(tr.scheduleGroupMemberCount(3)), findsOneWidget);
    // group-2 has no entry in the counts map at all: it reads as zero members, not "unknown".
    expect(find.text(tr.scheduleGroupMemberCount(0)), findsOneWidget);
  });

  testWidgets("the `+ Group` control dispatches creation", (tester) async {
    var added = false;
    await tester.pumpWidget(_wrapInApp(buildBand(isReadOnly: false, onGroupAdded: () => added = true)));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleGroupsBand)));
    await tester.tap(find.text(tr.scheduleAddGroupAction));
    await tester.pumpAndSettle();

    expect(added, isTrue);
  });

  testWidgets("a group's own label field reports what is typed, keyed by its id", (tester) async {
    final reported = <(String, String)>[];
    await tester.pumpWidget(
      _wrapInApp(
        buildBand(
          isReadOnly: false,
          groups: [groupA],
          onLabelChanged: (groupId, rawValue) => reported.add((groupId, rawValue)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The card holds two `TextField`s (the label field and the lead field); the label one is found
    // by its own current text, "Figuration".
    final labelFieldFinder = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.controller?.text == "Figuration",
    );
    await tester.enterText(labelFieldFinder, "Figurants");
    await tester.pump();

    expect(reported, [("group-1", "Figurants")]);
  });

  testWidgets("a group's own lead field reports what is typed, keyed by its id", (tester) async {
    final reported = <(String, int)>[];
    await tester.pumpWidget(
      _wrapInApp(
        buildBand(
          isReadOnly: false,
          groups: [groupA],
          onLeadChanged: (groupId, leadMinutes) => reported.add((groupId, leadMinutes)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The label field is a `TextField` too, so the lead field is found by its own current value.
    final leadFieldFinder = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.controller?.text == "90",
    );
    await tester.enterText(leadFieldFinder, "120");
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(reported, [("group-1", 120)]);
  });

  testWidgets("deleting a group only asks, through its own callback", (tester) async {
    final requested = <String>[];
    await tester.pumpWidget(
      _wrapInApp(
        buildBand(isReadOnly: false, groups: [groupA], onGroupDeletionRequested: requested.add),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // The widget only ever reports the request; it is the mode that opens `OcptConfirmDialog` and
    // decides whether the group is actually deleted — nothing here asserts a deletion happened.
    expect(requested, ["group-1"]);
  });

  testWidgets("every writing affordance is withheld when the mode is read-only", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        buildBand(isReadOnly: true, groups: [groupA], memberCountByGroupId: {"group-1": 2}),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleGroupsBand)));
    // The group still reads (label, lead, count), but nothing is editable and there is no `+ Group`
    // or delete control.
    expect(find.text("Figuration"), findsOneWidget);
    expect(find.text("90 min"), findsOneWidget);
    expect(find.text(tr.scheduleGroupMemberCount(2)), findsOneWidget);
    expect(find.text(tr.scheduleAddGroupAction), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
  });
}
