// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:sqlite3/sqlite3.dart';

/// The relay's own storage, over a plain `sqlite3` database file (or an in-memory one, for tests).
///
/// Every table this store owns holds an opaque payload plus routing and bookkeeping columns only:
/// `changesets.payload` is the JSON bytes of an [OcptChangesetEnvelope] and `snapshots.descriptor`/
/// `snapshots.bytes` are, respectively, the JSON of an [OcptSnapshotDescriptor] and the snapshot's
/// own bytes — this class never reads a byte of either, and it declares no table name and no
/// domain type of the app's own. That is the whole point of the relay
/// (`docs/adr/0009-offline-first-sync-through-a-domain-blind-relay.md`): a self-hostable server
/// that cannot see what it is carrying.
///
/// Besides the changeset log ([append]/[readSince]), this store holds each project's snapshots
/// ([uploadSnapshot]/[fetchLatestSnapshot]). A snapshot at sequence *N* is a complete
/// self-consistent state, so [uploadSnapshot] also prunes every changeset at or below *N* from
/// that project's log, atomically with the snapshot write — see [uploadSnapshot] for why that is
/// safe for a replica that has not read that far yet.
class OcptRelayStore {
  /// Opens (creating if absent) the database at [path], and creates the schema below if it is not
  /// already there. Pass the literal string `:memory:` to open a private, in-memory database — the
  /// form every test in this package uses.
  OcptRelayStore(String path) : _db = path == _inMemoryPath ? sqlite3.openInMemory() : sqlite3.open(path) {
    _createSchemaIfAbsent();
  }

  static const _inMemoryPath = ':memory:';

  final Database _db;

  /// Closes the underlying database and releases its resources. Call this once this store is no
  /// longer needed; nothing in this class re-opens it afterwards.
  void close() => _db.dispose();

  /// Registers a new project with [projectId], remembering only [tokenHash] — a fast hash of the
  /// bearer token a caller presents on every later request, never the token itself.
  void createProject({required String projectId, required String tokenHash}) {
    _db.execute(
      'INSERT INTO projects (projectId, tokenHash, createdAt) VALUES (?, ?, ?)',
      [projectId, tokenHash, DateTime.now().toUtc().toIso8601String()],
    );
  }

  /// The project registered under [projectId], or null when none has been created yet.
  ({String projectId, String tokenHash, DateTime createdAt})? findProject(String projectId) {
    final rows = _db.select(
      'SELECT projectId, tokenHash, createdAt FROM projects WHERE projectId = ?',
      [projectId],
    );
    if (rows.isEmpty) {
      return null;
    }

    final row = rows.first;

    return (
      projectId: row['projectId'] as String,
      tokenHash: row['tokenHash'] as String,
      createdAt: DateTime.parse(row['createdAt'] as String),
    );
  }

  /// Appends [envelope] to [projectId]'s changeset log, assigning it the next sequence number in
  /// that project's own log — one past the highest sequence number already stored for it, or
  /// [OcptSequenceNumber.zero]'s own `next()` when the log is still empty — and returns it.
  ///
  /// Every `sqlite3` call this method makes runs synchronously on the calling isolate, so within
  /// one relay process two appends for the same project can never race on the same number; nothing
  /// further is done here to serialise concurrent appends across processes.
  OcptSequenceNumber append(String projectId, OcptChangesetEnvelope envelope) {
    final sequence = _highestSequenceNumber(projectId).next();
    _db.execute(
      'INSERT INTO changesets (projectId, sequence, payload) VALUES (?, ?, ?)',
      [projectId, sequence.value, _encodeEnvelope(envelope)],
    );

    return sequence;
  }

  /// Every changeset appended to [projectId]'s log strictly after [cursor], oldest first — the
  /// same "tail of the log" contract the desktop folder transport's `readSince` keeps, so a
  /// replica behind either one converges the same way.
  List<OcptStoredChangeset> readSince(String projectId, OcptSequenceNumber cursor) {
    final rows = _db.select(
      'SELECT sequence, payload FROM changesets WHERE projectId = ? AND sequence > ? ORDER BY sequence ASC',
      [projectId, cursor.value],
    );

    return [
      for (final row in rows)
        OcptStoredChangeset(
          sequenceNumber: OcptSequenceNumber(row['sequence'] as int),
          envelope: _decodeEnvelope(row['payload'] as Uint8List),
        ),
    ];
  }

