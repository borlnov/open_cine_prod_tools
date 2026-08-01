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
    await tester.pumpWidget(_wrapInApp(const OcptShotStatusPill(status: OcptShotStatus.retake)));

    expect(find.text("Retake"), findsOneWidget);
  });

  testWidgets("is a read-out: tapping it opens nothing", (tester) async {
    await tester.pumpWidget(_wrapInApp(const OcptShotStatusPill(status: OcptShotStatus.shot)));

    await tester.tap(find.text("Shot"));
    await tester.pumpAndSettle();

    expect(find.text("Shot"), findsOneWidget);
    expect(find.text("To shoot"), findsNothing);
    expect(find.text("Retake"), findsNothing);
  });
}
