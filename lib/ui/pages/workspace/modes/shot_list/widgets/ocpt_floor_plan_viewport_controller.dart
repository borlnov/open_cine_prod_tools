// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:ui';

import 'package:flutter/foundation.dart';

/// The lowest zoom [OcptFloorPlanViewportController] allows (25%).
const double ocptFloorPlanMinZoom = 0.25;

/// The highest zoom [OcptFloorPlanViewportController] allows (400%).
const double ocptFloorPlanMaxZoom = 4;

/// The live, per-frame source of truth for the floor plans canvas's own zoom and pan while
/// `OcptFloorPlanView` is mounted, owned by that view's `State` exactly like
/// `OcptWorkspaceDockLayoutController` is owned by `_ShotListViewState` — the RFL1 exception that
/// precedent already documents, applied here to the canvas's own viewport
/// (`docs/plans/storyboard.md`, §4.3; `docs/adr/0031-storyboard-panels-and-floor-plans-in-metres.md`).
///
/// Dragging to pan, or turning the mouse wheel to zoom, must not emit a bloc state per frame or
/// every frame would rebuild the whole floor plans view. [setZoom]/[panBy] update these live
/// values and notify listeners on every gesture update instead; **pan is never reported to the
/// bloc at all** (ADR 0031: it is a pure view concern with no reason to survive past this
/// controller's own lifetime), while **zoom is reported once it settles** — the tool bar's `−`/`+`
/// buttons report it the moment they are clicked (already a discrete, "settled" action), and the
/// canvas's own scroll-wheel zoom debounces its own rapid-fire ticks before reporting, mirroring
/// the dock controller's "one bloc event per gesture, not per frame" rule for a gesture that has no
/// natural end signal of its own. [syncZoomFromPersisted] pushes the bloc's own last-settled zoom
/// back onto a freshly created controller (the view remounting after a centre view switch, or after
/// leaving and reopening the mode), following the same no-op-if-equal guard
/// `OcptWorkspaceDockLayoutController.syncFromPersisted` uses so a zoom this very controller just
/// committed never bounces back and forth with the bloc.
class OcptFloorPlanViewportController extends ChangeNotifier {
  /// The live zoom (1.0 = neutral/100%), clamped to [ocptFloorPlanMinZoom]/[ocptFloorPlanMaxZoom].
  double _zoom;

  /// The live pan offset, in logical pixels, added to a metres-to-pixels conversion before it is
  /// drawn — see `ocpt_floor_plan_geometry.dart`.
  Offset _pan;

  /// Whether a camera's own field-of-view wedge is drawn — a session view concern exactly like
  /// [_zoom]/[_pan], never synchronised, defaulted **on** so the wedge shows the moment a camera is
  /// placed, with no toggle to find first. `OcptFloorPlanSheet.of`'s own `showFieldOfView` parameter
  /// reads this. A tray toggle wiring [setShowFieldOfView] to a checkbox is a later piece of work;
  /// this controller only carries the flag.
  bool _showFieldOfView;

  /// Class constructor
  OcptFloorPlanViewportController({
    required double zoom,
    Offset pan = Offset.zero,
    bool showFieldOfView = true,
  }) : _zoom = zoom.clamp(ocptFloorPlanMinZoom, ocptFloorPlanMaxZoom),
       _pan = pan,
       _showFieldOfView = showFieldOfView;

  /// The canvas's current zoom.
  double get zoom => _zoom;

  /// The canvas's current pan offset, in logical pixels.
  Offset get pan => _pan;

  /// Whether a camera's own field-of-view wedge is currently drawn. See [_showFieldOfView].
  bool get showFieldOfView => _showFieldOfView;

  /// Sets the live zoom to [value] (clamped), notifying listeners if it actually changed.
  void setZoom(double value) {
    final clamped = value.clamp(ocptFloorPlanMinZoom, ocptFloorPlanMaxZoom);
    if (_zoom == clamped) {
      return;
    }
    _zoom = clamped;
    notifyListeners();
  }

  /// Sets the live pan offset to [value], notifying listeners if it actually changed.
  void setPan(Offset value) {
    if (_pan == value) {
      return;
    }
    _pan = value;
    notifyListeners();
  }

  /// Adds [delta] to the live pan offset — a canvas drag's own `onPanUpdate`.
  void panBy(Offset delta) => setPan(_pan + delta);

  /// Sets whether a camera's own field-of-view wedge is drawn, notifying listeners if it actually
  /// changed. Not called anywhere yet — a future tray toggle's own handler.
  void setShowFieldOfView({required bool value}) {
    if (_showFieldOfView == value) {
      return;
    }
    _showFieldOfView = value;
    notifyListeners();
  }

  /// Pushes the bloc's persisted [zoom] onto this controller — e.g. once this controller is first
  /// created from `OcptShotListState.floorPlanZoom`, or should the bloc's own value change for a
  /// reason other than this controller's own commit. A no-op for the value already current, which
  /// is what a zoom gesture's own settled-value report relies on to not bounce the value it just
  /// committed.
  void syncZoomFromPersisted(double zoom) => setZoom(zoom);
}
