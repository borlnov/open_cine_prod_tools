// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/models/ocpt_specific_colors.dart';
import 'package:open_cine_prod_tools/ui/pages/joining/widgets/ocpt_joining_scan_frame.dart';

/// Wraps [child] with the app theme, exactly `ocpt_hosting_panel_test.dart`'s own `_wrap` —
/// `OcptJoiningScanFrame` is pumped directly here, never `OcptJoiningScannerView`: `MobileScanner`
/// cannot be instantiated under `flutter test` at all, which is the whole reason the coloured
/// border was pulled out into its own, camera-free widget.
Widget _wrap(Widget child) =>
    MaterialApp(theme: ocptTheme.lightThemeData, home: Scaffold(body: child));

/// Reads [OcptJoiningScanFrame]'s own border colour off the `AnimatedContainer` it builds.
Color _borderColor(WidgetTester tester) {
  final container = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
  final decoration = container.decoration! as BoxDecoration;
  return decoration.border!.top.color;
}

void main() {
  testWidgets("idle status paints the theme's own outline colour", (tester) async {
    await tester.pumpWidget(
      _wrap(const OcptJoiningScanFrame(status: OcptJoiningScanStatus.idle, child: SizedBox())),
    );

    final theme = Theme.of(tester.element(find.byType(OcptJoiningScanFrame)));
    expect(_borderColor(tester), theme.colorScheme.outline);
  });

  testWidgets("error status paints the theme's own error colour", (tester) async {
    await tester.pumpWidget(
      _wrap(const OcptJoiningScanFrame(status: OcptJoiningScanStatus.error, child: SizedBox())),
    );

    final theme = Theme.of(tester.element(find.byType(OcptJoiningScanFrame)));
    expect(_borderColor(tester), theme.colorScheme.error);
  });

  testWidgets("success status paints the shared shot-status green", (tester) async {
    await tester.pumpWidget(
      _wrap(const OcptJoiningScanFrame(status: OcptJoiningScanStatus.success, child: SizedBox())),
    );

    final theme = Theme.of(tester.element(find.byType(OcptJoiningScanFrame)));
    final expectedColor =
        theme.extension<OcptSpecificColors>()?.shotStatusShot ?? theme.colorScheme.primary;
    expect(_borderColor(tester), expectedColor);
  });

  testWidgets("the framed child is still shown", (tester) async {
    await tester.pumpWidget(
      _wrap(
        const OcptJoiningScanFrame(
          status: OcptJoiningScanStatus.idle,
          child: Text("camera preview"),
        ),
      ),
    );

    expect(find.text("camera preview"), findsOneWidget);
  });
}
