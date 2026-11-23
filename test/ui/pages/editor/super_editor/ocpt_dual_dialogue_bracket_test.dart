// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'ocpt_styled_screenplay_editor_test_doubles.dart';

/// Find the bracket drawn next to the node [nodeId].
Finder _bracketOf(String nodeId) => find.byKey(ValueKey("dualDialogueBracket:$nodeId"));

/// Find the orphan marker drawn after the cue [nodeId].
Finder _orphanOf(String nodeId) => find.byKey(ValueKey("dualDialogueOrphan:$nodeId"));

/// Run the tests of the dual-dialogue bracket and orphan marker.
void main() {
  BlinkController.indeterminateAnimationsEnabled = false;

  testWidgets("a pair gets a bracket from its first cue to its last line", (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpStandaloneEditor(tester, "ROSS\nHello.\n\nKIM ^\nHi there.\n\nEND.\n");
    final document = SuperEditorInspector.findDocument()!;
    final ids = [for (var index = 0; index < 5; index++) nodeAt(document, index).id];

    for (final id in ids.take(4)) {
      expect(_bracketOf(id), findsOneWidget);
    }
    expect(_bracketOf(ids[4]), findsNothing);
    expect(_orphanOf(ids[2]), findsNothing);

    final first = tester.getRect(_bracketOf(ids[0]));
    final last = tester.getRect(_bracketOf(ids[3]));
    final firstNode = tester.getRect(
      find.byWidget(SuperEditorInspector.findWidgetForComponent(ids[0])),
    );
    final lastNode = tester.getRect(
      find.byWidget(SuperEditorInspector.findWidgetForComponent(ids[3])),
    );
    expect(first.top, firstNode.top);
    expect(last.bottom, lastNode.bottom);
    // The bracket is one column: every segment sits at the same distance from the page's edge, and
    // the second cue's segment reaches up to the one above it, across the blank line.
    final secondCue = tester.getRect(_bracketOf(ids[2]));
    final firstSpeechEnd = tester.getRect(_bracketOf(ids[1]));
    expect(secondCue.top, firstSpeechEnd.bottom);
    expect(first.left, last.left);
  });

  testWidgets("an orphan marker gets no bracket but a dimmed ^", (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpStandaloneEditor(tester, "A door opens.\n\nBOB ^\nYo.\n");
    final document = SuperEditorInspector.findDocument()!;
    final bobId = nodeAt(document, 1).id;

    expect(_bracketOf(bobId), findsNothing);
    expect(_orphanOf(bobId), findsOneWidget);
    expect(find.descendant(of: _orphanOf(bobId), matching: find.text(" ^")), findsOneWidget);
    expect(OcptWysiwygDualDialogue.suffixOf(nodeAt(document, 1)), " ^");
    expect(nodeAt(document, 1).text.toPlainText(), "BOB");
  });
}
