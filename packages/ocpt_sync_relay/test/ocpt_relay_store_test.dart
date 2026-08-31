// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:ocpt_sync_relay/ocpt_sync_relay.dart';
import 'package:test/test.dart';

OcptChangesetEnvelope _envelope(String changesetId, {int lamport = 1}) => OcptChangesetEnvelope(
  changesetId: changesetId,
  originDeviceId: 'device-1',
  lamport: lamport,
  createdAt: DateTime.utc(2026),
  payload: Uint8List.fromList([1, 2, 3]),
);

/// A snapshot descriptor over [bytes], with a real digest computed over them — the store treats
/// the digest as opaque, but a realistic one keeps these tests honest about what a caller passes.
OcptSnapshotDescriptor _descriptor({
  required String snapshotId,
  required OcptSequenceNumber sequenceUpTo,
  required Uint8List bytes,
}) => OcptSnapshotDescriptor(
  snapshotId: snapshotId,
  sequenceUpTo: sequenceUpTo,
  byteLength: bytes.length,
  contentDigest: sha256.convert(bytes).toString(),
);

void main() {
  group('OcptRelayStore', () {
    late OcptRelayStore store;

    setUp(() => store = OcptRelayStore(':memory:'));
    tearDown(() => store.close());

    test('a changeset appended is read back by readSince(zero)', () {
      final envelope = _envelope('changeset-1');

      final sequence = store.append('project-1', envelope);
      final stored = store.readSince('project-1', OcptSequenceNumber.zero);

      expect(sequence, const OcptSequenceNumber(1));
      expect(stored, [OcptStoredChangeset(sequenceNumber: sequence, envelope: envelope)]);
    });

    test('sequence numbers strictly increase across several appends', () {
      final first = store.append('project-1', _envelope('changeset-1'));
      final second = store.append('project-1', _envelope('changeset-2'));
      final third = store.append('project-1', _envelope('changeset-3'));

      expect(first, const OcptSequenceNumber(1));
      expect(second, const OcptSequenceNumber(2));
      expect(third, const OcptSequenceNumber(3));
      expect(first < second, isTrue);
      expect(second < third, isTrue);
    });

    test('readSince at the last position returns empty', () {
      final last = store.append('project-1', _envelope('changeset-1'));

      final stored = store.readSince('project-1', last);

      expect(stored, isEmpty);
    });

    test('two different projectIds keep independent sequences', () {
      final firstOfA = store.append('project-a', _envelope('a-1'));
      final firstOfB = store.append('project-b', _envelope('b-1'));
      final secondOfA = store.append('project-a', _envelope('a-2'));

      expect(firstOfA, const OcptSequenceNumber(1));
      expect(firstOfB, const OcptSequenceNumber(1));
      expect(secondOfA, const OcptSequenceNumber(2));

      final sinceZeroOnA = store.readSince('project-a', OcptSequenceNumber.zero);
      final sinceZeroOnB = store.readSince('project-b', OcptSequenceNumber.zero);

      expect(sinceZeroOnA.map((changeset) => changeset.envelope.changesetId), ['a-1', 'a-2']);
      expect(sinceZeroOnB.map((changeset) => changeset.envelope.changesetId), ['b-1']);
    });

    test('readSince returns the tail of the log, oldest first', () {
      store.append('project-1', _envelope('changeset-1'));
      store.append('project-1', _envelope('changeset-2'));
      store.append('project-1', _envelope('changeset-3'));

      final stored = store.readSince('project-1', const OcptSequenceNumber(1));

      expect(stored.map((changeset) => changeset.envelope.changesetId), ['changeset-2', 'changeset-3']);
    });

    test('appending the same changesetId twice is idempotent', () {
      final envelope = _envelope('changeset-1');

      final first = store.append('project-1', envelope);
      final second = store.append('project-1', envelope);

      expect(first, second);
      final stored = store.readSince('project-1', OcptSequenceNumber.zero);
      expect(stored, [OcptStoredChangeset(sequenceNumber: first, envelope: envelope)]);
    });

    test('appending envelopes with different changesetIds appends both', () {
      final first = store.append('project-1', _envelope('changeset-1'));
      final second = store.append('project-1', _envelope('changeset-2'));

      expect(first, const OcptSequenceNumber(1));
      expect(second, const OcptSequenceNumber(2));
      final stored = store.readSince('project-1', OcptSequenceNumber.zero);
      expect(stored.map((changeset) => changeset.envelope.changesetId), ['changeset-1', 'changeset-2']);
    });

    test('a duplicate append after other appends still returns its original sequence', () {
      final first = store.append('project-1', _envelope('changeset-1'));
      store.append('project-1', _envelope('changeset-2'));
      store.append('project-1', _envelope('changeset-3'));

      final duplicate = store.append('project-1', _envelope('changeset-1'));

      expect(duplicate, first);
      final stored = store.readSince('project-1', OcptSequenceNumber.zero);
      expect(stored.map((changeset) => changeset.envelope.changesetId), ['changeset-1', 'changeset-2', 'changeset-3']);
    });

    test('project lookup returns the stored tokenHash', () {
      store.createProject(projectId: 'project-1', tokenHash: 'hash-of-secret-token');

      final project = store.findProject('project-1');

      expect(project, isNotNull);
      expect(project!.projectId, 'project-1');
      expect(project.tokenHash, 'hash-of-secret-token');
    });

    test('an unknown project is not found', () {
      expect(store.findProject('unknown'), isNull);
    });

    test('a snapshot uploaded is fetched back, descriptor and bytes intact', () {
      final bytes = Uint8List.fromList(utf8.encode('a snapshot payload'));
      final descriptor = _descriptor(
        snapshotId: 'snapshot-1',
        sequenceUpTo: OcptSequenceNumber.zero,
        bytes: bytes,
      );

      store.uploadSnapshot('project-1', descriptor, bytes);
      final fetched = store.fetchLatestSnapshot('project-1');

      expect(fetched, isNotNull);
      expect(fetched!.$1, descriptor);
      expect(fetched.$2, bytes);
    });

    test('fetchLatestSnapshot returns null before any upload', () {
      expect(store.fetchLatestSnapshot('project-1'), isNull);
    });

    test('a second uploadSnapshot replaces the latest', () {
      final firstBytes = Uint8List.fromList(utf8.encode('first snapshot'));
      final secondBytes = Uint8List.fromList(utf8.encode('second snapshot'));
      final first = _descriptor(
        snapshotId: 'snapshot-1',
        sequenceUpTo: OcptSequenceNumber.zero,
        bytes: firstBytes,
      );
      final second = _descriptor(
        snapshotId: 'snapshot-2',
        sequenceUpTo: OcptSequenceNumber.zero,
        bytes: secondBytes,
      );

      store.uploadSnapshot('project-1', first, firstBytes);
      store.uploadSnapshot('project-1', second, secondBytes);
      final fetched = store.fetchLatestSnapshot('project-1');

      expect(fetched, isNotNull);
      expect(fetched!.$1, second);
      expect(fetched.$2, secondBytes);
    });

    test('pruning not losing a changeset a replica has not yet read', () {
      for (var i = 1; i <= 5; i++) {
        store.append('project-1', _envelope('changeset-$i'));
      }

      final snapshotBytes = Uint8List.fromList(utf8.encode('state up to sequence 3'));
      final descriptor = _descriptor(
        snapshotId: 'snapshot-1',
        sequenceUpTo: const OcptSequenceNumber(3),
        bytes: snapshotBytes,
      );
      store.uploadSnapshot('project-1', descriptor, snapshotBytes);

      // (a) the changesets at/below the snapshot's sequence are pruned from the log.
      final sinceZero = store.readSince('project-1', OcptSequenceNumber.zero);
      expect(sinceZero.map((changeset) => changeset.envelope.changesetId), ['changeset-4', 'changeset-5']);

      // (b) reading since the snapshot's own position returns exactly what is above it.
      final sinceSnapshot = store.readSince('project-1', const OcptSequenceNumber(3));
      expect(sinceSnapshot.map((changeset) => changeset.envelope.changesetId), ['changeset-4', 'changeset-5']);

      // (c) a replica at a cursor behind the snapshot still converges: fetching the snapshot jumps
      // it to sequence 3, and reading since 3 hands it everything above — nothing lost.
      final replicaCursor = const OcptSequenceNumber(1);
      final fetched = store.fetchLatestSnapshot('project-1')!;
      expect(fetched.$1.sequenceUpTo, const OcptSequenceNumber(3));
      expect(replicaCursor < fetched.$1.sequenceUpTo, isTrue);
      final replicaCatchUp = store.readSince('project-1', fetched.$1.sequenceUpTo);
      expect(replicaCatchUp.map((changeset) => changeset.envelope.changesetId), ['changeset-4', 'changeset-5']);
    });

    test('pruning is per-project', () {
      store.append('project-a', _envelope('a-1'));
      store.append('project-a', _envelope('a-2'));
      store.append('project-b', _envelope('b-1'));
      store.append('project-b', _envelope('b-2'));

      final bytes = Uint8List.fromList(utf8.encode('project-a snapshot'));
      final descriptor = _descriptor(
        snapshotId: 'snapshot-a-1',
        sequenceUpTo: const OcptSequenceNumber(2),
        bytes: bytes,
      );
      store.uploadSnapshot('project-a', descriptor, bytes);

      expect(store.readSince('project-a', OcptSequenceNumber.zero), isEmpty);
      final sinceZeroOnB = store.readSince('project-b', OcptSequenceNumber.zero);
      expect(sinceZeroOnB.map((changeset) => changeset.envelope.changesetId), ['b-1', 'b-2']);
    });
  });
}
