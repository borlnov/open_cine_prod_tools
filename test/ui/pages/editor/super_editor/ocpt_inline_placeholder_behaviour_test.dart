// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

/// A placeholder object standing for a note in the tests below.
class _Marker {
  /// Class constructor.
  const _Marker();
}

/// The key of the widget the test builder draws for a [_Marker].
const Key _markerKey = ValueKey("marker");

/// Pump a `SuperEditor` over one paragraph holding "ab", a [_Marker], then "cd", and return its
/// document, editor and the paragraph's id.
Future<(MutableDocument, Editor, String)> _pump(WidgetTester tester) async {
  final text = AttributedText("abcd").insertPlaceholder(2, const _Marker());
  final node = ParagraphNode(id: "p", text: text);
  final document = MutableDocument(nodes: <DocumentNode>[node]);
  final composer = MutableDocumentComposer();
  final editor = createDefaultDocumentEditor(document: document, composer: composer);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SuperEditor(
          editor: editor,
          stylesheet: defaultStylesheet.copyWith(
            inlineWidgetBuilders: [
              (context, style, placeholder) => placeholder is _Marker
                  ? const SizedBox(key: _markerKey, width: 18, height: 16)
                  : null,
            ],
          ),
        ),
      ),
    ),
  );
  return (document, editor, "p");
}

/// Read the text of the paragraph [id] of [document].
AttributedText _textOf(MutableDocument document, String id) =>
    (document.getNodeById(id)! as ParagraphNode).text;

/// Run the tests pinning how super_editor treats an inline placeholder, which the styled editor
/// builds its notes on.
void main() {
  BlinkController.indeterminateAnimationsEnabled = false;

  testWidgets("an inline widget builder draws the placeholder", (tester) async {
    await _pump(tester);

    expect(find.byKey(_markerKey), findsOneWidget);
  });

  testWidgets("the plain text stands a placeholder for one replacement character", (tester) async {
    final (document, _, id) = await _pump(tester);

    final text = _textOf(document, id);
    expect(text.toPlainText(), "ab￼cd");
    expect(text.length, 5);
    expect(text.placeholders.keys, [2]);
  });

  testWidgets("the caret moves over a placeholder as a single position", (tester) async {
    final (_, _, id) = await _pump(tester);
    await tester.placeCaretInParagraph(id, 2);

    int offset() =>
        (SuperEditorInspector.findDocumentSelection()!.extent.nodePosition as TextNodePosition)
            .offset;

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(offset(), 3);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(offset(), 4);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    expect(offset(), 2);
  });

  testWidgets("Backspace right after a placeholder deletes it whole", (tester) async {
    final (document, _, id) = await _pump(tester);
    await tester.placeCaretInParagraph(id, 3);

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);

    final text = _textOf(document, id);
    expect(text.toPlainText(), "abcd");
    expect(text.placeholders, isEmpty);
  });

  testWidgets(
    "typing before a placeholder shifts its index and deleting before it shifts it back",
    (tester) async {
      final (document, _, id) = await _pump(tester);
      await tester.placeCaretInParagraph(id, 1);

      await tester.typeImeText("xy");
      expect(_textOf(document, id).placeholders.keys, [4]);
      expect(_textOf(document, id).toPlainText(), "axyb￼cd");

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      expect(_textOf(document, id).placeholders.keys, [2]);
      expect(_textOf(document, id).toPlainText(), "ab￼cd".replaceFirst("ab", "ab"));
    },
  );
}
