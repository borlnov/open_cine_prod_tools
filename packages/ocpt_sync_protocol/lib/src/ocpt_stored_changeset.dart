// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:ocpt_sync_protocol/src/ocpt_changeset_envelope.dart';
import 'package:ocpt_sync_protocol/src/ocpt_sequence_number.dart';
import 'package:ocpt_sync_protocol/src/ocpt_sync_wire_json.dart';

/// One row of what a relay's *read changesets since a sequence number* route hands back: the
/// [envelope] a device appended, paired with the [sequenceNumber] the relay assigned it on
/// arrival.
///
/// The pairing exists only outside the changeset log itself: [envelope] alone is everything a
/// replica needs to apply the change, while [sequenceNumber] is only ever a delivery cursor —
/// where to resume a "read since" call — and, per ADR 0010, never something a merge reads to
/// decide a winner.
class OcptStoredChangeset extends Equatable {
  /// Creates a stored changeset pairing [sequenceNumber], the relay-assigned delivery position,
  /// with [envelope], the changeset itself.
  const OcptStoredChangeset({required this.sequenceNumber, required this.envelope});

  /// Parses a stored changeset from the JSON object a relay's "read since" route hands back.
  ///
  /// Throws whatever [OcptChangesetEnvelope.fromJson] throws when the envelope it carries cannot
  /// be read, and `OcptSyncMalformedDataError` when the sequence number is missing or of the
  /// wrong type.
  factory OcptStoredChangeset.fromJson(Map<String, dynamic> json) => OcptStoredChangeset(
    sequenceNumber: OcptSequenceNumber.fromJson(OcptSyncWireJson.integer(json, _sequenceNumberKey)),
    envelope: OcptChangesetEnvelope.fromJson(OcptSyncWireJson.object(json, _envelopeKey)),
  );

  static const _sequenceNumberKey = 'sequenceNumber';
  static const _envelopeKey = 'envelope';

  /// The position a relay assigned this changeset in its own log.
  final OcptSequenceNumber sequenceNumber;

  /// The changeset a device appended, unpacked and applied exactly as [OcptChangesetEnvelope]
  /// describes.
  final OcptChangesetEnvelope envelope;

  /// Serialises this stored changeset to the JSON object a relay's "read since" route hands back.
  Map<String, dynamic> toJson() => {
    _sequenceNumberKey: sequenceNumber.toJson(),
    _envelopeKey: envelope.toJson(),
  };

  @override
  List<Object?> get props => [sequenceNumber, envelope];

  @override
  String toString() =>
      'OcptStoredChangeset(sequenceNumber: $sequenceNumber, envelope: $envelope)';
}
