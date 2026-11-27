// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_jump_request.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_styled_editor_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_note.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_note_marker.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_screenplay_editor.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import 'ocpt_styled_screenplay_editor_test_doubles.dart';

/// The screenplay the tests read: a note over two lines in the middle of the second paragraph. The
/// heading is already numbered, as the text of the page is once the editor has reported its first
/// encode: the editor's own node mapping is built from that text.
const String _source = "INT. HOUSE - DAY #1#\n\nHe looks [[a\nb]] away.\n\nShe leaves.";

/// Run the tests of the styled editor over a note running over several lines.
void main() {
  BlinkController.indeterminateAnimationsEnabled = false;

  group("the note running over several lines", () {
    /// Pump the editor over [text], reporting the caret line to [onCaretLineChanged] and landing
    /// on [jumpRequest], one [key] being kept across calls so a second pump delivers the request
    /// to the same live editor.
    Future<void> pump(
      WidgetTester tester,
      String text, {
      OcptEditorJumpRequest? jumpRequest,
      ValueChanged<int>? onCaretLineChanged,
      ValueChanged<String>? onTextChanged,
      OcptStyledEditorController? styledController,
    }) async {
      await tester.pumpWidget(
        testWrap(
          OcptStyledScreenplayEditor(
            key: const ValueKey("multiline-note-editor"),
            text: text,
            pageSetup: const OcptPageSetup.standard(),
            isPageSimulationEnabled: false,
            areSceneNumbersVisible: false,
            isSpellCheckVisible: false,
            onTextChanged: onTextChanged ?? (_) {},
            onCaretLineChanged: onCaretLineChanged ?? (_) {},
            jumpRequest: jumpRequest,
            styledController: styledController,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets("is one node drawn with one marker", (tester) async {
      await pump(tester, _source);

      final document = SuperEditorInspector.findDocument()!;
      expect(document.nodeCount, 3);
      expect(find.byType(OcptFountainNoteMarker), findsOneWidget);
      expect(nodeAt(document, 1).text.toPlainText(), "He looks ￼ away.");
    });

    testWidgets("is landed on by a jump to any of its lines", (tester) async {
      await pump(tester, _source);

      for (final probe in ["He looks", "b]]"]) {
        await pump(
          tester,
          _source,
          jumpRequest: OcptEditorJumpRequest(charOffset: _source.indexOf(probe), id: probe.length),
        );

        final selection = SuperEditorInspector.findDocumentSelection()!;
        final document = SuperEditorInspector.findDocument()!;
        expect(selection.extent.nodeId, nodeAt(document, 1).id, reason: probe);
      }
    });

    testWidgets("is followed by a jump to the line after it, on the right node", (tester) async {
      await pump(tester, _source);

      await pump(
        tester,
        _source,
        jumpRequest: OcptEditorJumpRequest(charOffset: _source.indexOf("She leaves."), id: 1),
      );

      final selection = SuperEditorInspector.findDocumentSelection()!;
      expect(selection.extent.nodeId, nodeAt(SuperEditorInspector.findDocument()!, 2).id);
    });

    testWidgets("reports the first of its lines as the caret line, and the next node's own", (
      tester,
    ) async {
      final lines = <int>[];
      await pump(tester, _source, onCaretLineChanged: lines.add);
      final document = SuperEditorInspector.findDocument()!;

      for (final (index, offset) in [(1, 3), (2, 2)]) {
        (SuperEditorInspector.findComposer()! as MutableDocumentComposer).setSelectionWithReason(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: nodeAt(document, index).id,
              nodePosition: TextNodePosition(offset: offset),
            ),
          ),
        );
        await tester.pump();
      }

      expect(lines, [2, 5]);
    });

    testWidgets("is written back with its lines as it was typed around", (tester) async {
      final written = <String>[];
      await pump(tester, _source, onTextChanged: written.add);
      final document = SuperEditorInspector.findDocument()!;

      await tester.placeCaretInParagraph(nodeAt(document, 2).id, 11);
      await tester.typeImeText("!");
      await pumpPastSettleDebounce(tester);

      expect(written.last, "INT. HOUSE - DAY #1#\n\nHe looks [[a\nb]] away.\n\nShe leaves.!");
      expect(find.byType(OcptFountainNoteMarker), findsOneWidget);
      expect(nodeAt(document, 1).text.placeholders.values.single, isA<OcptFountainNote>());
    });

    testWidgets("is typed into without being broken up or made again", (tester) async {
      await pump(tester, _source);
      final document = SuperEditorInspector.findDocument()!;
      final node = nodeAt(document, 1);

      await tester.placeCaretInParagraph(node.id, 2);
      await tester.typeImeText("X");
      await pumpPastSettleDebounce(tester);

      expect(nodeAt(document, 1).text.toPlainText(), "HeX looks ￼ away.");
      expect(
        (nodeAt(document, 1).text.placeholders.values.single as OcptFountainNote).text,
        "a\nb",
      );
    });
  });

  group("the note running over several lines on the clipboard", () {
    String? clipboardText;
    setUp(() {
      clipboardText = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (methodCall) async {
          switch (methodCall.method) {
            case "Clipboard.setData":
              clipboardText = (methodCall.arguments as Map)["text"] as String?;
              return null;
            case "Clipboard.getData":
              return {"text": clipboardText};
            default:
              return null;
          }
        },
      );
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    testWidgets("is pasted as one note, its lines kept", (tester) async {
      await pumpStandaloneEditor(tester, "Hello");
      final document = SuperEditorInspector.findDocument()!;
      clipboardText = " [[from\noutside]]";
      await tester.placeCaretInParagraph(nodeAt(document, 0).id, 5);

      await sendCtrl(tester, LogicalKeyboardKey.keyV);
      await pumpPastSettleDebounce(tester);

      expect(document.nodeCount, 1);
      expect(nodeAt(document, 0).text.toPlainText(), "Hello ￼");
      expect(
        (nodeAt(document, 0).text.placeholders.values.single as OcptFountainNote).text,
        "from\noutside",
      );
    });
  });
}
