// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_sides_pdf_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_sides_layout.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/models/ocpt_sides_labels.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';

/// Episode A's own screenplay: a two-scene document short enough to fit each scene on a single
/// composed page — the same shape `ocpt_scenario_coverage_pdf_service_test.dart` parses, since
/// this service reads a scene's own span off the very same `FountainDocument.scenes`.
const _screenplayA =
    "INT. KITCHEN - DAY\n"
    "\n"
    "John walks in and looks around the room.\n"
    "\n"
    "EXT. STREET - NIGHT\n"
    "\n"
    "Rain falls on the empty pavement.\n";

/// Episode B's own screenplay: a single scene, deliberately of no episode A ever wrote, so a
/// booklet chaining both can never be mistaken for one screenplay's own two scenes.
const _screenplayB =
    "INT. OFFICE - DAY\n"
    "\n"
    "Sarah reads a memo at her desk.\n";

/// Every localized string of the document, filled with recognisable placeholders: nothing here
/// asserts on the printed text (Courier Prime is embedded as an Identity-H composite font, so a
/// content stream holds glyph indices rather than readable characters), only on what changes when
/// the schedule does — the same convention `ocpt_one_line_schedule_pdf_service_test.dart` follows.
///
/// [OcptSidesLabels.episodeLabels] is empty here, exactly what a single-episode project's own
/// resolver hands this service (`ocptSidesLabelsOf`) — the multi-episode tests below build their
/// own labels through [_labelsWithEpisodes] instead.
const _labels = OcptSidesLabels(
  fileNameSuffix: "sides",
  documentTitle: "Sides",
  versionLabel: "Version",
  dayTagPrefix: "D",
  dayTitle: "Thursday, 1 January 2026",
  episodeLabels: {},
  scriptPagePrefix: "p.",
  emptyDayNote: "Nothing planned for this day.",
);

/// [_labels], carrying [episodeLabels] in place of its own empty one — every other field copied
/// verbatim, exactly as `OcptOneLineScheduleLabels.dayTitles` callers build a variant labels object
/// per scenario rather than this file inventing a second full constant per test.
OcptSidesLabels _labelsWithEpisodes(Map<String, String> episodeLabels) => OcptSidesLabels(
  fileNameSuffix: _labels.fileNameSuffix,
  documentTitle: _labels.documentTitle,
  versionLabel: _labels.versionLabel,
  dayTagPrefix: _labels.dayTagPrefix,
  dayTitle: _labels.dayTitle,
  episodeLabels: episodeLabels,
  scriptPagePrefix: _labels.scriptPagePrefix,
  emptyDayNote: _labels.emptyDayNote,
);

/// Builds a shooting day with the few fields these tests read, everything else neutral.
OcptShootingDay _buildDay({required String id, required int dayNumber}) => OcptShootingDay(
  id: id,
  date: DateTime(2026, 1, dayNumber),
  dayNumber: dayNumber,
  status: OcptShootingDayStatus.planned,
  crewNote: "",
  weatherNote: "",
  notes: "",
);

/// Builds a slot with the few fields these tests read, everything else neutral.
OcptShootingSlot _buildSlot({required String id, required String shootingDayId}) => OcptShootingSlot(
  id: id,
  shootingDayId: shootingDayId,
  label: "",
  locationId: null,
  setId: null,
  anchorEdge: OcptShootingSlotAnchorEdge.start,
  anchorMinute: 480,
  anchorSlotId: null,
  notes: "",
  crew: const [],
  cast: const [],
  guests: const [],
  candidates: const [],
);

/// Builds a shooting day block with the few fields these tests read, everything else neutral.
OcptShootingDayBlock _buildBlock({
  required String id,
  required String shootingDayId,
  required String slotId,
  OcptShootingBlockKind kind = OcptShootingBlockKind.shot,
  String? shotId,
}) => OcptShootingDayBlock(
  id: id,
  shootingDayId: shootingDayId,
  slotId: slotId,
  kind: kind,
  shotId: shotId,
  sceneId: null,
  label: "",
  durationMinutes: 30,
  anchorMinute: null,
  notes: "",
  crewNote: "",
  roleId: null,
);

