// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';

/// The default footprint, in metres, a character silhouette is drawn at — the implicit ruler every
/// other measurement on a floor plan is read against (`docs/adr/0031-storyboard-panels-and-
/// floor-plans-in-metres.md`). Never stored: a symbol carries its own [ocptFloorPlanDefaultFootprintM]
/// only as a drawing default, geometry is always in metres regardless of this constant's value.
const double ocptFloorPlanCharacterFootprintM = 0.5;

/// The default footprint, in metres, a camera body is drawn at.
const double ocptFloorPlanCameraFootprintM = 0.3;

/// The default footprint, in metres, a light is drawn at.
const double ocptFloorPlanLightFootprintM = 0.3;

/// The camera field-of-view wedge's own default angle, in degrees, drawn when a camera symbol
/// carries no `OcptFloorPlanSymbol.fovDeg` of its own — a generic lens's rough field, not tied to
/// any real focal length or sensor size; the maintainer may retune this once the wedge is seen in
/// practice.
const double ocptFloorPlanDefaultCameraFovDeg = 50;

/// How deep, in metres, a camera's own field-of-view wedge reaches along its own heading — the
/// wedge's own **axial height**, from the lens tip to its far chord, never the length of either of
/// its two angled edges (those grow with the angle at a fixed height, they never set it). The one
/// constant both the canvas painter (drawing the wedge) and the canvas's own tip handle (dragging
/// it deeper or shallower) place the wedge's far chord at, so the handle always sits exactly on the
/// wedge it edits.
const double ocptFloorPlanCameraFovWedgeLengthM = 2;

/// The narrowest field of view a camera's own edge handles or `−`/`+` stepper allow.
const double ocptFloorPlanMinCameraFovDeg = 10;

/// The widest field of view a camera's own edge handles or `−`/`+` stepper allow — kept well short
/// of 180° because the wedge's own half-width at a fixed height is `height * tan(halfAngleDeg)`,
/// which grows without bound as the half angle nears 90°: 150° (a 75° half angle, `tan(75°) ≈
/// 3.73`) already draws a very wide cone at any reasonable reach, and anything closer to 180° would
/// draw one absurdly wide instead of narrating a lens's real field.
const double ocptFloorPlanMaxCameraFovDeg = 150;

/// The shortest field-of-view reach a camera's own tip handle allows.
const double ocptFloorPlanMinCameraFovReachM = 0.5;

/// The longest field-of-view reach a camera's own tip handle allows.
const double ocptFloorPlanMaxCameraFovReachM = 30;

/// The offset, in metres, both X and Y, a duplicated symbol is placed at from its source — far
/// enough that the copy is never drawn exactly on top of the original (`Ctrl+D`, or the default
/// `OcptShotListFloorPlanSymbolDuplicatedEvent` with no explicit position).
const double ocptFloorPlanDuplicateOffsetM = 0.3;

/// The default footprint, in metres, a hand prop is drawn at — small enough to read as "held",
/// never mistaken for a piece of furniture.
const double ocptFloorPlanHandPropFootprintM = 0.2;

/// A character disc's own fill opacity, over its `OcptFloorPlanSymbolShape.colorArgb` — the
/// validated glyph's low, name-derived tint (never a solid block, never white), read by the canvas
/// painter and the PDF service alike.
const double ocptFloorPlanCharacterDiscFillAlpha = 0.22;

/// The width, in logical pixels on the canvas and in points on the PDF, a character disc's own
/// stroke is drawn at — always in the character's own colour.
const double ocptFloorPlanCharacterStrokeWidth = 2.5;

/// How far past its own disc's rim a character's facing notch reaches, in logical pixels on the
/// canvas and points on the PDF — a short tick, not a long nose.
const double ocptFloorPlanCharacterNoseRimOffset = 6;

/// The angle, in radians, each of a character's own two arms opens from the facing direction —
/// the validated glyph's own ±66°, both arms pointing forward rather than back.
const double ocptFloorPlanCharacterArmAngleRad = 1.15;

