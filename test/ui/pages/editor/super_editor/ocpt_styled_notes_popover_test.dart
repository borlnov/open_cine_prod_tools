// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_note.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_note_marker.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_notes_margin.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_screenplay_editor.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_note_card.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'ocpt_styled_screenplay_editor_test_doubles.dart';

/// The text of the document the tests share: a note in the middle of an action line, and a line
/// below it.
const String _source = "He waits [[old]] now.\n\nShe leaves.";

/// The width of a surface that is not compact yet has no room for the margin column.
const double _narrowWidth = 1000;

/// The width of a surface with room for the margin column.
const double _wideWidth = 1600;

/// Pump the editor over [text] on a surface [width] logical pixels wide, compact or not.
Future<void> _pump(
  WidgetTester tester,
  String text, {
  double width = _narrowWidth,
  bool isCompact = false,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_editor(text, isCompact: isCompact));
  await tester.pumpAndSettle();
}

/// Build the editor over [text].
Widget _editor(String text, {bool isCompact = false}) => testWrap(
  OcptStyledScreenplayEditor(
    text: text,
    pageSetup: const OcptPageSetup.standard(),
    isPageSimulationEnabled: false,
    isCompact: isCompact,
    areSceneNumbersVisible: false,
    isSpellCheckVisible: false,
    onTextChanged: (_) {},
    onCaretLineChanged: (_) {},
    jumpRequest: null,
  ),
);

/// Run a [testWidgets] case with a desktop [defaultTargetPlatform], which is what makes the styled
/// editor build the mouse interactor that receives a secondary tap.
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

/// Get the document of the editor.
Document _document() => SuperEditorInspector.findDocument()!;

/// Get the notes the document holds, in document order.
List<OcptFountainNote> _notes() => [
  for (final node in _document().whereType<ParagraphNode>())
    ...node.text.placeholders.values.whereType<OcptFountainNote>(),
];

/// Get the field of the card.
Finder _field() => find.descendant(of: find.byType(OcptNoteCard), matching: find.byType(TextField));

/// Tap the marker of the first note.
Future<void> _tapMarker(WidgetTester tester) async {
  await tester.tapAt(tester.getCenter(find.byType(OcptFountainNoteMarker).first));
  await tester.pumpAndSettle();
}

/// Get the offset of the caret of the editor.
int _caretOffset() =>
    (SuperEditorInspector.findDocumentSelection()!.extent.nodePosition as TextNodePosition).offset;

