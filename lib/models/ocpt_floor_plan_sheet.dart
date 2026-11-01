// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_arrow_shape.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_set.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol_glyph_kind.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol_shape.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_underlay_shape.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_floor_plan_camera_label.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_floor_plan_character_colour.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_floor_plan_geometry.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_arrow_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_override_level.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';

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

/// Everything a Resources set's floor plan draws, for one focus — the **drawing as data** the
/// canvas, the metrics overlay and the floor-plans PDF all paint from and nothing else, the
/// sibling of `OcptScenarioCoverageLayout`.
///
/// Pure Dart, no Flutter import and no `pdf` import
/// (`docs/adr/0031-storyboard-panels-and-floor-plans-in-metres.md`): every shape is already in
/// metres and every colour is already an ARGB int, so a renderer has nothing left to decide beyond
/// where the viewport puts them.
class OcptFloorPlanSheet extends Equatable {
  /// The Resources set this sheet was built from.
  final String setId;

  /// The set's own name, for a page header or a canvas title.
  final String setName;

  /// The set's underlay, or null while none is placed.
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

  /// Builds the sheet [floorPlanSet] draws for sequence [focusSceneId], under one focus.
  ///
  /// [focusShotId] is null for the **sequence** focus (every set-scope symbol not overridden for
  /// [focusSceneId], plus [focusSceneId]'s own scene-scope symbols, plus every live camera of every
  /// shot on this set, numbered) or a shot's id for the
  /// **shot** focus (the same set/scene-scope symbols, plus that shot's own shot layers, plus, when
  /// given, [previousShotId]'s and [nextShotId]'s shot layers drawn as ghosts — the onion skin).
  /// No arrow is drawn under the sequence focus: an arrow is always a shot's own movement, and the
  /// sequence focus shows no single shot's blocking.
  ///
  /// **The override rule**, applied at two levels: a live scene-scope symbol of [focusSceneId]
  /// whose own `overridesSymbolId` names a live set-scope symbol **replaces** it here — the
  /// set-scope original itself is left out of the *editable* shapes, and a **visible** override
  /// ([OcptFloorPlanSymbolShape.isOverride], [OcptFloorPlanOverrideLevel.sequence]) draws in its
  /// place, the original still drawn as a faint, non-interactive ghost
  /// ([OcptFloorPlanSymbolShape.isOverriddenOriginalGhost]) at its own stored geometry. A
  /// **hidden** override draws nothing of its own at all: only the original's own faint ghost
  /// shows, this time *selectable* and naming the override
  /// ([OcptFloorPlanSymbolShape.isHiddenOverrideGhost]) so the inspector can restore it. A symbol
  /// of a *different* scene's own `overridesSymbolId` never hides anything from this sheet.
  ///
  /// **The very same rule runs a second time, scene → shot, under a shot focus only**: a live
  /// shot-scope symbol of [focusShotId] whose own `overridesSymbolId` names one of the
  /// scene-effective shapes just resolved (a plain prop/furniture, or itself already a
  /// sequence-scope override) replaces *that* — visible or hidden, marked exactly the same way but
  /// with [OcptFloorPlanOverrideLevel.shot] — never reaching past [focusShotId]'s own placements.
  /// Onion-skin ghosts are never resolved through this second level: a ghosted neighbour's own
  /// shot-scope overrides, if any, simply draw as its own placements do.
  ///
  /// [shotRankByShotId] is every shot of the sequence's own 1-based display rank
  /// (`OcptShot.position` + 1 — the number is the shot's rank in the
  /// sequence), read by [ocptFloorPlanCameraLabelOf]; a shot missing from it draws its cameras
  /// with no [OcptFloorPlanSymbolShape.cameraLabel] rather than throwing, since a floor plan can be
  /// built before every shot of a freshly reconciled sequence has been assigned one.
  ///
  /// [showFieldOfView] gates every camera's own [OcptFloorPlanSymbolShape.cameraFovWedgeDeg]:
  /// defaults to `true` (the wedge shows by default) so a caller that never touches the flag —
  /// every existing one, ahead of the tray toggle a later piece of work adds — still gets it.
  ///
  factory OcptFloorPlanSheet.of({
    required OcptFloorPlanSet floorPlanSet,
    required String focusSceneId,
    required String? focusShotId,
    required Map<String, int> shotRankByShotId,
    String? previousShotId,
    String? nextShotId,
    bool showFieldOfView = true,
  }) {
    final setScopeSymbols = [
      for (final symbol in floorPlanSet.symbols)
        if (symbol.shotId == null && symbol.sceneId == null) symbol,
    ];
    final sceneScopeSymbols = [
      for (final symbol in floorPlanSet.symbols)
        if (symbol.shotId == null && symbol.sceneId == focusSceneId) symbol,
    ];
    // A scene-scope symbol whose own `overridesSymbolId` names a live set-scope symbol — split by
    // its own `isHidden`, since a **visible** override draws in place of the original (plus the
    // original's own faint, non-interactive ghost) while a **hidden** one draws nothing of its own
    // at all (only the original's own faint, *selectable* ghost, see this factory's own doc
    // comment). A plain scene-scope symbol (a prop; `overridesSymbolId` null) is neither.
    final visibleSequenceOverrides = [
      for (final symbol in sceneScopeSymbols)
        if (symbol.overridesSymbolId != null && !symbol.isHidden) symbol,
    ];
    final hiddenSequenceOverrides = [
      for (final symbol in sceneScopeSymbols)
        if (symbol.overridesSymbolId != null && symbol.isHidden) symbol,
    ];
    final plainSceneSymbols = [
      for (final symbol in sceneScopeSymbols)
        if (symbol.overridesSymbolId == null) symbol,
    ];
    final overriddenSetSymbolIds = {
      for (final symbol in [...visibleSequenceOverrides, ...hiddenSequenceOverrides])
        symbol.overridesSymbolId!,
    };
    final setScopeSymbolById = {for (final symbol in setScopeSymbols) symbol.id: symbol};

    // The sequence's own effective shapes, set → scene already resolved — every one of these is a
    // candidate a shot-scope override may, in turn, replace one level further down.
    final sequenceEffectiveSymbols = [
      for (final symbol in setScopeSymbols)
        if (!overriddenSetSymbolIds.contains(symbol.id)) symbol,
      ...plainSceneSymbols,
      ...visibleSequenceOverrides,
    ];
    final sequenceEffectiveById = {
      for (final symbol in sequenceEffectiveSymbols) symbol.id: symbol,
    };

    // Scene → shot: only under a shot focus, and only a live shot-scope symbol of
    // [focusShotId] itself — never a ghosted neighbour's own placements.
    var liveSequenceSymbols = sequenceEffectiveSymbols;
    var visibleShotOverrides = const <OcptFloorPlanSymbol>[];
    var hiddenShotOverrides = const <OcptFloorPlanSymbol>[];
    if (focusShotId != null) {
      final shotOverrideCandidates = [
        for (final symbol in floorPlanSet.symbols)
          if (symbol.shotId == focusShotId &&
              symbol.overridesSymbolId != null &&
              sequenceEffectiveById.containsKey(symbol.overridesSymbolId))
            symbol,
      ];
      visibleShotOverrides = [
        for (final symbol in shotOverrideCandidates)
          if (!symbol.isHidden) symbol,
      ];
      hiddenShotOverrides = [
        for (final symbol in shotOverrideCandidates)
          if (symbol.isHidden) symbol,
      ];
      final overriddenSequenceSymbolIds = {
        for (final symbol in [...visibleShotOverrides, ...hiddenShotOverrides])
          symbol.overridesSymbolId!,
      };
      liveSequenceSymbols = [
        for (final symbol in sequenceEffectiveSymbols)
          if (!overriddenSequenceSymbolIds.contains(symbol.id)) symbol,
      ];
    }

    final sequenceOverrideSymbolIds = {for (final symbol in visibleSequenceOverrides) symbol.id};
    final shotOverrideSymbolIds = {for (final symbol in visibleShotOverrides) symbol.id};
    final symbolShapes = <OcptFloorPlanSymbolShape>[
      for (final shape in _shapesOf(
        liveSequenceSymbols,
        shotRankByShotId: shotRankByShotId,
        isGhost: false,
        showFieldOfView: showFieldOfView,
      ))
        if (sequenceOverrideSymbolIds.contains(shape.symbolId))
          shape.copyWith(isOverride: true, overrideLevel: OcptFloorPlanOverrideLevel.sequence)
        else if (shotOverrideSymbolIds.contains(shape.symbolId))
          shape.copyWith(isOverride: true, overrideLevel: OcptFloorPlanOverrideLevel.shot)
        else
          shape,
      // The faint, non-interactive ghost of every visibly-overridden original, at its own stored
      // geometry, `symbolId` still naming the original — `OcptFloorPlanCanvas` never builds a hit
      // overlay for one of these.
      for (final override in visibleSequenceOverrides)
        if (setScopeSymbolById[override.overridesSymbolId] case final original?)
          _shapeOf(original, isGhost: false, showFieldOfView: false, cameraLabel: null).copyWith(
            isOverriddenOriginalGhost: true,
            overrideLevel: OcptFloorPlanOverrideLevel.sequence,
          ),
      // The faint, *selectable* ghost of every hidden override's own original, at the original's
      // own stored geometry, but `symbolId` naming the **override** — selecting it is how the
      // inspector reaches `Restore` for an override the sequence currently masks entirely.
      for (final override in hiddenSequenceOverrides)
        if (setScopeSymbolById[override.overridesSymbolId] case final original?)
          _shapeOf(original, isGhost: false, showFieldOfView: false, cameraLabel: null).copyWith(
            symbolId: override.id,
            isHiddenOverrideGhost: true,
            overrideLevel: OcptFloorPlanOverrideLevel.sequence,
          ),
      // The shot-scope equivalent of the two ghost kinds just above, one level further down: the
      // original here is already scene-effective (a plain symbol, or itself a sequence override).
      for (final override in visibleShotOverrides)
        if (sequenceEffectiveById[override.overridesSymbolId] case final original?)
          _shapeOf(original, isGhost: false, showFieldOfView: false, cameraLabel: null).copyWith(
            isOverriddenOriginalGhost: true,
            overrideLevel: OcptFloorPlanOverrideLevel.shot,
          ),
      for (final override in hiddenShotOverrides)
        if (sequenceEffectiveById[override.overridesSymbolId] case final original?)
          _shapeOf(original, isGhost: false, showFieldOfView: false, cameraLabel: null).copyWith(
            symbolId: override.id,
            isHiddenOverrideGhost: true,
            overrideLevel: OcptFloorPlanOverrideLevel.shot,
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

    // A hidden shot override must draw nothing of its own (only its own ghost, already added
    // above) — excluded here, the one place its own shape would otherwise be built, since its
    // `shotId` is [focusShotId] exactly like every other one of the focused shot's own symbols.
    final hiddenShotOverrideIds = {for (final symbol in hiddenShotOverrides) symbol.id};
    final focusSymbols = [
      for (final symbol in floorPlanSet.symbols)
        if (symbol.shotId == focusShotId && !hiddenShotOverrideIds.contains(symbol.id)) symbol,
    ];
    symbolShapes.addAll([
      // A visible shot override is itself one of `focusSymbols` (its own `shotId` is
      // [focusShotId]) — mark it here, the one place its own shape is actually built.
      for (final shape in _shapesOf(
        focusSymbols,
        shotRankByShotId: shotRankByShotId,
        isGhost: false,
        showFieldOfView: showFieldOfView,
      ))
        shotOverrideSymbolIds.contains(shape.symbolId)
            ? shape.copyWith(isOverride: true, overrideLevel: OcptFloorPlanOverrideLevel.shot)
            : shape,
    ]);

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

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptFloorPlanSheet(setId: $setId, symbols: ${symbols.length}, arrows: ${arrows.length})";

  /// The underlay shape of [floorPlanSet], or null while it has none placed — a set that has an
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
  /// [OcptFloorPlanSymbolShape.cameraLabel] from its 0-based rank among, and the total count of,
  /// the *same shot's* camera symbols within this very list — which is always exactly the group a
  /// caller of this factory means by "the same shot's live cameras on the same set"
  /// (`OcptFloorPlanSymbolsTable`'s own doc comment), whether [symbols] holds one shot's placements
  /// or, under the sequence focus, every shot's at once. A first pass counts every shot's own
  /// cameras ([_cameraCountByShotIdOf]) before the second assigns labels, since
  /// [ocptFloorPlanCameraLabelOf] needs a camera's own shot's *total* count to know whether that
  /// shot's cameras are lettered at all.
  static List<OcptFloorPlanSymbolShape> _shapesOf(
    List<OcptFloorPlanSymbol> symbols, {
    required Map<String, int> shotRankByShotId,
    required bool isGhost,
    required bool showFieldOfView,
  }) {
    final sorted = symbols.toList()..sort((a, b) => a.sortKey.compareTo(b.sortKey));
    final cameraCountByShotId = _cameraCountByShotIdOf(sorted);
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
            cameraCountByShotId: cameraCountByShotId,
            cameraRankByShotId: cameraRankByShotId,
          ),
        ),
    ];
  }

