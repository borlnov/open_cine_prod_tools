// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// The underlay shape a floor plan sheet draws, or null while the set has none placed.
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
