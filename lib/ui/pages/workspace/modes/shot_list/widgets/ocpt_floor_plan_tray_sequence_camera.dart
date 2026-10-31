// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// One live camera symbol of the set, for the palette's own `View` group cameras row — see
/// `OcptFloorPlanLayerTray.sequenceCameras`'s own doc comment, which this replaces.
class OcptFloorPlanTraySequenceCamera extends Equatable {
  /// The camera symbol's own id.
  final String symbolId;

  /// The camera's derived label (`3`, `3A`, `3B`), or `?` while its shot's rank isn't known —
  /// mirrors `OcptFloorPlanSymbolShape.cameraLabel`.
  final String label;

  /// Class constructor
  const OcptFloorPlanTraySequenceCamera({required this.symbolId, required this.label});

  /// Object properties
  @override
  List<Object?> get props => [symbolId, label];
}
