// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_word_layout.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_coverage_range.dart';

/// Lay [sceneText] out as the scene `scene-1`.
OcptScriptWordLayout _layoutOf(String sceneText) =>
    OcptScriptWordLayout.of(sceneId: "scene-1", sceneText: sceneText);

/// Get the sides of [layout]'s blocks, one per non-blank line.
List<FountainDualDialogueSide?> _sidesOf(OcptScriptWordLayout layout) => [
  for (final block in layout.blocks) block.dualSide,
];

/// Get the source line a block of [layout] starts on.
int _lineOf(OcptScriptWordLayout layout, int blockIndex) =>
    '\n'.allMatches(layout.sceneText.substring(0, layout.blocks[blockIndex].startOffset)).length;

/// Run the tests of the dual-dialogue part of [OcptScriptWordLayout].
void main() {
  const left = FountainDualDialogueSide.left;
  const right = FountainDualDialogueSide.right;

  group("OcptScriptWordLayout dual dialogue", () {
    test("gives each block of a pair its side and exposes the pair over the blocks", () {
      final layout = _layoutOf("ROSS\n(sighs)\nFirst.\n\nKIM^\nSecond.\n\nAfter.");

      expect(_sidesOf(layout), [left, left, left, right, right, null]);
      expect(layout.dualPairs, [(left: (start: 0, end: 3), right: (start: 3, end: 5))]);
    });

    test("leaves a scene without any pair untouched", () {
      final layout = _layoutOf("INT. ROOM - DAY\n\nROSS\nHi.\n\nKIM\nYo.");

      expect(layout.dualPairs, isEmpty);
      expect(_sidesOf(layout).every((side) => side == null), isTrue);
    });

    test("pairs the first two of a ROSS, KIM^, ROSS^ chain and leaves the third alone", () {
      final layout = _layoutOf("ROSS\nA.\n\nKIM^\nB.\n\nROSS^\nC.");

      expect(_sidesOf(layout), [left, left, right, right, null, null]);
    });

    test("leaves an orphan cue with a caret outside any pair", () {
      final layout = _layoutOf("Action.\n\nKIM^\nB.");

      expect(layout.dualPairs, isEmpty);
      expect(_sidesOf(layout), [null, null, null]);
    });

    test("an intervening line breaks the pair", () {
      final layout = _layoutOf("ROSS\nA.\n\nSome action.\n\nKIM^\nB.");

      expect(layout.dualPairs, isEmpty);
    });

    test("keeps a lone caret out of the words and moves no offset", () {
      const sceneText = "ROSS\nA.\n\nKIM ^\nB.";
      final layout = _layoutOf(sceneText);
      final cue = layout.blocks[2];

      expect(cue.text, "KIM ^");
      expect(cue.words.map((word) => word.text), ["KIM"]);
      expect(cue.startOffset, 9);
      expect(cue.endOffset, 14);
      expect(layout.blocks[3].startOffset, 15);
    });

    test("keeps a caret glued to the name as part of its word", () {
      final layout = _layoutOf("ROSS\nA.\n\nKIM^\nB.");

      expect(layout.blocks[2].words.map((word) => word.text), ["KIM^"]);
    });

    test("keeps a caret that is no cue marker as a word", () {
      final layout = _layoutOf("ROSS\nA.\n\nKIM\nUp ^ there.");

      expect(layout.blocks[3].words.map((word) => word.text), ["Up", "^", "there."]);
    });

    test("does not count a lone caret among the covered words", () {
      final layout = _layoutOf("ROSS\nA.\n\nKIM ^\nB.");
      final whole = OcptShotCoverageRange(
        id: "r",
        sceneId: "scene-1",
        startOffset: 0,
        endOffset: layout.sceneText.length,
        coveredTextDigest: "",
        isStale: false,
      );

      // ROSS, A., KIM, B.
      expect(layout.countCoveredWords([whole]), 4);
    });

    test("names the covered column's character, or both for a range over the pair", () {
      final layout = _layoutOf("ROSS\nA.\n\nKIM^\nB.");
      final leftDialogue = layout.blocks[1];
      final rightDialogue = layout.blocks[3];

      expect(
        layout.charactersCoveredBy(
          startOffset: leftDialogue.startOffset,
          endOffset: leftDialogue.endOffset,
        ),
        ["ROSS"],
      );
      expect(
        layout.charactersCoveredBy(
          startOffset: rightDialogue.startOffset,
          endOffset: rightDialogue.endOffset,
        ),
        ["KIM"],
      );
      expect(
        layout.charactersCoveredBy(
          startOffset: leftDialogue.startOffset,
          endOffset: rightDialogue.endOffset,
        ),
        ["ROSS", "KIM"],
      );
    });
  });

  group("OcptScriptWordLayout dual dialogue against the parser", () {
    final files =
        Directory("packages/fountain_kit/test/corpus")
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith(".fountain"))
            .toList(growable: false)
          ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in files) {
      test("${file.uri.pathSegments.last}: the layout pairs what the parser pairs", () {
        final source = file.readAsStringSync();
        final blocks = const FountainParser().parse(source).blocks;
        final layout = _layoutOf(source);

        expect(
          [
            for (final pair in layout.dualPairs)
              (_lineOf(layout, pair.left.start), _lineOf(layout, pair.right.start)),
          ],
          [
            for (final pair in fountainDualDialoguePairs(blocks))
              (blocks[pair.left].sourceRange.startLine, blocks[pair.right].sourceRange.startLine),
          ],
        );
      });
    }
  });
}
