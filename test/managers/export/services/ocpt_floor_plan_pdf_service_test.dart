// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_floor_plan_pdf_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_arrow.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_set.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_arrow_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';

/// A minimal, valid 1×1 white PNG — small enough to embed in a test, real enough for the `pdf`
/// package's own decoder to accept it as a `pw.MemoryImage`.
final Uint8List _onePixelPng = base64Decode(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=",
);

/// Every localized string of the document, filled with recognisable placeholders.
const _labels = OcptFloorPlanLabels(
  fileNameSuffix: "floor plans",
  documentTitle: "Floor plans",
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
  sequenceTitles: {"scene-1": "Sequence 1"},
  noCameraNote: "No camera placed on this case yet.",
  scaleBarUnitLabel: "m",
);

/// Builds an [OcptShot] test double with sensible defaults for the fields a given test does not
/// care about.
OcptShot _buildShot({required String id, required String code}) => OcptShot(
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
  characters: const ["ROLE A"],
  coverageRanges: const [],
  code: code,
  averageDifficulty: 0,
);

/// Builds a camera symbol on [setId] for [shotId].
OcptFloorPlanSymbol _cameraSymbolOf({
  required String id,
  required String setId,
  required String shotId,
  double xM = 0,
  double yM = 0,
  double? fovDeg,
}) => OcptFloorPlanSymbol(
  id: id,
  setId: setId,
  shotId: shotId,
  layer: OcptFloorPlanLayer.cameras,
  sortKey: "a",
  xM: xM,
  yM: yM,
  rotationDeg: 0,
  widthM: null,
  heightM: null,
  fovDeg: fovDeg,
  label: "",
  setElementShape: null,
);

/// Builds a character symbol on [setId] for [shotId].
OcptFloorPlanSymbol _characterSymbolOf({
  required String id,
  required String setId,
  required String shotId,
  double xM = 0,
  double yM = 0,
}) => OcptFloorPlanSymbol(
  id: id,
  setId: setId,
  shotId: shotId,
  layer: OcptFloorPlanLayer.characters,
  sortKey: "b",
  xM: xM,
  yM: yM,
  rotationDeg: 0,
  widthM: null,
  heightM: null,
  fovDeg: null,
  label: "Sam",
  setElementShape: null,
);

/// A sequence-scoped character symbol on [setId] — never ghosted, always drawn (on the bare-décor
/// page too, since it carries no `shotId`), unlike [_characterSymbolOf]'s own shot-scoped one.
OcptFloorPlanSymbol _sequenceCharacterSymbolOf({required String id, required String setId}) =>
    OcptFloorPlanSymbol(
      id: id,
      setId: setId,
      shotId: null,
      layer: OcptFloorPlanLayer.characters,
      sortKey: "a",
      xM: 0,
      yM: 0,
      rotationDeg: 0,
      widthM: null,
      heightM: null,
      fovDeg: null,
      label: "Sam",
      setElementShape: null,
    );

/// A sequence-scoped décor symbol on [setId], drawn as [shape] (defaulting to freeform, today's
/// generic look, when unset).
OcptFloorPlanSymbol _decorSymbolOf({
  required String id,
  required String setId,
  OcptFloorPlanSetElementShape? shape,
}) => OcptFloorPlanSymbol(
  id: id,
  setId: setId,
  shotId: null,
  layer: OcptFloorPlanLayer.set,
  sortKey: "a",
  xM: 0,
  yM: 0,
  rotationDeg: 0,
  widthM: 2,
  heightM: 1,
  fovDeg: null,
  label: "wall",
  setElementShape: shape,
);

