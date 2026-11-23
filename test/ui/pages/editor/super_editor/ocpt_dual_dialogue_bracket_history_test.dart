// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_styled_editor_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_screenplay_editor.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'ocpt_styled_screenplay_editor_test_doubles.dart';

/// Count the brackets drawn in the editor.
int _bracketCount() => find
    .byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey &&
          "${(widget.key! as ValueKey).value}".startsWith("dualDialogueBracket:"),
    )
    .evaluate()
    .length;

/// Run the tests of the dual-dialogue bracket following the undo history.
void main() {
  BlinkController.indeterminateAnimationsEnabled = false;

  testWidgets("the bracket follows an undo and a redo at once, with no settle", (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = OcptStyledEditorController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      testWrap(
        OcptStyledScreenplayEditor(
          text: "ROSS\nHello.\n\nKIM\nHi.\n",
          pageSetup: const OcptPageSetup.standard(),
          isPageSimulationEnabled: false,
          areSceneNumbersVisible: false,
          isSpellCheckVisible: false,
          onTextChanged: (_) {},
          onCaretLineChanged: (_) {},
          jumpRequest: null,
          styledController: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final document = SuperEditorInspector.findDocument()!;
    await tester.placeCaretInParagraph(nodeAt(document, 3).id, 1);
    await tester.pump();
    controller.toggleDualDialogue();
    await pumpPastSettleDebounce(tester);
    expect(_bracketCount(), 4);

    await sendCtrl(tester, LogicalKeyboardKey.keyZ);
    await tester.pump();
    expect(_bracketCount(), 0);

    await sendCtrlShift(tester, LogicalKeyboardKey.keyZ);
    await tester.pump();
    expect(_bracketCount(), 4);
  });
}
