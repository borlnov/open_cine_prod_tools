// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// A position's identity, for everything in this file — the pair `(positionId, customLabel)` both
/// `person_positions` and `shooting_slot_crew` already model one with, exactly one of the two
/// non-empty at a time in either table.
class OcptCrewPositionRef extends Equatable {
  /// The stable code of the position, from `ocptCrewPositions` (`lib/constants/`), or empty when
  /// this is a free label ([customLabel]) instead of a catalogue entry.
  final String positionId;

  /// A free-text position label, used instead of [positionId] when the catalogue has nothing that
  /// fits. Empty when [positionId] is set.
  final String customLabel;

  /// Tell whether this ref names neither a catalogue entry nor a free label — a crew row holding
  /// neither holds **no** position and must never count as one.
  bool get isEmpty => positionId.isEmpty && customLabel.isEmpty;

  /// Class constructor
  const OcptCrewPositionRef({required this.positionId, required this.customLabel});

  /// Get a string representation of the object, useful for debugging and logging.
  @override
  String toString() => "OcptCrewPositionRef(positionId: $positionId, customLabel: $customLabel)";

  /// Get the object properties. Equality is exact on both strings — a free label is what the user
  /// typed,
  /// so it is compared verbatim, with no trimming and no case folding.
  @override
  List<Object?> get props => [positionId, customLabel];
}
