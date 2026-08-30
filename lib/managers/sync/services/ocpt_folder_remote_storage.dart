// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_remote_storage.dart';
import 'package:path/path.dart' as p;

/// An [OcptRemoteStorage] over a plain directory, usable with no network at all and, per
/// `docs/plans/collaboration-and-sync.md` (M3), over any file-sync client on desktop afterwards.
///
/// [directory] holds two subdirectories this transport creates as needed:
///
/// - `changesets/`, one file per appended [OcptChangesetEnvelope], named by its own sequence
///   number zero-padded to [_sequenceNumberWidth] digits (`0000000001.json`, …) — a directory
///   listing already sorts by name in sequence order, which is exactly what [readSince] walks.
/// - `snapshots/`, one `<snapshotId>.json`/`<snapshotId>.bin` pair per uploaded snapshot, plus a
///   `LATEST` marker file holding the id of the one [fetchLatestSnapshot] returns.
///
/// Built on nothing but `dart:io` and `package:path`: no drift, no Flutter, no network — the same
/// boundary [OcptRemoteStorage] itself draws, kept here so this class can be exercised, and used,
/// from a plain Dart isolate.
class OcptFolderRemoteStorage implements OcptRemoteStorage {
  /// Creates a transport rooted at [directory]. Neither [directory] nor its two subdirectories
  /// need to exist yet — every method that writes creates what it needs first.
  OcptFolderRemoteStorage(this.directory);

  /// The directory this transport reads and writes `changesets/` and `snapshots/` under.
  final Directory directory;

  /// The zero-padding width of a changeset file's name — wide enough that a project's whole
  /// history, appended one changeset at a time, never runs out of digits.
  static const _sequenceNumberWidth = 10;

  static const _changesetsDirName = 'changesets';
  static const _changesetFileExtension = '.json';
  static const _snapshotsDirName = 'snapshots';
  static const _snapshotDescriptorExtension = '.json';
  static const _snapshotBytesExtension = '.bin';
  static const _latestSnapshotMarkerFileName = 'LATEST';

  Directory get _changesetsDir => Directory(p.join(directory.path, _changesetsDirName));

  Directory get _snapshotsDir => Directory(p.join(directory.path, _snapshotsDirName));

  @override
  Future<OcptSequenceNumber> append(OcptChangesetEnvelope envelope) async {
    final changesetsDir = _changesetsDir;
    await changesetsDir.create(recursive: true);

    final sequence = (await _highestSequenceNumber(changesetsDir)).next();
    final file = File(p.join(changesetsDir.path, _changesetFileName(sequence)));
    await file.writeAsString(jsonEncode(envelope.toJson()), flush: true);

    return sequence;
  }

  @override
  Future<List<OcptStoredChangeset>> readSince(OcptSequenceNumber cursor) async {
    final changesetsDir = _changesetsDir;
    if (!changesetsDir.existsSync()) {
      return const [];
    }

    final stored = <OcptStoredChangeset>[];
    for (final entry in await _sortedChangesetFiles(changesetsDir)) {
      final sequence = _sequenceNumberOfChangesetFile(entry);
      if (sequence == null || sequence <= cursor) {
        continue;
      }

      final json = jsonDecode(await entry.readAsString()) as Map<String, dynamic>;
      stored.add(OcptStoredChangeset(sequenceNumber: sequence, envelope: OcptChangesetEnvelope.fromJson(json)));
    }

    return stored;
  }

  @override
  Future<void> uploadSnapshot(OcptSnapshotDescriptor descriptor, Uint8List bytes) async {
    final snapshotsDir = _snapshotsDir;
    await snapshotsDir.create(recursive: true);

    await File(
      p.join(snapshotsDir.path, '${descriptor.snapshotId}$_snapshotDescriptorExtension'),
    ).writeAsString(jsonEncode(descriptor.toJson()), flush: true);
    await File(
      p.join(snapshotsDir.path, '${descriptor.snapshotId}$_snapshotBytesExtension'),
    ).writeAsBytes(bytes, flush: true);
    await File(
      p.join(snapshotsDir.path, _latestSnapshotMarkerFileName),
    ).writeAsString(descriptor.snapshotId, flush: true);
  }

  @override
  Future<(OcptSnapshotDescriptor, Uint8List)?> fetchLatestSnapshot() async {
    final marker = File(p.join(_snapshotsDir.path, _latestSnapshotMarkerFileName));
    if (!marker.existsSync()) {
      return null;
    }

    final snapshotId = (await marker.readAsString()).trim();
    final descriptorFile = File(p.join(_snapshotsDir.path, '$snapshotId$_snapshotDescriptorExtension'));
    final bytesFile = File(p.join(_snapshotsDir.path, '$snapshotId$_snapshotBytesExtension'));
    if (!descriptorFile.existsSync() || !bytesFile.existsSync()) {
      return null;
    }

    final descriptorJson = jsonDecode(await descriptorFile.readAsString()) as Map<String, dynamic>;
    final descriptor = OcptSnapshotDescriptor.fromJson(descriptorJson);
    final bytes = await bytesFile.readAsBytes();

    return (descriptor, bytes);
  }

  // No network and no other process to watch for on the common case of a plain local directory;
  // a directory reached through a file-sync client only ever changes between app launches, which
  // every replica already re-reads on `readSince`/`fetchLatestSnapshot` at startup. A relay's
  // WebSocket route is what actually drives this stream once it exists.
  @override
  Stream<void> get newWorkStream => const Stream.empty();

  /// The highest sequence number already written under [changesetsDir], or
  /// [OcptSequenceNumber.zero] when it holds none — so that [append] always has a value to call
  /// `next()` on.
  Future<OcptSequenceNumber> _highestSequenceNumber(Directory changesetsDir) async {
    var highest = OcptSequenceNumber.zero;
    for (final entry in await _sortedChangesetFiles(changesetsDir)) {
      final sequence = _sequenceNumberOfChangesetFile(entry);
      if (sequence != null && sequence > highest) {
        highest = sequence;
      }
    }

    return highest;
  }

  /// Every changeset file directly under [changesetsDir], sorted by name — which, given
  /// [_changesetFileName]'s fixed-width zero-padding, is the same order as by sequence number.
  Future<List<File>> _sortedChangesetFiles(Directory changesetsDir) async {
    final entries =
        await changesetsDir
            .list()
            .where((entry) => entry is File && p.extension(entry.path) == _changesetFileExtension)
            .cast<File>()
            .toList();
    entries.sort((a, b) => a.path.compareTo(b.path));

    return entries;
  }

  /// The file name a changeset at [sequence] is written under.
  String _changesetFileName(OcptSequenceNumber sequence) =>
      '${sequence.value.toString().padLeft(_sequenceNumberWidth, '0')}$_changesetFileExtension';

  /// The sequence number [file]'s own name encodes, or null when it does not parse as one — which
  /// a well-formed transport directory never produces, but a hand-edited or foreign one might.
  OcptSequenceNumber? _sequenceNumberOfChangesetFile(File file) {
    final value = int.tryParse(p.basenameWithoutExtension(file.path));

    return value == null ? null : OcptSequenceNumber(value);
  }
}
