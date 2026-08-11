// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/constants/ocpt_coverage_palette.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_scenario_coverage_pdf_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_scenario_coverage_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_coverage_range.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';

/// A two-scene screenplay short enough to fit on a single composed page, with one action line per
/// scene a coverage range can be aimed at.
const _screenplay =
    "INT. KITCHEN - DAY\n"
    "\n"
    "John walks in and looks around the room.\n"
    "\n"
    "EXT. STREET - NIGHT\n"
    "\n"
    "Rain falls on the empty pavement.\n";

/// The action line of the first scene, the passage most tests cover.
const _actionLine = "John walks in and looks around the room.";

/// The PDF fill-colour operands of the opaque plate a bar's label is printed on: plain white.
const _labelPlateFill = "1 1 1";

/// Every localized string of the document, filled with recognisable placeholders: nothing here
/// asserts on the printed text (Courier Prime is embedded as an Identity-H composite font, so a
/// content stream holds glyph indices rather than readable characters), only on what changes when
/// the coverage does.
const _labels = OcptScenarioCoverageLabels(
  fileNameSuffix: "coverage",
  legendTitle: "Legend",
  legendShotHeader: "Shot",
  legendShotSizeHeader: "Shot size",
  legendFramingHeader: "Framing",
  legendCameraMoveHeader: "Camera move",
  summaryTitle: "Summary",
  summarySequenceHeader: "Sequence",
  summaryShotCountHeader: "Shots",
  summaryCoveredHeader: "Covered",
  summaryStaleHeader: "To check",
  summaryUncoveredHeader: "Uncovered",
  laneOverflowNote: "Some bars share a lane.",
  sequenceTitles: {"scene-1": "Sequence 1", "scene-2": "Sequence 2"},
);

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
  required String sceneId,
  String abbreviation = "",
  List<OcptShotCoverageRange> coverageRanges = const [],
}) => OcptShot(
  id: id,
  screenplayId: "screenplay",
  sceneId: sceneId,
  orphanedHeading: null,
  position: 0,
  shotSize: "Medium shot",
  abbreviation: abbreviation,
  framing: "Front",
  cameraMove: "Static",
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A single shared instance, reused across every test below: this also exercises the font-loading
  // cache (repeated `generate` calls must not re-read the asset bundle).
  final service = OcptScenarioCoveragePdfService();
  const parser = FountainParser();
  const composer = FountainScriptComposer();
  const pageSetup = OcptPageSetup.standard();

  final document = parser.parse(_screenplay);
  final scenes = document.scenes;

  /// The scene-relative offset of [passage] within the [index]th scene, as a coverage range
  /// records it.
  int offsetOf(int index, String passage) =>
      _screenplay.indexOf(passage) - scenes[index].sourceRange.startOffset;

  /// The [OcptSceneShotSequence] of the [index]th scene, holding [shots], with the very character
  /// bounds `OcptSceneIndexService` would have stored for it.
  OcptSceneShotSequence sceneSequence(int index, List<OcptShot> shots) => OcptSceneShotSequence(
    sceneId: "scene-${index + 1}",
    heading: scenes[index].headingText,
    sceneNumber: null,
    displaySceneNumber: "${index + 1}",
    charStart: scenes[index].sourceRange.startOffset,
    charEnd: index + 1 < scenes.length
        ? scenes[index + 1].sourceRange.startOffset
        : _screenplay.length,
    shots: shots,
  );

  /// A shot list whose single shot covers [_actionLine], stale or not.
  OcptShotListSnapshot coveringSnapshot({bool isStale = false, String abbreviation = "PM"}) =>
      OcptShotListSnapshot.build(
        screenplayId: "screenplay",
        sequences: [
          sceneSequence(0, [
            _buildShot(
              id: "shot-1",
              code: "1/1",
              sceneId: "scene-1",
              abbreviation: abbreviation,
              coverageRanges: [
                _buildRange(
                  sceneId: "scene-1",
                  startOffset: offsetOf(0, _actionLine),
                  endOffset: offsetOf(0, _actionLine) + _actionLine.length,
                  isStale: isStale,
                ),
              ],
            ),
          ]),
          sceneSequence(1, const []),
        ],
      );

  /// A shot list whose two shots both cover the start of [_actionLine], so their bars land on the
  /// same row in two different lanes — the very case a label reaches over a neighbour's bar in.
  OcptShotListSnapshot overlappingSnapshot() => OcptShotListSnapshot.build(
    screenplayId: "screenplay",
    sequences: [
      sceneSequence(0, [
        for (final (index, length) in [_actionLine.length, 10].indexed)
          _buildShot(
            id: "shot-${index + 1}",
            code: "1/${index + 1}",
            sceneId: "scene-1",
            abbreviation: "PM",
            coverageRanges: [
              _buildRange(
                id: "range-${index + 1}",
                sceneId: "scene-1",
                startOffset: offsetOf(0, _actionLine),
                endOffset: offsetOf(0, _actionLine) + length,
              ),
            ],
          ),
      ]),
      sceneSequence(1, const []),
    ],
  );

  /// The same shot list with no coverage range at all: every shot is there, nothing is covered.
  OcptShotListSnapshot uncoveredSnapshot() => OcptShotListSnapshot.build(
    screenplayId: "screenplay",
    sequences: [
      sceneSequence(0, [_buildShot(id: "shot-1", code: "1/1", sceneId: "scene-1")]),
      sceneSequence(1, const []),
    ],
  );

  Future<Uint8List> generate({
    required OcptShotListSnapshot snapshot,
    bool includeTitlePage = false,
    bool includeLegendPage = false,
    bool includeSummaryPage = false,
  }) => service.generate(
    document: document,
    screenplayText: _screenplay,
    snapshot: snapshot,
    pageSetup: pageSetup,
    labels: _labels,
    projectName: "My Movie",
    includeSceneNumbers: true,
    includeTitlePage: includeTitlePage,
    includeLegendPage: includeLegendPage,
    includeSummaryPage: includeSummaryPage,
  );

  group("generate", () {
    test("produces bytes starting with the %PDF magic string", () async {
      final bytes = await generate(snapshot: coveringSnapshot());

      expect(bytes, isNotEmpty);
      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
    });

    test("prints every script page the composer produced, and nothing else by default", () async {
      final scriptPageCount = composer
          .compose(document: document, metrics: pageSetup.toMetrics())
          .pages
          .length;

      final bytes = await generate(snapshot: coveringSnapshot());

      expect(_pageCount(bytes), scriptPageCount);
    });

    test("each of the three optional pages adds exactly one page", () async {
      final plain = await generate(snapshot: coveringSnapshot());
      final withTitlePage = await generate(snapshot: coveringSnapshot(), includeTitlePage: true);
      final withLegend = await generate(snapshot: coveringSnapshot(), includeLegendPage: true);
      final withSummary = await generate(snapshot: coveringSnapshot(), includeSummaryPage: true);

      expect(_pageCount(withTitlePage), _pageCount(plain) + 1);
      expect(_pageCount(withLegend), _pageCount(plain) + 1);
      expect(_pageCount(withSummary), _pageCount(plain) + 1);
    });

    test("the same coverage exported twice draws exactly the same pages", () async {
      // The palette is read at a shot's rank within its sequence and the lanes are assigned by a
      // deterministic sweep, so two exports of one project must be comparable page by page — which
      // is the whole point of a printed copy somebody annotates.
      final first = await generate(
        snapshot: coveringSnapshot(),
        includeLegendPage: true,
        includeSummaryPage: true,
      );
      final second = await generate(
        snapshot: coveringSnapshot(),
        includeLegendPage: true,
        includeSummaryPage: true,
      );

      expect(_contentStreams(first), _contentStreams(second));
    });
  });

  group("what the coverage draws on the screenplay", () {
    // Every assertion below compares the *content streams* of two generated documents rather than
    // reading their text: Courier Prime is embedded as an Identity-H composite font, so a content
    // stream's text operands are font-specific glyph indices rather than readable characters.
    // Deflate being deterministic, two documents drawing the same thing hold byte-identical
    // streams and two documents drawing different things do not — a genuine, parser-free oracle.
    test("a covered passage draws something the same screenplay uncovered does not", () async {
      final covered = await generate(snapshot: coveringSnapshot());
      final uncovered = await generate(snapshot: uncoveredSnapshot());

      expect(_contentStreams(covered), isNot(_contentStreams(uncovered)));
    });

    test("a stale range draws differently from the very same range up to date", () async {
      // Hollow rather than solid: a bar the reader must re-check may not look like solid coverage.
      final fresh = await generate(snapshot: coveringSnapshot());
      final stale = await generate(snapshot: coveringSnapshot(isStale: true));

      expect(_contentStreams(fresh), isNot(_contentStreams(stale)));
    });

    test("a shot's abbreviation reaches its bar's label", () async {
      final withAbbreviation = await generate(snapshot: coveringSnapshot());
      final withoutAbbreviation = await generate(snapshot: coveringSnapshot(abbreviation: ""));

      expect(_contentStreams(withAbbreviation), isNot(_contentStreams(withoutAbbreviation)));
    });

    test("closes a bar with a cap at each end of the passage it covers", () async {
      final bytes = await generate(snapshot: coveringSnapshot());

      // The bar and the two caps closing it: three fills in the shot's own colour, where the bar
      // alone used to be the only one. The passage covers whole lines here, so no tick of the same
      // colour is drawn inside the text to be counted with them.
      final fills = _filledRectangleColors(bytes);
      expect(fills.where((fill) => fill == _fillOf(ocptCoverageColorAt(0))), hasLength(3));
    });

    test("prints every bar's label on an opaque plate of its own", () async {
      final bytes = await generate(snapshot: coveringSnapshot());

      // A plate the label alone is printed on: without it, a label reaching over a neighbouring
      // bar prints a coloured word over a coloured stroke, which no reader can tell apart.
      expect(_filledRectangleColors(bytes), contains(_labelPlateFill));
    });

    test("draws every label over every bar of the page, never under one", () async {
      final bytes = await generate(snapshot: overlappingSnapshot());
      final fills = _filledRectangleColors(bytes);

      // Two bars on the same row, hence two labels, hence two plates — and both of them come after
      // every coloured fill of the page (the bars themselves and their ticks), which is the only
      // stacking order that keeps the first label readable when the second bar runs under it.
      final plates = fills.where((fill) => fill == _labelPlateFill);
      expect(plates, hasLength(2));
      expect(fills.sublist(fills.length - 2), everyElement(_labelPlateFill));
    });

    test("a shot list holding no coverage at all still prints the whole screenplay", () async {
      final bytes = await generate(snapshot: uncoveredSnapshot());

      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
      expect(_pageCount(bytes), 1);
    });

    test("an empty shot list is an export like any other", () async {
      final bytes = await generate(
        snapshot: OcptShotListSnapshot.build(screenplayId: "screenplay", sequences: const []),
        includeLegendPage: true,
        includeSummaryPage: true,
      );

      expect(_pageCount(bytes), 3);
    });
  });

  group("coverageFileName", () {
    test("joins the project name and the localized suffix", () {
      expect(
        service.coverageFileName(projectName: "My Movie", suffix: "coverage"),
        "My Movie - coverage.pdf",
      );
    });

    test("a blank suffix falls back to the project name alone", () {
      expect(service.coverageFileName(projectName: "My Movie", suffix: "   "), "My Movie.pdf");
    });

    test("a padded suffix is trimmed rather than printed as is", () {
      expect(
        service.coverageFileName(projectName: "My Movie", suffix: " coverage "),
        "My Movie - coverage.pdf",
      );
    });

    test("appends the episode tag last, after the suffix, when there is one", () {
      expect(
        service.coverageFileName(projectName: "My Movie", suffix: "coverage", episodeTag: "ep. 2"),
        "My Movie - coverage - ep. 2.pdf",
      );
    });
  });
}

