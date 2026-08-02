// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/models/ocpt_scenario_coverage_layout.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_coverage_range.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';

/// A screenplay with two scenes, short enough that every printed row of it can be named in a
/// test's expectations:
///
/// ```text
/// row 0  INT. KITCHEN - DAY
/// row 1  (blank spacer)
/// row 2  John walks in and looks around the room.
/// row 3  (blank spacer)
/// row 4  JOHN
/// row 5  Hello there.
/// row 6  (blank spacer)
/// row 7  EXT. STREET - NIGHT
/// row 8  (blank spacer)
/// row 9  Rain falls on the empty pavement.
/// ```
const _screenplay =
    "INT. KITCHEN - DAY\n"
    "\n"
    "John walks in and looks around the room.\n"
    "\n"
    "JOHN\n"
    "Hello there.\n"
    "\n"
    "EXT. STREET - NIGHT\n"
    "\n"
    "Rain falls on the empty pavement.\n";

/// The action line of the first scene, the passage most tests cover.
const _actionLine = "John walks in and looks around the room.";

/// Builds an [OcptShotCoverageRange] test double, its offsets already scene-relative.
OcptShotCoverageRange _buildRange({
  required String sceneId,
  required int startOffset,
  required int endOffset,
  String id = "range",
  bool isStale = false,
}) => OcptShotCoverageRange(
  id: id,
  sceneId: sceneId,
  startOffset: startOffset,
  endOffset: endOffset,
  coveredTextDigest: "irrelevant-for-this-test",
  isStale: isStale,
);

/// Builds an [OcptShot] test double with sensible defaults for the fields a given test does not
/// care about.
OcptShot _buildShot({
  required String id,
  required String code,
  String? sceneId,
  String abbreviation = "",
  String shotSize = "",
  String framing = "",
  String cameraMove = "",
  List<OcptShotCoverageRange> coverageRanges = const [],
}) => OcptShot(
  id: id,
  screenplayId: "screenplay",
  sceneId: sceneId,
  orphanedHeading: sceneId == null ? "INT. GONE - DAY" : null,
  position: 0,
  shotSize: shotSize,
  abbreviation: abbreviation,
  framing: framing,
  cameraMove: cameraMove,
  lens: "",
  recordingFormat: "",
  estimatedDurationMs: null,
  shootingDay: null,
  plannedTakes: null,
  sound: "",
  status: OcptShotStatus.toShoot,
  difficultySet: 0,
  difficultyCamera: 0,
  difficultyActing: 0,
  difficultySound: 0,
  notes: "",
  locationNotes: "",
  needsCheck: false,
  checkReason: null,
  characters: const [],
  coverageRanges: coverageRanges,
  code: code,
  averageDifficulty: 0,
);

/// A screenplay parsed, composed and ready to be laid coverage out over: everything
/// [OcptScenarioCoverageLayout.of] needs except the shot list itself.
class _ComposedScreenplay {
  /// Creates a [_ComposedScreenplay] by parsing and composing [text].
  factory _ComposedScreenplay(String text) {
    final document = const FountainParser().parse(text);
    final metrics = FountainLayoutMetrics.usLetter();
    return _ComposedScreenplay._(
      text: text,
      document: document,
      metrics: metrics,
      script: const FountainScriptComposer().compose(document: document, metrics: metrics),
    );
  }

  /// Class constructor
  const _ComposedScreenplay._({
    required this.text,
    required this.document,
    required this.metrics,
    required this.script,
  });

  /// The screenplay's whole Fountain text.
  final String text;

  /// The parsed document, the scene bounds are read from.
  final FountainDocument document;

  /// The metrics the screenplay was composed with.
  final FountainLayoutMetrics metrics;

  /// The composed pages.
  final FountainScriptLayout script;

  /// Builds the [OcptSceneShotSequence] of the [index]th scene of the screenplay, holding [shots],
  /// with the very character bounds `OcptSceneIndexService` would have stored for it.
  OcptSceneShotSequence sceneSequence(int index, List<OcptShot> shots) {
    final scenes = document.scenes;
    return OcptSceneShotSequence(
      sceneId: "scene-${index + 1}",
      heading: scenes[index].headingText,
      sceneNumber: null,
      displaySceneNumber: "${index + 1}",
      charStart: scenes[index].sourceRange.startOffset,
      charEnd: index + 1 < scenes.length ? scenes[index + 1].sourceRange.startOffset : text.length,
      shots: shots,
    );
  }

