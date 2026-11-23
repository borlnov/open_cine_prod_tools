// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// The zoom of the screenplay page: either one of the fixed [steps], or the "fit to width" mode,
/// where the sheet fills the width of the area it is shown in.
///
/// "Fit to width" is a *mode*, not a step: it keeps following the area as the window is resized,
/// bounded to [minFactor]–[maxFactor], until a step is picked. The zoom a page is actually typeset
/// at (its *effective* factor) is therefore [factorFor] the width measured by the area, and
/// stepping out of that mode starts from the step nearest to it ([stepped]).
///
/// It is stored as one text, the percentage of a step or `fit` ([serialized], [tryParse]).
final class OcptPageZoom extends Equatable {
  /// The zoom factors the user steps through, from the smallest to the largest.
  static const List<double> steps = [0.5, 0.67, 0.75, 0.9, 1, 1.1, 1.25, 1.5, 1.75, 2];

  /// The smallest factor a page can be shown at.
  static const double minFactor = 0.5;

  /// The largest factor a page can be shown at.
  static const double maxFactor = 2;

  /// The text stored for the "fit to width" mode.
  static const String _fitToWidthText = "fit";

  /// The factor of the fixed step the zoom sits on; meaningless while [isFitToWidth].
  final double step;

  /// Whether the sheet fills the width of its area instead of sitting on [step].
  final bool isFitToWidth;

  /// Get the percentage [step] stands for, rounded (67 for 0.67).
  int get stepPercent => percentOf(step);

  /// Get the text this zoom is stored as: `fit`, or the percentage of its step.
  String get serialized => isFitToWidth ? _fitToWidthText : stepPercent.toString();

  /// Create the zoom sitting on the 100 % step.
  const OcptPageZoom.actualSize() : step = 1, isFitToWidth = false;

  /// Create the "fit to width" mode.
  const OcptPageZoom.fitToWidth() : step = 1, isFitToWidth = true;

  /// Create a zoom sitting on the fixed step [step].
  const OcptPageZoom._(this.step) : isFitToWidth = false;

  /// Create the zoom sitting on the step nearest to [factor], which is brought back into the
  /// bounds first.
  factory OcptPageZoom.nearestStep(double factor) =>
      OcptPageZoom._(steps[_nearestStepIndex(factor)]);

  /// Get the factor this zoom typesets the page at, [fitFactor] being the one the area measured.
  double factorFor(double fitFactor) => isFitToWidth ? fitFactor : step;

  /// Get the zoom one step further in [direction] (-1 out, 1 in) from the effective [factor],
  /// leaving the "fit to width" mode: it starts from the step nearest to [factor].
  OcptPageZoom stepped(int direction, {required double factor}) =>
      OcptPageZoom._(steps[(_nearestStepIndex(factor) + direction).clamp(0, steps.length - 1)]);

  /// Get the zoom [text] was stored as ([serialized]), or null when it is not one.
  ///
  /// A percentage outside the bounds is brought back to the nearest step, so a stored value never
  /// leaves the page at a size it can't be stepped back from.
  static OcptPageZoom? tryParse(String text) {
    final trimmed = text.trim();
    if (trimmed == _fitToWidthText) {
      return const OcptPageZoom.fitToWidth();
    }

    final percent = int.tryParse(trimmed);
    if (percent == null) {
      return null;
    }

    return OcptPageZoom.nearestStep(percent / 100);
  }

  /// Get the percentage [factor] stands for, rounded (67 for 0.67).
  static int percentOf(double factor) => (factor * 100).round();

  /// Get the factor that makes a sheet [pageWidthAtActualSize] wide at 100 % fill
  /// [availableWidth] once [gutter] is kept free on each side, brought back into the bounds.
  static double fitFactorFor({
    required double availableWidth,
    required double pageWidthAtActualSize,
    double gutter = 16,
  }) {
    if (pageWidthAtActualSize <= 0) {
      return 1;
    }

    return ((availableWidth - gutter * 2) / pageWidthAtActualSize).clamp(minFactor, maxFactor);
  }

  /// Tell whether the page can be zoomed one step in [direction] (-1 out, 1 in) from the
  /// effective [factor].
  static bool canStep(int direction, double factor) {
    final index = _nearestStepIndex(factor) + direction;
    return index >= 0 && index < steps.length;
  }

  /// Get the index of the step nearest to [factor].
  static int _nearestStepIndex(double factor) {
    var nearest = 0;
    for (var index = 1; index < steps.length; index++) {
      if ((steps[index] - factor).abs() < (steps[nearest] - factor).abs()) {
        nearest = index;
      }
    }

    return nearest;
  }

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [step, isFitToWidth];
}
