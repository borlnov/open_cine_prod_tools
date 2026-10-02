// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_storyboard_pdf_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_annotation.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_panel.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_snapshot.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_kind.dart';

/// A minimal, valid 1×1 white PNG — small enough to embed in a test, real enough for the `pdf`
/// package's own decoder to accept it as a `pw.MemoryImage`.
final Uint8List _onePixelPng = base64Decode(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=",
);

/// Every localized string of the document, filled with recognisable placeholders.
const _labels = OcptStoryboardLabels(
  fileNameSuffix: "storyboard",
  documentTitle: "Storyboard",
  shotSizeLabel: "Shot size",
  framingLabel: "Framing",
  cameraMoveLabel: "Camera move",
  lensLabel: "Lens",
  recordingFormatLabel: "Format",
  castLabel: "Cast",
  statusLabels: {
    OcptShotStatus.toShoot: "To shoot",
    OcptShotStatus.shot: "Shot",
    OcptShotStatus.retake: "Retake",
  },
  noPanelNote: "no panel yet",
  fileNotFoundNote: "File not found",
  sequenceTitles: {"scene-1": "Sequence 1"},
);

/// Builds an [OcptShot] test double with sensible defaults for the fields a given test does not
/// care about.
OcptShot _buildShot({required String id, required String code, String recordingFormat = ""}) => OcptShot(
  id: id,
  screenplayId: "screenplay",
  sceneId: "scene-1",
  orphanedHeading: null,
  position: 0,
  shotSize: "Medium shot",
  abbreviation: "PM",
  framing: "Front",
  cameraMove: "Static",
  lens: "35mm",
  recordingFormat: recordingFormat,
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
  characters: const ["ROLE A"],
  coverageRanges: const [],
  code: code,
  averageDifficulty: 0,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = OcptStoryboardPdfService();
  const pageSetup = OcptPageSetup.standard();

  late Directory tempDir;
  late String imagePath;
  late String missingPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_storyboard_pdf_test_");
    imagePath = "${tempDir.path}/frame.png";
    await File(imagePath).writeAsBytes(_onePixelPng);
    missingPath = "${tempDir.path}/gone.png";
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  /// A shot list of one sequence holding [shotCount] shots, each named `shot-<n>`/`n/n`.
  OcptShotListSnapshot snapshotOf(int shotCount) => OcptShotListSnapshot.build(
    screenplayId: "screenplay",
    sequences: [
      OcptSceneShotSequence(
        sceneId: "scene-1",
        heading: "INT. KITCHEN - DAY",
        sceneNumber: null,
        displaySceneNumber: "1",
        charStart: 0,
        charEnd: 100,
        shots: [
          for (var i = 0; i < shotCount; i++) _buildShot(id: "shot-$i", code: "1/${i + 1}"),
        ],
      ),
    ],
  );

  Future<Uint8List> generate({
    required OcptShotListSnapshot snapshot,
    required OcptStoryboardSnapshot storyboardSnapshot,
    int shotsPerPage = 4,
  }) => service.generate(
    snapshot: snapshot,
    storyboardSnapshot: storyboardSnapshot,
    pageSetup: pageSetup,
    labels: _labels,
    projectName: "My Movie",
    shotsPerPage: shotsPerPage,
  );

  group("generate", () {
    test("produces bytes starting with the %PDF magic string", () async {
      final bytes = await generate(
        snapshot: snapshotOf(1),
        storyboardSnapshot: const OcptStoryboardSnapshot(screenplayId: "screenplay", panelsByShotId: {}),
      );

      expect(bytes, isNotEmpty);
      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
    });

    test("one page per shotsPerPage-sized chunk of a sequence's shots", () async {
      // 5 shots at 2 per page: 3 chunks, hence 3 pages — no floor plans appended, no title page.
      final bytes = await generate(
        snapshot: snapshotOf(5),
        storyboardSnapshot: const OcptStoryboardSnapshot(screenplayId: "screenplay", panelsByShotId: {}),
        shotsPerPage: 2,
      );

      expect(_pageCount(bytes), 3);
    });

    test("a sequence with no shot at all contributes no page", () async {
      final bytes = await generate(
        snapshot: OcptShotListSnapshot.build(screenplayId: "screenplay", sequences: const []),
        storyboardSnapshot: const OcptStoryboardSnapshot(screenplayId: "screenplay", panelsByShotId: {}),
      );

      expect(_pageCount(bytes), 0);
    });

    test("a shot with no panel still prints its own row", () async {
      final bytes = await generate(
        snapshot: snapshotOf(1),
        storyboardSnapshot: const OcptStoryboardSnapshot(screenplayId: "screenplay", panelsByShotId: {}),
      );

      expect(_pageCount(bytes), 1);
    });
  });

  group("the missing-file placeholder", () {
    test("a panel whose image cannot be found still exports without throwing", () async {
      final storyboardSnapshot = OcptStoryboardSnapshot(
        screenplayId: "screenplay",
        panelsByShotId: {
          "shot-0": [
            OcptStoryboardPanel(
              id: "panel-1",
              shotId: "shot-0",
              sortKey: "a",
              imageAssetId: "asset-1",
              imagePath: missingPath,
              comment: "",
              annotations: const [],
            ),
          ],
        },
      );

      final bytes = await generate(snapshot: snapshotOf(1), storyboardSnapshot: storyboardSnapshot);

      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
      expect(_pageCount(bytes), 1);
    });

    test("a resolved image draws differently from a missing one", () async {
      OcptStoryboardSnapshot storyboardSnapshotWith(String? path) => OcptStoryboardSnapshot(
        screenplayId: "screenplay",
        panelsByShotId: {
          "shot-0": [
            OcptStoryboardPanel(
              id: "panel-1",
              shotId: "shot-0",
              sortKey: "a",
              imageAssetId: path == null ? null : "asset-1",
              imagePath: path,
              comment: "",
              annotations: const [],
            ),
          ],
        },
      );

      final withImage = await generate(
        snapshot: snapshotOf(1),
        storyboardSnapshot: storyboardSnapshotWith(imagePath),
      );
      final withoutImage = await generate(
        snapshot: snapshotOf(1),
        storyboardSnapshot: storyboardSnapshotWith(null),
      );

      expect(_contentStreams(withImage), isNot(_contentStreams(withoutImage)));
    });
  });

  group("annotation geometry", () {
    test("a panel with an annotation draws differently from the same panel without one", () async {
      OcptStoryboardSnapshot storyboardSnapshotWith(List<OcptStoryboardAnnotation> annotations) =>
          OcptStoryboardSnapshot(
            screenplayId: "screenplay",
            panelsByShotId: {
              "shot-0": [
                OcptStoryboardPanel(
                  id: "panel-1",
                  shotId: "shot-0",
                  sortKey: "a",
                  imageAssetId: "asset-1",
                  imagePath: imagePath,
                  comment: "",
                  annotations: annotations,
                ),
              ],
            },
          );

      final withoutAnnotation = await generate(
        snapshot: snapshotOf(1),
        storyboardSnapshot: storyboardSnapshotWith(const []),
      );
      final withAnnotation = await generate(
        snapshot: snapshotOf(1),
        storyboardSnapshot: storyboardSnapshotWith(const [
          OcptStoryboardAnnotation(
            id: "ann-1",
            panelId: "panel-1",
            kind: OcptStoryboardAnnotationKind.movementArrow,
            sortKey: "a",
            x1: 0.1,
            y1: 0.2,
            x2: 0.8,
            y2: 0.6,
            text: "",
          ),
        ]),
      );

      expect(_contentStreams(withAnnotation), isNot(_contentStreams(withoutAnnotation)));
    });

    test("moving an annotation's own normalised endpoint draws differently again", () async {
      OcptStoryboardSnapshot storyboardSnapshotWith(double y2) => OcptStoryboardSnapshot(
        screenplayId: "screenplay",
        panelsByShotId: {
          "shot-0": [
            OcptStoryboardPanel(
              id: "panel-1",
              shotId: "shot-0",
              sortKey: "a",
              imageAssetId: "asset-1",
              imagePath: imagePath,
              comment: "",
              annotations: [
                OcptStoryboardAnnotation(
                  id: "ann-1",
                  panelId: "panel-1",
                  kind: OcptStoryboardAnnotationKind.cameraMoveArrow,
                  sortKey: "a",
                  x1: 0.1,
                  y1: 0.1,
                  x2: 0.5,
                  y2: y2,
                  text: "",
                ),
              ],
            ),
          ],
        },
      );

      final first = await generate(
        snapshot: snapshotOf(1),
        storyboardSnapshot: storyboardSnapshotWith(0.4),
      );
      final second = await generate(
        snapshot: snapshotOf(1),
        storyboardSnapshot: storyboardSnapshotWith(0.9),
      );

      expect(_contentStreams(first), isNot(_contentStreams(second)));
    });

    test("a label annotation's own text reaches the page", () async {
      final withText = await generate(
        snapshot: snapshotOf(1),
        storyboardSnapshot: OcptStoryboardSnapshot(
          screenplayId: "screenplay",
          panelsByShotId: {
            "shot-0": [
              OcptStoryboardPanel(
                id: "panel-1",
                shotId: "shot-0",
                sortKey: "a",
                imageAssetId: "asset-1",
                imagePath: imagePath,
                comment: "",
                annotations: const [
                  OcptStoryboardAnnotation(
                    id: "ann-1",
                    panelId: "panel-1",
                    kind: OcptStoryboardAnnotationKind.label,
                    sortKey: "a",
                    x1: 0.3,
                    y1: 0.3,
                    x2: 0,
                    y2: 0,
                    text: "dolly in",
                  ),
                ],
              ),
            ],
          },
        ),
      );
      final withoutText = await generate(
        snapshot: snapshotOf(1),
        storyboardSnapshot: OcptStoryboardSnapshot(
          screenplayId: "screenplay",
          panelsByShotId: {
            "shot-0": [
              OcptStoryboardPanel(
                id: "panel-1",
                shotId: "shot-0",
                sortKey: "a",
                imageAssetId: "asset-1",
                imagePath: imagePath,
                comment: "",
                annotations: const [
                  OcptStoryboardAnnotation(
                    id: "ann-1",
                    panelId: "panel-1",
                    kind: OcptStoryboardAnnotationKind.label,
                    sortKey: "a",
                    x1: 0.3,
                    y1: 0.3,
                    x2: 0,
                    y2: 0,
                    text: "",
                  ),
                ],
              ),
            ],
          },
        ),
      );

      expect(_contentStreams(withText), isNot(_contentStreams(withoutText)));
    });
  });

  group("storyboardFileName", () {
    test("joins the project name and the localized suffix", () {
      expect(
        service.storyboardFileName(projectName: "My Movie", suffix: "storyboard"),
        "My Movie - storyboard.pdf",
      );
    });

    test("appends the episode tag last, after the suffix, when there is one", () {
      expect(
        service.storyboardFileName(projectName: "My Movie", suffix: "storyboard", episodeTag: "ep. 2"),
        "My Movie - storyboard - ep. 2.pdf",
      );
    });
  });
}

/// Counts a PDF's pages by counting its `/Type /Page` object markers (excluding `/Type /Pages`, the
/// tree node) — see `ocpt_scenario_coverage_pdf_service_test.dart`'s own copy of this helper.
int _pageCount(Uint8List bytes) {
  final text = latin1.decode(bytes, allowInvalid: true);
  return RegExp(r"/Type\s*/Page[^s]").allMatches(text).length;
}

/// The raw (still-compressed) bytes of every `stream`/`endstream` object in [bytes], in file order
/// — see `ocpt_scenario_coverage_pdf_service_test.dart`'s own copy of this helper for why this is a
/// boundary search rather than a full PDF parser.
List<String> _contentStreams(Uint8List bytes) {
  final text = latin1.decode(bytes, allowInvalid: true);
  final pattern = RegExp(r"stream\r?\n(.*?)endstream", dotAll: true);
  return [for (final match in pattern.allMatches(text)) match.group(1)!];
}