  /// The scene-relative offset of [passage] within the [index]th scene, as a coverage range
  /// records it.
  int offsetOf(int index, String passage) =>
      text.indexOf(passage) - document.scenes[index].sourceRange.startOffset;

  /// The Fountain text of the [index]th scene: the very slice a coverage range's own offsets are
  /// relative to, so its length is the offset a range covering the scene to its end stops at.
  String sceneText(int index) {
    final scenes = document.scenes;
    final start = scenes[index].sourceRange.startOffset;
    final end = index + 1 < scenes.length ? scenes[index + 1].sourceRange.startOffset : text.length;
    return text.substring(start, end);
  }

  /// Lays [sequences]' coverage out over this screenplay.
  OcptScenarioCoverageLayout layoutOf(List<OcptShotSequence> sequences) =>
      OcptScenarioCoverageLayout.of(
        script: script,
        snapshot: OcptShotListSnapshot.build(screenplayId: "screenplay", sequences: sequences),
        screenplayText: text,
        metrics: metrics,
      );
}

void main() {
  group("OcptScenarioCoverageLayout.of bars", () {
    test("draws one bar on the rows the covered passage was printed on", () {
      final screenplay = _ComposedScreenplay(_screenplay);
      final start = screenplay.offsetOf(0, _actionLine);

      final layout = screenplay.layoutOf([
        screenplay.sceneSequence(0, [
          _buildShot(
            id: "shot-1",
            code: "1/1",
            sceneId: "scene-1",
            abbreviation: "PM",
            coverageRanges: [
              _buildRange(
                sceneId: "scene-1",
                startOffset: start,
                endOffset: start + _actionLine.length,
              ),
            ],
          ),
        ]),
      ]);

      expect(layout.pages, hasLength(1));
      final segments = layout.pages.single.segments;
      expect(segments, hasLength(1));
      expect(segments.single.firstRow, 2);
      expect(segments.single.lastRow, 2);
      expect(segments.single.lane, 0);
      expect(segments.single.side, OcptCoverageBarSide.left);
      expect(segments.single.label, "PM1/1");
      expect(segments.single.colorIndex, 0);
      expect(segments.single.isStale, isFalse);
      expect(segments.single.startTick, isNull);
      expect(segments.single.endTick, isNull);
    });

    test("labels a bar with the shot code alone when the shot has no abbreviation", () {
      final screenplay = _ComposedScreenplay(_screenplay);
      final start = screenplay.offsetOf(0, _actionLine);

      final layout = screenplay.layoutOf([
        screenplay.sceneSequence(0, [
          _buildShot(
            id: "shot-1",
            code: "1/1",
            sceneId: "scene-1",
            coverageRanges: [
              _buildRange(
                sceneId: "scene-1",
                startOffset: start,
                endOffset: start + _actionLine.length,
              ),
            ],
          ),
        ]),
      ]);

      expect(layout.pages.single.segments.single.label, "1/1");
    });

    test("runs a bar continuously across the blank lines inside the passage it covers", () {
      final screenplay = _ComposedScreenplay(_screenplay);
      final start = screenplay.offsetOf(0, _actionLine);
      final end = screenplay.offsetOf(0, "Hello there.") + "Hello there.".length;

      final layout = screenplay.layoutOf([
        screenplay.sceneSequence(0, [
          _buildShot(
            id: "shot-1",
            code: "1/1",
            sceneId: "scene-1",
            coverageRanges: [_buildRange(sceneId: "scene-1", startOffset: start, endOffset: end)],
          ),
        ]),
      ]);

      final segment = layout.pages.single.segments.single;
      // Rows 3 (a blank spacer) and 4 (the character cue) sit inside the bar, so it is drawn as
      // one continuous stroke from the action line down to the dialogue line.
      expect(segment.firstRow, 2);
      expect(segment.lastRow, 5);
    });

    test("draws one bar per range, so a shot covering two passages draws two of them", () {
      final screenplay = _ComposedScreenplay(_screenplay);
      final action = screenplay.offsetOf(0, _actionLine);
      final dialogue = screenplay.offsetOf(0, "Hello there.");

      final layout = screenplay.layoutOf([
        screenplay.sceneSequence(0, [
          _buildShot(
            id: "shot-1",
            code: "1/1",
            sceneId: "scene-1",
            abbreviation: "GP",
            coverageRanges: [
              _buildRange(
                sceneId: "scene-1",
                startOffset: action,
                endOffset: action + _actionLine.length,
                id: "range-1",
              ),
              _buildRange(
                sceneId: "scene-1",
                startOffset: dialogue,
                endOffset: dialogue + "Hello there.".length,
                id: "range-2",
              ),
            ],
          ),
        ]),
      ]);

      final segments = layout.pages.single.segments;
      expect(segments.map((segment) => segment.firstRow), [2, 5]);
      expect(segments.map((segment) => segment.label), ["GP1/1", "GP1/1"]);
      expect(segments.map((segment) => segment.colorIndex), [0, 0]);
    });

    test("carries a range staleness onto its bar", () {
      final screenplay = _ComposedScreenplay(_screenplay);
      final start = screenplay.offsetOf(0, _actionLine);

      final layout = screenplay.layoutOf([
        screenplay.sceneSequence(0, [
          _buildShot(
            id: "shot-1",
            code: "1/1",
            sceneId: "scene-1",
            coverageRanges: [
              _buildRange(
                sceneId: "scene-1",
                startOffset: start,
                endOffset: start + _actionLine.length,
                isStale: true,
              ),
            ],
          ),
        ]),
      ]);

      expect(layout.pages.single.segments.single.isStale, isTrue);
    });

    test("draws no bar at all for a shot whose scene no longer exists", () {
      final screenplay = _ComposedScreenplay(_screenplay);

      final layout = screenplay.layoutOf([
        screenplay.sceneSequence(0, const []),
        OcptOrphanShotSequence(
          shots: [
            _buildShot(
              id: "shot-1",
              code: "?/1",
              coverageRanges: [
                _buildRange(sceneId: "deleted-scene", startOffset: 0, endOffset: 10),
              ],
            ),
          ],
        ),
      ]);

      expect(layout.pages.single.segments, isEmpty);
    });
  });

  group("OcptScenarioCoverageLayout.of ticks", () {
    test("marks both boundaries when the passage starts and ends mid-line", () {
      final screenplay = _ComposedScreenplay(_screenplay);
      const passage = "looks around";
      final start = screenplay.offsetOf(0, passage);

      final layout = screenplay.layoutOf([
        screenplay.sceneSequence(0, [
          _buildShot(
            id: "shot-1",
            code: "1/1",
            sceneId: "scene-1",
            coverageRanges: [
              _buildRange(
                sceneId: "scene-1",
                startOffset: start,
                endOffset: start + passage.length,
              ),
            ],
          ),
        ]),
      ]);

      final segment = layout.pages.single.segments.single;
      expect(segment.startTick, OcptCoverageTick(row: 2, column: _actionLine.indexOf(passage)));
      expect(
        segment.endTick,
        OcptCoverageTick(row: 2, column: _actionLine.indexOf(passage) + passage.length),
      );
    });

    test("marks neither boundary when the passage covers whole lines", () {
      final screenplay = _ComposedScreenplay(_screenplay);
      final start = screenplay.offsetOf(0, _actionLine);

      final layout = screenplay.layoutOf([
        screenplay.sceneSequence(0, [
          _buildShot(
            id: "shot-1",
            code: "1/1",
            sceneId: "scene-1",
            coverageRanges: [
              _buildRange(
                sceneId: "scene-1",
                startOffset: start,
                endOffset: start + _actionLine.length,
              ),
            ],
          ),
        ]),
      ]);

      final segment = layout.pages.single.segments.single;
      expect(segment.startTick, isNull);
      expect(segment.endTick, isNull);
    });
  });

  group("OcptScenarioCoverageLayout.of page splitting", () {
    test("draws a bar on both pages a passage spans, label repeated", () {
      // One action block of 60 source lines, so the rows are exactly: the heading, a spacer, then
      // one row per action line. A US Letter page holds 54 of them.
      final beats = [for (var index = 0; index < 60; index++) "Beat ${index + 1} happens."];
      final screenplay = _ComposedScreenplay("INT. LOOP - DAY\n\n${beats.join("\n")}\n");
      final start = screenplay.offsetOf(0, beats[51]);
      final end = screenplay.offsetOf(0, beats[52]) + beats[52].length;

      final layout = screenplay.layoutOf([
        screenplay.sceneSequence(0, [
          _buildShot(
            id: "shot-1",
            code: "1/1",
            sceneId: "scene-1",
            abbreviation: "PT",
            coverageRanges: [_buildRange(sceneId: "scene-1", startOffset: start, endOffset: end)],
          ),
        ]),
      ]);

      expect(layout.pages, hasLength(2));
      final first = layout.pages[0].segments.single;
      final second = layout.pages[1].segments.single;
      expect(first.firstRow, 53);
      expect(first.lastRow, 53);
      expect(second.firstRow, 0);
      expect(second.lastRow, 0);
      expect(second.label, first.label);
      expect(second.colorIndex, first.colorIndex);
      // The passage starts and ends on a line boundary, so neither page carries a tick.
      expect(first.startTick, isNull);
      expect(second.endTick, isNull);
    });
  });

  group("OcptScenarioCoverageLayout.of lanes", () {
    /// Lays out [count] shots of the first scene, each covering [_actionLine] and, for all but the
    /// first, the dialogue line as well — so every one of them overlaps every other.
    OcptScenarioCoverageLayout overlappingShots(int count) {
      final screenplay = _ComposedScreenplay(_screenplay);
      final start = screenplay.offsetOf(0, _actionLine);
      final end = screenplay.offsetOf(0, "Hello there.") + "Hello there.".length;

      return screenplay.layoutOf([
        screenplay.sceneSequence(0, [
          for (var index = 0; index < count; index++)
            _buildShot(
              id: "shot-$index",
              code: "1/${index + 1}",
              sceneId: "scene-1",
              coverageRanges: [_buildRange(sceneId: "scene-1", startOffset: start, endOffset: end)],
            ),
        ]),
      ]);
    }

    test("keeps two bars that do not overlap in the innermost lane", () {
      final screenplay = _ComposedScreenplay(_screenplay);
      final action = screenplay.offsetOf(0, _actionLine);
      final dialogue = screenplay.offsetOf(0, "Hello there.");

      final layout = screenplay.layoutOf([
        screenplay.sceneSequence(0, [
          _buildShot(
            id: "shot-1",
            code: "1/1",
            sceneId: "scene-1",
            coverageRanges: [
              _buildRange(
                sceneId: "scene-1",
                startOffset: action,
                endOffset: action + _actionLine.length,
              ),
            ],
          ),
          _buildShot(
            id: "shot-2",
            code: "1/2",
            sceneId: "scene-1",
            coverageRanges: [
              _buildRange(
                sceneId: "scene-1",
                startOffset: dialogue,
                endOffset: dialogue + "Hello there.".length,
              ),
            ],
          ),
        ]),
      ]);

      expect(layout.pages.single.segments.map((segment) => segment.lane), [0, 0]);
    });

    test("stacks overlapping bars one lane further out each", () {
      final layout = overlappingShots(3);

      expect(layout.pages.single.segments.map((segment) => segment.lane), [0, 1, 2]);
      expect(
        layout.pages.single.segments.map((segment) => segment.side),
        everyElement(OcptCoverageBarSide.left),
      );
    });

    test("moves a bar to the right margin once the left one is full", () {
      // The standard US Letter margins hold 6 lanes on the left and 3 on the right at the default
      // pitch, so the 7th overlapping bar is the first one drawn on the right.
      final layout = overlappingShots(7);
      final segments = layout.pages.single.segments;

      expect(
        segments.take(6).map((segment) => segment.side),
        everyElement(OcptCoverageBarSide.left),
      );
      expect(segments.last.side, OcptCoverageBarSide.right);
      expect(segments.last.lane, 0);
      expect(layout.hasLaneOverflow, isFalse);
      expect(
        layout.pages.single.lanePitchInches,
        OcptScenarioCoverageLayout.defaultLanePitchInches,
      );
    });

    test("shrinks the lane pitch instead of overflowing, while that is enough", () {
      final layout = overlappingShots(12);

      expect(
        layout.pages.single.lanePitchInches,
        lessThan(OcptScenarioCoverageLayout.defaultLanePitchInches),
      );
      expect(layout.pages.single.laneCapacity, greaterThanOrEqualTo(12));
      expect(layout.hasLaneOverflow, isFalse);
      expect(layout.pages.single.segments.where((segment) => segment.sharesOutermostLane), isEmpty);
    });

    test("shares the outermost lane once even the smallest pitch runs out of room", () {
      final layout = overlappingShots(24);
      final page = layout.pages.single;

      expect(page.lanePitchInches, OcptScenarioCoverageLayout.minimumLanePitchInches);
      expect(layout.hasLaneOverflow, isTrue);
      expect(
        page.segments.where((segment) => segment.sharesOutermostLane),
        hasLength(24 - page.laneCapacity),
      );
      expect(
        page.segments.map((segment) => segment.lane).reduce((a, b) => a > b ? a : b),
        lessThan(page.laneCapacity),
      );
    });

    test("measures a lane inset from the text edge, outside the scene number gutter", () {
      final layout = overlappingShots(2);
      final page = layout.pages.single;

      expect(
        page.laneInsetInches(page.segments.first),
        OcptScenarioCoverageLayout.sceneNumberGutterInches,
      );
      expect(
        page.laneInsetInches(page.segments.last),
        OcptScenarioCoverageLayout.sceneNumberGutterInches + page.lanePitchInches,
      );
    });
  });

  group("OcptScenarioCoverageLayout.of uncovered passages", () {
    test("washes every printed row no shot covers, and none of the covered one", () {
      final screenplay = _ComposedScreenplay(_screenplay);
      final start = screenplay.offsetOf(0, _actionLine);

      final layout = screenplay.layoutOf([
        screenplay.sceneSequence(0, [
          _buildShot(
            id: "shot-1",
            code: "1/1",
            sceneId: "scene-1",
            coverageRanges: [
              _buildRange(
                sceneId: "scene-1",
                startOffset: start,
                endOffset: start + _actionLine.length,
              ),
            ],
          ),
        ]),
        screenplay.sceneSequence(1, const []),
      ]);

      final gaps = layout.pages.single.gaps;
      // Every row but the covered action line (row 2), the blank spacers (rows 1, 3, 6, 8) and the
      // two scene headings (rows 0 and 7).
      expect(gaps.map((gap) => gap.row), [4, 5, 9]);
      expect(gaps.first.startColumn, 0);
      expect(gaps.first.endColumn, "JOHN".length);
    });

    test("never washes a scene heading, covered or not", () {
      final screenplay = _ComposedScreenplay(_screenplay);

      // A shot list covering nothing at all: every printed row is uncovered, headings included.
      final layout = screenplay.layoutOf([
        screenplay.sceneSequence(0, const []),
        screenplay.sceneSequence(1, const []),
      ]);

      expect(layout.pages.single.gaps.map((gap) => gap.row), isNot(contains(0)));
      expect(layout.pages.single.gaps.map((gap) => gap.row), isNot(contains(7)));
    });

    test("washes only the uncovered part of a partially covered line", () {
      final screenplay = _ComposedScreenplay(_screenplay);
      const passage = "John walks in";
      final start = screenplay.offsetOf(0, passage);

      final layout = screenplay.layoutOf([
        screenplay.sceneSequence(0, [
          _buildShot(
            id: "shot-1",
            code: "1/1",
            sceneId: "scene-1",
            coverageRanges: [
              _buildRange(
                sceneId: "scene-1",
                startOffset: start,
                endOffset: start + passage.length,
              ),
            ],
          ),
        ]),
        screenplay.sceneSequence(1, const []),
      ]);

      final gap = layout.pages.single.gaps.firstWhere((gap) => gap.row == 2);
      // The space between the covered words and the rest is trimmed off the wash.
      expect(gap.startColumn, passage.length + 1);
      expect(gap.endColumn, _actionLine.length);
    });
  });

  group("OcptScenarioCoverageLayout.of legend and summary", () {
    /// A two-scene shot list: the first scene holds two shots (one of them covering the action
    /// line, staled), the second holds none, and an orphan group closes the list.
    OcptScenarioCoverageLayout buildLayout(_ComposedScreenplay screenplay) {
      final start = screenplay.offsetOf(0, _actionLine);

      return screenplay.layoutOf([
        screenplay.sceneSequence(0, [
          _buildShot(
            id: "shot-1",
            code: "1/1",
            sceneId: "scene-1",
            abbreviation: "PM",
            shotSize: "Plan moyen",
            framing: "Face",
            cameraMove: "Fixe",
            coverageRanges: [
              _buildRange(
                sceneId: "scene-1",
                startOffset: start,
                endOffset: start + _actionLine.length,
                isStale: true,
              ),
            ],
          ),
          _buildShot(id: "shot-2", code: "1/2", sceneId: "scene-1", shotSize: "Gros plan"),
        ]),
        screenplay.sceneSequence(1, const []),
        OcptOrphanShotSequence(
          shots: [_buildShot(id: "shot-3", code: "?/1")],
        ),
      ]);
    }

    test("lists every shot in sequence then rank order, orphans included", () {
      final layout = buildLayout(_ComposedScreenplay(_screenplay));

      expect(layout.legend.map((entry) => entry.shotId), ["shot-1", "shot-2", "shot-3"]);
      expect(layout.legend.map((entry) => entry.label), ["PM1/1", "1/2", "?/1"]);
      expect(layout.legend.map((entry) => entry.colorIndex), [0, 1, 0]);
      expect(layout.legend.first.shotSize, "Plan moyen");
      expect(layout.legend.first.framing, "Face");
      expect(layout.legend.first.cameraMove, "Fixe");
    });

    test("summarises each sequence, orphan group last", () {
      final layout = buildLayout(_ComposedScreenplay(_screenplay));

      expect(layout.summary.map((row) => row.sequenceId), [
        "scene-1",
        "scene-2",
        OcptOrphanShotSequence.sequenceId,
      ]);

      final first = layout.summary.first;
      expect(first.sceneNumber, "1");
      expect(first.heading, "INT. KITCHEN - DAY");
      expect(first.shotCount, 2);
      expect(first.staleRangeCount, 1);
      // The scene's coverable text is the action line and the dialogue group — its heading counts
      // for nothing — and only the action line's 8 words are covered.
      expect(first.coveredWordCount, 8);
      expect(first.wordCount, greaterThan(first.coveredWordCount));
      expect(first.coveredWordShare, first.coveredWordCount / first.wordCount);
      expect(first.uncoveredExtracts, ["JOHN", "Hello there."]);
      expect(first.isOrphanGroup, isFalse);
    });

    test("leaves the scene headings out of the measures a scene is summarised by", () {
      final screenplay = _ComposedScreenplay(_screenplay);
      final start = screenplay.offsetOf(0, _actionLine);
      final scene = screenplay.sceneText(0);

      // Everything of the scene but its heading: the action line and the whole dialogue group.
      final layout = screenplay.layoutOf([
        screenplay.sceneSequence(0, [
          _buildShot(
            id: "shot-1",
            code: "1/1",
            sceneId: "scene-1",
            coverageRanges: [
              _buildRange(sceneId: "scene-1", startOffset: start, endOffset: scene.length),
            ],
          ),
        ]),
        screenplay.sceneSequence(1, const []),
      ]);

      final first = layout.summary.first;
      // A scene nothing but its heading is left out of therefore reads as fully covered, rather
      // than as short of the words no shot can ever claim.
      expect(first.coveredWordCount, first.wordCount);
      expect(first.coveredWordShare, 1);
      expect(first.uncoveredExtracts, isEmpty);
    });

    test("measures a scene with no shot at all as entirely uncovered", () {
      final layout = buildLayout(_ComposedScreenplay(_screenplay));
      final second = layout.summary[1];

      expect(second.shotCount, 0);
      expect(second.coveredWordCount, 0);
      expect(second.wordCount, greaterThan(0));
      expect(second.coveredWordShare, 0);
      expect(second.uncoveredExtracts, isNotEmpty);
    });

    test("names the orphan group without measuring it", () {
      final layout = buildLayout(_ComposedScreenplay(_screenplay));
      final orphans = layout.summary.last;

      expect(orphans.isOrphanGroup, isTrue);
      expect(orphans.sceneNumber, isNull);
      expect(orphans.heading, isEmpty);
      expect(orphans.shotCount, 1);
      expect(orphans.wordCount, 0);
      expect(orphans.coveredWordShare, 0);
    });
  });
}
