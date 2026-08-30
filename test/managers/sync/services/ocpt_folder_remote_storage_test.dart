// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_folder_remote_storage.dart';

/// Builds a changeset envelope distinguishable from any other only by [suffix], so a test can
/// assert which one came back without caring about the rest of its fields.
OcptChangesetEnvelope _envelope(String suffix) => OcptChangesetEnvelope(
  changesetId: 'changeset-$suffix',
  originDeviceId: 'device-$suffix',
  lamport: 1,
  createdAt: DateTime.utc(2026),
  payload: Uint8List.fromList('payload-$suffix'.codeUnits),
);

void main() {
  late Directory tempDir;
  late OcptFolderRemoteStorage storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ocpt_folder_remote_storage_test_');
    storage = OcptFolderRemoteStorage(tempDir);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('append/readSince', () {
    test('a round trip returns the same envelope', () async {
      final envelope = _envelope('a');

      final sequence = await storage.append(envelope);
      final stored = await storage.readSince(OcptSequenceNumber.zero);

      expect(stored, [OcptStoredChangeset(sequenceNumber: sequence, envelope: envelope)]);
    });

    test('two separate appends both become visible in sequence order', () async {
      final first = await storage.append(_envelope('a'));
      final second = await storage.append(_envelope('b'));

      final stored = await storage.readSince(OcptSequenceNumber.zero);

      expect(stored.map((entry) => entry.sequenceNumber), [first, second]);
      expect(stored.map((entry) => entry.envelope.changesetId), ['changeset-a', 'changeset-b']);
    });

    test('sequence numbers are strictly monotonic', () async {
      final sequences = [
        await storage.append(_envelope('a')),
        await storage.append(_envelope('b')),
        await storage.append(_envelope('c')),
      ];

      for (var i = 1; i < sequences.length; i++) {
        expect(sequences[i] > sequences[i - 1], isTrue);
      }
    });

    test('a cursor at the end of the log returns nothing new', () async {
      final second = await storage.append(_envelope('a'));
      await storage.append(_envelope('b'));

      final stored = await storage.readSince(await storage.append(_envelope('c')));

      expect(stored, isEmpty);
      // Reading from an earlier cursor still sees everything appended after it, including
      // [second]'s own follow-up.
      expect((await storage.readSince(second)).length, 2);
    });

    test('readSince past the very end of an empty log returns nothing', () async {
      final stored = await storage.readSince(OcptSequenceNumber.zero);

      expect(stored, isEmpty);
    });
  });

  group('uploadSnapshot/fetchLatestSnapshot', () {
    test('a round trip returns the same descriptor and bytes', () async {
      const descriptor = OcptSnapshotDescriptor(
        snapshotId: 'snapshot-a',
        sequenceUpTo: OcptSequenceNumber(3),
        byteLength: 4,
        contentDigest: 'digest-a',
      );
      final bytes = Uint8List.fromList([1, 2, 3, 4]);

      await storage.uploadSnapshot(descriptor, bytes);
      final fetched = await storage.fetchLatestSnapshot();

      expect(fetched, isNotNull);
      expect(fetched!.$1, descriptor);
      expect(fetched.$2, bytes);
    });

    test('fetching with nothing uploaded yet returns null', () async {
      expect(await storage.fetchLatestSnapshot(), isNull);
    });

    test('a later upload becomes the one fetched', () async {
      const first = OcptSnapshotDescriptor(
        snapshotId: 'snapshot-a',
        sequenceUpTo: OcptSequenceNumber(1),
        byteLength: 1,
        contentDigest: 'digest-a',
      );
      const second = OcptSnapshotDescriptor(
        snapshotId: 'snapshot-b',
        sequenceUpTo: OcptSequenceNumber(2),
        byteLength: 1,
        contentDigest: 'digest-b',
      );

      await storage.uploadSnapshot(first, Uint8List.fromList([1]));
      await storage.uploadSnapshot(second, Uint8List.fromList([2]));

      final fetched = await storage.fetchLatestSnapshot();

      expect(fetched!.$1, second);
      expect(fetched.$2, Uint8List.fromList([2]));
    });
  });
}
