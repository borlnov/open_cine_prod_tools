// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_word_layout.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_fountain_line_display.dart';

/// Lays [sceneText] out and returns the block at [index], the unit
/// [ocptFountainWordDisplayRuns] works on.
OcptScriptWordBlock _blockOf(String sceneText, {int index = 0}) =>
    OcptScriptWordLayout.of(sceneId: "scene-1", sceneText: sceneText).blocks[index];

/// The whole printed text of [block]'s words, runs and words concatenated back together: what the
/// coverage sheet ends up showing for that line.
String _printedTextOf(OcptScriptWordBlock block) => ocptFountainWordDisplayRuns(
  block,
).expand((runs) => runs).map((run) => run.text).join();

void main() {
  group("ocptFountainWordDisplayRuns", () {
    test("keeps a plain line as it is, each word carrying the whitespace that follows it", () {
      final block = _blockOf("Action one two.");

      final runs = ocptFountainWordDisplayRuns(block);

      expect(runs, hasLength(3));
      expect(runs[0], [(text: "Action ", style: FountainInlineStyle.plain)]);
      expect(runs[1], [(text: "one ", style: FountainInlineStyle.plain)]);
      expect(runs[2], [(text: "two.", style: FountainInlineStyle.plain)]);
    });

    test("resolves emphasis markers away, keeping the style they carried", () {
      final block = _blockOf("John *walks* in.");

      final runs = ocptFountainWordDisplayRuns(block);

      expect(_printedTextOf(block), "John walks in.");
      // The emphasised text and the space after the closing marker are two runs of the same word's
      // box: the space carries no emphasis of its own.
      expect(runs[1], [
        (text: "walks", style: FountainInlineStyle.italic),
        (text: " ", style: FountainInlineStyle.plain),
      ]);
    });

    test("resolves bold and underline the same way", () {
      expect(_printedTextOf(_blockOf("John **walks** in.")), "John walks in.");
      expect(_printedTextOf(_blockOf("John _walks_ in.")), "John walks in.");
      expect(
        ocptFountainWordDisplayRuns(_blockOf("John **walks** in."))[1].first.style,
        FountainInlineStyle.bold,
      );
    });

    test("splits a word carrying two styles into one run each", () {
      final block = _blockOf("*two*words follow.");

      final runs = ocptFountainWordDisplayRuns(block);

      expect(runs.first, [
        (text: "two", style: FountainInlineStyle.italic),
        (text: "words ", style: FountainInlineStyle.plain),
      ]);
    });

    test("drops an inline note entirely: it is never part of the printed screenplay", () {
      final block = _blockOf("John walks [[check this]] in.");

      expect(_printedTextOf(block), "John walks  in.");
    });

    test("hides a scene heading's forcing dot and its trailing scene number", () {
      final block = _blockOf(".INT. HOUSE - DAY #3#");

      expect(_printedTextOf(block).trim(), "INT. HOUSE - DAY");
    });

    test("hides a forced action's `!`, a forced character's `@` and a forced transition's `>`", () {
      expect(_printedTextOf(_blockOf("!Action forced.")), "Action forced.");
      expect(_printedTextOf(_blockOf("@McAvoy")), "McAvoy");
      expect(_printedTextOf(_blockOf(">CUT TO:")), "CUT TO:");
    });

    test("hides both markers of a centered line", () {
      expect(_printedTextOf(_blockOf("> THE END <")).trim(), "THE END");
    });

    test("only strips a marker where its own line type may carry one", () {
      // A trailing `#N#` is a scene heading's scene number; a dialogue line ending the same way is
      // just text, and keeps it.
      final layout = OcptScriptWordLayout.of(
        sceneId: "scene-1",
        sceneText: "INT. HOUSE - DAY\n\nJOHN\nRoom #3#",
      );
      final dialogue = layout.blocks.last;

      expect(dialogue.type, FountainLineType.dialogue);
      expect(_printedTextOf(dialogue), "Room #3#");
    });

    test("leaves an escaped marker visible rather than guessing which side it belongs to", () {
      // `\\*` prints a literal asterisk; the span's source is one character longer on one side
      // only, so the helper shows the run as it stands rather than hiding a character.
      expect(_printedTextOf(_blockOf(r"John \*walks in.")), contains("walks in."));
    });

    test("never changes the words' own source offsets", () {
      const sceneText = "John *walks* in.";
      final block = _blockOf(sceneText);

      for (final word in block.words) {
        expect(sceneText.substring(word.startOffset, word.endOffset), word.text);
      }
      // The emphasised word still covers its markers in the source, which is what a coverage range
      // recorded from a click on it stores.
      expect(block.words[1].text, "*walks*");
    });
  });
}
