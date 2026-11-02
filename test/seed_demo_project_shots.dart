// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_floor_plan_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_storyboard_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_kind.dart';

import 'ocpt_result_expectations.dart';
import 'seed_demo_project_images.dart';

/// Seeds the shot list of every scene.
Future<Map<int, List<String>>> seedShotList({
  required OcptProjectDatabase database,
  required List<String> sceneIds,
  required String screenplayId,
  required OcptShotListService shotListService,
}) async {
  // ------------------------------------------------------------------------------- the shot
  // list

  /// Creates one shot of scene [sceneIndex] and returns its id.
  Future<String> createShot({
    required int sceneIndex,
    required String shotSize,
    required String framing,
    required String cameraMove,
    required int screenSeconds,
    required List<String> characters,
    int difficulty = 1,
  }) async {
    final shotId = (await shotListService.createShot(
      database: database,
      screenplayId: screenplayId,
      sceneId: sceneIds[sceneIndex],
    ))!;
    await shotListService.updateShot(
      database: database,
      shotId: shotId,
      shotSize: Value(shotSize),
      framing: Value(framing),
      cameraMove: Value(cameraMove),
      lens: const Value("35 mm"),
      recordingFormat: const Value("4K · 25 fps"),
      sound: const Value("Direct"),
      estimatedDurationMs: Value(screenSeconds * 1000),
      plannedTakes: const Value(3),
      difficultySet: Value(difficulty),
      difficultyCamera: Value(difficulty),
    );
    for (final character in characters) {
      final roleId = (await shotListService.resolveOrCreateRoleId(
        database: database,
        screenplayId: screenplayId,
        name: character,
      ))!;
      await shotListService.attachCharacter(database: database, shotId: shotId, roleId: roleId);
    }
    return shotId;
  }

  final shotsByScene = <int, List<String>>{};

  /// Records [shotId] as the next shot of scene [sceneIndex].
  void record(int sceneIndex, String shotId) =>
      shotsByScene.putIfAbsent(sceneIndex, () => <String>[]).add(shotId);

  record(
    0,
    await createShot(
      sceneIndex: 0,
      shotSize: "Wide",
      framing: "The cafe, the rain on the window, Nora coming in.",
      cameraMove: "Static",
      screenSeconds: 24,
      characters: ["NORA", "OWNER"],
    ),
  );
  record(
    0,
    await createShot(
      sceneIndex: 0,
      shotSize: "Medium",
      framing: "Nora at the counter, the satchel between them.",
      cameraMove: "Slow push in",
      screenSeconds: 32,
      characters: ["NORA", "OWNER"],
      difficulty: 2,
    ),
  );
  record(
    0,
    await createShot(
      sceneIndex: 0,
      shotSize: "Close-up",
      framing: "The brass compass in the open satchel.",
      cameraMove: "Static",
      screenSeconds: 9,
      characters: ["NORA"],
    ),
  );
  record(
    0,
    await createShot(
      sceneIndex: 0,
      shotSize: "Close-up",
      framing: "The owner, still polishing, watching her.",
      cameraMove: "Handheld",
      screenSeconds: 11,
      characters: ["OWNER"],
      difficulty: 2,
    ),
  );

  record(
    1,
    await createShot(
      sceneIndex: 1,
      shotSize: "Medium",
      framing: "The owner puts the glass down.",
      cameraMove: "Static",
      screenSeconds: 18,
      characters: ["OWNER"],
    ),
  );
  record(
    1,
    await createShot(
      sceneIndex: 1,
      shotSize: "Close-up",
      framing: "Nora, hearing what he is not saying.",
      cameraMove: "Static",
      screenSeconds: 14,
      characters: ["NORA"],
    ),
  );
  record(
    1,
    await createShot(
      sceneIndex: 1,
      shotSize: "Wide",
      framing: "The banknote under the saucer, the door swinging.",
      cameraMove: "Pan",
      screenSeconds: 16,
      characters: ["NORA", "OWNER"],
    ),
  );

  record(
    2,
    await createShot(
      sceneIndex: 2,
      shotSize: "Wide",
      framing: "The pier, the boat riding the swell, Martin at the far end.",
      cameraMove: "Crane down",
      screenSeconds: 22,
      characters: ["NORA", "MARTIN"],
      difficulty: 3,
    ),
  );
  record(
    2,
    await createShot(
      sceneIndex: 2,
      shotSize: "Medium",
      framing: "Martin coiling the rope, not looking up.",
      cameraMove: "Static",
      screenSeconds: 26,
      characters: ["MARTIN"],
      difficulty: 2,
    ),
  );
  record(
    2,
    await createShot(
      sceneIndex: 2,
      shotSize: "Close-up",
      framing: "The chart snapping in the wind, the pencil ring.",
      cameraMove: "Handheld",
      screenSeconds: 12,
      characters: ["NORA"],
      difficulty: 2,
    ),
  );
  record(
    2,
    await createShot(
      sceneIndex: 2,
      shotSize: "Two-shot",
      framing: "Nora and Martin, the wind between them.",
      cameraMove: "Static",
      screenSeconds: 28,
      characters: ["NORA", "MARTIN"],
    ),
  );

  record(
    3,
    await createShot(
      sceneIndex: 3,
      shotSize: "Wide",
      framing: "The boat digging into the swell, no horizon.",
      cameraMove: "Handheld",
      screenSeconds: 20,
      characters: ["NORA", "MARTIN"],
      difficulty: 3,
    ),
  );
  record(
    3,
    await createShot(
      sceneIndex: 3,
      shotSize: "Medium",
      framing: "Nora braced against the wheelhouse.",
      cameraMove: "Handheld",
      screenSeconds: 17,
      characters: ["NORA"],
      difficulty: 3,
    ),
  );
  record(
    3,
    await createShot(
      sceneIndex: 3,
      shotSize: "Close-up",
      framing: "The compass swinging, the course held.",
      cameraMove: "Static",
      screenSeconds: 13,
      characters: ["MARTIN"],
    ),
  );

  return shotsByScene;
}

