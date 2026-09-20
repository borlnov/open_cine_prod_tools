// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_set.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_arrow_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'package:open_cine_prod_tools/utils/ocpt_floor_plan_camera_label.dart';
import 'package:open_cine_prod_tools/utils/ocpt_floor_plan_character_colour.dart';
import 'package:open_cine_prod_tools/utils/ocpt_floor_plan_geometry.dart';

/// The ARGB colour (`0xAARRGGBB`) a symbol of [layer] is drawn with — the one palette the canvas,
/// the metrics overlay and the floor-plans PDF all read, so a colour is never picked twice.
int ocptFloorPlanLayerColorArgb(OcptFloorPlanLayer layer) => switch (layer) {
  OcptFloorPlanLayer.set => 0xFF6B7280,
  OcptFloorPlanLayer.cameras => 0xFF2196F3,
  OcptFloorPlanLayer.characters => 0xFFFF9800,
  OcptFloorPlanLayer.lights => 0xFFFBC02D,
  OcptFloorPlanLayer.props => 0xFF9C27B0,
};

/// The ARGB colour a movement arrow is drawn with.
const int ocptFloorPlanMovementArrowColorArgb = 0xFF37474F;

/// The ARGB colour a camera-move arrow is drawn with.
const int ocptFloorPlanCameraMoveArrowColorArgb = 0xFF1565C0;

/// Which glyph a symbol shape draws as, derived from its own [OcptFloorPlanSymbolShape.layer] —
/// the one switch [OcptFloorPlanSheet] resolves so neither renderer has to re-derive it from the
/// layer itself: [OcptFloorPlanLayer.characters] → [character], [OcptFloorPlanLayer.cameras] →
/// [camera], [OcptFloorPlanLayer.lights] → [light], and [OcptFloorPlanLayer.set]/`.props` →
/// [setElement].
enum OcptFloorPlanSymbolGlyphKind {
  /// A character's own facing disc, drawn in [OcptFloorPlanSymbolShape.colorArgb] — the colour
  /// [ocptFloorPlanCharacterColourOf] derives from the symbol's own [OcptFloorPlanSymbolShape.label].
  character,

  /// A camera's own body, lens and, while [OcptFloorPlanSymbolShape.cameraFovWedgeDeg] is set, its
  /// field-of-view wedge.
  camera,

  /// A light/projector's own body and beam.
  light,

  /// A décor primitive — see [OcptFloorPlanSymbolShape.setElementShape] and
  /// [OcptFloorPlanSetElementShape].
  setElement,
}

/// One symbol shape a floor plan sheet draws: a frozen, ready-to-paint copy of a
/// `floor_plan_symbols` row, carrying the colour it draws with and, for a camera, the label
/// [ocptFloorPlanCameraLabelOf] derives.
class OcptFloorPlanSymbolShape extends Equatable {
  /// The id of the `floor_plan_symbols` row this shape was built from.
  final String symbolId;

  /// The shot this symbol belongs to, or null on a sequence layer.
  final String? shotId;

  /// Which layer this symbol is drawn on.
  final OcptFloorPlanLayer layer;

  /// The symbol's centre X, in metres.
  final double xM;

  /// The symbol's centre Y, in metres.
  final double yM;

  /// The symbol's rotation, in degrees.
  final double rotationDeg;

  /// The symbol's footprint width, in metres — its own `widthM`, or the layer's default footprint
  /// when it has none of its own.
  final double widthM;

  /// The symbol's footprint height, in metres. See [widthM].
  final double heightM;

  /// A camera's field-of-view wedge, in degrees, or null for every other layer (or a camera left at
  /// the drawing default). The symbol's own raw stored value — see [cameraFovWedgeDeg] for the
  /// resolved angle a painter actually draws the wedge at.
  final double? fovDeg;

  /// The symbol's own free-text label.
  final String label;

  /// The colour this shape draws with: [ocptFloorPlanLayerColorArgb] for every layer but
  /// [OcptFloorPlanLayer.characters], whose own colour [ocptFloorPlanCharacterColourOf] derives
  /// from [label] instead — the one colour both renderers read rather than re-deriving.
  final int colorArgb;

  /// A camera symbol's derived letter/number label (`3`, `3A`, `3B`), or null for every other
  /// layer, or for a camera whose shot has no known rank yet.
  final String? cameraLabel;

  /// Whether this shape belongs to the previous or next shot under a shot focus — drawn as an onion
  /// skin the renderer draws at reduced opacity, never as a claim about the current shot.
  final bool isGhost;

