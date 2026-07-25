// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_dock.dart';

void main() {
  group("OcptEditorDock.resolveDockWidths", () {
    test("resolves both docks at their fraction when the row comfortably fits them", () {
      final widths = OcptEditorDock.resolveDockWidths(
        rowWidth: 1200,
        leftFraction: 0.18,
        rightFraction: 0.45,
        isLeftDockVisible: true,
        isRightDockVisible: true,
      );

      expect(widths.left, closeTo(216, 0.001));
      expect(widths.right, closeTo(540, 0.001));
    });

    test("a dock that isn't visible contributes no width and reserves no divider", () {
      final withLeftOnly = OcptEditorDock.resolveDockWidths(
        rowWidth: 1200,
        leftFraction: 0.18,
        rightFraction: 0.45,
        isLeftDockVisible: true,
        isRightDockVisible: false,
      );
      expect(withLeftOnly.left, closeTo(216, 0.001));
      expect(withLeftOnly.right, 0);

      final withNeither = OcptEditorDock.resolveDockWidths(
        rowWidth: 1200,
        leftFraction: 0.18,
        rightFraction: 0.45,
        isLeftDockVisible: false,
        isRightDockVisible: false,
      );
      expect(withNeither.left, 0);
      expect(withNeither.right, 0);
    });

    test("the left dock never resolves below its minimum width", () {
      final widths = OcptEditorDock.resolveDockWidths(
        rowWidth: 1200,
        leftFraction: 0.01,
        rightFraction: 0.45,
        isLeftDockVisible: true,
        isRightDockVisible: true,
      );

      expect(widths.left, closeTo(OcptEditorDock.leftMinWidth, 0.001));
    });

    test("the right dock never resolves above its maximum fraction of the row", () {
      // The left dock is hidden here so the centre floor (which would otherwise force the right
      // dock to give up width first) never engages, isolating the plain fraction clamp.
      final widths = OcptEditorDock.resolveDockWidths(
        rowWidth: 1200,
        leftFraction: 0.18,
        rightFraction: 0.99,
        isLeftDockVisible: false,
        isRightDockVisible: true,
      );

      expect(widths.right, closeTo(1200 * OcptEditorDock.rightMaxFraction, 0.001));
    });

    test("the centre floor is honoured: the right dock gives up width first", () {
      // At rowWidth 700, the left dock clamps to its 180px minimum and the right dock would
      // naturally take 315px, leaving only 189px of centre (below the 320px floor): the right
      // dock alone must give up the 131px deficit, the left dock must stay at its minimum.
      final widths = OcptEditorDock.resolveDockWidths(
        rowWidth: 700,
        leftFraction: 0.18,
        rightFraction: 0.45,
        isLeftDockVisible: true,
        isRightDockVisible: true,
      );

      expect(widths.left, closeTo(OcptEditorDock.leftMinWidth, 0.001));
      expect(widths.right, closeTo(184, 0.001));

      const dividerWidth = OcptEditorDock.dividerHitWidth * 2;
      final centre = 700 - dividerWidth - widths.left - widths.right;
      expect(centre, closeTo(OcptEditorDock.centreMinWidth, 0.001));
    });

    test("the left dock also gives up width once the right dock has given up everything", () {
      // Narrow enough that even after the right dock is squeezed to 0, the centre floor still
      // isn't met: the left dock must give up some of its own width too, but each dock stays
      // non-negative (a real degenerate case: the window narrower than both mins plus the floor).
      final widths = OcptEditorDock.resolveDockWidths(
        rowWidth: 400,
        leftFraction: 0.18,
        rightFraction: 0.45,
        isLeftDockVisible: true,
        isRightDockVisible: true,
      );

      expect(widths.left, greaterThanOrEqualTo(0));
      expect(widths.right, 0);

      const dividerWidth = OcptEditorDock.dividerHitWidth * 2;
      final centre = 400 - dividerWidth - widths.left - widths.right;
      expect(centre, closeTo(OcptEditorDock.centreMinWidth, 0.001));
    });

    test("an extremely narrow row never produces negative widths", () {
      final widths = OcptEditorDock.resolveDockWidths(
        rowWidth: 200,
        leftFraction: 0.18,
        rightFraction: 0.45,
        isLeftDockVisible: true,
        isRightDockVisible: true,
      );

      expect(widths.left, greaterThanOrEqualTo(0));
      expect(widths.right, greaterThanOrEqualTo(0));
    });
  });

  group("OcptEditorDock.clampLeftFraction / clampRightFraction", () {
    test("returns the fraction unchanged for a non-positive row width", () {
      expect(OcptEditorDock.clampLeftFraction(0.18, 0), 0.18);
      expect(OcptEditorDock.clampRightFraction(0.45, -10), 0.45);
    });

    test("never throws even when the minimum width's fraction exceeds the maximum fraction", () {
      expect(() => OcptEditorDock.clampLeftFraction(0.18, 100), returnsNormally);
      expect(() => OcptEditorDock.clampRightFraction(0.45, 100), returnsNormally);
    });
  });
}
