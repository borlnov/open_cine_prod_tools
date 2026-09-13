// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('OcptChangesetEnvelope', () {
    final createdAt = DateTime.utc(2026, 8, 29, 12, 30);
    final envelope = OcptChangesetEnvelope(
      changesetId: 'changeset-1',
      originDeviceId: 'device-a',
      lamport: 3,
      createdAt: createdAt,
      payload: Uint8List.fromList([1, 2, 3, 4]),
    );

    test('round-trips through JSON, byte for byte', () {
      final decoded = OcptChangesetEnvelope.fromJson(envelope.toJson());

      expect(decoded, envelope);
      expect(decoded.payload, envelope.payload);
    });

    test('defaults to the current protocol format', () {
      expect(envelope.protocolFormat, OcptChangesetEnvelope.currentProtocolFormat);
    });

    test('base64-encodes the opaque payload on the wire', () {
      final json = envelope.toJson();

      expect(json['payload'], base64Encode(envelope.payload));
    });

    test('two envelopes with the same fields are equal', () {
      final other = OcptChangesetEnvelope(
        changesetId: 'changeset-1',
        originDeviceId: 'device-a',
        lamport: 3,
        createdAt: createdAt,
        payload: Uint8List.fromList([1, 2, 3, 4]),
      );

      expect(envelope, other);
    });

    test('a differing payload makes two envelopes unequal', () {
      final other = OcptChangesetEnvelope(
        changesetId: 'changeset-1',
        originDeviceId: 'device-a',
        lamport: 3,
        createdAt: createdAt,
        payload: Uint8List.fromList([1, 2, 3, 5]),
      );

      expect(envelope, isNot(other));
    });

    test('refuses a newer protocol format than this build knows', () {
      final json = envelope.toJson()
        ..['protocolFormat'] = OcptChangesetEnvelope.currentProtocolFormat + 1;

      expect(
        () => OcptChangesetEnvelope.fromJson(json),
        throwsA(isA<OcptSyncUnsupportedFormatError>()),
      );
    });

    test('accepts a protocol format at or below the current one', () {
      final atCurrent = envelope.toJson()
        ..['protocolFormat'] = OcptChangesetEnvelope.currentProtocolFormat;
      final older = envelope.toJson()..['protocolFormat'] = OcptChangesetEnvelope.currentProtocolFormat - 1;

      expect(() => OcptChangesetEnvelope.fromJson(atCurrent), returnsNormally);
      expect(() => OcptChangesetEnvelope.fromJson(older), returnsNormally);
    });

    test('reports malformed JSON with a typed error', () {
      final json = envelope.toJson()..remove('changesetId');

      expect(
        () => OcptChangesetEnvelope.fromJson(json),
        throwsA(isA<OcptSyncMalformedDataError>()),
      );
    });
  });
}