/// Seeds the floor plans of the cafe, the pier and the fishing boat.
Future<void> seedFloorPlans({
  required String boatSetId,
  required String cafeSetId,
  required OcptProjectDatabase database,
  required OcptFloorPlanService floorPlanService,
  required String pierSetId,
  required List<String> sceneIds,
  required Map<int, List<String>> shotsByScene,
}) async {
  // -------------------------------------------------------------------------- the floor plans

  // The harbour cafe: a readable room — four thin walls (0.12 m) enclosing roughly 6 x 4 m,
  // a gap in the south one for a door, a counter, a table with two chairs, a camera and Nora —
  // all set-scope (shared by both scenes shot there: `cafeSetId` is linked to sceneIds[0] and
  // sceneIds[1] above) except the camera and Nora, which belong to the opening shot alone.
  const wallThicknessM = 0.12;

  Future<void> wall({
    required double xM,
    required double yM,
    required double widthM,
    required double heightM,
    required String label,
  }) => floorPlanService
      .placeSymbol(
        database: database,
        setId: cafeSetId,
        sceneId: null,
        shotId: null,
        layer: OcptFloorPlanLayer.set,
        xM: xM,
        yM: yM,
        widthM: widthM,
        heightM: heightM,
        label: label,
        setElementShape: OcptFloorPlanSetElementShape.wall,
      )
      .maybeValueOrFail;

  // `xM`/`yM` are a symbol's own centre (`Rect.fromCenter` in the canvas painter), not a
  // corner, so a wall's own centre sits on the room's own perimeter, half its thickness either
  // side of it.
  await wall(xM: 3, yM: 0, widthM: 6, heightM: wallThicknessM, label: "Cafe wall, north");
  await wall(xM: 0, yM: 2, widthM: wallThicknessM, heightM: 4, label: "Cafe wall, west");
  await wall(xM: 6, yM: 2, widthM: wallThicknessM, heightM: 4, label: "Cafe wall, east");
  // The south wall stops short twice, once on each side of the door below.
  await wall(xM: 1.9, yM: 4, widthM: 3.8, heightM: wallThicknessM, label: "Cafe wall, south-west");
  await wall(xM: 5.6, yM: 4, widthM: 0.8, heightM: wallThicknessM, label: "Cafe wall, south-east");
  await floorPlanService
      .placeSymbol(
        database: database,
        setId: cafeSetId,
        sceneId: null,
        shotId: null,
        layer: OcptFloorPlanLayer.set,
        xM: 4.5,
        yM: 4,
        widthM: 1.4,
        heightM: wallThicknessM,
        label: "Cafe door",
        setElementShape: OcptFloorPlanSetElementShape.door,
      )
      .maybeValueOrFail;

  final counterSymbolId = (await floorPlanService
      .placeSymbol(
        database: database,
        setId: cafeSetId,
        sceneId: null,
        shotId: null,
        layer: OcptFloorPlanLayer.set,
        xM: 2.25,
        yM: 0.5,
        widthM: 2.5,
        heightM: 0.5,
        label: "Counter",
        setElementShape: OcptFloorPlanSetElementShape.furniture,
      )
      .valueOrFail);

  // The second scene shot at the cafe re-dresses the counter for that sequence only — a
  // scene-scope override: it replaces the counter above while sceneIds[1] is being drawn, and
  // the original keeps showing for sceneIds[0].
  await floorPlanService
      .placeSymbol(
        database: database,
        setId: cafeSetId,
        sceneId: sceneIds[1],
        shotId: null,
        layer: OcptFloorPlanLayer.set,
        xM: 2.55,
        yM: 0.7,
        widthM: 2.5,
        heightM: 0.5,
        label: "Counter, cleared for the second visit",
        setElementShape: OcptFloorPlanSetElementShape.furniture,
        overridesSymbolId: counterSymbolId,
      )
      .maybeValueOrFail;

  // A table and two chairs, well clear of the counter and of the camera's own sightline below.
  await floorPlanService
      .placeSymbol(
        database: database,
        setId: cafeSetId,
        sceneId: null,
        shotId: null,
        layer: OcptFloorPlanLayer.set,
        xM: 4.6,
        yM: 2,
        widthM: 1,
        heightM: 1,
        label: "Table",
        setElementShape: OcptFloorPlanSetElementShape.furniture,
      )
      .maybeValueOrFail;
  await floorPlanService
      .placeSymbol(
        database: database,
        setId: cafeSetId,
        sceneId: null,
        shotId: null,
        layer: OcptFloorPlanLayer.set,
        xM: 4.1,
        yM: 1.3,
        widthM: 0.4,
        heightM: 0.4,
        label: "Chair",
        setElementShape: OcptFloorPlanSetElementShape.furniture,
      )
      .maybeValueOrFail;
  await floorPlanService
      .placeSymbol(
        database: database,
        setId: cafeSetId,
        sceneId: null,
        shotId: null,
        layer: OcptFloorPlanLayer.set,
        xM: 5.1,
        yM: 1.3,
        widthM: 0.4,
        heightM: 0.4,
        label: "Chair",
        setElementShape: OcptFloorPlanSetElementShape.furniture,
      )
      .maybeValueOrFail;

  // A camera on the cafe's own opening shot, inside the room and aimed north at Nora, its
  // field-of-view cone reaching well past her own position.
  await floorPlanService
      .placeSymbol(
        database: database,
        setId: cafeSetId,
        sceneId: null,
        shotId: shotsByScene[0]!.first,
        layer: OcptFloorPlanLayer.cameras,
        xM: 2.25,
        yM: 3.2,
        // rotationDeg defaults to 0, which already points local "up" (north) — straight at Nora.
        fovDeg: 50,
        fovReachM: 2.6,
      )
      .maybeValueOrFail;
  await floorPlanService
      .placeSymbol(
        database: database,
        setId: cafeSetId,
        sceneId: null,
        shotId: shotsByScene[0]!.first,
        layer: OcptFloorPlanLayer.characters,
        xM: 2.25,
        yM: 1,
        label: "NORA",
      )
      .maybeValueOrFail;

  // The pier: a railing and a camera on its own first shot.
  await floorPlanService
      .placeSymbol(
        database: database,
        setId: pierSetId,
        sceneId: null,
        shotId: null,
        layer: OcptFloorPlanLayer.set,
        xM: 0,
        yM: 0,
        widthM: 10,
        heightM: 2,
        label: "Pier railing",
        setElementShape: OcptFloorPlanSetElementShape.wall,
      )
      .maybeValueOrFail;
  await floorPlanService
      .placeSymbol(
        database: database,
        setId: pierSetId,
        sceneId: null,
        shotId: shotsByScene[2]!.first,
        layer: OcptFloorPlanLayer.cameras,
        xM: 2,
        yM: 4,
        rotationDeg: 180,
      )
      .maybeValueOrFail;

  // The fishing boat: the wheelhouse and a camera and a light on its own first shot.
  await floorPlanService
      .placeSymbol(
        database: database,
        setId: boatSetId,
        sceneId: null,
        shotId: null,
        layer: OcptFloorPlanLayer.set,
        xM: 0,
        yM: 0,
        widthM: 3,
        heightM: 2,
        label: "Wheelhouse",
        setElementShape: OcptFloorPlanSetElementShape.furniture,
      )
      .maybeValueOrFail;
  await floorPlanService
      .placeSymbol(
        database: database,
        setId: boatSetId,
        sceneId: null,
        shotId: shotsByScene[3]!.first,
        layer: OcptFloorPlanLayer.cameras,
        xM: -1,
        yM: 3,
      )
      .maybeValueOrFail;
  await floorPlanService
      .placeSymbol(
        database: database,
        setId: boatSetId,
        sceneId: null,
        shotId: shotsByScene[3]!.first,
        layer: OcptFloorPlanLayer.lights,
        xM: 1,
        yM: 3,
        label: "Key",
      )
      .maybeValueOrFail;
}

