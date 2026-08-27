// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_horizontal_scroll_view.dart';

void main() {
  group("OcptHorizontalScrollView", () {
    testWidgets("draws an always-visible scrollbar over a horizontal scroll view", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              child: OcptHorizontalScrollView(child: SizedBox(width: 400, height: 40)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollView = tester.widget<SingleChildScrollView>(find.byType(SingleChildScrollView));
      expect(scrollView.scrollDirection, Axis.horizontal);

      final scrollbar = tester.widget<Scrollbar>(find.byType(Scrollbar));
      expect(scrollbar.thumbVisibility, isTrue);
      // The bar and its scroll view share the one controller, so dragging the bar scrolls the view.
      expect(scrollbar.controller, isNotNull);
      expect(scrollbar.controller, same(scrollView.controller));
    });

    testWidgets("content wider than the frame actually scrolls", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              child: OcptHorizontalScrollView(child: SizedBox(width: 400, height: 40)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final position = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      ).controller!.position;
      expect(position.maxScrollExtent, greaterThan(0));

      await tester.drag(find.byType(SingleChildScrollView), const Offset(-120, 0));
      await tester.pumpAndSettle();
      expect(position.pixels, greaterThan(0));
    });
  });
}
