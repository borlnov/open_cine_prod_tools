// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_page_zoom.dart';

/// Run the tests of [OcptPageZoom].
void main() {
  test('the steps run from 50 % to 200 % and include 100 %', () {
    expect(OcptPageZoom.steps.map(OcptPageZoom.percentOf), [
      50,
      67,
      75,
      90,
      100,
      110,
      125,
      150,
      175,
      200,
    ]);
  });

  test('a stored zoom round-trips, for a step and for the fit to width mode', () {
    for (final step in OcptPageZoom.steps) {
      final zoom = OcptPageZoom.nearestStep(step);

      expect(OcptPageZoom.tryParse(zoom.serialized), zoom);
    }

    expect(const OcptPageZoom.fitToWidth().serialized, "fit");
    expect(OcptPageZoom.tryParse("fit"), const OcptPageZoom.fitToWidth());
  });

  test('a stored percentage out of the bounds is brought back to the nearest step', () {
    expect(OcptPageZoom.tryParse("300"), OcptPageZoom.nearestStep(2));
    expect(OcptPageZoom.tryParse("10"), OcptPageZoom.nearestStep(0.5));
    expect(OcptPageZoom.tryParse("-40"), OcptPageZoom.nearestStep(0.5));
    expect(OcptPageZoom.tryParse("104"), const OcptPageZoom.actualSize());
  });

  test('a stored text that is no zoom is refused', () {
    expect(OcptPageZoom.tryParse("wide"), isNull);
    expect(OcptPageZoom.tryParse(""), isNull);
  });

  test('stepping moves to the next step and stops at the ends', () {
    expect(const OcptPageZoom.actualSize().stepped(1, factor: 1), OcptPageZoom.nearestStep(1.1));
    expect(const OcptPageZoom.actualSize().stepped(-1, factor: 1), OcptPageZoom.nearestStep(0.9));
    expect(OcptPageZoom.nearestStep(2).stepped(1, factor: 2), OcptPageZoom.nearestStep(2));
    expect(OcptPageZoom.canStep(1, 2), isFalse);
    expect(OcptPageZoom.canStep(-1, 2), isTrue);
    expect(OcptPageZoom.canStep(-1, 0.5), isFalse);
    expect(OcptPageZoom.canStep(1, 0.5), isTrue);
  });

  test('stepping out of the fit to width mode starts from the step nearest to its factor', () {
    const fit = OcptPageZoom.fitToWidth();

    expect(fit.stepped(1, factor: 1.3), OcptPageZoom.nearestStep(1.5));
    expect(fit.stepped(-1, factor: 1.3), OcptPageZoom.nearestStep(1.1));
    expect(fit.stepped(1, factor: 1.3).isFitToWidth, isFalse);
  });

  test('the fit to width factor fills the area, bounded to the zoom bounds', () {
    expect(
      OcptPageZoom.fitFactorFor(availableWidth: 1000, pageWidthAtActualSize: 500, gutter: 0),
      2,
    );
    expect(
      OcptPageZoom.fitFactorFor(availableWidth: 600, pageWidthAtActualSize: 500, gutter: 0),
      closeTo(1.2, 1e-9),
    );
    expect(
      OcptPageZoom.fitFactorFor(availableWidth: 100, pageWidthAtActualSize: 500, gutter: 0),
      0.5,
    );
    expect(const OcptPageZoom.fitToWidth().factorFor(1.3), 1.3);
    expect(OcptPageZoom.nearestStep(1.5).factorFor(1.3), 1.5);
  });
}
