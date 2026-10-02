// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/utils/ocpt_storyboard_annotation_geometry.dart';

void main() {
  group("ocptStoryboardAnnotationPointOf", () {
    test("maps the frame's own top-left corner to the origin", () {
      final point = ocptStoryboardAnnotationPointOf(xNorm: 0, yNorm: 0, widthPx: 200, heightPx: 100);

      expect(point.x, 0);
      expect(point.y, 0);
    });

    test("maps the frame's own bottom-right corner to its own width/height", () {
      final point = ocptStoryboardAnnotationPointOf(xNorm: 1, yNorm: 1, widthPx: 200, heightPx: 100);

      expect(point.x, 200);
      expect(point.y, 100);
    });

    test("is a plain product against the frame's own width/height, nothing else", () {
      final point = ocptStoryboardAnnotationPointOf(xNorm: 0.25, yNorm: 0.75, widthPx: 80, heightPx: 40);

      expect(point.x, 20);
      expect(point.y, 30);
    });

    test("scales with the frame's own size, so a replaced image of another size keeps a mark in "
        "the same relative place", () {
      final small = ocptStoryboardAnnotationPointOf(xNorm: 0.5, yNorm: 0.5, widthPx: 100, heightPx: 100);
      final large = ocptStoryboardAnnotationPointOf(xNorm: 0.5, yNorm: 0.5, widthPx: 400, heightPx: 200);

      expect(small.x / 100, large.x / 400);
      expect(small.y / 100, large.y / 200);
    });
  });
}
