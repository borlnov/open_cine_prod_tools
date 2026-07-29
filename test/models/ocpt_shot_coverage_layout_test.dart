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

    test("blockBoundaries is ascending, one entry per source line, ending at sceneText.length", () {
      final layout = OcptShotCoverageLayout.of(sceneId: sceneId, sceneText: sceneText);

      // 7 source lines (blank ones included) + the trailing sceneText.length entry.
      expect(layout.blockBoundaries, hasLength(8));
      expect(layout.blockBoundaries.last, sceneText.length);
      for (var i = 1; i < layout.blockBoundaries.length; i++) {
        expect(layout.blockBoundaries[i], greaterThan(layout.blockBoundaries[i - 1]));
      }
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

      expect(layoutWithout.blockBoundaries.last, withoutTrailingNewline.length);
      expect(layoutWith.blockBoundaries.last, withTrailingNewline.length);
      // Both still see exactly the two non-blank blocks; the trailing newline only adds one more
      // (blank) line boundary.
      expect(layoutWithout.blocks, hasLength(2));
      expect(layoutWith.blocks, hasLength(2));
      expect(layoutWith.blockBoundaries.length, layoutWithout.blockBoundaries.length + 1);
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

  group("OcptShotCoverageBlock.containsRange", () {
    test("is true for a range fully inside the block", () {
      final layout = OcptShotCoverageLayout.of(sceneId: sceneId, sceneText: sceneText);
      final heading = layout.blocks.first;

      expect(heading.containsRange(heading.startOffset, heading.endOffset), isTrue);
      expect(heading.containsRange(heading.startOffset + 1, heading.endOffset - 1), isTrue);
    });

    test("is false for a range spilling past the block's end", () {
      final layout = OcptShotCoverageLayout.of(sceneId: sceneId, sceneText: sceneText);
      final heading = layout.blocks.first;

      expect(heading.containsRange(heading.startOffset, heading.endOffset + 5), isFalse);
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
    final headingWords = layout.blocks.first.words;
    final range = layout.rangeBetween(headingWords[0], headingWords[1]);

    final shotId = await shotListService.createShot(
      database: database,
      screenplayId: screenplayId,
      sceneId: scene.id,
    );

    // Must not throw: the range sits inside a single block, and blockBoundaries is exactly the
    // shape addRange expects.
    await coverageService.addRange(
      database: database,
      shotId: shotId,
      sceneId: scene.id,
      startOffset: range.startOffset,
      endOffset: range.endOffset,
      coveredText: sceneText.substring(range.startOffset, range.endOffset),
      blockBoundaries: layout.blockBoundaries,
    );
  });
}