/// A movement arrow between two symbols of [setId], curved when [ctrlXM]/[ctrlYM] are set,
/// straight otherwise.
OcptFloorPlanArrow _movementArrowOf({
  required String id,
  required String setId,
  required String shotId,
  required String fromSymbolId,
  required String toSymbolId,
  double? ctrlXM,
  double? ctrlYM,
}) => OcptFloorPlanArrow(
  id: id,
  setId: setId,
  shotId: shotId,
  kind: OcptFloorPlanArrowKind.movement,
  fromSymbolId: fromSymbolId,
  toSymbolId: toSymbolId,
  label: "",
  ctrlXM: ctrlXM,
  ctrlYM: ctrlYM,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = OcptFloorPlanPdfService();
  const pageSetup = OcptPageSetup.standard();

  late Directory tempDir;
  late String imagePath;
  late String missingPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_floor_plan_pdf_test_");
    imagePath = "${tempDir.path}/underlay.png";
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

  OcptFloorPlanSet buildCase({
    required String id,
    List<OcptFloorPlanSymbol> symbols = const [],
    List<OcptFloorPlanArrow> arrows = const [],
    String? underlayPath,
    double underlayRotationDeg = 0,
  }) => OcptFloorPlanSet(
    id: id,
    sceneId: "scene-1",
    name: "Kitchen",
    sortKey: "a",
    underlayAssetId: underlayPath == null ? null : "underlay-asset",
    underlayPath: underlayPath,
    underlayXM: underlayPath == null ? null : 0,
    underlayYM: underlayPath == null ? null : 0,
    underlayWidthM: underlayPath == null ? null : 3,
    underlayHeightM: underlayPath == null ? null : 2,
    underlayRotationDeg: underlayPath == null ? null : underlayRotationDeg,
    symbols: symbols,
    arrows: arrows,
  );

  Future<Uint8List> generate({
    required OcptShotListSnapshot snapshot,
    required OcptFloorPlanSnapshot floorPlanSnapshot,
  }) => service.generate(
    snapshot: snapshot,
    floorPlanSnapshot: floorPlanSnapshot,
    pageSetup: pageSetup,
    labels: _labels,
    projectName: "My Movie",
  );

  group("generate", () {
    test("produces bytes starting with the %PDF magic string", () async {
      final bytes = await generate(
        snapshot: snapshotOf(1),
        floorPlanSnapshot: OcptFloorPlanSnapshot.build(
          screenplayId: "screenplay",
          setsBySceneId: {
            "scene-1": [buildCase(id: "case-1", symbols: [_decorSymbolOf(id: "sym-1", setId: "case-1")])],
          },
        ),
      );

      expect(bytes, isNotEmpty);
      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
    });

    test("a case with no camera anywhere prints exactly one bare-décor page", () async {
      final bytes = await generate(
        snapshot: snapshotOf(2),
        floorPlanSnapshot: OcptFloorPlanSnapshot.build(
          screenplayId: "screenplay",
          setsBySceneId: {
            "scene-1": [buildCase(id: "case-1", symbols: [_decorSymbolOf(id: "sym-1", setId: "case-1")])],
          },
        ),
      );

      expect(_pageCount(bytes), 1);
    });

    test("one page per shot that has a camera placed on this case, not per shot of the sequence", () async {
      // 3 shots, only shot-0 and shot-2 have a camera on case-1: exactly 2 pages, never 3 or 1.
      final bytes = await generate(
        snapshot: snapshotOf(3),
        floorPlanSnapshot: OcptFloorPlanSnapshot.build(
          screenplayId: "screenplay",
          setsBySceneId: {
            "scene-1": [
              buildCase(
                id: "case-1",
                symbols: [
                  _cameraSymbolOf(id: "cam-0", setId: "case-1", shotId: "shot-0"),
                  _cameraSymbolOf(id: "cam-2", setId: "case-1", shotId: "shot-2"),
                ],
              ),
            ],
          },
        ),
      );

      expect(_pageCount(bytes), 2);
    });

    test("several cases of the same sequence each contribute their own pages", () async {
      final bytes = await generate(
        snapshot: snapshotOf(3),
        floorPlanSnapshot: OcptFloorPlanSnapshot.build(
          screenplayId: "screenplay",
          setsBySceneId: {
            "scene-1": [
              buildCase(
                id: "case-1",
                symbols: [
                  _cameraSymbolOf(id: "cam-0", setId: "case-1", shotId: "shot-0"),
                  _cameraSymbolOf(id: "cam-2", setId: "case-1", shotId: "shot-2"),
                ],
              ),
              buildCase(id: "case-2", symbols: [_decorSymbolOf(id: "sym-1", setId: "case-2")]),
            ],
          },
        ),
      );

      // case-1: 2 camera pages; case-2: 1 bare-décor page.
      expect(_pageCount(bytes), 3);
    });

    test("the orphan group has no scene and so contributes no page", () async {
      final snapshot = OcptShotListSnapshot.build(
        screenplayId: "screenplay",
        sequences: [OcptOrphanShotSequence(shots: [_buildShot(id: "shot-orphan", code: "0/1")])],
      );

      final bytes = await generate(
        snapshot: snapshot,
        floorPlanSnapshot: OcptFloorPlanSnapshot.build(screenplayId: "screenplay", setsBySceneId: const {}),
      );

      expect(_pageCount(bytes), 0);
    });
  });

  group("what the floor plan draws", () {
    test("a case with a camera draws differently from the very same case with none", () async {
      OcptFloorPlanSnapshot snapshotWith(List<OcptFloorPlanSymbol> symbols) => OcptFloorPlanSnapshot.build(
        screenplayId: "screenplay",
        setsBySceneId: {
          "scene-1": [buildCase(id: "case-1", symbols: symbols)],
        },
      );

      final withCamera = await generate(
        snapshot: snapshotOf(1),
        floorPlanSnapshot: snapshotWith([_cameraSymbolOf(id: "cam-0", setId: "case-1", shotId: "shot-0")]),
      );
      final withoutCamera = await generate(
        snapshot: snapshotOf(1),
        floorPlanSnapshot: snapshotWith(const []),
      );

      expect(_contentStreams(withCamera), isNot(_contentStreams(withoutCamera)));
    });

    test("moving a camera relative to a fixed décor anchor draws differently again", () async {
      // A lone symbol would always draw at the very same spot: the page's fit-to-content layout
      // recentres its own bounding box on whatever is placed, so only a symbol's position
      // *relative to another one* can ever change what a page draws.
      OcptFloorPlanSnapshot snapshotAt(double xM) => OcptFloorPlanSnapshot.build(
        screenplayId: "screenplay",
        setsBySceneId: {
          "scene-1": [
            buildCase(
              id: "case-1",
              symbols: [
                _decorSymbolOf(id: "sym-1", setId: "case-1"),
                _cameraSymbolOf(id: "cam-0", setId: "case-1", shotId: "shot-0", xM: xM),
              ],
            ),
          ],
        },
      );

      final first = await generate(snapshot: snapshotOf(1), floorPlanSnapshot: snapshotAt(1));
      final second = await generate(snapshot: snapshotOf(1), floorPlanSnapshot: snapshotAt(4));

      expect(_contentStreams(first), isNot(_contentStreams(second)));
    });

    test("a camera's own field-of-view wedge angle changes what its own page draws", () async {
      OcptFloorPlanSnapshot snapshotOfFov(double fovDeg) => OcptFloorPlanSnapshot.build(
        screenplayId: "screenplay",
        setsBySceneId: {
          "scene-1": [
            buildCase(
              id: "case-1",
              symbols: [_cameraSymbolOf(id: "cam-0", setId: "case-1", shotId: "shot-0", fovDeg: fovDeg)],
            ),
          ],
        },
      );

      final narrow = await generate(snapshot: snapshotOf(1), floorPlanSnapshot: snapshotOfFov(20));
      final wide = await generate(snapshot: snapshotOf(1), floorPlanSnapshot: snapshotOfFov(160));

      expect(_contentStreams(narrow), isNot(_contentStreams(wide)));
    });

    test("each décor primitive draws its own page", () async {
      OcptFloorPlanSnapshot snapshotOfShape(OcptFloorPlanSetElementShape shape) => OcptFloorPlanSnapshot.build(
        screenplayId: "screenplay",
        setsBySceneId: {
          "scene-1": [
            buildCase(id: "case-1", symbols: [_decorSymbolOf(id: "sym-1", setId: "case-1", shape: shape)]),
          ],
        },
      );

      final wall = await generate(snapshot: snapshotOf(1), floorPlanSnapshot: snapshotOfShape(OcptFloorPlanSetElementShape.wall));
      final door = await generate(snapshot: snapshotOf(1), floorPlanSnapshot: snapshotOfShape(OcptFloorPlanSetElementShape.door));
      final furniture = await generate(
        snapshot: snapshotOf(1),
        floorPlanSnapshot: snapshotOfShape(OcptFloorPlanSetElementShape.furniture),
      );
      final freeform = await generate(
        snapshot: snapshotOf(1),
        floorPlanSnapshot: snapshotOfShape(OcptFloorPlanSetElementShape.freeform),
      );

      expect(_contentStreams(wall), isNot(_contentStreams(door)));
      expect(_contentStreams(door), isNot(_contentStreams(furniture)));
      expect(_contentStreams(furniture), isNot(_contentStreams(freeform)));
      expect(_contentStreams(freeform), isNot(_contentStreams(wall)));
    });

    test("a curved movement arrow draws differently from a straight one", () async {
      OcptFloorPlanSnapshot snapshotOfArrow({double? ctrlXM, double? ctrlYM}) => OcptFloorPlanSnapshot.build(
        screenplayId: "screenplay",
        setsBySceneId: {
          "scene-1": [
            buildCase(
              id: "case-1",
              symbols: [
                _cameraSymbolOf(id: "cam-0", setId: "case-1", shotId: "shot-0"),
                _characterSymbolOf(id: "char-0", setId: "case-1", shotId: "shot-0", xM: 2, yM: 2),
              ],
              arrows: [
                _movementArrowOf(
                  id: "arrow-1",
                  setId: "case-1",
                  shotId: "shot-0",
                  fromSymbolId: "char-0",
                  toSymbolId: "cam-0",
                  ctrlXM: ctrlXM,
                  ctrlYM: ctrlYM,
                ),
              ],
            ),
          ],
        },
      );

      final straight = await generate(snapshot: snapshotOf(1), floorPlanSnapshot: snapshotOfArrow());
      final curved = await generate(
        snapshot: snapshotOf(1),
        floorPlanSnapshot: snapshotOfArrow(ctrlXM: 3, ctrlYM: -1),
      );

      expect(_contentStreams(straight), isNot(_contentStreams(curved)));
    });
  });

  group("the character glyph and the camera label pill", () {
    test("a character's own facing indicator (rim notch and arms) never draws in plain white", () async {
      // Sequence-scoped, so it draws on the bare-décor page even with no camera anywhere on this
      // case — the one page this case's set of symbols can ever draw with no camera label pill
      // (see the sibling test below) to also contribute a white fill/stroke of its own.
      final bytes = await generate(
        snapshot: snapshotOf(1),
        floorPlanSnapshot: OcptFloorPlanSnapshot.build(
          screenplayId: "screenplay",
          setsBySceneId: {
            "scene-1": [
              buildCase(id: "case-1", symbols: [_sequenceCharacterSymbolOf(id: "char-0", setId: "case-1")]),
            ],
          },
        ),
      );

      final inflated = _inflatedContentOf(bytes);

      expect(inflated, isNot(contains("1 1 1 rg")));
      expect(inflated, isNot(contains("1 1 1 RG")));
    });

    test("a camera's own derived label draws white text on a filled pill; a page with no camera "
        "never draws that white at all", () async {
      final withCamera = await generate(
        snapshot: snapshotOf(1),
        floorPlanSnapshot: OcptFloorPlanSnapshot.build(
          screenplayId: "screenplay",
          setsBySceneId: {
            "scene-1": [
              buildCase(id: "case-1", symbols: [_cameraSymbolOf(id: "cam-0", setId: "case-1", shotId: "shot-0")]),
            ],
          },
        ),
      );
      final decorOnly = await generate(
        snapshot: snapshotOf(1),
        floorPlanSnapshot: OcptFloorPlanSnapshot.build(
          screenplayId: "screenplay",
          setsBySceneId: {
            "scene-1": [buildCase(id: "case-1", symbols: [_decorSymbolOf(id: "sym-1", setId: "case-1")])],
          },
        ),
      );

      expect(_inflatedContentOf(withCamera), contains("1 1 1 rg"));
      expect(_inflatedContentOf(decorOnly), isNot(contains("1 1 1 rg")));
    });
  });

  group("the underlay", () {
    OcptFloorPlanSnapshot snapshotWithUnderlay(String? underlayPath, {double rotationDeg = 0}) =>
        OcptFloorPlanSnapshot.build(
          screenplayId: "screenplay",
          setsBySceneId: {
            "scene-1": [
              buildCase(
                id: "case-1",
                symbols: [_decorSymbolOf(id: "sym-1", setId: "case-1")],
                underlayPath: underlayPath,
                underlayRotationDeg: rotationDeg,
              ),
            ],
          },
        );

    test("a case whose underlay file resolves draws differently from one whose file is missing", () async {
      final resolved = await generate(
        snapshot: snapshotOf(1),
        floorPlanSnapshot: snapshotWithUnderlay(imagePath),
      );
      final missing = await generate(
        snapshot: snapshotOf(1),
        floorPlanSnapshot: snapshotWithUnderlay(missingPath),
      );

      expect(_contentStreams(resolved), isNot(_contentStreams(missing)));
    });

    test("a case with no underlay at all still exports without throwing", () async {
      final bytes = await generate(snapshot: snapshotOf(1), floorPlanSnapshot: snapshotWithUnderlay(null));

      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
    });

    test("a rotated underlay still exports without throwing, and draws differently from an "
        "unrotated one", () async {
      final unrotated = await generate(
        snapshot: snapshotOf(1),
        floorPlanSnapshot: snapshotWithUnderlay(imagePath),
      );
      final rotated = await generate(
        snapshot: snapshotOf(1),
        floorPlanSnapshot: snapshotWithUnderlay(imagePath, rotationDeg: 30),
      );

      expect(ascii.decode(rotated.sublist(0, 4)), "%PDF");
      expect(_contentStreams(unrotated), isNot(_contentStreams(rotated)));
    });
  });

  group("floorPlansFileName", () {
    test("joins the project name and the localized suffix", () {
      expect(
        service.floorPlansFileName(projectName: "My Movie", suffix: "floor plans"),
        "My Movie - floor plans.pdf",
      );
    });

    test("appends the episode tag last, after the suffix, when there is one", () {
      expect(
        service.floorPlansFileName(projectName: "My Movie", suffix: "floor plans", episodeTag: "ep. 2"),
        "My Movie - floor plans - ep. 2.pdf",
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

/// Every content stream of [bytes], inflated and joined — what a test greps a literal PDF
/// operator sequence (a colour's own `r g b rg`/`RG`) out of, since `Document` compresses every
/// stream by default. See `ocpt_scenario_coverage_pdf_service_test.dart`'s own copy of this
/// helper.
String _inflatedContentOf(Uint8List bytes) =>
    [for (final stream in _contentStreams(bytes)) _inflated(stream) ?? ""].join("\n");

/// [stream] inflated, or null when it is not a deflated stream at all.
String? _inflated(String stream) {
  try {
    return latin1.decode(ZLibDecoder().convert(latin1.encode(stream)));
  } on FormatException {
    return null;
  }
}