/// Where a character's own arm starts, as a fraction of the disc's own radius, from its centre.
const double ocptFloorPlanCharacterArmStartFactor = 0.55;

/// Where a character's own arm ends, as a fraction of the disc's own radius, from its centre.
const double ocptFloorPlanCharacterArmEndFactor = 1.35;

/// The default footprint, in metres, a sequence-scoped symbol with no [OcptFloorPlanLayer]-specific
/// default of its own (furniture, a fixed prop, a décor mark) is drawn at, before a per-symbol
/// [OcptFloorPlanLayer]-null `widthM`/`heightM` override (v1: never set, see
/// `OcptFloorPlanSymbolsTable`'s own doc comment) replaces it.
const double ocptFloorPlanDefaultElementFootprintM = 0.6;

/// A wall's own default footprint, in metres (`widthM` × `heightM`) — long and thin, a plausible
/// segment rather than the generic furniture square.
const ({double widthM, double heightM}) ocptFloorPlanWallDefaultFootprintM = (
  widthM: 1.2,
  heightM: 0.12,
);

/// A door's own default footprint, in metres — roughly a standard door's own width, no thicker
/// than a wall's.
const ({double widthM, double heightM}) ocptFloorPlanDoorDefaultFootprintM = (
  widthM: 0.9,
  heightM: 0.12,
);

/// The default footprint, in metres, a set-element symbol of [shape] is drawn at absent a
/// per-symbol `widthM`/`heightM` override — [OcptFloorPlanSetElementShape.wall] long and thin,
/// [OcptFloorPlanSetElementShape.door] a standard door's own width, and
/// [OcptFloorPlanSetElementShape.furniture]/[OcptFloorPlanSetElementShape.freeform] the generic
/// [ocptFloorPlanDefaultElementFootprintM] square, unchanged from before typed shapes existed.
({double widthM, double heightM}) ocptFloorPlanSetElementDefaultFootprintM(
  OcptFloorPlanSetElementShape shape,
) => switch (shape) {
  OcptFloorPlanSetElementShape.wall => ocptFloorPlanWallDefaultFootprintM,
  OcptFloorPlanSetElementShape.door => ocptFloorPlanDoorDefaultFootprintM,
  OcptFloorPlanSetElementShape.furniture ||
  OcptFloorPlanSetElementShape.freeform => (
    widthM: ocptFloorPlanDefaultElementFootprintM,
    heightM: ocptFloorPlanDefaultElementFootprintM,
  ),
};

/// How many logical pixels one metre draws at when the floor plan canvas is at its neutral, 100%
/// zoom (`zoom == 1.0`). Every other zoom scales linearly from this baseline
/// ([ocptFloorPlanPixelsPerMetreAt]).
const double ocptFloorPlanBasePixelsPerMetre = 48;

/// The "nice" multipliers a scale bar's length is rounded to, at whichever power of ten fits —
/// `1 m`, `2 m`, `5 m`, `10 m`, `20 m`, `50 m`, and so on down to tenths. The same 1-2-5 progression
/// a chart axis is conventionally labelled with, so the bar always reads as a round number a viewer
/// can do mental arithmetic against.
const List<double> _niceScaleBarMultipliers = [1, 2, 5];

/// The default footprint, in metres, a symbol of [layer] is drawn at absent a per-symbol
/// `widthM`/`heightM` override.
///
/// A `switch` with no `default`, mirroring [OcptFloorPlanScope]'s own doc comment: an eighth layer
/// must be given a footprint here rather than silently falling back to whichever default happens
/// to be listed last.
double ocptFloorPlanDefaultFootprintM(OcptFloorPlanLayer layer) => switch (layer) {
  OcptFloorPlanLayer.characters => ocptFloorPlanCharacterFootprintM,
  OcptFloorPlanLayer.cameras => ocptFloorPlanCameraFootprintM,
  OcptFloorPlanLayer.lights => ocptFloorPlanLightFootprintM,
  OcptFloorPlanLayer.props => ocptFloorPlanHandPropFootprintM,
  OcptFloorPlanLayer.set => ocptFloorPlanDefaultElementFootprintM,
};

