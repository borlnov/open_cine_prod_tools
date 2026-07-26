// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/foundation.dart';

/// The live, per-frame source of truth for the two dock fractions while a mode's view is mounted,
/// owned by that view's state exactly like `OcptStyledEditorController` is owned by
/// `_EditorViewState`.
///
/// This exists for a performance reason that must not be undone: dragging a divider must not emit
/// a bloc state per frame, or every frame would rebuild the mode's own centre content (e.g. the
/// styled editor and the preview). Instead [setLeftFraction]/[setRightFraction] update these live
/// values and notify listeners on every drag update; the page only dispatches a single bloc event
/// once the drag ends, which is what actually persists the final value. [syncFromPersisted] pushes
/// the bloc's own persisted values back onto this controller whenever they change for a reason
/// other than a drag this controller itself just committed (the initial load, or "Reset panel
/// layout"), following a no-op-if-equal guard so a drag's own committed value doesn't bounce back
/// and forth with the bloc.
class OcptWorkspaceDockLayoutController extends ChangeNotifier {
  /// The live left dock fraction.
  double _leftFraction;

  /// The live right dock fraction.
  double _rightFraction;

  /// Class constructor
  OcptWorkspaceDockLayoutController({required double leftFraction, required double rightFraction})
    : _leftFraction = leftFraction,
      _rightFraction = rightFraction;

  /// The left dock's current fraction of the editing row's width.
  double get leftFraction => _leftFraction;

  /// The right dock's current fraction of the editing row's width.
  double get rightFraction => _rightFraction;

  /// Sets the live left fraction to [value], notifying listeners if it actually changed.
  void setLeftFraction(double value) {
    if (_leftFraction == value) {
      return;
    }
    _leftFraction = value;
    notifyListeners();
  }

  /// Sets the live right fraction to [value], notifying listeners if it actually changed.
  void setRightFraction(double value) {
    if (_rightFraction == value) {
      return;
    }
    _rightFraction = value;
    notifyListeners();
  }

  /// Pushes the bloc's persisted [leftFraction]/[rightFraction] onto this controller, e.g. once
  /// the initial load resolves or after "Reset panel layout". A no-op for whichever value is
  /// already current, which is what a drag's own end-of-gesture bloc event relies on to not
  /// bounce the value it just committed.
  void syncFromPersisted({required double leftFraction, required double rightFraction}) {
    setLeftFraction(leftFraction);
    setRightFraction(rightFraction);
  }
}
