// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:ocpt_sync_protocol/src/ocpt_sync_protocol_format_error.dart';
import 'package:ocpt_sync_protocol/src/ocpt_sync_wire_json.dart';

/// One unit of work appended to a project's changeset log: everything a relay's *append* route
/// accepts and everything its *read since* route hands back, before an `OcptSequenceNumber` is
/// attached to it.
///
/// An envelope is opaque by design. `ocpt_sync_protocol` reads only the five fields below;
/// [payload] itself is the app's own serialisation of the per-column field stamps
/// `docs/adr/0010-sync-ready-data-model-prerequisites.md` describes, and this package never
/// looks inside it — a relay built against this protocol never learns a table name, a column
/// name or a row id.
class OcptChangesetEnvelope extends Equatable {
  /// Creates an envelope. [protocolFormat] defaults to [currentProtocolFormat], which is what
  /// every envelope this build writes should carry; a caller decoding one off the wire uses
  /// [OcptChangesetEnvelope.fromJson] instead, which reads the format the envelope actually
  /// declares.
  const OcptChangesetEnvelope({
    required this.changesetId,
    required this.originDeviceId,
    required this.lamport,
    required this.createdAt,
    required this.payload,
    this.protocolFormat = currentProtocolFormat,
  });

  /// Parses an envelope from the JSON object a relay stores or transmits it as.
  ///
  /// Throws [OcptSyncUnsupportedFormatError] when [json]'s `protocolFormat` is newer than
  /// [currentProtocolFormat] — this build cannot know what such an envelope means and refuses to
  /// guess — and [OcptSyncMalformedDataError] when a required field is missing or of the wrong
  /// type. An **older** `protocolFormat` is accepted: per
  /// `docs/adr/0029-schema-versions-frozen-at-stable-releases.md`'s sibling rule for this
  /// protocol, no stable release has shipped yet, so there is no older shape to upgrade from
  /// today, and the fields below are simply read as they are.
  factory OcptChangesetEnvelope.fromJson(Map<String, dynamic> json) {
    final protocolFormat = OcptSyncWireJson.integer(json, _protocolFormatKey);
    if (protocolFormat > currentProtocolFormat) {
      throw OcptSyncUnsupportedFormatError(
        subject: 'changeset envelope',
        foundFormat: protocolFormat,
        knownUpTo: currentProtocolFormat,
      );
    }
    return OcptChangesetEnvelope(
      changesetId: OcptSyncWireJson.string(json, _changesetIdKey),
      originDeviceId: OcptSyncWireJson.string(json, _originDeviceIdKey),
      lamport: OcptSyncWireJson.integer(json, _lamportKey),
      createdAt: OcptSyncWireJson.dateTime(json, _createdAtKey),
      payload: base64Decode(OcptSyncWireJson.string(json, _payloadKey)),
      protocolFormat: protocolFormat,
    );
  }

  /// The wire format this build writes, and the highest one it can read.
  ///
  /// Mirrors the overwrite-vs-create discipline `OcptProjectVersionCodec.currentPayloadFormat`
  /// documents for the project version payload: a change to what [toJson] writes bumps this
  /// constant, and [OcptChangesetEnvelope.fromJson] refuses anything higher rather than
  /// half-reading it.
  static const currentProtocolFormat = 1;

  static const _changesetIdKey = 'changesetId';
  static const _originDeviceIdKey = 'originDeviceId';
  static const _lamportKey = 'lamport';
  static const _createdAtKey = 'createdAt';
  static const _payloadKey = 'payload';
  static const _protocolFormatKey = 'protocolFormat';

  /// The UUID identifying this changeset, minted once by the device that created it and stable
  /// forever after: a relay and every replica refer to the same changeset by this id.
  final String changesetId;

  /// The UUID of the device (`OcptPropertiesManager.deviceId`, from the app's side) that created
  /// this changeset.
  final String originDeviceId;

  /// The originating device's own Lamport counter at the moment this changeset was created.
  ///
  /// This is the device's own clock, not a relay `OcptSequenceNumber`; per ADR 0010, only the
  /// per-column stamps inside [payload] — not this field directly — are what a merge orders two
  /// writes by.
  final int lamport;

  /// When the originating device created this changeset, by its own clock.
  final DateTime createdAt;

  /// The app's own serialisation of the changes this changeset carries — opaque to this package.
  ///
  /// [OcptSyncWireJson] never reads a byte of it: this package parses only the envelope around
  /// it, and it is base64-encoded when the envelope is written as JSON.
  final Uint8List payload;

  /// The wire format this envelope declares itself to be written in.
  final int protocolFormat;

  /// Serialises this envelope to the JSON object a relay stores or transmits it as.
  Map<String, dynamic> toJson() => {
    _changesetIdKey: changesetId,
    _originDeviceIdKey: originDeviceId,
    _lamportKey: lamport,
    _createdAtKey: createdAt.toIso8601String(),
    _payloadKey: base64Encode(payload),
    _protocolFormatKey: protocolFormat,
  };

  @override
  List<Object?> get props => [changesetId, originDeviceId, lamport, createdAt, payload, protocolFormat];

  @override
  String toString() =>
      'OcptChangesetEnvelope(changesetId: $changesetId, originDeviceId: $originDeviceId, '
      'lamport: $lamport, createdAt: $createdAt, payload: ${payload.length} bytes, '
      'protocolFormat: $protocolFormat)';
}