  /// Which glyph this shape draws as — see [OcptFloorPlanSymbolGlyphKind].
  final OcptFloorPlanSymbolGlyphKind glyphKind;

  /// A camera symbol's own field-of-view wedge angle, in degrees, already resolved to
  /// [ocptFloorPlanDefaultCameraFovDeg] when the symbol carries no [fovDeg] of its own — null
  /// whenever no wedge should be drawn at all: every non-camera symbol, and a camera symbol while
  /// the sheet was built with `showFieldOfView: false` (`OcptFloorPlanSheet.of`'s own parameter). A
  /// painter draws the wedge exactly when this is non-null, with no default of its own to apply.
  final double? cameraFovWedgeDeg;

  /// A set-element symbol's own drawn primitive, resolved to [OcptFloorPlanSetElementShape.freeform]
  /// when the symbol carries none of its own — null for every symbol whose [glyphKind] isn't
  /// [OcptFloorPlanSymbolGlyphKind.setElement].
  final OcptFloorPlanSetElementShape? setElementShape;

  /// Class constructor
  const OcptFloorPlanSymbolShape({
    required this.symbolId,
    required this.shotId,
    required this.layer,
    required this.xM,
    required this.yM,
    required this.rotationDeg,
    required this.widthM,
    required this.heightM,
    required this.fovDeg,
    required this.label,
    required this.colorArgb,
    required this.cameraLabel,
    required this.isGhost,
    required this.glyphKind,
    required this.cameraFovWedgeDeg,
    required this.setElementShape,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptFloorPlanSymbolShape(symbolId: $symbolId, layer: $layer, isGhost: $isGhost)";

  /// Object properties
  @override
  List<Object?> get props => [
    symbolId,
    shotId,
    layer,
    xM,
    yM,
    rotationDeg,
    widthM,
    heightM,
    fovDeg,
    label,
    colorArgb,
    cameraLabel,
    isGhost,
    glyphKind,
    cameraFovWedgeDeg,
    setElementShape,
  ];
}

/// One arrow shape a floor plan sheet draws: a `floor_plan_arrows` row resolved down to the metre
/// coordinates of the two symbols it connects.
class OcptFloorPlanArrowShape extends Equatable {
  /// The id of the `floor_plan_arrows` row this shape was built from.
  final String arrowId;

  /// The shot this movement belongs to.
  final String shotId;

  /// Whether this is a movement or a camera-move arrow.
  final OcptFloorPlanArrowKind kind;

  /// The starting symbol's centre X, in metres.
  final double fromXM;

  /// The starting symbol's centre Y, in metres.
  final double fromYM;

  /// The ending symbol's centre X, in metres.
  final double toXM;

  /// The ending symbol's centre Y, in metres.
  final double toYM;

  /// The arrow's own free-text label.
  final String label;

  /// The colour this shape draws with.
  final int colorArgb;

  /// Whether this shape belongs to the previous or next shot under a shot focus. See
  /// [OcptFloorPlanSymbolShape.isGhost].
  final bool isGhost;

  /// A curved arrow's bezier control point X, in metres — null meaning a straight arrow. See
  /// `OcptFloorPlanArrow.ctrlXM`'s own doc comment; a painter draws a quadratic bezier through
  /// `(ctrlXM, ctrlYM)` when set, a straight line from `(fromXM, fromYM)` to `(toXM, toYM)`
  /// otherwise.
  final double? ctrlXM;

  /// A curved arrow's bezier control point Y, in metres. See [ctrlXM].
  final double? ctrlYM;

  /// Class constructor
  const OcptFloorPlanArrowShape({
    required this.arrowId,
    required this.shotId,
    required this.kind,
    required this.fromXM,
    required this.fromYM,
    required this.toXM,
    required this.toYM,
    required this.label,
    required this.colorArgb,
    required this.isGhost,
    required this.ctrlXM,
    required this.ctrlYM,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptFloorPlanArrowShape(arrowId: $arrowId, kind: $kind, isGhost: $isGhost)";

  /// Object properties
  @override
  List<Object?> get props => [
    arrowId,
    shotId,
    kind,
    fromXM,
    fromYM,
    toXM,
    toYM,
    label,
    colorArgb,
    isGhost,
    ctrlXM,
    ctrlYM,
  ];
}

/// The underlay shape a floor plan sheet draws, or null while the case has none placed.
class OcptFloorPlanUnderlayShape extends Equatable {
  /// The underlay's `assets` row id.
  final String assetId;

  /// The underlay's resolved absolute path, or null — a normal state, drawn as a placeholder.
  final String? path;

  /// The underlay's centre X, in metres.
  final double xM;

  /// The underlay's centre Y, in metres.
  final double yM;

  /// The underlay's width, in metres.
  final double widthM;

  /// The underlay's height, in metres.
  final double heightM;

  /// The underlay's rotation, in degrees.
  final double rotationDeg;

  /// Class constructor
  const OcptFloorPlanUnderlayShape({
    required this.assetId,
    required this.path,
    required this.xM,
    required this.yM,
    required this.widthM,
    required this.heightM,
    required this.rotationDeg,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptFloorPlanUnderlayShape(assetId: $assetId)";

  /// Object properties
  @override
  List<Object?> get props => [assetId, path, xM, yM, widthM, heightM, rotationDeg];
}

/// Everything a floor plan case draws, for one focus — the **drawing as data** the canvas, the
/// metrics overlay and the floor-plans PDF all paint from and nothing else, the sibling of
/// `OcptScenarioCoverageLayout`.
///
/// Pure Dart, no Flutter import and no `pdf` import (`docs/plans/storyboard.md`, §2;
/// `docs/adr/0031-storyboard-panels-and-floor-plans-in-metres.md`): every shape is already in
/// metres and every colour is already an ARGB int, so a renderer has nothing left to decide beyond
/// where the viewport puts them.
class OcptFloorPlanSheet extends Equatable {
  /// The case this sheet was built from.
  final String setId;

  /// The case's own name, for a page header or a canvas title.
  final String setName;

  /// The case's underlay, or null while none is placed.
  final OcptFloorPlanUnderlayShape? underlay;

  /// Every symbol this sheet draws, in draw order — sequence layers first (never ghosted), then
  /// shot layers of the focused shot, then any ghosted neighbour's.
  final List<OcptFloorPlanSymbolShape> symbols;

  /// Every arrow this sheet draws, in draw order.
  final List<OcptFloorPlanArrowShape> arrows;

  /// Class constructor
  const OcptFloorPlanSheet({
    required this.setId,
    required this.setName,
    required this.underlay,
    required this.symbols,
    required this.arrows,
  });

  /// Builds the sheet [floorPlanSet] draws under one focus.
  ///
  /// [focusShotId] is null for the **sequence** focus (every sequence layer, plus every live
  /// camera of every shot on this case, numbered — `docs/plans/storyboard.md`, §4.3) or a shot's id
  /// for the **shot** focus (every sequence layer, plus that shot's own shot layers, plus, when
  /// given, [previousShotId]'s and [nextShotId]'s shot layers drawn as ghosts — the onion skin).
  /// No arrow is drawn under the sequence focus: an arrow is always a shot's own movement, and the
  /// sequence focus shows no single shot's blocking.
  ///
  /// [shotRankByShotId] is every shot of the sequence's own 1-based display rank
  /// (`OcptShot.position` + 1, `docs/plans/storyboard.md`'s "the number is the shot's rank in the
  /// sequence"), read by [ocptFloorPlanCameraLabelOf]; a shot missing from it draws its cameras
  /// with no [OcptFloorPlanSymbolShape.cameraLabel] rather than throwing, since a floor plan can be
  /// built before every shot of a freshly reconciled sequence has been assigned one.
  ///
  /// [showFieldOfView] gates every camera's own [OcptFloorPlanSymbolShape.cameraFovWedgeDeg]:
  /// defaults to `true` (the wedge shows by default) so a caller that never touches the flag — every
  /// existing one, ahead of the tray toggle a later piece of work adds — still gets it.
  factory OcptFloorPlanSheet.of({
    required OcptFloorPlanSet floorPlanSet,
    required String? focusShotId,
    required Map<String, int> shotRankByShotId,
    String? previousShotId,
    String? nextShotId,
    bool showFieldOfView = true,
  }) {
    final sequenceSymbols = [
      for (final symbol in floorPlanSet.symbols) if (symbol.shotId == null) symbol,
    ];

    final symbolShapes = <OcptFloorPlanSymbolShape>[
      ..._shapesOf(
        sequenceSymbols,
        shotRankByShotId: shotRankByShotId,
        isGhost: false,
        showFieldOfView: showFieldOfView,
      ),
    ];

    if (focusShotId == null) {
      final cameraSymbols = [
        for (final symbol in floorPlanSet.symbols)
          if (symbol.shotId != null && symbol.layer == OcptFloorPlanLayer.cameras) symbol,
      ];
      symbolShapes.addAll(
        _shapesOf(
          cameraSymbols,
          shotRankByShotId: shotRankByShotId,
          isGhost: false,
          showFieldOfView: showFieldOfView,
        ),
      );

      return OcptFloorPlanSheet(
        setId: floorPlanSet.id,
        setName: floorPlanSet.name,
        underlay: _underlayOf(floorPlanSet),
        symbols: symbolShapes,
        arrows: const [],
      );
    }

    final focusSymbols = [
      for (final symbol in floorPlanSet.symbols) if (symbol.shotId == focusShotId) symbol,
    ];
    symbolShapes.addAll(
      _shapesOf(
        focusSymbols,
        shotRankByShotId: shotRankByShotId,
        isGhost: false,
        showFieldOfView: showFieldOfView,
      ),
    );

    final ghostShotIds = [
      if (previousShotId != null) previousShotId,
      if (nextShotId != null) nextShotId,
    ];
    final ghostSymbols = [
      for (final symbol in floorPlanSet.symbols)
        if (ghostShotIds.contains(symbol.shotId)) symbol,
    ];
    symbolShapes.addAll(
      _shapesOf(
        ghostSymbols,
        shotRankByShotId: shotRankByShotId,
        isGhost: true,
        showFieldOfView: showFieldOfView,
      ),
    );

    final relevantShotIds = {focusShotId, ...ghostShotIds};
    final symbolById = {for (final symbol in floorPlanSet.symbols) symbol.id: symbol};
    final arrowShapes = <OcptFloorPlanArrowShape>[
      for (final arrow in floorPlanSet.arrows)
        if (relevantShotIds.contains(arrow.shotId))
          if (symbolById[arrow.fromSymbolId] case final from?)
            if (symbolById[arrow.toSymbolId] case final to?)
              OcptFloorPlanArrowShape(
                arrowId: arrow.id,
                shotId: arrow.shotId,
                kind: arrow.kind,
                fromXM: from.xM,
                fromYM: from.yM,
                toXM: to.xM,
                toYM: to.yM,
                label: arrow.label,
                colorArgb: arrow.kind == OcptFloorPlanArrowKind.cameraMove
                    ? ocptFloorPlanCameraMoveArrowColorArgb
                    : ocptFloorPlanMovementArrowColorArgb,
                isGhost: arrow.shotId != focusShotId,
                ctrlXM: arrow.ctrlXM,
                ctrlYM: arrow.ctrlYM,
              ),
    ];

    return OcptFloorPlanSheet(
      setId: floorPlanSet.id,
      setName: floorPlanSet.name,
      underlay: _underlayOf(floorPlanSet),
      symbols: symbolShapes,
      arrows: arrowShapes,
    );
  }

  /// The underlay shape of [floorPlanSet], or null while it has none placed — a case that has an
  /// `underlayAssetId` but no frame yet (mid-import) is treated the same as having none, since
  /// there is nothing yet to draw it at.
  static OcptFloorPlanUnderlayShape? _underlayOf(OcptFloorPlanSet floorPlanSet) {
    final assetId = floorPlanSet.underlayAssetId;
    final xM = floorPlanSet.underlayXM;
    final yM = floorPlanSet.underlayYM;
    final widthM = floorPlanSet.underlayWidthM;
    final heightM = floorPlanSet.underlayHeightM;
    if (assetId == null || xM == null || yM == null || widthM == null || heightM == null) {
      return null;
    }

    return OcptFloorPlanUnderlayShape(
      assetId: assetId,
      path: floorPlanSet.underlayPath,
      xM: xM,
      yM: yM,
      widthM: widthM,
      heightM: heightM,
      rotationDeg: floorPlanSet.underlayRotationDeg ?? 0,
    );
  }

  /// Freezes [symbols] into their drawn shapes, in `sortKey` order, deriving each camera symbol's
  /// [OcptFloorPlanSymbolShape.cameraLabel] from its 0-based rank among the *same shot's* camera
  /// symbols within this very list — which is always exactly the group a caller of this factory
  /// means by "the same shot's live cameras on the same case" (`OcptFloorPlanSymbolsTable`'s own
  /// doc comment), whether [symbols] holds one shot's placements or, under the sequence focus,
  /// every shot's at once.
  static List<OcptFloorPlanSymbolShape> _shapesOf(
    List<OcptFloorPlanSymbol> symbols, {
    required Map<String, int> shotRankByShotId,
    required bool isGhost,
    required bool showFieldOfView,
  }) {
    final sorted = symbols.toList()..sort((a, b) => a.sortKey.compareTo(b.sortKey));
    final cameraRankByShotId = <String, int>{};

    return [
      for (final symbol in sorted)
        _shapeOf(
          symbol,
          isGhost: isGhost,
          showFieldOfView: showFieldOfView,
          cameraLabel: _cameraLabelOf(
            symbol,
            shotRankByShotId: shotRankByShotId,
            cameraRankByShotId: cameraRankByShotId,
          ),
        ),
    ];
  }

  /// The camera label [symbol] draws, or null when it isn't a camera symbol on a shot, or that
  /// shot's rank isn't known. Advances [cameraRankByShotId] for [symbol]'s shot as a side effect,
  /// which is what gives the *next* camera symbol of that same shot the following rank.
  static String? _cameraLabelOf(
    OcptFloorPlanSymbol symbol, {
    required Map<String, int> shotRankByShotId,
    required Map<String, int> cameraRankByShotId,
  }) {
    final shotId = symbol.shotId;
    if (symbol.layer != OcptFloorPlanLayer.cameras || shotId == null) {
      return null;
    }

    final cameraRank = cameraRankByShotId[shotId] ?? 0;
    cameraRankByShotId[shotId] = cameraRank + 1;

    final shotRank = shotRankByShotId[shotId];
    if (shotRank == null) {
      return null;
    }

    return ocptFloorPlanCameraLabelOf(shotRank: shotRank, cameraRank: cameraRank);
  }

  /// Freezes [symbol] into its drawn shape, its footprint resolved to
  /// [ocptFloorPlanDefaultFootprintM] when it carries no `widthM`/`heightM` of its own, its
  /// [OcptFloorPlanSymbolShape.glyphKind] derived from [OcptFloorPlanSymbol.layer]
  /// ([_glyphKindOf]), and, from that glyph kind, its own colour, wedge and décor primitive.
  static OcptFloorPlanSymbolShape _shapeOf(
    OcptFloorPlanSymbol symbol, {
    required bool isGhost,
    required bool showFieldOfView,
    required String? cameraLabel,
  }) {
    final glyphKind = _glyphKindOf(symbol.layer);

    return OcptFloorPlanSymbolShape(
      symbolId: symbol.id,
      shotId: symbol.shotId,
      layer: symbol.layer,
      xM: symbol.xM,
      yM: symbol.yM,
      rotationDeg: symbol.rotationDeg,
      widthM: symbol.widthM ?? ocptFloorPlanDefaultFootprintM(symbol.layer),
      heightM: symbol.heightM ?? ocptFloorPlanDefaultFootprintM(symbol.layer),
      fovDeg: symbol.fovDeg,
      label: symbol.label,
      colorArgb: glyphKind == OcptFloorPlanSymbolGlyphKind.character
          ? ocptFloorPlanCharacterColourOf(symbol.label)
          : ocptFloorPlanLayerColorArgb(symbol.layer),
      cameraLabel: cameraLabel,
      isGhost: isGhost,
      glyphKind: glyphKind,
      cameraFovWedgeDeg: glyphKind == OcptFloorPlanSymbolGlyphKind.camera && showFieldOfView
          ? (symbol.fovDeg ?? ocptFloorPlanDefaultCameraFovDeg)
          : null,
      setElementShape: glyphKind == OcptFloorPlanSymbolGlyphKind.setElement
          ? (symbol.setElementShape ?? OcptFloorPlanSetElementShape.freeform)
          : null,
    );
  }

  /// The glyph [layer] draws as — see [OcptFloorPlanSymbolGlyphKind]'s own doc comment for the
  /// mapping. A `switch` with no `default`, mirroring [OcptFloorPlanLayerScope.isSequenceScoped]'s
  /// own doc comment: an eighth layer must be placed on one glyph or another here rather than
  /// silently falling back to whichever branch happens to be listed last.
  static OcptFloorPlanSymbolGlyphKind _glyphKindOf(OcptFloorPlanLayer layer) => switch (layer) {
    OcptFloorPlanLayer.characters => OcptFloorPlanSymbolGlyphKind.character,
    OcptFloorPlanLayer.cameras => OcptFloorPlanSymbolGlyphKind.camera,
    OcptFloorPlanLayer.lights => OcptFloorPlanSymbolGlyphKind.light,
    OcptFloorPlanLayer.set || OcptFloorPlanLayer.props => OcptFloorPlanSymbolGlyphKind.setElement,
  };

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptFloorPlanSheet(setId: $setId, symbols: ${symbols.length}, arrows: ${arrows.length})";

  /// Object properties
  @override
  List<Object?> get props => [setId, setName, underlay, symbols, arrows];
}
