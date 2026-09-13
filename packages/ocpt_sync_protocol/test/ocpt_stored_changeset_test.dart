// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';

import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('OcptStoredChangeset', () {
    final stored = OcptStoredChangeset(
      sequenceNumber: const OcptSequenceNumber(9),
      envelope: OcptChangesetEnvelope(
        changesetId: 'changeset-1',
        originDeviceId: 'device-a',
        lamport: 1,
        createdAt: DateTime.utc(2026, 8, 29),
        payload: Uint8List.fromList([9, 8, 7]),
      ),
    );

    test('round-trips through JSON', () {
      final decoded = OcptStoredChangeset.fromJson(stored.toJson());

      expect(decoded, stored);
    });

    test('two stored changesets with the same fields are equal', () {
      final other = OcptStoredChangeset(
        sequenceNumber: const OcptSequenceNumber(9),
        envelope: OcptChangesetEnvelope(
          changesetId: 'changeset-1',
          originDeviceId: 'device-a',
          lamport: 1,
          createdAt: DateTime.utc(2026, 8, 29),
          payload: Uint8List.fromList([9, 8, 7]),
        ),
      );

      expect(stored, other);
    });

    test('a differing sequence number makes two stored changesets unequal', () {
      final other = OcptStoredChangeset(sequenceNumber: const OcptSequenceNumber(10), envelope: stored.envelope);

      expect(stored, isNot(other));
    });

    test('propagates a malformed envelope as a typed error', () {
      final json = stored.toJson();
      (json['envelope'] as Map<String, dynamic>).remove('originDeviceId');

      expect(
        () => OcptStoredChangeset.fromJson(json),
        throwsA(isA<OcptSyncMalformedDataError>()),
      );
    });
  });
}