  /// Stores [bytes] under [descriptor]'s own `snapshotId` for [projectId] and marks it that
  /// project's latest — the one [fetchLatestSnapshot] returns — clearing the flag off whatever
  /// snapshot held it before, mirroring `OcptFolderRemoteStorage.uploadSnapshot`'s `LATEST` marker.
  ///
  /// A snapshot at `descriptor.sequenceUpTo` is a complete, self-consistent state on its own: a
  /// replica behind that position converges by fetching the snapshot (which jumps its cursor to
  /// `sequenceUpTo`) and then reading whatever comes after, never the changesets the snapshot
  /// already subsumes. So this method also deletes every changeset at or below `sequenceUpTo` from
  /// [projectId]'s log, in the same `sqlite3` transaction as the snapshot write and the `isLatest`
  /// update — a crash between them would otherwise leave a snapshot without its prune, or a prune
  /// with no snapshot to stand in for what it removed.
  void uploadSnapshot(String projectId, OcptSnapshotDescriptor descriptor, Uint8List bytes) {
    _db.execute('BEGIN');
    try {
      _db.execute('UPDATE snapshots SET isLatest = 0 WHERE projectId = ?', [projectId]);
      _db.execute(
        'INSERT INTO snapshots (projectId, snapshotId, descriptor, bytes, isLatest) '
        'VALUES (?, ?, ?, ?, 1)',
        [projectId, descriptor.snapshotId, _encodeSnapshotDescriptor(descriptor), bytes],
      );
      _db.execute(
        'DELETE FROM changesets WHERE projectId = ? AND sequence <= ?',
        [projectId, descriptor.sequenceUpTo.value],
      );
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// [projectId]'s latest snapshot — its descriptor and its own bytes — or null when it has none
  /// yet, mirroring `OcptFolderRemoteStorage.fetchLatestSnapshot`.
  (OcptSnapshotDescriptor, Uint8List)? fetchLatestSnapshot(String projectId) {
    final rows = _db.select(
      'SELECT descriptor, bytes FROM snapshots WHERE projectId = ? AND isLatest = 1',
      [projectId],
    );
    if (rows.isEmpty) {
      return null;
    }

    final row = rows.first;
    final descriptor = _decodeSnapshotDescriptor(row['descriptor'] as Uint8List);
    final bytes = row['bytes'] as Uint8List;

    return (descriptor, bytes);
  }

  /// The highest sequence number already stored for [projectId], or [OcptSequenceNumber.zero] when
  /// its log holds nothing yet — so [append] always has a value to call `next()` on.
  OcptSequenceNumber _highestSequenceNumber(String projectId) {
    final rows = _db.select(
      'SELECT MAX(sequence) AS highest FROM changesets WHERE projectId = ?',
      [projectId],
    );
    final highest = rows.first['highest'] as int?;

    return highest == null ? OcptSequenceNumber.zero : OcptSequenceNumber(highest);
  }

  /// The opaque bytes [envelope] is stored as: its own JSON, UTF-8 encoded.
  Uint8List _encodeEnvelope(OcptChangesetEnvelope envelope) =>
      Uint8List.fromList(utf8.encode(jsonEncode(envelope.toJson())));

  /// The envelope stored as [bytes] by [_encodeEnvelope].
  OcptChangesetEnvelope _decodeEnvelope(Uint8List bytes) =>
      OcptChangesetEnvelope.fromJson(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);

  /// The opaque bytes [descriptor] is stored as: its own JSON, UTF-8 encoded.
  Uint8List _encodeSnapshotDescriptor(OcptSnapshotDescriptor descriptor) =>
      Uint8List.fromList(utf8.encode(jsonEncode(descriptor.toJson())));

  /// The descriptor stored as [bytes] by [_encodeSnapshotDescriptor].
  OcptSnapshotDescriptor _decodeSnapshotDescriptor(Uint8List bytes) =>
      OcptSnapshotDescriptor.fromJson(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);

  void _createSchemaIfAbsent() {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS projects (
        projectId TEXT PRIMARY KEY,
        tokenHash TEXT NOT NULL,
        createdAt TEXT NOT NULL
      );
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS changesets (
        projectId TEXT NOT NULL,
        sequence INTEGER NOT NULL,
        payload BLOB NOT NULL,
        PRIMARY KEY (projectId, sequence)
      );
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS snapshots (
        projectId TEXT NOT NULL,
        snapshotId TEXT NOT NULL,
        descriptor BLOB NOT NULL,
        bytes BLOB NOT NULL,
        isLatest INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (projectId, snapshotId)
      );
    ''');
  }
}
