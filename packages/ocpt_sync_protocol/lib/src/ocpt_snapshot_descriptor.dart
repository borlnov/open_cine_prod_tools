// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:ocpt_sync_protocol/src/ocpt_sequence_number.dart';
import 'package:ocpt_sync_protocol/src/ocpt_sync_malformed_data_error.dart';
import 'package:ocpt_sync_protocol/src/ocpt_sync_protocol_format_error.dart';
import 'package:ocpt_sync_protocol/src/ocpt_sync_wire_json.dart';

/// What a relay's *fetch the latest snapshot* route hands back describing a snapshot, without the
/// snapshot's own bytes: enough for a replica to decide whether it already has this snapshot and
/// to verify what it downloads next against [contentDigest].
///
/// Defined alongside the rest of the wire format, so that snapshot upload and download add no
/// protocol churn on top of what the changeset log already committed to.
class OcptSnapshotDescriptor extends Equatable {
  /// The wire format this build writes, and the highest one it can read.
  ///
  /// Independent of `OcptChangesetEnvelope.currentProtocolFormat`: a snapshot and a changeset
  /// evolve for different reasons and are read at different times, exactly as
  /// `OcptProjectVersionCodec.currentPayloadFormat` is kept independent of the database's own
  /// schema version.
  static const currentSnapshotFormat = 1;

  /// The JSON key of `snapshotId`.
  static const _snapshotIdKey = 'snapshotId';

  /// The JSON key of `sequenceUpTo`.
  static const _sequenceUpToKey = 'sequenceUpTo';

  /// The JSON key of `byteLength`.
  static const _byteLengthKey = 'byteLength';

  /// The JSON key of `contentDigest`.
  static const _contentDigestKey = 'contentDigest';

  /// The JSON key of `snapshotFormat`.
  static const _snapshotFormatKey = 'snapshotFormat';

  /// The UUID identifying this snapshot.
  final String snapshotId;

  /// The last sequence number this snapshot already reflects: a replica that has read up to this
  /// position can skip straight to whatever comes after, instead of replaying the whole log.
  final OcptSequenceNumber sequenceUpTo;

  /// The size, in bytes, of the snapshot's own opaque payload — not carried by this descriptor,
  /// only sized by it — as stored by the relay's snapshot route.
  final int byteLength;

  /// A digest of the snapshot's own bytes, for a replica to verify what it downloads.
  final String contentDigest;

  /// The wire format this descriptor declares itself to be written in.
  final int snapshotFormat;

  /// Create a descriptor. [snapshotFormat] defaults to [currentSnapshotFormat], which is what
  /// every snapshot this build writes should carry; a caller decoding one off the wire uses
  /// [OcptSnapshotDescriptor.fromJson] instead, which reads the format the descriptor actually
  /// declares.
  const OcptSnapshotDescriptor({
    required this.snapshotId,
    required this.sequenceUpTo,
    required this.byteLength,
    required this.contentDigest,
    this.snapshotFormat = currentSnapshotFormat,
  });

  /// Parse a descriptor from the JSON object a relay stores or transmit it as.
  ///
  /// Throws [OcptSyncUnsupportedFormatError] when [json]'s `snapshotFormat` is newer than
  /// [currentSnapshotFormat], and [OcptSyncMalformedDataError] when a required field is missing
  /// or of the wrong type. An **older** `snapshotFormat` is accepted, for the same reason
  /// `OcptChangesetEnvelope.fromJson` accepts one: no stable release has shipped yet, so there is
  /// no older shape to upgrade from today.
  factory OcptSnapshotDescriptor.fromJson(Map<String, dynamic> json) {
    final snapshotFormat = OcptSyncWireJson.integer(json, _snapshotFormatKey);
    if (snapshotFormat > currentSnapshotFormat) {
      throw OcptSyncUnsupportedFormatError(
        subject: 'snapshot descriptor',
        foundFormat: snapshotFormat,
        knownUpTo: currentSnapshotFormat,
      );
    }
    return OcptSnapshotDescriptor(
      snapshotId: OcptSyncWireJson.string(json, _snapshotIdKey),
      sequenceUpTo: OcptSequenceNumber.fromJson(OcptSyncWireJson.integer(json, _sequenceUpToKey)),
      byteLength: OcptSyncWireJson.integer(json, _byteLengthKey),
      contentDigest: OcptSyncWireJson.string(json, _contentDigestKey),
      snapshotFormat: snapshotFormat,
    );
  }

  /// Serialise this descriptor to the JSON object a relay stores or transmit it as.
  Map<String, dynamic> toJson() => {
    _snapshotIdKey: snapshotId,
    _sequenceUpToKey: sequenceUpTo.toJson(),
    _byteLengthKey: byteLength,
    _contentDigestKey: contentDigest,
    _snapshotFormatKey: snapshotFormat,
  };

  /// Describe this [OcptSnapshotDescriptor] for debugging and logging.
  @override
  String toString() =>
      'OcptSnapshotDescriptor(snapshotId: $snapshotId, sequenceUpTo: $sequenceUpTo, '
      'byteLength: $byteLength, contentDigest: $contentDigest, snapshotFormat: $snapshotFormat)';

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [snapshotId, sequenceUpTo, byteLength, contentDigest, snapshotFormat];
}
