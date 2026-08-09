// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_day_alert_badge.dart';
import 'package:open_cine_prod_tools/utils/ocpt_schedule_alerts.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve.
Widget _wrapInApp(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: Center(child: child)),
);

/// A soft alert about `day-1` — rule 7, the cheapest of the nine to build by hand.
const _softAlert = OcptScheduleTimelineOverrunAlert(
  dayId: "day-1",
  blockId: "block-1",
  reachedMinute: 600,
  anchorMinute: 550,
);

/// A hard alert about `day-1` — rule 2.
const _hardAlert = OcptSchedulePersonDoubleBookedAlert(
  dayId: "day-1",
  personId: "person-1",
  firstSlotId: "slot-a",
  secondSlotId: "slot-b",
);

void main() {
  testWidgets("a day raising nothing draws nothing at all", (tester) async {
    await tester.pumpWidget(_wrapInApp(const OcptScheduleDayAlertBadge(alerts: [])));

    expect(find.byType(Icon), findsNothing);
    expect(find.byType(Tooltip), findsNothing);
  });

  testWidgets("a soft-only day wears the warning mark and its own count", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(const OcptScheduleDayAlertBadge(alerts: [_softAlert, _softAlert])),
    );

    expect(tester.widget<Icon>(find.byType(Icon)).icon, Icons.warning_amber_rounded);
    expect(find.text("2"), findsOneWidget);
  });

  testWidgets("one hard alert among soft ones makes the whole day read as blocked", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(const OcptScheduleDayAlertBadge(alerts: [_hardAlert, _softAlert])),
    );

    expect(tester.widget<Icon>(find.byType(Icon)).icon, Icons.error_outline);
  });

  testWidgets("the compact form drops the count, keeping the mark and its tooltip", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(const OcptScheduleDayAlertBadge(alerts: [_softAlert], isCompact: true)),
    );

    expect(find.byType(Icon), findsOneWidget);
    expect(find.text("1"), findsNothing);
    expect(find.byType(Tooltip), findsOneWidget);
  });

  testWidgets("the informative form offers no gesture of its own", (tester) async {
    await tester.pumpWidget(_wrapInApp(const OcptScheduleDayAlertBadge(alerts: [_softAlert])));

    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets("the day view's own form reports its click", (tester) async {
    var tapCount = 0;
    await tester.pumpWidget(
      _wrapInApp(OcptScheduleDayAlertBadge(alerts: const [_softAlert], onTap: () => tapCount++)),
    );

    await tester.tap(find.byType(Icon));
    await tester.pump();

    expect(tapCount, 1);
  });

  testWidgets("the tooltip names each kind once, however often it was raised", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(const OcptScheduleDayAlertBadge(alerts: [_softAlert, _softAlert, _hardAlert])),
    );

    final context = tester.element(find.byType(OcptScheduleDayAlertBadge));
    final tr = Tr.of(context);
    final message = tester.widget<Tooltip>(find.byType(Tooltip)).message;

    expect(message, contains(tr.scheduleAlertKindTimelineOverrun));
    expect(message, contains(tr.scheduleAlertKindPersonDoubleBooked));
    expect(
      tr.scheduleAlertKindTimelineOverrun.allMatches(message!).length,
      1,
      reason: "a kind raised twice must be named once",
    );
  });
}
