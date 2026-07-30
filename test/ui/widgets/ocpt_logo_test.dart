// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_logo.dart';

/// Wraps [child] in an app themed with [brightness], the only thing [OcptLogo] reads from its
/// context.
Widget _wrapInApp(Widget child, {required Brightness brightness}) => MaterialApp(
  theme: ThemeData(brightness: brightness),
  home: Scaffold(body: child),
);

void main() {
  testWidgets("every variant of the mark is bundled with the application", (tester) async {
    // The three assets are declared one by one in the pubspec (their directory also holds the
    // packaging masters, which must stay out of the bundle), so a variant added later could easily
    // be left undeclared: this reads each of them back from the bundle the app really ships.
    for (final path in [
      ocptLogoAssetFor(Brightness.light).path,
      ocptLogoAssetFor(Brightness.dark).path,
      ocptLogoGlyphAssetPath,
    ]) {
      expect(await rootBundle.loadString(path), contains("<svg"), reason: path);
    }
  });

  test("the light variant is picked on a light surface, the hollow one on a dark surface", () {
    expect(ocptLogoAssetFor(Brightness.light).path, endsWith("ocpt_logo_light.svg"));
    expect(ocptLogoAssetFor(Brightness.dark).path, endsWith("ocpt_logo_dark.svg"));
  });

  testWidgets("the logo takes the square it is given, whatever the theme's brightness", (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        _wrapInApp(const Center(child: OcptLogo(size: 48)), brightness: brightness),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(OcptLogo)), const Size.square(48));
    }
  });

  testWidgets("the glyph takes the width it is given and keeps its own proportions", (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapInApp(
        const Center(child: OcptLogoGlyph(width: 48, color: Colors.white)),
        brightness: Brightness.dark,
      ),
    );
    await tester.pumpAndSettle();

    final size = tester.getSize(find.byType(OcptLogoGlyph));
    expect(size.width, 48);
    // The glyph is authored wider than it is tall, so the height it takes is smaller than the
    // width it was given rather than equal to it.
    expect(size.height, lessThan(size.width));
  });
}