/// How many logical pixels one metre draws at when the canvas is at [zoom] (1.0 = neutral/100%).
///
/// Zoom is a **view concern, never synchronised** (`docs/adr/0031-…`): this is the one place the
/// canvas, the scale bar and the metrics overlay all derive screen coordinates from stored metres,
/// so they can never disagree about what a given zoom looks like.
double ocptFloorPlanPixelsPerMetreAt(double zoom) => ocptFloorPlanBasePixelsPerMetre * zoom;

/// [metres] converted to logical pixels at [zoom]. See [ocptFloorPlanPixelsPerMetreAt].
double ocptFloorPlanMetresToPixels({required double metres, required double zoom}) =>
    metres * ocptFloorPlanPixelsPerMetreAt(zoom);

/// [pixels] converted to metres at [zoom], the inverse of [ocptFloorPlanMetresToPixels].
double ocptFloorPlanPixelsToMetres({required double pixels, required double zoom}) =>
    pixels / ocptFloorPlanPixelsPerMetreAt(zoom);

/// The straight-line distance, in metres, between two points of a floor plan's geometry — what the
/// metrics toggle prints between the selected symbol and every other visible one, and between a
/// selected camera and its subject.
double ocptFloorPlanDistanceM({
  required double x1M,
  required double y1M,
  required double x2M,
  required double y2M,
}) {
  final dx = x2M - x1M;
  final dy = y2M - y1M;
  return math.sqrt(dx * dx + dy * dy);
}

/// The scale bar's length, in metres, at [zoom]: the "nice" round number (`1 m`, `2 m`, `5 m`, and
/// their decades either way) whose on-screen length is closest to [targetPixelLength] without
/// exceeding it — so the bar stays legible and inside the canvas corner it is drawn in, whatever
/// the zoom.
///
/// [targetPixelLength] defaults to a comfortable on-screen bar width; a caller measuring a smaller
/// corner may pass a smaller one.
double ocptFloorPlanScaleBarLengthM({required double zoom, double targetPixelLength = 96}) {
  final pixelsPerMetre = ocptFloorPlanPixelsPerMetreAt(zoom);
  if (pixelsPerMetre <= 0) {
    return _niceScaleBarMultipliers.first;
  }

  final roughMetres = targetPixelLength / pixelsPerMetre;
  if (roughMetres <= 0) {
    return _niceScaleBarMultipliers.first;
  }

  final magnitude = math.pow(10, (math.log(roughMetres) / math.ln10).floor()).toDouble();

  // The widest "nice" length (at this or the decade below) that still does not exceed
  // `roughMetres`, so the bar never overruns `targetPixelLength`; falls back to the smallest nice
  // length of the decade below when even that is too wide (a very small `roughMetres`).
  var best = magnitude / 10 * _niceScaleBarMultipliers.first;
  for (final decadeFactor in [magnitude / 10, magnitude, magnitude * 10]) {
    for (final multiplier in _niceScaleBarMultipliers) {
      final candidate = multiplier * decadeFactor;
      if (candidate <= roughMetres && candidate > best) {
        best = candidate;
      }
    }
  }

  return best;
}

/// [lengthM] (a scale bar's own [ocptFloorPlanScaleBarLengthM]) formatted as a plain number with
/// no trailing `.0` (`2`, `0.5`) — what `shotListFloorPlanScaleBarLengthLabel` prints its `m` unit
/// around. A pure string helper rather than an ICU `double` placeholder: every value this rule
/// hands out is already a "nice" one- or two-digit number, so a locale-aware `NumberFormat` would
/// be more machinery than the one decimal digit it ever has to print.
String ocptFloorPlanScaleBarLengthLabelOf(double lengthM) {
  if (lengthM == lengthM.roundToDouble()) {
    return lengthM.round().toString();
  }
  return lengthM.toStringAsFixed(1);
}
