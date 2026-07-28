// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_status_pill.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve.
Widget _wrapInApp(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: Align(alignment: Alignment.topLeft, child: child)),
);

void main() {
  testWidgets("shows the current status label", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptShotStatusPill(status: OcptShotStatus.retake, onStatusSelected: (_) {}),
      ),
    );

    expect(find.text("Retake"), findsOneWidget);
  });

  testWidgets("opening the menu lists every status, the active one ticked", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptShotStatusPill(status: OcptShotStatus.shot, onStatusSelected: (_) {}),
      ),
    );

    await tester.tap(find.text("Shot"));
    await tester.pumpAndSettle();

    expect(find.text("To shoot"), findsOneWidget);
    // "Shot" now appears twice: the pill itself and its menu entry.
    expect(find.text("Shot"), findsNWidgets(2));
    expect(find.text("Retake"), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets("picking a status from the menu reports it", (tester) async {
    OcptShotStatus? reported;

    await tester.pumpWidget(
      _wrapInApp(
        OcptShotStatusPill(
          status: OcptShotStatus.toShoot,
          onStatusSelected: (status) => reported = status,
        ),
      ),
    );

    await tester.tap(find.text("To shoot"));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Retake"));
    await tester.pumpAndSettle();

    expect(reported, OcptShotStatus.retake);
  });
}
