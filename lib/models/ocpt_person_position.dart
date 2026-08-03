// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';

/// A crew position a person holds on the film, assigned at project level rather than per time
/// slot. See `OcptPersonPositionsTable`'s own doc comment for why this carries no scope of its
/// own.
class OcptPersonPosition extends Equatable {
  /// The stable, unique id of this assignment (a UUID).
  final String id;

  /// The person holding this position.
  final String personId;

  /// The stable code of the position, from `ocptCrewPositions` (`lib/constants/`), or empty when
  /// this assignment is a free label ([customLabel]) instead of a catalogue entry.
  final String positionId;

  /// A free-text position label, used instead of [positionId] when the catalogue has nothing that
  /// fits. Empty when [positionId] is set.
  final String customLabel;

  /// Class constructor
  const OcptPersonPosition({
    required this.id,
    required this.personId,
    required this.positionId,
    required this.customLabel,
  });

  /// Builds an [OcptPersonPosition] from its stored [row].
  factory OcptPersonPosition.fromRow(OcptPersonPositionRow row) => OcptPersonPosition(
    id: row.id,
    personId: row.personId,
    positionId: row.positionId,
    customLabel: row.customLabel,
  );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptPersonPosition(id: $id, positionId: $positionId, customLabel: $customLabel)";

  /// Object properties
  @override
  List<Object?> get props => [id, personId, positionId, customLabel];
}