/// Seeds the storyboard of the cafe's opening shot.
Future<void> seedStoryboard({
  required OcptProjectDatabase database,
  required File file,
  required String path,
  required Map<int, List<String>> shotsByScene,
  required OcptStoryboardService storyboardService,
}) async {
  // ----------------------------------------------------------------------------- the storyboard

  // The cafe's own opening shot gets three panels — its own leader shot, tracked through the
  // scene — each with a placeholder frame image and a short comment, plus one movement arrow and
  // one label, so the board shows a shot's own strip, its leader card and its annotation layer at
  // once.
  final frameDir = "${file.parent.path}/storyboard-frames";
  final openingCafeShotId = shotsByScene[0]!.first;

  final wideFramePath = "$frameDir/cafe-wide.png";
  await writePlaceholderImage(
    path: wideFramePath,
    width: 1600,
    height: 900,
    topColor: 0x1C2436,
    bottomColor: 0x6C5CE7,
  );
  final widePanelId = (await storyboardService
      .addPanel(database: database, shotId: openingCafeShotId)
      .valueOrFail);
  await storyboardService
      .replacePanelImage(database: database, panelId: widePanelId, path: wideFramePath)
      .okOrFail;
  await storyboardService
      .updatePanelComment(
        database: database,
        panelId: widePanelId,
        comment: "Establishing — Nora alone at the counter, dawn light through the window.",
      )
      .okOrFail;
  await storyboardService
      .addAnnotation(
        database: database,
        panelId: widePanelId,
        kind: OcptStoryboardAnnotationKind.label,
        x1: 0.18,
        y1: 0.3,
        text: "NORA",
      )
      .maybeValueOrFail;

  final mediumFramePath = "$frameDir/cafe-medium.png";
  await writePlaceholderImage(
    path: mediumFramePath,
    width: 1600,
    height: 900,
    topColor: 0x232B1C,
    bottomColor: 0x6C5CE7,
  );
  final mediumPanelId = (await storyboardService
      .addPanel(database: database, shotId: openingCafeShotId)
      .valueOrFail);
  await storyboardService
      .replacePanelImage(database: database, panelId: mediumPanelId, path: mediumFramePath)
      .okOrFail;
  await storyboardService
      .updatePanelComment(
        database: database,
        panelId: mediumPanelId,
        comment: "Martin enters, shaking off the rain.",
      )
      .okOrFail;
  await storyboardService
      .addAnnotation(
        database: database,
        panelId: mediumPanelId,
        kind: OcptStoryboardAnnotationKind.movementArrow,
        x1: 0.85,
        y1: 0.55,
        x2: 0.4,
        y2: 0.6,
      )
      .maybeValueOrFail;

  final closeFramePath = "$frameDir/cafe-close.png";
  await writePlaceholderImage(
    path: closeFramePath,
    width: 1600,
    height: 900,
    topColor: 0x2C1C23,
    bottomColor: 0x6C5CE7,
  );
  final closePanelId = (await storyboardService
      .addPanel(database: database, shotId: openingCafeShotId)
      .valueOrFail);
  await storyboardService
      .replacePanelImage(database: database, panelId: closePanelId, path: closeFramePath)
      .okOrFail;
  await storyboardService
      .updatePanelComment(
        database: database,
        panelId: closePanelId,
        comment: "Nora's hands around the mug.",
      )
      .okOrFail;
}