/// Counts a PDF's pages by counting its `/Type /Page` object markers (excluding `/Type /Pages`, the
/// tree node), a cheap way to assert on page count without pulling in a full PDF parser as a test
/// dependency.
int _pageCount(Uint8List bytes) {
  final text = latin1.decode(bytes, allowInvalid: true);
  return RegExp(r"/Type\s*/Page[^s]").allMatches(text).length;
}

/// The fill colour of every filled rectangle the document draws, in drawing order, as the PDF
/// operand triple itself — white being [_labelPlateFill].
///
/// Inflates every `stream` object and reads back the `W H re R G B rg f` sequences a coloured
/// `pdf`-package container emits. Like [_contentStreams] this is a boundary search rather than a
/// PDF parser: it keeps whichever streams hold such a sequence at all, which on these documents are
/// the page contents and never the embedded font files.
List<String> _filledRectangleColors(Uint8List bytes) {
  final pattern = RegExp(r"re ((?:[\d.]+ ){3})rg f");

  return [
    for (final stream in _contentStreams(bytes))
      for (final match in pattern.allMatches(_inflated(stream) ?? "")) match.group(1)!.trim(),
  ];
}

/// The PDF fill-colour operands of the ARGB [color], formatted exactly as the `pdf` package's own
/// `PdfNum` writes them: five decimals with the trailing zeros (and a bare decimal point) dropped.
String _fillOf(int color) => [
  for (final shift in [16, 8, 0]) _operandOf((color >> shift & 0xFF) / 255),
].join(" ");

