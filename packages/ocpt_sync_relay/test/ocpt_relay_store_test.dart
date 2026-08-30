// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';

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
  });
}