/// Builds a shot with the few fields these tests read, everything else neutral.
OcptShot _buildShot({required String id, String? sceneId, required String code}) => OcptShot(
  id: id,
  screenplayId: "screenplay-1",
  sceneId: sceneId,
  orphanedHeading: null,
  position: 0,
  shotSize: "",
  abbreviation: "",
  framing: "",
  cameraMove: "",
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
  coverageRanges: const [],
  code: code,
  averageDifficulty: 0,
);

/// Builds an [OcptSchedulePlanSnapshot] over one screenplay's worth of days/slots/blocks, plus
/// whichever shot list a test needs — the same fixture shape
/// `ocpt_one_line_schedule_pdf_service_test.dart` uses.
OcptSchedulePlanSnapshot _buildSnapshot({
  required List<OcptShootingDay> days,
  required Map<String, List<OcptShootingSlot>> slotsByDayId,
  Map<String, List<OcptShootingDayBlock>> blocksByDayId = const {},
  List<OcptShotListSnapshot> shotLists = const [],
}) => OcptSchedulePlanSnapshot.build(
  schedule: OcptScheduleSnapshot.build(
    days: days,
    slotsByDayId: slotsByDayId,
    blocksByDayId: blocksByDayId,
    eventsByDayId: const {},
  ),
  shotLists: shotLists,
  episodes: const [],
  locations: const [],
  roles: const [],
  people: const [],
  elements: const [],
  minimumRestMinutes: null,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A single shared instance, reused across every test below: this also exercises the font-loading
  // cache (repeated `generate` calls must not re-read the asset bundle).
  final service = OcptSidesPdfService();
  const parser = FountainParser();
  const pageSetup = OcptPageSetup.standard();
  final pinnedExportDate = DateTime(2026, 1, 15);

  final documentA = parser.parse(_screenplayA);
  final scenesA = documentA.scenes;
  final documentB = parser.parse(_screenplayB);
  final scenesB = documentB.scenes;

  /// A one-scene shot list snapshot for [screenplayId] whose scene carries the very source span
  /// `OcptSchedulePlanSnapshot.sceneSpanBySceneId` would read out of [scene] — the join this
  /// service slices its pages by. [shots] belongs to that one scene, which is what lets
  /// [OcptSchedulePlanSnapshot.shotById] resolve a block's own `shotId` back onto its `sceneId`.
  OcptShotListSnapshot buildShotList({
    required String screenplayId,
    required String sceneId,
    required FountainSceneHeading scene,
    required int charEnd,
    required List<OcptShot> shots,
  }) => OcptShotListSnapshot.build(
    screenplayId: screenplayId,
    sequences: [
      OcptSceneShotSequence(
        sceneId: sceneId,
        heading: scene.headingText,
        sceneNumber: null,
        displaySceneNumber: "1",
        charStart: scene.sourceRange.startOffset,
        charEnd: charEnd,
        shots: shots,
      ),
    ],
  );

  /// Episode A's own shot list: `scene-1`, spanning from its heading to episode A's second scene.
  OcptShotListSnapshot buildShotListA({required List<OcptShot> shots}) => buildShotList(
    screenplayId: "screenplay-1",
    sceneId: "scene-1",
    scene: scenesA[0],
    charEnd: scenesA[1].sourceRange.startOffset,
    shots: shots,
  );

  /// Episode B's own shot list: `scene-b1`, spanning from its heading to the end of episode B's own
  /// (one-scene) text.
  OcptShotListSnapshot buildShotListB({required List<OcptShot> shots}) => buildShotList(
    screenplayId: "screenplay-2",
    sceneId: "scene-b1",
    scene: scenesB[0],
    charEnd: documentB.sourceText.length,
    shots: shots,
  );

  /// A one-day plan with one slot, one shot block placing a shot of `scene-1`.
  OcptSchedulePlanSnapshot buildOneScenePlan() {
    final shot = _buildShot(id: "shot-1", sceneId: "scene-1", code: "1/1");
    return _buildSnapshot(
      days: [_buildDay(id: "day-1", dayNumber: 3)],
      slotsByDayId: {
        "day-1": [_buildSlot(id: "slot-1", shootingDayId: "day-1")],
      },
      blocksByDayId: {
        "day-1": [_buildBlock(id: "block-1", shootingDayId: "day-1", slotId: "slot-1", shotId: "shot-1")],
      },
      shotLists: [buildShotListA(shots: [shot])],
    );
  }

  /// A one-day plan with two slots, each placing a shot of episode A's `scene-1` and episode B's
  /// `scene-b1` respectively — the fixture the multi-episode tests below share.
  ({OcptSchedulePlanSnapshot plan, List<({String screenplayId, FountainDocument document})> documents})
  buildTwoEpisodePlan() {
    final shotA = _buildShot(id: "shot-a1", sceneId: "scene-1", code: "1/1");
    final shotB = _buildShot(id: "shot-b1", sceneId: "scene-b1", code: "1/1");
    final plan = _buildSnapshot(
      days: [_buildDay(id: "day-1", dayNumber: 3)],
      slotsByDayId: {
        "day-1": [
          _buildSlot(id: "slot-a", shootingDayId: "day-1"),
          _buildSlot(id: "slot-b", shootingDayId: "day-1"),
        ],
      },
      blocksByDayId: {
        "day-1": [
          _buildBlock(id: "block-a", shootingDayId: "day-1", slotId: "slot-a", shotId: "shot-a1"),
          _buildBlock(id: "block-b", shootingDayId: "day-1", slotId: "slot-b", shotId: "shot-b1"),
        ],
      },
      shotLists: [buildShotListA(shots: [shotA]), buildShotListB(shots: [shotB])],
    );

    return (
      plan: plan,
      documents: [
        (screenplayId: "screenplay-1", document: documentA),
        (screenplayId: "screenplay-2", document: documentB),
      ],
    );
  }

  group("generate", () {
    test("a day whose placed shot names a real scene composes a non-empty script page", () async {
      final bytes = await service.generate(
        plan: buildOneScenePlan(),
        dayId: "day-1",
        documents: [(screenplayId: "screenplay-1", document: documentA)],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeSceneNumbers: false,
        presentation: OcptSidesPresentation.scriptPages,
        exportDate: pinnedExportDate,
      );

      expect(bytes, isNotEmpty);
      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
      expect(_pageCount(bytes), 1);
    });

    test("packing reproduces the same selected rows as the script-pages presentation", () async {
      final plan = buildOneScenePlan();

      Future<Uint8List> generateFor(OcptSidesPresentation presentation) => service.generate(
        plan: plan,
        dayId: "day-1",
        documents: [(screenplayId: "screenplay-1", document: documentA)],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeSceneNumbers: false,
        presentation: presentation,
        exportDate: pinnedExportDate,
      );

      final scriptPagesBytes = await generateFor(OcptSidesPresentation.scriptPages);
      final packedBytes = await generateFor(OcptSidesPresentation.packed);

      expect(_pageCount(scriptPagesBytes), 1);
      expect(_pageCount(packedBytes), 1);
      // Both presentations print the same one scene, so their bodies must differ from a document
      // holding no scene at all (below) while still each being their own readable page.
      expect(scriptPagesBytes, isNotEmpty);
      expect(packedBytes, isNotEmpty);
    });

    test("a day placing no scene still produces a readable, non-empty document", () async {
      final plan = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 3)],
        slotsByDayId: {
          "day-1": [_buildSlot(id: "slot-1", shootingDayId: "day-1")],
        },
      );

      final bytes = await service.generate(
        plan: plan,
        dayId: "day-1",
        documents: [(screenplayId: "screenplay-1", document: documentA)],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeSceneNumbers: false,
        presentation: OcptSidesPresentation.scriptPages,
        exportDate: pinnedExportDate,
      );

      expect(bytes, isNotEmpty);
      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
      expect(_pageCount(bytes), 1);
    });

    test("a dayId naming no live day prints the same one-note document", () async {
      final bytes = await service.generate(
        plan: buildOneScenePlan(),
        dayId: "nope",
        documents: [(screenplayId: "screenplay-1", document: documentA)],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeSceneNumbers: false,
        presentation: OcptSidesPresentation.scriptPages,
        exportDate: pinnedExportDate,
      );

      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
      expect(_pageCount(bytes), 1);
    });

    test("the export moment is what the running foot prints, not the wall clock", () async {
      final plan = buildOneScenePlan();

      Future<Uint8List> generateFor(DateTime exportDate) => service.generate(
        plan: plan,
        dayId: "day-1",
        documents: [(screenplayId: "screenplay-1", document: documentA)],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeSceneNumbers: false,
        presentation: OcptSidesPresentation.scriptPages,
        exportDate: exportDate,
      );

      final first = await generateFor(pinnedExportDate);
      final second = await generateFor(pinnedExportDate);
      final differentMoment = await generateFor(DateTime(2026, 1, 15, 16, 45));

      // Content streams, not the raw bytes, are what two runs of the same [exportDate] must agree
      // on: the `pdf` package stamps its own `/CreationDate` object with the wall clock regardless
      // of what this service is asked to print, exactly the reason every sibling test compares
      // content streams rather than whole files.
      expect(_contentStreams(first), _contentStreams(second));
      expect(_contentStreams(first), isNot(_contentStreams(differentMoment)));
    });

    group("more than one episode", () {
      test("a day playing sequences from two episodes composes one page per episode, chained in order", () async {
        final fixture = buildTwoEpisodePlan();

        final bytes = await service.generate(
          plan: fixture.plan,
          dayId: "day-1",
          documents: fixture.documents,
          pageSetup: pageSetup,
          labels: _labels,
          projectName: "My Movie",
          includeSceneNumbers: false,
          presentation: OcptSidesPresentation.scriptPages,
          exportDate: pinnedExportDate,
        );

        expect(_pageCount(bytes), 2);
      });

      test("the runs chain in the order the documents are given, not a fixed one", () async {
        final fixture = buildTwoEpisodePlan();

        Future<Uint8List> generateInOrder(
          List<({String screenplayId, FountainDocument document})> documents,
        ) => service.generate(
          plan: fixture.plan,
          dayId: "day-1",
          documents: documents,
          pageSetup: pageSetup,
          labels: _labels,
          projectName: "My Movie",
          includeSceneNumbers: false,
          presentation: OcptSidesPresentation.scriptPages,
          exportDate: pinnedExportDate,
        );

        final aThenB = await generateInOrder(fixture.documents);
        final bThenA = await generateInOrder(fixture.documents.reversed.toList());

        // Reversing the input list must reverse the booklet's own pages: the first PDF's whole
        // content differs from the reversed one's whole content, which the [_contentStreams]
        // equality check every other test in this file already relies on is exactly built to
        // detect.
        expect(_contentStreams(aThenB), isNot(_contentStreams(bThenA)));
      });

      test("each printed page carries its own screenplay's raw, unprefixed scene number", () {
        // A side's margin numbers come straight off `FountainScriptComposer`'s own reading of the
        // screenplay it composed — never off the shot list's own prefixed `displaySceneNumber`
        // (`1.1`/`2.1`) another export prints elsewhere. Composing each episode's document alone,
        // exactly as `generate` does, is what keeps the two numbering systems apart: this mirrors
        // that composer/layout call directly (pure Dart, no PDF bytes to decode) to prove neither
        // one silently prefixes the other's numbers.
        const numberedA = "INT. KITCHEN - DAY #1#\n\nJohn walks in.\n";
        const numberedB = "INT. OFFICE - DAY #1#\n\nSarah reads a memo.\n";
        final docA = parser.parse(numberedA);
        final docB = parser.parse(numberedB);
        final metrics = pageSetup.toMetrics();

        String sceneNumberOf(FountainDocument doc) {
          final composed = const FountainScriptComposer().compose(document: doc, metrics: metrics);
          final scene = doc.scenes.single;
          final layout = OcptScriptSidesLayout.of(
            script: composed,
            sceneSpans: [(charStart: scene.sourceRange.startOffset, charEnd: doc.sourceText.length)],
            metrics: metrics,
            presentation: OcptSidesPresentation.scriptPages,
          );

          return layout.pages.first.lines
              .firstWhere((line) => line.sceneNumber != null)
              .sceneNumber!;
        }

        // Both episodes explicitly number their own (and only) scene "1": composing them apart
        // keeps that collision harmless, each printing its own raw "1" rather than either one
        // being renumbered or prefixed by the other's presence in the same booklet.
        expect(sceneNumberOf(docA), "1");
        expect(sceneNumberOf(docB), "1");
      });

      test("an episode the day plays nothing of contributes no page", () async {
        final fixture = buildTwoEpisodePlan();
        final plan = _buildSnapshot(
          days: [_buildDay(id: "day-1", dayNumber: 3)],
          slotsByDayId: {
            "day-1": [_buildSlot(id: "slot-a", shootingDayId: "day-1")],
          },
          blocksByDayId: {
            "day-1": [
              _buildBlock(id: "block-a", shootingDayId: "day-1", slotId: "slot-a", shotId: "shot-a1"),
            ],
          },
          // Episode B's own shot list is still read (as it would be for any episode the day's
          // scenes might name), it simply places no shot of it on this day.
          shotLists: [
            buildShotListA(shots: [_buildShot(id: "shot-a1", sceneId: "scene-1", code: "1/1")]),
            buildShotListB(shots: [_buildShot(id: "shot-b1", sceneId: "scene-b1", code: "1/1")]),
          ],
        );

        final bytes = await service.generate(
          plan: plan,
          dayId: "day-1",
          documents: fixture.documents,
          pageSetup: pageSetup,
          labels: _labels,
          projectName: "My Movie",
          includeSceneNumbers: false,
          presentation: OcptSidesPresentation.scriptPages,
          exportDate: pinnedExportDate,
        );

        expect(_pageCount(bytes), 1, reason: "episode A's own single page only, episode B named nothing to print");
      });

      test("the empty-day note page still prints when no episode contributes anything", () async {
        final fixture = buildTwoEpisodePlan();
        final plan = _buildSnapshot(
          days: [_buildDay(id: "day-1", dayNumber: 3)],
          slotsByDayId: {
            "day-1": [_buildSlot(id: "slot-1", shootingDayId: "day-1")],
          },
          shotLists: [
            buildShotListA(shots: [_buildShot(id: "shot-a1", sceneId: "scene-1", code: "1/1")]),
            buildShotListB(shots: [_buildShot(id: "shot-b1", sceneId: "scene-b1", code: "1/1")]),
          ],
        );

        final bytes = await service.generate(
          plan: plan,
          dayId: "day-1",
          documents: fixture.documents,
          pageSetup: pageSetup,
          labels: _labels,
          projectName: "My Movie",
          includeSceneNumbers: false,
          presentation: OcptSidesPresentation.scriptPages,
          exportDate: pinnedExportDate,
        );

        expect(_pageCount(bytes), 1);
      });

      test("a packed booklet spanning two episodes counts pages over the whole booklet, not one run", () async {
        final fixture = buildTwoEpisodePlan();

        final singleEpisodeBytes = await service.generate(
          plan: fixture.plan,
          dayId: "day-1",
          documents: [fixture.documents.first],
          pageSetup: pageSetup,
          labels: _labels,
          projectName: "My Movie",
          includeSceneNumbers: false,
          presentation: OcptSidesPresentation.packed,
          exportDate: pinnedExportDate,
        );
        final twoEpisodeBytes = await service.generate(
          plan: fixture.plan,
          dayId: "day-1",
          documents: fixture.documents,
          pageSetup: pageSetup,
          labels: _labels,
          projectName: "My Movie",
          includeSceneNumbers: false,
          presentation: OcptSidesPresentation.packed,
          exportDate: pinnedExportDate,
        );

        expect(_pageCount(singleEpisodeBytes), 1);
        expect(_pageCount(twoEpisodeBytes), 2, reason: "one packed page per episode, chained into the same booklet");
        // Episode A's own page identity reads "1 / 1" alone but "1 / 2" once episode B joins the
        // booklet: the denominator is the only thing that changed, so the two runs cannot print an
        // identical document.
        expect(_contentStreams(singleEpisodeBytes), isNot(_contentStreams(twoEpisodeBytes)));
      });

      test("a matching episode label changes the running head", () async {
        final withoutLabel = await service.generate(
          plan: buildOneScenePlan(),
          dayId: "day-1",
          documents: [(screenplayId: "screenplay-1", document: documentA)],
          pageSetup: pageSetup,
          labels: _labels,
          projectName: "My Movie",
          includeSceneNumbers: false,
          presentation: OcptSidesPresentation.scriptPages,
          exportDate: pinnedExportDate,
        );
        final withLabel = await service.generate(
          plan: buildOneScenePlan(),
          dayId: "day-1",
          documents: [(screenplayId: "screenplay-1", document: documentA)],
          pageSetup: pageSetup,
          labels: _labelsWithEpisodes({"screenplay-1": "Episode 2"}),
          projectName: "My Movie",
          includeSceneNumbers: false,
          presentation: OcptSidesPresentation.scriptPages,
          exportDate: pinnedExportDate,
        );

        expect(_contentStreams(withoutLabel), isNot(_contentStreams(withLabel)));
      });

      test("a screenplay id absent from episodeLabels leaves the head unchanged", () async {
        // What a single-episode project's own resolver hands this service (`ocptSidesLabelsOf`
        // builds an empty map on such a project, ADR 0019): an unrelated key changes nothing,
        // proving the head only ever reacts to a label matching the page's own screenplay.
        final withEmptyMap = await service.generate(
          plan: buildOneScenePlan(),
          dayId: "day-1",
          documents: [(screenplayId: "screenplay-1", document: documentA)],
          pageSetup: pageSetup,
          labels: _labels,
          projectName: "My Movie",
          includeSceneNumbers: false,
          presentation: OcptSidesPresentation.scriptPages,
          exportDate: pinnedExportDate,
        );
        final withUnrelatedKey = await service.generate(
          plan: buildOneScenePlan(),
          dayId: "day-1",
          documents: [(screenplayId: "screenplay-1", document: documentA)],
          pageSetup: pageSetup,
          labels: _labelsWithEpisodes({"screenplay-9": "Episode 9"}),
          projectName: "My Movie",
          includeSceneNumbers: false,
          presentation: OcptSidesPresentation.scriptPages,
          exportDate: pinnedExportDate,
        );

        expect(_contentStreams(withEmptyMap), _contentStreams(withUnrelatedKey));
      });
    });
  });

  group("sidesFileName", () {
    test("joins the project name, the localized suffix and the day tag", () {
      final plan = _buildSnapshot(days: [_buildDay(id: "day-1", dayNumber: 3)], slotsByDayId: const {});

      expect(
        service.sidesFileName(plan: plan, dayId: "day-1", projectName: "My Movie", labels: _labels),
        "My Movie - sides - D3.pdf",
      );
    });

    test("a blank suffix drops that segment", () {
      final plan = _buildSnapshot(days: [_buildDay(id: "day-1", dayNumber: 3)], slotsByDayId: const {});
      const blankSuffixLabels = OcptSidesLabels(
        fileNameSuffix: "   ",
        documentTitle: "Sides",
        versionLabel: "Version",
        dayTagPrefix: "D",
        dayTitle: "",
        episodeLabels: {},
        scriptPagePrefix: "p.",
        emptyDayNote: "Nothing planned for this day.",
      );

      expect(
        service.sidesFileName(plan: plan, dayId: "day-1", projectName: "My Movie", labels: blankSuffixLabels),
        "My Movie - D3.pdf",
      );
    });

    test("a dayId naming no live day drops the day segment", () {
      final plan = _buildSnapshot(days: const [], slotsByDayId: const {});

      expect(
        service.sidesFileName(plan: plan, dayId: "nope", projectName: "My Movie", labels: _labels),
        "My Movie - sides.pdf",
      );
    });

    test("carries no episode segment (a booklet is a day's paperwork, not one episode's)", () {
      final plan = _buildSnapshot(days: [_buildDay(id: "day-1", dayNumber: 3)], slotsByDayId: const {});

      expect(
        service.sidesFileName(
          plan: plan,
          dayId: "day-1",
          projectName: "My Movie",
          labels: _labelsWithEpisodes({"screenplay-1": "Episode 1", "screenplay-2": "Episode 2"}),
        ),
        "My Movie - sides - D3.pdf",
      );
    });
  });
}

/// Counts a PDF's pages by counting its `/Type /Page` object markers (excluding `/Type /Pages`, the
/// tree node) — the same cheap approach `ocpt_one_line_schedule_pdf_service_test.dart` uses.
int _pageCount(Uint8List bytes) {
  final text = latin1.decode(bytes, allowInvalid: true);
  return RegExp(r"/Type\s*/Page[^s]").allMatches(text).length;
}

/// The raw (still-compressed) bytes of every `stream`/`endstream` object in [bytes], in file order —
/// see `ocpt_call_sheet_pdf_service_test.dart`'s own doc comment for why this, rather than the
/// printed text, is what every "prints something different" assertion above compares.
List<String> _contentStreams(Uint8List bytes) {
  final text = latin1.decode(bytes, allowInvalid: true);
  final pattern = RegExp(r"stream\r?\n(.*?)endstream", dotAll: true);
  return [for (final match in pattern.allMatches(text)) match.group(1)!];
}
