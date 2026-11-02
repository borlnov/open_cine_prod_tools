// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_override_level.dart';
import 'ocpt_floor_plan_sheet_test_doubles.dart';

/// Run the tests of the floor plan sheet scopes and overrides.
void main() {
  group("OcptFloorPlanSheet.of — sequence scope", () {
    test("always includes sequence-scoped symbols, never ghosted", () {
      final shootingSet = testSymbol(id: "decor-1", layer: OcptFloorPlanLayer.set);
      final floorPlanSet = caseOf(symbols: [shootingSet]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: "scene-1",
        focusShotId: "shot-1",
        shotRankByShotId: const {},
      );

      expect(sheet.symbols, hasLength(1));
      expect(sheet.symbols.single.symbolId, "decor-1");
      expect(sheet.symbols.single.isGhost, isFalse);
    });

    test("includes a scene-scope symbol of the focused scene", () {
      final prop = testSymbol(id: "prop-1", sceneId: "scene-1", layer: OcptFloorPlanLayer.props);
      final floorPlanSet = caseOf(symbols: [prop]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: "scene-1",
        focusShotId: null,
        shotRankByShotId: const {},
      );

      expect(sheet.symbols.map((shape) => shape.symbolId), ["prop-1"]);
    });

    test("leaves out a scene-scope symbol of a different scene", () {
      final prop = testSymbol(id: "prop-1", sceneId: "scene-2", layer: OcptFloorPlanLayer.props);
      final floorPlanSet = caseOf(symbols: [prop]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: "scene-1",
        focusShotId: null,
        shotRankByShotId: const {},
      );

      expect(sheet.symbols, isEmpty);
    });
  });

  group("OcptFloorPlanSheet.of — the override rule", () {
    test(
      "a live scene-scope override replaces the set-scope symbol it names, in its own scene",
      () {
        final original = testSymbol(id: "orig-1", layer: OcptFloorPlanLayer.set, label: "Original");
        final override = testSymbol(
          id: "override-1",
          sceneId: "scene-1",
          layer: OcptFloorPlanLayer.set,
          label: "Re-dressed",
          overridesSymbolId: "orig-1",
        );
        final floorPlanSet = caseOf(symbols: [original, override]);

        final sheet = OcptFloorPlanSheet.of(
          floorPlanSet: floorPlanSet,
          focusSceneId: "scene-1",
          focusShotId: null,
          shotRankByShotId: const {},
        );

        // The visible override draws in place of the original, plus the original's own faint,
        // non-interactive ghost.
        expect(sheet.symbols, hasLength(2));
        final overrideShape = sheet.symbols.singleWhere(
          (symbol) => symbol.symbolId == "override-1",
        );
        expect(overrideShape.label, "Re-dressed");
        expect(overrideShape.isOverride, isTrue);
        expect(overrideShape.isOverriddenOriginalGhost, isFalse);
        final ghostShape = sheet.symbols.singleWhere((symbol) => symbol.symbolId == "orig-1");
        expect(ghostShape.label, "Original");
        expect(ghostShape.isOverriddenOriginalGhost, isTrue);
        expect(ghostShape.isOverride, isFalse);
      },
    );

    test("the original still shows in every other scene", () {
      final original = testSymbol(id: "orig-1", layer: OcptFloorPlanLayer.set, label: "Original");
      final override = testSymbol(
        id: "override-1",
        sceneId: "scene-1",
        layer: OcptFloorPlanLayer.set,
        label: "Re-dressed",
        overridesSymbolId: "orig-1",
      );
      final floorPlanSet = caseOf(symbols: [original, override]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: "scene-2",
        focusShotId: null,
        shotRankByShotId: const {},
      );

      expect(sheet.symbols, hasLength(1));
      expect(sheet.symbols.single.symbolId, "orig-1");
      expect(sheet.symbols.single.label, "Original");
    });

    test("editing the original still shows in the overriding scene's own sheet too", () {
      // Editing the original writes the very same row `testSymbol` here stands in for — this sheet
      // only ever reads what the store hands it, so a moved original is simply a different
      // `xM`/`yM` on the same row, still excluded from scene-1's own sheet by the override.
      final movedOriginal = testSymbol(id: "orig-1", layer: OcptFloorPlanLayer.set, xM: 9, yM: 9);
      final override = testSymbol(
        id: "override-1",
        sceneId: "scene-1",
        layer: OcptFloorPlanLayer.set,
        overridesSymbolId: "orig-1",
      );
      final floorPlanSet = caseOf(symbols: [movedOriginal, override]);

      final sceneOneSheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: "scene-1",
        focusShotId: null,
        shotRankByShotId: const {},
      );
      final sceneTwoSheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: "scene-2",
        focusShotId: null,
        shotRankByShotId: const {},
      );

      final sceneOneOverride = sceneOneSheet.symbols.singleWhere(
        (symbol) => symbol.symbolId == "override-1",
      );
      expect(sceneOneOverride.isOverride, isTrue);
      expect(sceneTwoSheet.symbols, hasLength(1));
      expect(sceneTwoSheet.symbols.single.symbolId, "orig-1");
      expect(sceneTwoSheet.symbols.single.xM, 9);
    });

    test("a tombstoned override is simply absent, so the original reappears in that scene", () {
      // A tombstoned row is filtered out well before `OcptFloorPlanSheet.of` ever sees it
      // (`OcptFloorPlanService.loadFloorPlans` only reads live rows) — so "the override is
      // removed" is simply "the symbol list no longer carries it".
      final original = testSymbol(id: "orig-1", layer: OcptFloorPlanLayer.set, label: "Original");
      final floorPlanSet = caseOf(symbols: [original]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: "scene-1",
        focusShotId: null,
        shotRankByShotId: const {},
      );

      expect(sheet.symbols, hasLength(1));
      expect(sheet.symbols.single.symbolId, "orig-1");
    });

    test("a hidden override draws no override shape of its own, only the original's own faint, "
        "selectable ghost, naming the override", () {
      final original = testSymbol(id: "orig-1", layer: OcptFloorPlanLayer.set, label: "Original");
      final hiddenOverride = testSymbol(
        id: "override-1",
        sceneId: "scene-1",
        layer: OcptFloorPlanLayer.set,
        overridesSymbolId: "orig-1",
        isHidden: true,
      );
      final floorPlanSet = caseOf(symbols: [original, hiddenOverride]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: "scene-1",
        focusShotId: null,
        shotRankByShotId: const {},
      );

      expect(sheet.symbols, hasLength(1));
      final ghost = sheet.symbols.single;
      // Drawn at the original's own geometry/label, but naming the override — selecting it is
      // how the inspector reaches `Restore`.
      expect(ghost.symbolId, "override-1");
      expect(ghost.label, "Original");
      expect(ghost.isHiddenOverrideGhost, isTrue);
      expect(ghost.isOverride, isFalse);
      expect(ghost.isOverriddenOriginalGhost, isFalse);
    });

    test("the original still shows, unhidden, in every other scene", () {
      final original = testSymbol(id: "orig-1", layer: OcptFloorPlanLayer.set, label: "Original");
      final hiddenOverride = testSymbol(
        id: "override-1",
        sceneId: "scene-1",
        layer: OcptFloorPlanLayer.set,
        overridesSymbolId: "orig-1",
        isHidden: true,
      );
      final floorPlanSet = caseOf(symbols: [original, hiddenOverride]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: "scene-2",
        focusShotId: null,
        shotRankByShotId: const {},
      );

      expect(sheet.symbols, hasLength(1));
      expect(sheet.symbols.single.symbolId, "orig-1");
      expect(sheet.symbols.single.isHiddenOverrideGhost, isFalse);
    });
  });

  group("OcptFloorPlanSheet.of — the shot override rule", () {
    test("a live shot-scope override replaces the scene-effective symbol it names, under that "
        "shot's focus", () {
      final prop = testSymbol(
        id: "prop-1",
        sceneId: "scene-1",
        layer: OcptFloorPlanLayer.props,
        label: "Candle",
      );
      final override = testSymbol(
        id: "override-1",
        shotId: "shot-1",
        layer: OcptFloorPlanLayer.props,
        label: "Broken candle",
        overridesSymbolId: "prop-1",
      );
      final floorPlanSet = caseOf(symbols: [prop, override]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: "scene-1",
        focusShotId: "shot-1",
        shotRankByShotId: const {},
      );

      expect(sheet.symbols, hasLength(2));
      final overrideShape = sheet.symbols.singleWhere((symbol) => symbol.symbolId == "override-1");
      expect(overrideShape.label, "Broken candle");
      expect(overrideShape.isOverride, isTrue);
      expect(overrideShape.overrideLevel, OcptFloorPlanOverrideLevel.shot);
      final ghostShape = sheet.symbols.singleWhere((symbol) => symbol.symbolId == "prop-1");
      expect(ghostShape.label, "Candle");
      expect(ghostShape.isOverriddenOriginalGhost, isTrue);
      expect(ghostShape.overrideLevel, OcptFloorPlanOverrideLevel.shot);
    });

    test("the scene-effective symbol still shows, unreplaced, under another shot's own focus", () {
      final prop = testSymbol(
        id: "prop-1",
        sceneId: "scene-1",
        layer: OcptFloorPlanLayer.props,
        label: "Candle",
      );
      final override = testSymbol(
        id: "override-1",
        shotId: "shot-1",
        layer: OcptFloorPlanLayer.props,
        label: "Broken candle",
        overridesSymbolId: "prop-1",
      );
      final floorPlanSet = caseOf(symbols: [prop, override]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: "scene-1",
        focusShotId: "shot-2",
        shotRankByShotId: const {},
      );

      expect(sheet.symbols, hasLength(1));
      expect(sheet.symbols.single.symbolId, "prop-1");
      expect(sheet.symbols.single.label, "Candle");
      expect(sheet.symbols.single.isOverride, isFalse);
    });

    test("a hidden shot override draws no shape of its own, only the scene symbol's own faint, "
        "selectable ghost, naming the override", () {
      final prop = testSymbol(
        id: "prop-1",
        sceneId: "scene-1",
        layer: OcptFloorPlanLayer.props,
        label: "Candle",
      );
      final hiddenOverride = testSymbol(
        id: "override-1",
        shotId: "shot-1",
        layer: OcptFloorPlanLayer.props,
        overridesSymbolId: "prop-1",
        isHidden: true,
      );
      final floorPlanSet = caseOf(symbols: [prop, hiddenOverride]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: "scene-1",
        focusShotId: "shot-1",
        shotRankByShotId: const {},
      );

      expect(sheet.symbols, hasLength(1));
      final ghost = sheet.symbols.single;
      expect(ghost.symbolId, "override-1");
      expect(ghost.label, "Candle");
      expect(ghost.isHiddenOverrideGhost, isTrue);
      expect(ghost.overrideLevel, OcptFloorPlanOverrideLevel.shot);
      expect(ghost.isOverride, isFalse);
    });

    test("a shot override may replace a symbol that is itself a sequence-level override, "
        "ghosting the sequence override's own geometry, not the set-scope original's", () {
      final setOriginal = testSymbol(
        id: "orig-1",
        layer: OcptFloorPlanLayer.set,
        label: "Original",
      );
      final sequenceOverride = testSymbol(
        id: "seq-override-1",
        sceneId: "scene-1",
        layer: OcptFloorPlanLayer.set,
        xM: 5,
        yM: 5,
        label: "Re-dressed",
        overridesSymbolId: "orig-1",
      );
      final shotOverride = testSymbol(
        id: "shot-override-1",
        shotId: "shot-1",
        layer: OcptFloorPlanLayer.set,
        xM: 9,
        yM: 9,
        label: "Moved for this shot",
        overridesSymbolId: "seq-override-1",
      );
      final floorPlanSet = caseOf(symbols: [setOriginal, sequenceOverride, shotOverride]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: "scene-1",
        focusShotId: "shot-1",
        shotRankByShotId: const {},
      );

      // The set-scope original's own ghost (sequence-level) plus the shot-level override and
      // its own ghost (at the sequence override's geometry) — the sequence override itself is
      // no longer drawn live, replaced one level further down.
      expect(sheet.symbols, hasLength(3));
      final shotOverrideShape = sheet.symbols.singleWhere(
        (symbol) => symbol.symbolId == "shot-override-1",
      );
      expect(shotOverrideShape.isOverride, isTrue);
      expect(shotOverrideShape.overrideLevel, OcptFloorPlanOverrideLevel.shot);
      final sequenceGhost = sheet.symbols.singleWhere(
        (symbol) => symbol.symbolId == "seq-override-1",
      );
      expect(sequenceGhost.isOverriddenOriginalGhost, isTrue);
      expect(sequenceGhost.overrideLevel, OcptFloorPlanOverrideLevel.shot);
      expect(sequenceGhost.xM, 5);
      expect(sequenceGhost.yM, 5);
      final setGhost = sheet.symbols.singleWhere((symbol) => symbol.symbolId == "orig-1");
      expect(setGhost.isOverriddenOriginalGhost, isTrue);
      expect(setGhost.overrideLevel, OcptFloorPlanOverrideLevel.sequence);
    });

    test(
      "a ghosted neighbour's own shot-scope override draws as its own placement, unresolved",
      () {
        final prop = testSymbol(
          id: "prop-1",
          sceneId: "scene-1",
          layer: OcptFloorPlanLayer.props,
          label: "Candle",
        );
        final neighbourOverride = testSymbol(
          id: "override-1",
          shotId: "shot-0",
          layer: OcptFloorPlanLayer.props,
          label: "Broken candle",
          overridesSymbolId: "prop-1",
        );
        final floorPlanSet = caseOf(symbols: [prop, neighbourOverride]);

        final sheet = OcptFloorPlanSheet.of(
          floorPlanSet: floorPlanSet,
          focusSceneId: "scene-1",
          focusShotId: "shot-1",
          previousShotId: "shot-0",
          shotRankByShotId: const {},
        );

        expect(sheet.symbols, hasLength(2));
        final ghostedOverride = sheet.symbols.singleWhere(
          (symbol) => symbol.symbolId == "override-1",
        );
        expect(ghostedOverride.isGhost, isTrue);
        expect(ghostedOverride.isOverride, isFalse);
        final scenePropShape = sheet.symbols.singleWhere((symbol) => symbol.symbolId == "prop-1");
        expect(scenePropShape.isGhost, isFalse);
        expect(scenePropShape.isOverride, isFalse);
      },
    );
  });

  group("OcptFloorPlanSheet.of — sequence focus (focusShotId null)", () {
    test("shows every live camera of every shot, numbered, and nothing else of the shot scope", () {
      final camera1 = testSymbol(id: "cam-1", shotId: "shot-1", layer: OcptFloorPlanLayer.cameras);
      final character1 = testSymbol(
        id: "char-1",
        shotId: "shot-1",
        layer: OcptFloorPlanLayer.characters,
      );
      final camera2 = testSymbol(id: "cam-2", shotId: "shot-2", layer: OcptFloorPlanLayer.cameras);
      final floorPlanSet = caseOf(symbols: [camera1, character1, camera2]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: "scene-1",
        focusShotId: null,
        shotRankByShotId: const {"shot-1": 1, "shot-2": 2},
      );

      final symbolIds = sheet.symbols.map((shape) => shape.symbolId).toSet();
      expect(symbolIds, {"cam-1", "cam-2"});
      expect(sheet.arrows, isEmpty);
    });

    test("a shot's single camera carries no letter", () {
      final camera = testSymbol(id: "cam-1", shotId: "shot-1", layer: OcptFloorPlanLayer.cameras);
      final floorPlanSet = caseOf(symbols: [camera]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: "scene-1",
        focusShotId: null,
        shotRankByShotId: const {"shot-1": 3},
      );

      expect(sheet.symbols.single.cameraLabel, "3");
    });

    test("two or more cameras of one shot are lettered from the first", () {
      final camera1 = testSymbol(id: "cam-1", shotId: "shot-1", layer: OcptFloorPlanLayer.cameras);
      final camera2 = testSymbol(
        id: "cam-2",
        shotId: "shot-1",
        layer: OcptFloorPlanLayer.cameras,
        sortKey: "b",
      );
      final floorPlanSet = caseOf(symbols: [camera1, camera2]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: "scene-1",
        focusShotId: null,
        shotRankByShotId: const {"shot-1": 3},
      );

      final labelBySymbolId = {
        for (final shape in sheet.symbols) shape.symbolId: shape.cameraLabel,
      };
      expect(labelBySymbolId["cam-1"], "3A");
      expect(labelBySymbolId["cam-2"], "3B");
    });

    test("a camera whose shot has no known rank draws with no camera label", () {
      final camera = testSymbol(id: "cam-1", shotId: "shot-1", layer: OcptFloorPlanLayer.cameras);
      final floorPlanSet = caseOf(symbols: [camera]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: "scene-1",
        focusShotId: null,
        shotRankByShotId: const {},
      );

      expect(sheet.symbols.single.cameraLabel, isNull);
    });
  });

  group("OcptFloorPlanSheet.of — shot focus", () {
    test("shows the focused shot's own shot layers, not another shot's", () {
      final ownCamera = testSymbol(
        id: "cam-own",
        shotId: "shot-1",
        layer: OcptFloorPlanLayer.cameras,
      );
      final otherCamera = testSymbol(
        id: "cam-other",
        shotId: "shot-2",
        layer: OcptFloorPlanLayer.cameras,
      );
      final floorPlanSet = caseOf(symbols: [ownCamera, otherCamera]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: "scene-1",
        focusShotId: "shot-1",
        shotRankByShotId: const {"shot-1": 1},
      );

      final symbolIds = sheet.symbols.map((shape) => shape.symbolId).toSet();
      expect(symbolIds, {"cam-own"});
    });

    test("draws the previous and next shot's placements as ghosts, and no one else's", () {
      final focusCamera = testSymbol(
        id: "cam-focus",
        shotId: "shot-2",
        layer: OcptFloorPlanLayer.cameras,
      );
      final previousCamera = testSymbol(
        id: "cam-prev",
        shotId: "shot-1",
        layer: OcptFloorPlanLayer.cameras,
      );
      final nextCamera = testSymbol(
        id: "cam-next",
        shotId: "shot-3",
        layer: OcptFloorPlanLayer.cameras,
      );
      final farCamera = testSymbol(
        id: "cam-far",
        shotId: "shot-9",
        layer: OcptFloorPlanLayer.cameras,
      );
      final floorPlanSet = caseOf(symbols: [focusCamera, previousCamera, nextCamera, farCamera]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: "scene-1",
        focusShotId: "shot-2",
        shotRankByShotId: const {"shot-1": 1, "shot-2": 2, "shot-3": 3},
        previousShotId: "shot-1",
        nextShotId: "shot-3",
      );

      final ghostBySymbolId = {for (final shape in sheet.symbols) shape.symbolId: shape.isGhost};
      expect(ghostBySymbolId, {"cam-focus": false, "cam-prev": true, "cam-next": true});
    });

    test("draws an arrow of the focus shot with both endpoints resolved to symbol positions", () {
      final camera = testSymbol(
        id: "cam-1",
        shotId: "shot-1",
        layer: OcptFloorPlanLayer.cameras,
        xM: 1,
        yM: 2,
      );
      final character = testSymbol(
        id: "char-1",
        shotId: "shot-1",
        layer: OcptFloorPlanLayer.characters,
        xM: 4,
        yM: 6,
      );
      final arrow = testArrow(
        id: "arrow-1",
        shotId: "shot-1",
        fromSymbolId: "char-1",
        toSymbolId: "cam-1",
      );
      final floorPlanSet = caseOf(symbols: [camera, character], arrows: [arrow]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: "scene-1",
        focusShotId: "shot-1",
        shotRankByShotId: const {"shot-1": 1},
      );

      expect(sheet.arrows, hasLength(1));
      final shape = sheet.arrows.single;
      expect(shape.arrowId, "arrow-1");
      expect(shape.fromXM, 4);
      expect(shape.fromYM, 6);
      expect(shape.toXM, 1);
      expect(shape.toYM, 2);
      expect(shape.isGhost, isFalse);
    });

    test("flags a ghosted neighbour's own arrow as a ghost too", () {
      final previousCamera = testSymbol(
        id: "cam-prev",
        shotId: "shot-1",
        layer: OcptFloorPlanLayer.cameras,
      );
      final previousCharacter = testSymbol(
        id: "char-prev",
        shotId: "shot-1",
        layer: OcptFloorPlanLayer.characters,
      );
      final previousArrow = testArrow(
        id: "arrow-prev",
        shotId: "shot-1",
        fromSymbolId: "char-prev",
        toSymbolId: "cam-prev",
      );
      final floorPlanSet = caseOf(
        symbols: [previousCamera, previousCharacter],
        arrows: [previousArrow],
      );

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: "scene-1",
        focusShotId: "shot-2",
        shotRankByShotId: const {"shot-1": 1, "shot-2": 2},
        previousShotId: "shot-1",
      );

      expect(sheet.arrows.single.isGhost, isTrue);
    });

    test("an arrow of a shot outside the focus and its ghosts is not drawn at all", () {
      final farCameraA = testSymbol(
        id: "cam-a",
        shotId: "shot-9",
        layer: OcptFloorPlanLayer.cameras,
      );
      final farCameraB = testSymbol(
        id: "cam-b",
        shotId: "shot-9",
        layer: OcptFloorPlanLayer.cameras,
      );
      final farArrow = testArrow(
        id: "arrow-far",
        shotId: "shot-9",
        fromSymbolId: "cam-a",
        toSymbolId: "cam-b",
      );
      final floorPlanSet = caseOf(symbols: [farCameraA, farCameraB], arrows: [farArrow]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: "scene-1",
        focusShotId: "shot-1",
        shotRankByShotId: const {"shot-1": 1},
      );

      expect(sheet.arrows, isEmpty);
    });
  });

  group("OcptFloorPlanSheet.of — underlay", () {
    test("draws no underlay while the set's frame is incomplete", () {
      final floorPlanSet = caseOf(underlayAssetId: "asset-1");

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: "scene-1",
        focusShotId: null,
        shotRankByShotId: const {},
      );

      expect(sheet.underlay, isNull);
    });

    test("draws the underlay once its frame is fully placed", () {
      final floorPlanSet = caseOf(
        underlayAssetId: "asset-1",
        underlayXM: 1,
        underlayYM: 2,
        underlayWidthM: 3,
        underlayHeightM: 4,
      );

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: "scene-1",
        focusShotId: null,
        shotRankByShotId: const {},
      );

      expect(sheet.underlay, isNotNull);
      expect(sheet.underlay!.assetId, "asset-1");
      expect(sheet.underlay!.path, "/tmp/underlay.jpg");
      expect(sheet.underlay!.widthM, 3);
      expect(sheet.underlay!.heightM, 4);
    });
  });
}