/// Run the tests of the popover a note opens in while the margin column has no room.
void main() {
  BlinkController.indeterminateAnimationsEnabled = false;

  group("the popover of a note", () {
    testWidgets("opens under the marker on a tap, as the same editable card", (tester) async {
      await _pump(tester, _source);
      expect(find.byType(OcptNoteCard), findsNothing);

      await _tapMarker(tester);

      expect(find.byType(OcptNoteCard), findsOneWidget);
      expect(tester.widget<OcptNoteCard>(find.byType(OcptNoteCard)).isSelected, isTrue);
      expect(_field(), findsOneWidget);
      expect(tester.widget<TextField>(_field()).focusNode!.hasFocus, isTrue);
      final marker = tester.getRect(find.byType(OcptFountainNoteMarker).first);
      final card = tester.getRect(find.byType(OcptNoteCard));
      expect(card.top, greaterThan(marker.bottom));
      expect(card.center.dx, closeTo(marker.center.dx, card.width / 2));
    });

    testWidgets("opens on a compact surface the same way", (tester) async {
      await _pump(tester, _source, width: _wideWidth, isCompact: true);

      await _tapMarker(tester);

      expect(find.byType(OcptNoteCard), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(OcptStyledNotesMargin),
          matching: find.byType(OcptNoteCard),
        ),
        findsNothing,
      );
    });

    testWidgets("writes what is typed in it to the note, in one undo step", (tester) async {
      await _pump(tester, _source);
      await _tapMarker(tester);

      await tester.enterText(_field(), "n");
      await tester.pump();
      await tester.enterText(_field(), "new");
      await tester.pump();
      await tester.enterText(_field(), "refused ]]");
      await tester.pump();

      expect(_notes().single.text, "new");

      tester.widget<SuperEditor>(find.byType(SuperEditor)).editor.undo();
      await tester.pumpAndSettle();
      expect(_notes().single.text, "old");
    });

    testWidgets("closes on Escape, the caret after the marker", (tester) async {
      await _pump(tester, _source);
      await _tapMarker(tester);
      final offset = _document()
          .whereType<ParagraphNode>()
          .firstWhere((node) => node.text.placeholders.isNotEmpty)
          .text
          .placeholders
          .keys
          .single;

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(OcptNoteCard), findsNothing);
      expect(_caretOffset(), offset + 1);
      expect(_notes().single.text, "old");
    });

    testWidgets("closes on Enter, keeping what was typed", (tester) async {
      await _pump(tester, _source);
      await _tapMarker(tester);
      await tester.enterText(_field(), "kept");
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.byType(OcptNoteCard), findsNothing);
      expect(_notes().single.text, "kept");
    });

    testWidgets("closes on a click outside it, in the text", (tester) async {
      await _pump(tester, _source);
      await _tapMarker(tester);

      await tester.tapAt(tester.getTopLeft(find.byType(SuperEditor)) + const Offset(400, 600));
      await tester.pumpAndSettle();

      expect(find.byType(OcptNoteCard), findsNothing);
    });

    testWidgets("closes on a click outside the editor while it is being typed in", (tester) async {
      await _pump(tester, _source);
      await _tapMarker(tester);

      await tester.tapAt(const Offset(5, 995));
      await tester.pumpAndSettle();

      expect(find.byType(OcptNoteCard), findsNothing);
    });

    testWidgets("stays open on a click inside it", (tester) async {
      await _pump(tester, _source);
      await _tapMarker(tester);

      await tester.tap(_field());
      await tester.pumpAndSettle();

      expect(find.byType(OcptNoteCard), findsOneWidget);
    });

    testWidgets("removes an empty note when it is closed", (tester) async {
      await _pump(tester, _source);
      await _tapMarker(tester);
      await tester.enterText(_field(), "");
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(_notes(), isEmpty);
    });

    testWidgets("removes the note with its Remove note button", (tester) async {
      await _pump(tester, _source);
      await _tapMarker(tester);
      final tr = Tr.of(tester.element(find.byType(OcptNoteCard)));

      await tester.tap(find.text(tr.editorContextMenuRemoveNoteAction));
      await tester.pumpAndSettle();

      expect(_notes(), isEmpty);
      expect(find.byType(OcptNoteCard), findsNothing);
      expect(find.byType(OcptFountainNoteMarker), findsNothing);
    });

    testWidgets("gives way to the column when the surface widens", (tester) async {
      await _pump(tester, _source);
      await _tapMarker(tester);
      expect(
        find.descendant(
          of: find.byType(OcptStyledNotesMargin),
          matching: find.byType(OcptNoteCard),
        ),
        findsNothing,
      );

      tester.view.physicalSize = const Size(_wideWidth, 1000);
      await tester.pumpAndSettle();

      expect(find.byType(OcptNoteCard), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(OcptStyledNotesMargin),
          matching: find.byType(OcptNoteCard),
        ),
        findsOneWidget,
      );
      expect(tester.widget<OcptNoteCard>(find.byType(OcptNoteCard)).isSelected, isTrue);
    });

    testWidgets("flips above the marker when there is no room below", (tester) async {
      await _pump(tester, "One.\n\nTwo.\n\nThree.\n\nFour.\n\nHe waits [[old]] now.");
      final markerBottom = tester.getRect(find.byType(OcptFountainNoteMarker).first).bottom;
      tester.view.physicalSize = Size(_narrowWidth, markerBottom + 50);
      await tester.pumpAndSettle();

      await _tapMarker(tester);

      final marker = tester.getRect(find.byType(OcptFountainNoteMarker).first);
      final card = tester.getRect(find.byType(OcptNoteCard));
      expect(card.bottom, lessThan(marker.top));
      expect(card.top, greaterThanOrEqualTo(0));
    });

    _testWidgetsAsDesktop("opens on Insert note from the context menu", (tester) async {
      await _pump(tester, "He waits now.\n\nShe leaves.");
      final nodeId = _document().first.id;
      await tester.tapAt(
        SuperEditorInspector.findComponentOffset(nodeId, Alignment.centerLeft) + const Offset(4, 0),
        buttons: kSecondaryButton,
      );
      await tester.pumpAndSettle();
      final tr = Tr.of(tester.element(find.byType(OcptStyledScreenplayEditor)));

      await tester.tap(find.widgetWithText(MenuItemButton, tr.editorContextMenuInsertNoteAction));
      await tester.pumpAndSettle();

      expect(_notes().length, 1);
      expect(find.byType(OcptNoteCard), findsOneWidget);
      expect(tester.widget<TextField>(_field()).focusNode!.hasFocus, isTrue);
    });
  });
}
