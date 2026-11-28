// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_note_marker.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_note_connector_painter.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_notes_margin.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_screenplay_editor.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_note_card.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import 'ocpt_styled_screenplay_editor_test_doubles.dart';

/// The text of the document the tests below share: two notes, one in each of two lines.
final String _twoNotes =
    "First line [[one]] ends.\n\n${List.generate(8, (index) => "Filler line $index.\n\n").join()}"
    "Second line [[two]] ends.";

/// Pump a bare editor of [text] on a surface [width] logical pixels wide.
Future<void> _pump(
  WidgetTester tester,
  String text, {
  double width = 1600,
  double height = 3000,
  bool isPageSimulationEnabled = false,
  bool isCompact = false,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    testWrap(
      OcptStyledScreenplayEditor(
        text: text,
        pageSetup: const OcptPageSetup.standard(),
        isPageSimulationEnabled: isPageSimulationEnabled,
        isCompact: isCompact,
        areSceneNumbersVisible: false,
        isSpellCheckVisible: false,
        onTextChanged: (_) {},
        onCaretLineChanged: (_) {},
        jumpRequest: null,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Find the first node of [document] that holds a note, which in page simulation is not the first.
TextNode _firstNoteNode(Document document) =>
    document.whereType<TextNode>().firstWhere((node) => node.text.placeholders.isNotEmpty);

/// Find the line joining a selected note's marker to its card.
final Finder _connector = find.byWidgetPredicate(
  (widget) => widget is CustomPaint && widget.painter is OcptNoteConnectorPainter,
);

/// Tell whether the card number [index] is drawn as the selected one.
bool _isSelected(WidgetTester tester, int index) =>
    tester.widget<OcptNoteCard>(find.byType(OcptNoteCard).at(index)).isSelected;

/// Tell whether the marker number [index] is drawn solid.
bool _isSolid(WidgetTester tester, int index) {
  final container = tester.widget<Container>(
    find
        .descendant(
          of: find.byType(OcptFountainNoteMarker).at(index),
          matching: find.byType(Container),
        )
        .first,
  );
  return (container.decoration! as BoxDecoration).color == OcptFountainNoteMarker.accentColor;
}

/// Run the tests of the notes margin of the styled screenplay editor.
void main() {
  BlinkController.indeterminateAnimationsEnabled = false;

  for (final isPageSimulationEnabled in [true, false]) {
    group(
      "the notes margin ${isPageSimulationEnabled ? "beside the page" : "of the fluid text"}",
      () {
        Future<void> pump(
          WidgetTester tester,
          String text, {
          double width = 1600,
          bool isCompact = false,
        }) => _pump(
          tester,
          text,
          width: width,
          isPageSimulationEnabled: isPageSimulationEnabled,
          isCompact: isCompact,
        );

        testWidgets("shows one card per note, in document order, when the surface is wide", (
          tester,
        ) async {
          await pump(tester, _twoNotes);

          expect(find.byType(OcptNoteCard), findsNWidgets(2));
          final texts = [
            for (var index = 0; index < 2; index++)
              tester.widget<OcptNoteCard>(find.byType(OcptNoteCard).at(index)).text,
          ];
          expect(texts, ["one", "two"]);
          expect(
            tester.getTopLeft(find.byType(OcptNoteCard).at(0)).dy,
            lessThan(tester.getTopLeft(find.byType(OcptNoteCard).at(1)).dy),
          );
        });

        testWidgets("aligns each card with the line of its marker", (tester) async {
          await pump(tester, _twoNotes);

          for (var index = 0; index < 2; index++) {
            final marker = tester.getCenter(find.byType(OcptFountainNoteMarker).at(index));
            final card = tester.getRect(find.byType(OcptNoteCard).at(index));

            expect(card.top, closeTo(marker.dy, 20));
            expect(card.left, greaterThan(tester.getRect(find.byType(SuperEditor)).left));
            expect(card.width, OcptStyledNotesMargin.cardWidth);
          }
        });

        testWidgets("has no card without a note", (tester) async {
          await pump(tester, "A line without any note.");

          expect(find.byType(OcptNoteCard), findsNothing);
        });

        testWidgets("has no card when the surface is too narrow for it", (tester) async {
          await pump(tester, _twoNotes, width: 1000);

          expect(find.byType(OcptNoteCard), findsNothing);
          expect(find.byType(OcptFountainNoteMarker), findsNWidgets(2));
        });

        testWidgets("has no card on a compact surface", (tester) async {
          await pump(tester, _twoNotes, isCompact: true);

          expect(find.byType(OcptNoteCard), findsNothing);
        });

        testWidgets("selects a note on a tap on its marker, and draws it solid", (tester) async {
          await pump(tester, _twoNotes);
          expect(_isSolid(tester, 0), isFalse);

          await tester.tapAt(tester.getCenter(find.byType(OcptFountainNoteMarker).at(1)));
          await tester.pumpAndSettle();

          expect(_isSelected(tester, 0), isFalse);
          expect(_isSelected(tester, 1), isTrue);
          expect(_isSolid(tester, 0), isFalse);
          expect(_isSolid(tester, 1), isTrue);
        });

        testWidgets("shifts the selected card towards the page", (tester) async {
          await pump(tester, _twoNotes);
          final left = tester.getRect(find.byType(OcptNoteCard).at(0)).left;

          await tester.tapAt(tester.getCenter(find.byType(OcptFountainNoteMarker).at(0)));
          await tester.pumpAndSettle();

          expect(
            tester.getRect(find.byType(OcptNoteCard).at(0)).left,
            left - OcptStyledNotesMargin.selectedShift,
          );
        });

        testWidgets("joins the marker of the selected note only to its card", (tester) async {
          await pump(tester, _twoNotes);
          expect(_connector, findsNothing);

          await tester.tap(find.byType(OcptNoteCard).at(1));
          await tester.pumpAndSettle();

          expect(_connector, findsOneWidget);
        });

        testWidgets("selects a note on a tap on its card", (tester) async {
          await pump(tester, _twoNotes);

          await tester.tap(find.byType(OcptNoteCard).at(0));
          await tester.pumpAndSettle();

          expect(_isSelected(tester, 0), isTrue);
          expect(_isSolid(tester, 0), isTrue);
          expect(_isSolid(tester, 1), isFalse);
        });

        testWidgets("drops the selection on a tap elsewhere in the text", (tester) async {
          await pump(tester, _twoNotes);
          await tester.tap(find.byType(OcptNoteCard).at(0));
          await tester.pumpAndSettle();
          final document = SuperEditorInspector.findDocument()!;

          await tester.placeCaretInParagraph(_firstNoteNode(document).id, 2);
          await tester.pumpAndSettle();

          expect(_isSelected(tester, 0), isFalse);
          expect(_isSolid(tester, 0), isFalse);
        });

        testWidgets("drops the selection and the card of a note that is deleted", (tester) async {
          await pump(tester, _twoNotes);
          await tester.tap(find.byType(OcptNoteCard).at(0));
          await tester.pumpAndSettle();
          final document = SuperEditorInspector.findDocument()!;
          final node = _firstNoteNode(document);
          final offset = node.text.placeholders.keys.first;
          tester.widget<SuperEditor>(find.byType(SuperEditor)).editor.execute([
            DeleteContentRequest(
              documentRange: DocumentRange(
                start: DocumentPosition(
                  nodeId: node.id,
                  nodePosition: TextNodePosition(offset: offset),
                ),
                end: DocumentPosition(
                  nodeId: node.id,
                  nodePosition: TextNodePosition(offset: offset + 1),
                ),
              ),
            ),
          ]);
          await pumpPastSettleDebounce(tester);

          expect(find.byType(OcptNoteCard), findsOneWidget);
          expect(_isSelected(tester, 0), isFalse);
          expect(_isSolid(tester, 0), isFalse);
        });
      },
    );
  }

  group("the notes margin while the text scrolls", () {
    testWidgets("keeps each card level with its marker", (tester) async {
      await _pump(
        tester,
        "[[one]] First.\n\n${List.generate(8, (index) => "Filler $index.\n\n").join()}"
        "Second [[two]] line.\n\n${List.generate(30, (index) => "Tail $index.\n\n").join()}",
        height: 500,
      );
      final marker = find.byType(OcptFountainNoteMarker).at(1);
      final card = find.byType(OcptNoteCard).at(1);
      final before = tester.getCenter(marker).dy;

      tester.widget<SuperEditor>(find.byType(SuperEditor)).scrollController!.jumpTo(150);
      await tester.pumpAndSettle();

      expect(tester.getCenter(marker).dy, lessThan(before - 100));
      expect(tester.getRect(card).top, closeTo(tester.getCenter(marker).dy, 20));
    });
  });

  group("the notes margin of the simulated page", () {
    testWidgets("centres the page and the column together", (tester) async {
      await _pump(tester, _twoNotes, isPageSimulationEnabled: true);
      final page = tester.getRect(find.byType(SuperEditor));
      final card = tester.getRect(find.byType(OcptNoteCard).first);

      final columnRight = card.right;
      final totalLeft = page.left;
      expect(
        (totalLeft - 0) - (1600 - columnRight),
        closeTo(0, 12),
        reason: "the page and the column leave the same room on both sides",
      );
    });
  });
}
