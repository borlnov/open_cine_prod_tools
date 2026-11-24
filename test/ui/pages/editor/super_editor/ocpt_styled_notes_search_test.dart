// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_text_search.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_editor_search.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_styled_editor_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_note.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_note_marker.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_notes_margin.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_screenplay_editor.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_note_card.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'ocpt_styled_screenplay_editor_test_doubles.dart';

/// The text of the document the tests share: a match in the text, one in the note, one in the text
/// again.
const String _source = "Old man waits [[an old one]] now, so old.\n\nTHE END.";

/// The query most tests run.
const OcptEditorSearchQuery _old = OcptEditorSearchQuery(
  query: "old",
  isCaseSensitive: false,
  isWholeWord: false,
);

/// The width of a surface with room for the margin column.
const double _wideWidth = 1600;

/// The width of a surface that is not compact yet has no room for the margin column.
const double _narrowWidth = 1000;

/// The controller of the editor of the test being run.
late OcptStyledEditorController _controller;

/// The text the editor last reported.
String _encoded = "";

/// The stand-in for the find field of the page, whose focus a navigation must leave alone.
late FocusNode _findFocus;

/// Pump the editor over [text] on a surface [width] logical pixels wide, with a text field above it
/// standing for the find field, which has the focus.
Future<void> _pump(WidgetTester tester, String text, {double width = _wideWidth}) async {
  _controller = OcptStyledEditorController();
  _findFocus = FocusNode();
  _encoded = "";
  addTearDown(_controller.dispose);
  addTearDown(_findFocus.dispose);
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    testWrap(
      Column(
        children: [
          SizedBox(height: 40, child: TextField(focusNode: _findFocus)),
          Expanded(
            child: OcptStyledScreenplayEditor(
              text: text,
              pageSetup: const OcptPageSetup.standard(),
              isPageSimulationEnabled: false,
              areSceneNumbersVisible: false,
              isSpellCheckVisible: false,
              onTextChanged: (value) => _encoded = value,
              onCaretLineChanged: (_) {},
              jumpRequest: null,
              styledController: _controller,
            ),
          ),
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();
  _findFocus.requestFocus();
  await tester.pump();
}

/// Point the search at the match [index] of [query].
Future<void> _search(WidgetTester tester, int index, {OcptEditorSearchQuery query = _old}) async {
  _controller.updateSearch(query: query, currentMatchIndex: index);
  await tester.pumpAndSettle();
}

/// Get the notes the document holds, in document order.
List<OcptFountainNote> _notes() => [
  for (final node in SuperEditorInspector.findDocument()!.whereType<ParagraphNode>())
    ...node.text.placeholders.values.whereType<OcptFountainNote>(),
];

/// Get the background colours of the spans of [span] that have one, in order.
List<Color> _backgrounds(InlineSpan span) {
  final colors = <Color>[];
  span.visitChildren((child) {
    final background = child is TextSpan ? child.style?.backgroundColor : null;
    if (background != null) {
      colors.add(background);
    }
    return true;
  });
  return colors;
}

/// Get the background colours painted over the text of the card, in order.
List<Color> _cardBackgrounds(WidgetTester tester) {
  final field = find.descendant(of: find.byType(OcptNoteCard), matching: find.byType(TextField));
  if (field.evaluate().isNotEmpty) {
    final controller = tester.widget<TextField>(field).controller!;
    return _backgrounds(
      controller.buildTextSpan(context: tester.element(field), withComposing: false),
    );
  }

  final text = find.descendant(of: find.byType(OcptNoteCard), matching: find.byType(RichText));
  return [
    for (final element in text.evaluate()) ..._backgrounds((element.widget as RichText).text),
  ];
}

/// Tell whether the marker of the first note is drawn with the outline hinting at a match.
bool _markerHintsAtMatch(WidgetTester tester) {
  final container = tester.widget<Container>(
    find.descendant(
      of: find.byType(OcptFountainNoteMarker).first,
      matching: find.byType(Container),
    ),
  );
  return (container.decoration! as BoxDecoration).border != null;
}

/// Run the tests of the search and replace in the text of the notes.
void main() {
  BlinkController.indeterminateAnimationsEnabled = false;

  group("the search in the notes of the styled editor", () {
    testWidgets("counts the matches in the text of the notes with the others", (tester) async {
      await _pump(tester, _source);

      await _search(tester, 0);

      expect(_controller.searchMatchCount, 3);
    });

    testWidgets("selects the note holding the current match, highlighting it in its card", (
      tester,
    ) async {
      await _pump(tester, _source);
      expect(find.byType(OcptNoteCard), findsOneWidget);
      expect(tester.widget<OcptNoteCard>(find.byType(OcptNoteCard)).isSelected, isFalse);
      expect(_markerHintsAtMatch(tester), isFalse);

      await _search(tester, 1);

      final card = tester.widget<OcptNoteCard>(find.byType(OcptNoteCard));
      expect(card.isSelected, isTrue);
      expect(card.matches!.current, const OcptTextMatch(start: 3, end: 6));
      expect(_cardBackgrounds(tester), [ocptEditorSearchCurrentMatchColor]);
      expect(_markerHintsAtMatch(tester), isTrue);
    });

    testWidgets("leaves no text selected once the current match moves into a note", (tester) async {
      await _pump(tester, _source);
      await _search(tester, 0);
      expect(SuperEditorInspector.findDocumentSelection()!.isCollapsed, isFalse);

      await _search(tester, 1);

      final selection = SuperEditorInspector.findDocumentSelection()!;
      final node = SuperEditorInspector.findDocument()!.first as ParagraphNode;
      expect(selection.isCollapsed, isTrue);
      expect(
        (selection.extent.nodePosition as TextNodePosition).offset,
        node.text.placeholders.keys.single + 1,
      );
    });

    testWidgets("keeps the focus in the find field while it navigates to a note", (tester) async {
      await _pump(tester, _source);
      expect(_findFocus.hasFocus, isTrue);

      await _search(tester, 1);

      expect(_findFocus.hasFocus, isTrue);
      final field = find.descendant(
        of: find.byType(OcptNoteCard),
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(field).focusNode!.hasFocus, isFalse);
    });

    testWidgets("paints a match of a note that is not the current one with the other colour", (
      tester,
    ) async {
      await _pump(tester, _source);

      await _search(tester, 2);

      expect(tester.widget<OcptNoteCard>(find.byType(OcptNoteCard)).isSelected, isFalse);
      expect(_cardBackgrounds(tester), [ocptEditorSearchMatchColor]);
      expect(_markerHintsAtMatch(tester), isTrue);
    });

    testWidgets("lets go of the note when the current match goes back to the text", (tester) async {
      await _pump(tester, _source);
      await _search(tester, 1);

      await _search(tester, 0);

      expect(tester.widget<OcptNoteCard>(find.byType(OcptNoteCard)).isSelected, isFalse);
      expect(_findFocus.hasFocus, isTrue);
    });

    testWidgets("lets go of the note when the search ends", (tester) async {
      await _pump(tester, _source);
      await _search(tester, 1);

      _controller.updateSearch(query: null, currentMatchIndex: null);
      await tester.pumpAndSettle();

      expect(tester.widget<OcptNoteCard>(find.byType(OcptNoteCard)).isSelected, isFalse);
      expect(_cardBackgrounds(tester), isEmpty);
      expect(_markerHintsAtMatch(tester), isFalse);
    });

    testWidgets("opens the popover of the note where the column has no room", (tester) async {
      await _pump(tester, _source, width: _narrowWidth);
      expect(find.byType(OcptNoteCard), findsNothing);

      await _search(tester, 1);

      expect(find.byType(OcptStyledNotesMargin), findsNothing);
      expect(find.byType(OcptNoteCard), findsOneWidget);
      expect(_cardBackgrounds(tester), [ocptEditorSearchCurrentMatchColor]);
      expect(_findFocus.hasFocus, isTrue);
      expect(_markerHintsAtMatch(tester), isTrue);
    });

    testWidgets("keeps the popover open on a click in the find field", (tester) async {
      await _pump(tester, _source, width: _narrowWidth);
      await _search(tester, 1);

      await tester.tapAt(const Offset(200, 20));
      await tester.pumpAndSettle();

      expect(find.byType(OcptNoteCard), findsOneWidget);
    });

    testWidgets("replaces a match in a note, as its own undo step, and moves on to the next", (
      tester,
    ) async {
      await _pump(tester, _source);
      await _search(tester, 1);

      final next = _controller.replaceCurrentMatch("new");
      await pumpPastSettleDebounce(tester);

      expect(next, 1);
      expect(_notes().single.text, "an new one");
      expect(_encoded, contains("Old man waits [[an new one]] now, so old."));

      tester.widget<SuperEditor>(find.byType(SuperEditor)).editor.undo();
      await pumpPastSettleDebounce(tester);

      expect(_notes().single.text, "an old one");
    });

    testWidgets("replaces all the matches of the text and of the notes in one undo step", (
      tester,
    ) async {
      await _pump(tester, _source);
      await _search(tester, 0);

      _controller.replaceAllMatches("X");
      await pumpPastSettleDebounce(tester);

      expect(_notes().single.text, "an X one");
      expect(_encoded, startsWith("X man waits [[an X one]] now, so X."));

      tester.widget<SuperEditor>(find.byType(SuperEditor)).editor.undo();
      await pumpPastSettleDebounce(tester);

      expect(_notes().single.text, "an old one");
      expect(_encoded, startsWith("Old man waits [[an old one]] now, so old."));
    });

    testWidgets("keeps the identifier of a note it replaces in", (tester) async {
      await _pump(tester, _source);
      final id = _notes().single.id;
      await _search(tester, 1);

      _controller.replaceAllMatches("X");
      await pumpPastSettleDebounce(tester);

      expect(_notes().single.id, id);
    });

    testWidgets("skips a note that cannot hold the replacement, the others being replaced", (
      tester,
    ) async {
      await _pump(tester, "Old man waits [[ends with old]] now, so old.\n\nTHE END.");
      await _search(tester, 0);
      expect(_controller.searchMatchCount, 3);

      _controller.replaceAllMatches("x]");
      await pumpPastSettleDebounce(tester);

      expect(_notes().single.text, "ends with old");
      expect(_encoded, startsWith("x] man waits [[ends with old]] now, so x]."));
    });

    testWidgets("refuses a replacement making `]]` or a boneyard mark in a note", (tester) async {
      for (final replacement in ["a]]b", "a/*b", "a*/b"]) {
        await _pump(tester, "Say [[an old one]] now.\n\nTHE END.");
        await _search(tester, 0);

        _controller.replaceAllMatches(replacement);
        await pumpPastSettleDebounce(tester);

        expect(_notes().single.text, "an old one", reason: replacement);
      }
    });

    testWidgets("goes on to the next match when replacing one a note cannot hold", (tester) async {
      await _pump(tester, "Old man waits [[ends with old]] now, so old.\n\nTHE END.");
      await _search(tester, 1);

      final next = _controller.replaceCurrentMatch("x]");
      await pumpPastSettleDebounce(tester);

      expect(next, 2);
      expect(_notes().single.text, "ends with old");
    });

    testWidgets("orders the matches of a note where its marker stands", (tester) async {
      await _pump(tester, "Say old [[old and old]] old.\n\nTHE END.");

      await _search(tester, 2);

      expect(_controller.searchMatchCount, 4);
      expect(tester.widget<OcptNoteCard>(find.byType(OcptNoteCard)).isSelected, isTrue);
      expect(
        tester.widget<OcptNoteCard>(find.byType(OcptNoteCard)).matches!.current,
        const OcptTextMatch(start: 8, end: 11),
      );
    });
  });
}
