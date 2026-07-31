// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_scene_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_coverage_layout.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_coverage_range.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';

/// Builds an [OcptShotCoverageRange] test double with sensible defaults for the fields a given
/// test doesn't care about.
OcptShotCoverageRange _buildRange({
  required String sceneId,
  required int startOffset,
  required int endOffset,
  String id = "range",
}) => OcptShotCoverageRange(
  id: id,
  sceneId: sceneId,
  startOffset: startOffset,
  endOffset: endOffset,
  coveredTextDigest: "irrelevant-for-this-test",
  isStale: false,
);

void main() {
  const sceneId = "scene-1";

  // A realistic scene: heading, a blank line, an action line, another blank line, a character
  // cue, a parenthetical, and a dialogue line.
  const sceneText = 'INT. HOUSE - DAY\n\nJohn walks in.\n\nJOHN\n(whispering)\nHello there.';

  group("OcptShotCoverageLayout.of", () {
    test("skips blank lines, keeping one block per non-blank source line", () {
      final layout = OcptShotCoverageLayout.of(sceneId: sceneId, sceneText: sceneText);

      expect(layout.blocks.map((block) => block.text), [
        "INT. HOUSE - DAY",
        "John walks in.",
        "JOHN",
        "(whispering)",
        "Hello there.",
      ]);
    });

    test("classifies a realistic scene's lines by Fountain line type", () {
      final layout = OcptShotCoverageLayout.of(sceneId: sceneId, sceneText: sceneText);

      expect(layout.blocks.map((block) => block.type), [
        FountainLineType.sceneHeading,
        FountainLineType.action,
        FountainLineType.character,
        FountainLineType.parenthetical,
        FountainLineType.dialogue,
      ]);
    });

    test("every word's offsets round-trip through sceneText.substring", () {
      final layout = OcptShotCoverageLayout.of(sceneId: sceneId, sceneText: sceneText);

      for (final block in layout.blocks) {
        for (final word in block.words) {
          expect(sceneText.substring(word.startOffset, word.endOffset), word.text);
        }
      }
    });

    test("keeps punctuation attached to the word it touches", () {
      final layout = OcptShotCoverageLayout.of(sceneId: sceneId, sceneText: sceneText);

      final heading = layout.blocks.first;
      expect(heading.words.map((word) => word.text), ["INT.", "HOUSE", "-", "DAY"]);
    });

    test("a block's own startOffset/endOffset exclude the line's trailing newline", () {
      final layout = OcptShotCoverageLayout.of(sceneId: sceneId, sceneText: sceneText);

      final heading = layout.blocks.first;
      expect(heading.startOffset, 0);
      expect(heading.endOffset, "INT. HOUSE - DAY".length);
      expect(sceneText.substring(heading.startOffset, heading.endOffset), heading.text);
    });

    test("leaves a wider gap between two blocks the source separates with a blank line", () {
      final layout = OcptShotCoverageLayout.of(sceneId: sceneId, sceneText: sceneText);
      final heading = layout.blocks[0];
      final action = layout.blocks[1];
      final character = layout.blocks[2];
      final parenthetical = layout.blocks[3];

      // A blank line separates the heading from the action, so their offsets are more than one
      // character (the newline) apart; the cue and its parenthetical are adjacent lines, so theirs
      // are exactly one apart. This is what the coverage sheet reads to reproduce the paper
      // preview's spacing.
      expect(action.startOffset - heading.endOffset, greaterThan(1));
      expect(parenthetical.startOffset - character.endOffset, 1);
    });

    test("handles a scene text with no trailing newline and one with a trailing blank line", () {
      const withoutTrailingNewline = "INT. HOUSE - DAY\n\nAction.";
      const withTrailingNewline = "INT. HOUSE - DAY\n\nAction.\n";

      final layoutWithout = OcptShotCoverageLayout.of(
        sceneId: sceneId,
        sceneText: withoutTrailingNewline,
      );
      final layoutWith = OcptShotCoverageLayout.of(
        sceneId: sceneId,
        sceneText: withTrailingNewline,
      );

      // Both still see exactly the two non-blank blocks; a trailing newline only adds a blank
      // line, which never carries a block of its own.
      expect(layoutWithout.blocks, hasLength(2));
      expect(layoutWith.blocks, hasLength(2));
      expect(layoutWith.blocks, layoutWithout.blocks);
    });
  });

  group("OcptShotCoverageLayout.blockContaining", () {
    test("returns the block holding the given offset", () {
      final layout = OcptShotCoverageLayout.of(sceneId: sceneId, sceneText: sceneText);
      final actionBlock = layout.blocks[1];

      final found = layout.blockContaining(actionBlock.startOffset + 2);

      expect(found, actionBlock);
    });

    test("returns null for an offset on a blank line", () {
      final layout = OcptShotCoverageLayout.of(sceneId: sceneId, sceneText: sceneText);
      // Offset right after "INT. HOUSE - DAY\n": the blank line.
      final blankLineOffset = "INT. HOUSE - DAY\n".length;

      expect(layout.blockContaining(blankLineOffset), isNull);
    });
  });

  group("OcptShotCoverageLayout.rangeBetween", () {
    test("is order-insensitive: clicking backwards yields the same range as clicking forwards", () {
      final layout = OcptShotCoverageLayout.of(sceneId: sceneId, sceneText: sceneText);
      final headingWords = layout.blocks.first.words;
      final first = headingWords[0];
      final second = headingWords[2];

      final forward = layout.rangeBetween(first, second);
      final backward = layout.rangeBetween(second, first);

      expect(forward, backward);
      expect(forward.startOffset, first.startOffset);
      expect(forward.endOffset, second.endOffset);
    });
  });

  group("OcptShotCoverageLayout.blocksSpannedBy", () {
    test("returns the single block a range stays inside", () {
      final layout = OcptShotCoverageLayout.of(sceneId: sceneId, sceneText: sceneText);
      final heading = layout.blocks.first;

      final spanned = layout.blocksSpannedBy(
        _buildRange(
          sceneId: sceneId,
          startOffset: heading.startOffset,
          endOffset: heading.endOffset,
        ),
      );

      expect(spanned, [heading]);
    });

    test("returns every block a range runs through, in reading order", () {
      final layout = OcptShotCoverageLayout.of(sceneId: sceneId, sceneText: sceneText);
      final action = layout.blocks[1];
      final dialogue = layout.blocks.last;

      final spanned = layout.blocksSpannedBy(
        _buildRange(
          sceneId: sceneId,
          startOffset: action.startOffset,
          endOffset: dialogue.endOffset,
        ),
      );

      expect(spanned, layout.blocks.sublist(1));
    });

    test("ignores a range of another scene", () {
      final layout = OcptShotCoverageLayout.of(sceneId: sceneId, sceneText: sceneText);
      final heading = layout.blocks.first;

      final spanned = layout.blocksSpannedBy(
        _buildRange(
          sceneId: "another-scene",
          startOffset: heading.startOffset,
          endOffset: heading.endOffset,
        ),
      );

      expect(spanned, isEmpty);
    });
  });

  group("OcptShotCoverageLayout.isWordCovered", () {
    test("true when a range overlaps the word, ignoring ranges of another scene", () {
      final layout = OcptShotCoverageLayout.of(sceneId: sceneId, sceneText: sceneText);
      final word = layout.blocks.first.words.first; // "INT."

      final coveringRange = _buildRange(
        sceneId: sceneId,
        startOffset: word.startOffset,
        endOffset: word.endOffset,
      );
      final otherSceneRange = _buildRange(
        sceneId: "some-other-scene",
        startOffset: word.startOffset,
        endOffset: word.endOffset,
      );

      expect(layout.isWordCovered(word, [otherSceneRange]), isFalse);
      expect(layout.isWordCovered(word, [otherSceneRange, coveringRange]), isTrue);
    });

    test("false when no range overlaps the word", () {
      final layout = OcptShotCoverageLayout.of(sceneId: sceneId, sceneText: sceneText);
      final headingWords = layout.blocks.first.words;
      final untouchedWord = headingWords.last; // "DAY"
      final rangeOverFirstWord = _buildRange(
        sceneId: sceneId,
        startOffset: headingWords.first.startOffset,
        endOffset: headingWords.first.endOffset,
      );

      expect(layout.isWordCovered(untouchedWord, [rangeOverFirstWord]), isFalse);
    });
  });

  group("OcptShotCoverageLayout.countCoveredWords", () {
    test("counts a union: overlapping ranges over the same word count it once", () {
      final layout = OcptShotCoverageLayout.of(sceneId: sceneId, sceneText: sceneText);
      final headingWords = layout.blocks.first.words; // INT. / HOUSE / - / DAY

      // Both ranges cover "INT." and "HOUSE", overlapping each other entirely.
      final rangeA = _buildRange(
        id: "range-a",
        sceneId: sceneId,
        startOffset: headingWords[0].startOffset,
        endOffset: headingWords[1].endOffset,
      );
      final rangeB = _buildRange(
        id: "range-b",
        sceneId: sceneId,
        startOffset: headingWords[0].startOffset,
        endOffset: headingWords[1].endOffset,
      );

      expect(layout.countCoveredWords([rangeA, rangeB]), 2);
    });

    test("ignores ranges of another scene", () {
      final layout = OcptShotCoverageLayout.of(sceneId: sceneId, sceneText: sceneText);
      final otherSceneRange = _buildRange(
        sceneId: "some-other-scene",
        startOffset: 0,
        endOffset: sceneText.length,
      );

      expect(layout.countCoveredWords([otherSceneRange]), 0);
    });

    test("sums distinct words covered by non-overlapping ranges", () {
      final layout = OcptShotCoverageLayout.of(sceneId: sceneId, sceneText: sceneText);
      final headingWords = layout.blocks.first.words;

      final rangeOverInt = _buildRange(
        id: "range-int",
        sceneId: sceneId,
        startOffset: headingWords[0].startOffset,
        endOffset: headingWords[0].endOffset,
      );
      final rangeOverDay = _buildRange(
        id: "range-day",
        sceneId: sceneId,
        startOffset: headingWords[3].startOffset,
        endOffset: headingWords[3].endOffset,
      );

      expect(layout.countCoveredWords([rangeOverInt, rangeOverDay]), 2);
    });
  });

  group("OcptShotCoverageLayout.rangesIn", () {
    test("returns only the ranges overlapping the given block, ignoring other scenes", () {
      final layout = OcptShotCoverageLayout.of(sceneId: sceneId, sceneText: sceneText);
      final headingBlock = layout.blocks.first;
      final actionBlock = layout.blocks[1];

      final rangeOnHeading = _buildRange(
        id: "range-heading",
        sceneId: sceneId,
        startOffset: headingBlock.startOffset,
        endOffset: headingBlock.endOffset,
      );
      final rangeOnAction = _buildRange(
        id: "range-action",
        sceneId: sceneId,
        startOffset: actionBlock.startOffset,
        endOffset: actionBlock.endOffset,
      );
      final otherSceneRangeOnHeading = _buildRange(
        id: "range-other-scene",
        sceneId: "some-other-scene",
        startOffset: headingBlock.startOffset,
        endOffset: headingBlock.endOffset,
      );

      final found = layout.rangesIn(headingBlock, [
        rangeOnHeading,
        rangeOnAction,
        otherSceneRangeOnHeading,
      ]);

      expect(found, [rangeOnHeading]);
    });
  });

  group("OcptShotCoverageLayout.rangeAt", () {
    test("returns the range covering the given offset", () {
      final layout = OcptShotCoverageLayout.of(sceneId: sceneId, sceneText: sceneText);
      final word = layout.blocks.first.words.first;
      final range = _buildRange(
        sceneId: sceneId,
        startOffset: word.startOffset,
        endOffset: word.endOffset,
      );

      expect(layout.rangeAt(word.startOffset, [range]), range);
    });

    test("returns null when no range covers the offset, or only another scene's does", () {
      final layout = OcptShotCoverageLayout.of(sceneId: sceneId, sceneText: sceneText);
      final word = layout.blocks.first.words.first;
      final otherSceneRange = _buildRange(
        sceneId: "some-other-scene",
        startOffset: word.startOffset,
        endOffset: word.endOffset,
      );

      expect(layout.rangeAt(word.startOffset, []), isNull);
      expect(layout.rangeAt(word.startOffset, [otherSceneRange]), isNull);
    });
  });

  group("OcptShotCoverageLayout.charactersCoveredBy", () {
    // Two speakers, the second one cued twice, so first-appearance order and deduplication are
    // both observable; JOHN's cue carries an extension and a forcing marker, neither of which may
    // reach the name the shot list stores.
    const dialogueSceneText = 'INT. HOUSE - DAY\n\nJohn walks in.\n\n@JOHN (V.O.)\n'
        '(whispering)\nHello there.\n\nSARAH\nHello back.\n\nThey wait.\n\nJOHN\nStill here.';

    /// The layout of [dialogueSceneText], and the span of the block whose text is [blockText].
    (OcptShotCoverageLayout, OcptShotCoverageBlock) layoutAndBlock(String blockText) {
      final layout = OcptShotCoverageLayout.of(sceneId: sceneId, sceneText: dialogueSceneText);
      return (layout, layout.blocks.firstWhere((block) => block.text == blockText));
    }

    test("names the character a covered cue line introduces", () {
      final (layout, block) = layoutAndBlock("@JOHN (V.O.)");

      expect(
        layout.charactersCoveredBy(
          startOffset: block.startOffset,
          endOffset: block.endOffset,
        ),
        ["JOHN"],
      );
    });

    test("names the speaker of a covered dialogue or parenthetical line, cue left out", () {
      final (layout, dialogue) = layoutAndBlock("Hello there.");
      final (_, parenthetical) = layoutAndBlock("(whispering)");

      expect(
        layout.charactersCoveredBy(
          startOffset: dialogue.startOffset,
          endOffset: dialogue.endOffset,
        ),
        ["JOHN"],
      );
      expect(
        layout.charactersCoveredBy(
          startOffset: parenthetical.startOffset,
          endOffset: parenthetical.endOffset,
        ),
        ["JOHN"],
      );
    });

    test("names nobody for a span covering only a heading or an action line", () {
      final (layout, action) = layoutAndBlock("John walks in.");
      final (_, heading) = layoutAndBlock("INT. HOUSE - DAY");

      expect(
        layout.charactersCoveredBy(startOffset: action.startOffset, endOffset: action.endOffset),
        isEmpty,
      );
      expect(
        layout.charactersCoveredBy(startOffset: heading.startOffset, endOffset: heading.endOffset),
        isEmpty,
      );
    });

    test("names every speaker of a wider span once, in first-appearance order", () {
      final (layout, _) = layoutAndBlock("INT. HOUSE - DAY");

      expect(
        layout.charactersCoveredBy(startOffset: 0, endOffset: dialogueSceneText.length),
        ["JOHN", "SARAH"],
      );
    });

    test("stops naming a speaker once the dialogue group is over", () {
      final (layout, action) = layoutAndBlock("They wait.");

      // From SARAH's reply through the action line under it: the action ends the group, so the
      // JOHN cued *after* it is not named.
      final (_, sarahDialogue) = layoutAndBlock("Hello back.");
      expect(
        layout.charactersCoveredBy(
          startOffset: sarahDialogue.startOffset,
          endOffset: action.endOffset,
        ),
        ["SARAH"],
      );
    });
  });

  test("a range built from two words of one block passes OcptShotCoverageService.addRange's "
      "own single-block rule", () async {
    const shotListService = OcptShotListService();
    const coverageService = OcptShotCoverageService();
    const sceneIndexService = OcptSceneIndexService();
    const screenplayService = OcptScreenplayService(
      sceneIndexService: sceneIndexService,
      shotListService: shotListService,
      shotCoverageService: coverageService,
    );
    const screenplayId = "screenplay-1";

    final database = OcptProjectDatabase.memory();
    addTearDown(database.close);
    await database
        .into(database.ocptScreenplaysTable)
        .insert(
          OcptScreenplaysTableCompanion.insert(
            id: screenplayId,
            title: "Draft",
            updatedAt: DateTime.now(),
          ),
        );

    await screenplayService.saveScreenplayText(
      database: database,
      screenplayId: screenplayId,
      fountainText: '''
INT. HOUSE - DAY

John walks in.
''',
      snapshotReason: OcptSnapshotReason.manual,
    );

    final scene = await database.select(database.ocptScenesTable).getSingle();
    final wholeFountainText =
        (await database.select(database.ocptScreenplaysTable).getSingle()).fountainText;
    final sceneText = wholeFountainText.substring(scene.charStart, scene.charEnd);

    final layout = OcptShotCoverageLayout.of(sceneId: scene.id, sceneText: sceneText);
    // Deliberately across two blocks: the heading's first word to the action line's last one.
    final range = layout.rangeBetween(
      layout.blocks.first.words.first,
      layout.blocks.last.words.last,
    );

    final shotId = await shotListService.createShot(
      database: database,
      screenplayId: screenplayId,
      sceneId: scene.id,
    );

    // Must not throw: a range built from two of the layout's words is exactly the shape addRange
    // expects, whether the two words sit in one block or in two.
    await coverageService.addRange(
      database: database,
      shotId: shotId,
      sceneId: scene.id,
      startOffset: range.startOffset,
      endOffset: range.endOffset,
      sceneText: sceneText,
    );
  });
}
