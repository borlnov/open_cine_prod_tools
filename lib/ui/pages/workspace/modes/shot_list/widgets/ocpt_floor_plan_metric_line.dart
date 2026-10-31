// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// One line the metrics overlay draws, from the selected symbol to another visible one — a pure
/// data record `OcptFloorPlanCanvas` builds (it alone can resolve a localized label) and this
/// painter only ever draws from metres to pixels, exactly as it does every symbol shape.
class OcptFloorPlanMetricLine extends Equatable {
  /// The line's own starting point X, in metres (the selected symbol's own centre).
  final double fromXM;

  /// The line's own starting point Y, in metres.
  final double fromYM;

  /// The line's own end point X, in metres (the other symbol's own centre).
  final double toXM;

  /// The line's own end point Y, in metres.
  final double toYM;

  /// The line's own already-localized distance label (`3.2 m`).
  final String label;

  /// Class constructor
  const OcptFloorPlanMetricLine({
    required this.fromXM,
    required this.fromYM,
    required this.toXM,
    required this.toYM,
    required this.label,
  });

  /// Object properties
  @override
  List<Object?> get props => [fromXM, fromYM, toXM, toYM, label];
}
