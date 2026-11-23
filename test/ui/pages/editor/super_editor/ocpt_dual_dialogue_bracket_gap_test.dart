// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_screenplay_editor.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'ocpt_styled_screenplay_editor_test_doubles.dart';

/// Pump a fluid styled editor over a pair then an action, on a compact surface [width] wide, and
/// measure the gap between the right edge of the bracket and the left edge of the action's box.
Future<double> _gapAt(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    testWrap(
      OcptStyledScreenplayEditor(
        text: "A door opens.\n\nROSS\nHello.\n\nKIM ^\nHi there.\n",
        pageSetup: const OcptPageSetup.standard(),
        isPageSimulationEnabled: false,
        areSceneNumbersVisible: false,
        isSpellCheckVisible: false,
        onTextChanged: (_) {},
        onCaretLineChanged: (_) {},
        jumpRequest: null,
        isCompact: true,
      ),
    ),
  );
  await tester.pumpAndSettle();
  final document = SuperEditorInspector.findDocument()!;
  final bracket = tester.getRect(
    find.byKey(ValueKey("dualDialogueBracket:${nodeAt(document, 1).id}")),
  );
  // The action's box starts at the page's left edge, and its text a fixed indent further.
  final actionBox = tester.getRect(
    find.byWidget(SuperEditorInspector.findWidgetForComponent(nodeAt(document, 0).id)),
  );
  return actionBox.left - bracket.right;
}

/// Run the tests of the distance between the dual-dialogue bracket and the action box.
void main() {
  BlinkController.indeterminateAnimationsEnabled = false;

  testWidgets("the bracket keeps its gap to the action box on a narrow compact surface", (
    tester,
  ) async {
    final reference = await _gapAt(tester, 1400);

    for (final width in [500.0, 380.0]) {
      expect(await _gapAt(tester, width), closeTo(reference, 0.5), reason: "width $width");
    }
  });
}
