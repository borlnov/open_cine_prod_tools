// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/joining/joining_state.dart';
import 'package:open_cine_prod_tools/ui/pages/joining/widgets/ocpt_joining_status_overlay.dart';

/// Wraps [child] with the app theme and the localization delegates so `Tr.of` lookups resolve,
/// exactly `sharing_page_test.dart`'s own `_wrapWithLocalization` — `OcptJoiningStatusOverlay` is
/// pumped directly here, no `OcptJoiningBloc` or `OcptJoiningView` involved at all, since it takes
/// everything it needs as plain constructor parameters.
Widget _wrap(Widget child) => MaterialApp(
  theme: ocptTheme.lightThemeData,
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  // A Stack ancestor: `OcptJoiningStatusOverlay` builds a `Positioned.fill`, which needs one.
  home: Scaffold(body: Stack(children: [child])),
);

void main() {
  testWidgets("the busy state shows a spinner, the current step's own label and Annuler", (
    tester,
  ) async {
    var cancelled = false;

    await tester.pumpWidget(
      _wrap(
        OcptJoiningStatusOverlay(
          step: OcptJoinStep.downloading,
          succeeded: false,
          onCancelRequested: () => cancelled = true,
          onOpenRequested: () => fail("onOpenRequested must not be called in the busy state"),
        ),
      ),
    );

    final tr = Tr.of(tester.element(find.byType(OcptJoiningStatusOverlay)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(tr.joiningStepDownloading), findsOneWidget);
    expect(find.text(tr.joiningCancelAction), findsOneWidget);
    expect(find.text(tr.joiningOpenAction), findsNothing);

    await tester.tap(find.text(tr.joiningCancelAction));
    await tester.pump();

    expect(cancelled, isTrue);
  });

  testWidgets("each join step shows its own label", (tester) async {
    for (final step in OcptJoinStep.values) {
      await tester.pumpWidget(
        _wrap(
          OcptJoiningStatusOverlay(
            step: step,
            succeeded: false,
            onCancelRequested: () {},
            onOpenRequested: () {},
          ),
        ),
      );

      final tr = Tr.of(tester.element(find.byType(OcptJoiningStatusOverlay)));
      final expectedLabel = switch (step) {
        OcptJoinStep.connecting => tr.joiningStepConnecting,
        OcptJoinStep.downloading => tr.joiningStepDownloading,
        OcptJoinStep.opening => tr.joiningStepOpening,
      };
      expect(find.text(expectedLabel), findsOneWidget, reason: "for step $step");
    }
  });

  testWidgets("the success state shows a check mark, the success title and Ouvrir", (
    tester,
  ) async {
    var opened = false;

    await tester.pumpWidget(
      _wrap(
        OcptJoiningStatusOverlay(
          step: null,
          succeeded: true,
          onCancelRequested: () => fail("onCancelRequested must not be called in the success state"),
          onOpenRequested: () => opened = true,
        ),
      ),
    );

    final tr = Tr.of(tester.element(find.byType(OcptJoiningStatusOverlay)));
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.text(tr.joiningSuccessTitle), findsOneWidget);
    expect(find.text(tr.joiningOpenAction), findsOneWidget);
    expect(find.text(tr.joiningCancelAction), findsNothing);

    await tester.tap(find.text(tr.joiningOpenAction));
    await tester.pump();

    expect(opened, isTrue);
  });
}