/// [value] as one such operand.
String _operandOf(double value) {
  final fixed = value.toStringAsFixed(5);
  if (!fixed.contains(".")) {
    return fixed;
  }

  final trimmed = fixed.replaceFirst(RegExp(r"0+$"), "");
  return trimmed.endsWith(".") ? trimmed.substring(0, trimmed.length - 1) : trimmed;
}

/// [stream] inflated, or null when it is not a deflated stream at all.
String? _inflated(String stream) {
  try {
    return latin1.decode(ZLibDecoder().convert(latin1.encode(stream)));
  } on FormatException {
    return null;
  }
}

/// The raw (still-compressed) bytes of every `stream`/`endstream` object in [bytes], in file order.
///
/// This is a boundary search, not a PDF parser: it never inspects the surrounding object
/// dictionaries (so it can't tell a page's content stream from a font's embedded file), which is
/// fine for an equality comparison between two documents built from the same `generate` call shape
/// — both sides always contain the same kind of streams in the same order, so any content
/// difference between them still shows up.
List<String> _contentStreams(Uint8List bytes) {
  final text = latin1.decode(bytes, allowInvalid: true);
  final pattern = RegExp(r"stream\r?\n(.*?)endstream", dotAll: true);
  return [for (final match in pattern.allMatches(text)) match.group(1)!];
}
