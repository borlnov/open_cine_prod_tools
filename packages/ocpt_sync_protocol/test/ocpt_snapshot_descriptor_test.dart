// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('OcptSnapshotDescriptor', () {
    const descriptor = OcptSnapshotDescriptor(
      snapshotId: 'snapshot-1',
      sequenceUpTo: OcptSequenceNumber(120),
      byteLength: 4096,
      contentDigest: 'sha256:deadbeef',
    );

    test('round-trips through JSON', () {
      final decoded = OcptSnapshotDescriptor.fromJson(descriptor.toJson());

      expect(decoded, descriptor);
    });

    test('defaults to the current snapshot format', () {
      expect(descriptor.snapshotFormat, OcptSnapshotDescriptor.currentSnapshotFormat);
    });

    test('two descriptors with the same fields are equal', () {
      const other = OcptSnapshotDescriptor(
        snapshotId: 'snapshot-1',
        sequenceUpTo: OcptSequenceNumber(120),
        byteLength: 4096,
        contentDigest: 'sha256:deadbeef',
      );

      expect(descriptor, other);
    });

    test('refuses a newer snapshot format than this build knows', () {
      final json = descriptor.toJson()
        ..['snapshotFormat'] = OcptSnapshotDescriptor.currentSnapshotFormat + 1;

      expect(
        () => OcptSnapshotDescriptor.fromJson(json),
        throwsA(isA<OcptSyncUnsupportedFormatError>()),
      );
    });

    test('accepts a snapshot format at or below the current one', () {
      final atCurrent = descriptor.toJson()
        ..['snapshotFormat'] = OcptSnapshotDescriptor.currentSnapshotFormat;
      final older = descriptor.toJson()..['snapshotFormat'] = OcptSnapshotDescriptor.currentSnapshotFormat - 1;

      expect(() => OcptSnapshotDescriptor.fromJson(atCurrent), returnsNormally);
      expect(() => OcptSnapshotDescriptor.fromJson(older), returnsNormally);
    });

    test('reports malformed JSON with a typed error', () {
      final json = descriptor.toJson()..remove('contentDigest');

      expect(
        () => OcptSnapshotDescriptor.fromJson(json),
        throwsA(isA<OcptSyncMalformedDataError>()),
      );
    });
  });
}
