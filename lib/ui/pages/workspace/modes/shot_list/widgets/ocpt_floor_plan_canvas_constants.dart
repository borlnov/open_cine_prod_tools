// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The side, in logical pixels, of a selected symbol's own resize handle hit box.
const double ocptFloorPlanHandleHitSize = 18;

/// The gap, in metres, between a selected symbol's own top edge and its rotate handle.
const double ocptFloorPlanRotateHandleGapM = 0.3;

/// The smallest footprint, in metres, a resize may shrink a set element to.
const double ocptFloorPlanMinSymbolFootprintM = 0.2;

/// How close, in logical pixels, a click has to land to an arrow's own shaft (straight or curved)
/// to select it under the `select` tool.
const double ocptFloorPlanArrowHitTolerancePx = 10;

/// How close, in metres, a bent arrow's own control point has to end up to the straight from-to
/// line for a drag on its midpoint handle to straighten it back out instead of writing a curve.
const double ocptFloorPlanArrowStraightenToleranceM = 0.08;

/// The angle, in degrees, a rotate-handle drag snaps to while `Shift` is held.
const double ocptFloorPlanRotateSnapStepDeg = 15;