  /// The live camera symbol count of every shot found in [symbols], keyed by shot id — the first
  /// pass [_shapesOf] needs before it can tell whether a shot's cameras are lettered at all.
  static Map<String, int> _cameraCountByShotIdOf(List<OcptFloorPlanSymbol> symbols) {
    final counts = <String, int>{};
    for (final symbol in symbols) {
      final shotId = symbol.shotId;
      if (symbol.layer != OcptFloorPlanLayer.cameras || shotId == null) {
        continue;
      }
      counts[shotId] = (counts[shotId] ?? 0) + 1;
    }
    return counts;
  }

  /// The camera label [symbol] draws, or null when it isn't a camera symbol on a shot, or that
  /// shot's rank isn't known. Advances [cameraRankByShotId] for [symbol]'s shot as a side effect,
  /// which is what gives the *next* camera symbol of that same shot the following rank.
  static String? _cameraLabelOf(
    OcptFloorPlanSymbol symbol, {
    required Map<String, int> shotRankByShotId,
    required Map<String, int> cameraCountByShotId,
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

    return ocptFloorPlanCameraLabelOf(
      shotRank: shotRank,
      cameraRank: cameraRank,
      cameraCount: cameraCountByShotId[shotId] ?? 0,
    );
  }

  /// Freezes [symbol] into its drawn shape, its footprint resolved to
  /// [ocptFloorPlanSetElementDefaultFootprintM] for a set-element symbol (own typed shape) or
  /// [ocptFloorPlanDefaultFootprintM] for every other layer when it carries no `widthM`/`heightM`
  /// of its own, its [OcptFloorPlanSymbolShape.glyphKind] derived from [OcptFloorPlanSymbol.layer]
  /// ([_glyphKindOf]), and, from that glyph kind, its own colour, wedge and décor primitive.
  static OcptFloorPlanSymbolShape _shapeOf(
    OcptFloorPlanSymbol symbol, {
    required bool isGhost,
    required bool showFieldOfView,
    required String? cameraLabel,
  }) {
    final glyphKind = _glyphKindOf(symbol.layer);
    // Only a set-element symbol (never a hand prop, which shares the same glyph kind) carries a
    // typed shape of its own — the other layers keep their plain per-layer default footprint.
    final setElementDefault = symbol.layer == OcptFloorPlanLayer.set
        ? ocptFloorPlanSetElementDefaultFootprintM(
            symbol.setElementShape ?? OcptFloorPlanSetElementShape.freeform,
          )
        : null;

    return OcptFloorPlanSymbolShape(
      symbolId: symbol.id,
      shotId: symbol.shotId,
      layer: symbol.layer,
      xM: symbol.xM,
      yM: symbol.yM,
      rotationDeg: symbol.rotationDeg,
      widthM:
          symbol.widthM ??
          setElementDefault?.widthM ??
          ocptFloorPlanDefaultFootprintM(symbol.layer),
      heightM:
          symbol.heightM ??
          setElementDefault?.heightM ??
          ocptFloorPlanDefaultFootprintM(symbol.layer),
      fovDeg: symbol.fovDeg,
      fovReachM: symbol.fovReachM,
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
      cameraFovWedgeReachM: glyphKind == OcptFloorPlanSymbolGlyphKind.camera && showFieldOfView
          ? (symbol.fovReachM ?? ocptFloorPlanCameraFovWedgeLengthM)
          : null,
      setElementShape: glyphKind == OcptFloorPlanSymbolGlyphKind.setElement
          ? (symbol.setElementShape ?? OcptFloorPlanSetElementShape.freeform)
          : null,
    );
  }

  /// The glyph [layer] draws as — see [OcptFloorPlanSymbolGlyphKind]'s own doc comment for the
  /// mapping. A `switch` with no `default`: an eighth layer must be placed on one glyph or another
  /// here rather than silently falling back to whichever branch happens to be listed last.
  static OcptFloorPlanSymbolGlyphKind _glyphKindOf(OcptFloorPlanLayer layer) => switch (layer) {
    OcptFloorPlanLayer.characters => OcptFloorPlanSymbolGlyphKind.character,
    OcptFloorPlanLayer.cameras => OcptFloorPlanSymbolGlyphKind.camera,
    OcptFloorPlanLayer.lights => OcptFloorPlanSymbolGlyphKind.light,
    OcptFloorPlanLayer.set || OcptFloorPlanLayer.props => OcptFloorPlanSymbolGlyphKind.setElement,
  };

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [setId, setName, underlay, symbols, arrows];
}
