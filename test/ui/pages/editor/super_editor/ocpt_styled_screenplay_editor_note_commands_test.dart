// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_screenplay_editor.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'ocpt_styled_screenplay_editor_test_doubles.dart';

/// Run a right-click [testWidgets] case with a desktop [defaultTargetPlatform], which is what
/// makes the styled editor build the mouse interactor that receives a secondary tap.
void _testWidgetsAsDesktop(String description, Future<void> Function(WidgetTester tester) body) {
  testWidgets(description, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await body(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

/// Right-click inside the text of the node [nodeId], which places the caret at the start of the
/// node unless the click lands inside an expanded selection.
Future<Tr> _rightClickIn(WidgetTester tester, String nodeId) async {
  await tester.tapAt(
    SuperEditorInspector.findComponentOffset(nodeId, Alignment.centerLeft) + const Offset(4, 0),
    buttons: kSecondaryButton,
  );
  await tester.pumpAndSettle();
  return Tr.of(tester.element(find.byType(OcptStyledScreenplayEditor)));
}

/// Run the tests of the styled editor's note commands.
void main() {
  BlinkController.indeterminateAnimationsEnabled = false;

  _testWidgetsAsDesktop("Insert note adds empty brackets at the caret, in one undo step", (
    tester,
  ) async {
    await pumpStandaloneEditor(tester, "Some action text.");
    final document = SuperEditorInspector.findDocument()!;
    final nodeId = nodeAt(document, 0).id;

    final tr = await _rightClickIn(tester, nodeId);
    expect(find.text(tr.editorContextMenuRemoveNoteAction), findsNothing);
    await tester.tap(find.text(tr.editorContextMenuInsertNoteAction));
    await pumpPastSettleDebounce(tester);

    expect(nodeAt(document, 0).text.toPlainText(), "[[]]Some action text.");
    final selection = SuperEditorInspector.findDocumentSelection()!;
    expect(selection.isCollapsed, isTrue);
    expect((selection.extent.nodePosition as TextNodePosition).offset, 2);

    await sendCtrl(tester, LogicalKeyboardKey.keyZ);
    await pumpPastSettleDebounce(tester);

    expect(nodeAt(document, 0).text.toPlainText(), "Some action text.");
  });

  _testWidgetsAsDesktop(
    "Remove note over a selected note takes the whole note away, and Ctrl+Z brings it back",
    (tester) async {
      await pumpStandaloneEditor(tester, "[[a note]] text.");
      final document = SuperEditorInspector.findDocument()!;
      final nodeId = nodeAt(document, 0).id;

      final composer = SuperEditorInspector.findComposer()! as MutableDocumentComposer;
      await tester.placeCaretInParagraph(nodeId, 0);
      composer.setSelectionWithReason(
        DocumentSelection(
          base: DocumentPosition(nodeId: nodeId, nodePosition: const TextNodePosition(offset: 0)),
          extent: DocumentPosition(
            nodeId: nodeId,
            nodePosition: const TextNodePosition(offset: 10),
          ),
        ),
      );
      await tester.pump();
      final tr = await _rightClickIn(tester, nodeId);
      expect(find.text(tr.editorContextMenuInsertNoteAction), findsNothing);
      await tester.tap(find.text(tr.editorContextMenuRemoveNoteAction));
      await pumpPastSettleDebounce(tester);

      expect(nodeAt(document, 0).text.toPlainText(), "text.");

      await sendCtrl(tester, LogicalKeyboardKey.keyZ);
      await pumpPastSettleDebounce(tester);

      expect(nodeAt(document, 0).text.toPlainText(), "[[a note]] text.");
    },
  );
}
