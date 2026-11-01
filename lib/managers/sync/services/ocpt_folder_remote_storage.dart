// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:act_dart_result/act_dart_result.dart';
import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_remote_storage.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_sync_transport_failure.dart';
import 'package:open_cine_prod_tools/types/ocpt_remote_storage_status.dart';
import 'package:path/path.dart' as p;

/// An [OcptRemoteStorage] over a plain directory, usable with no network at all and, on desktop,
/// over any file-sync client.
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
  /// The zero-padding width of a changeset file's name — wide enough that a project's whole
  /// history, appended one changeset at a time, never runs out of digits.
  static const _sequenceNumberWidth = 10;

  /// The name of the subdirectory holding the changeset files.
  static const _changesetsDirName = 'changesets';

  /// The extension of a changeset file.
  static const _changesetFileExtension = '.json';

  /// The name of the subdirectory holding the snapshot files.
  static const _snapshotsDirName = 'snapshots';

  /// The extension of a snapshot descriptor file.
  static const _snapshotDescriptorExtension = '.json';

  /// The extension of a snapshot bytes file.
  static const _snapshotBytesExtension = '.bin';

  /// The name of the file holding the id of the latest snapshot.
  static const _latestSnapshotMarkerFileName = 'LATEST';

  /// The directory this transport reads and writes `changesets/` and `snapshots/` under.
  final Directory directory;

  // No network and no other process to watch for on the common case of a plain local directory;
  // a directory reached through a file-sync client only ever changes between app launches, which
  // every replica already re-reads on `readSince`/`fetchLatestSnapshot` at startup. A relay's
  // WebSocket route is what actually drives this stream once it exists.
  /// Emit nothing: a plain directory has no peer to push work.
  @override
  Stream<void> get newWorkStream => const Stream.empty();

  // Mirrors newWorkStream above: no peer, nothing to receive.
  /// Emit nothing: a plain directory has no peer to send frames.
  @override
  Stream<String> get presenceStream => const Stream.empty();

  /// Get the subdirectory holding the changeset files.
  Directory get _changesetsDir => Directory(p.join(directory.path, _changesetsDirName));

  /// Get the subdirectory holding the snapshot files.
  Directory get _snapshotsDir => Directory(p.join(directory.path, _snapshotsDirName));

  /// Create a transport rooted at [directory]. Neither [directory] nor its two subdirectories
  /// need to exist yet — every method that writes creates what it needs first.
  OcptFolderRemoteStorage(this.directory);

  /// Write [envelope] to a new changeset file named after the next free sequence number.
  @override
  Future<ResultWithStatus<OcptRemoteStorageStatus, OcptSequenceNumber>> append(
    OcptChangesetEnvelope envelope,
  ) => _guarded(() async {
    final changesetsDir = _changesetsDir;
    await changesetsDir.create(recursive: true);

    final sequence = (await _highestSequenceNumber(changesetsDir)).next();
    final file = File(p.join(changesetsDir.path, _changesetFileName(sequence)));
    await file.writeAsString(jsonEncode(envelope.toJson()), flush: true);

    return ResultWithStatus(status: OcptRemoteStorageStatus.ok, value: sequence);
  });

  /// Read the changeset files whose sequence number is after [cursor], oldest first.
  @override
  Future<ResultWithStatus<OcptRemoteStorageStatus, List<OcptStoredChangeset>>> readSince(
    OcptSequenceNumber cursor,
  ) => _guarded(() async {
    final changesetsDir = _changesetsDir;
    if (!changesetsDir.existsSync()) {
      return const ResultWithStatus(status: OcptRemoteStorageStatus.ok, value: []);
    }

    final stored = <OcptStoredChangeset>[];
    for (final entry in await _sortedChangesetFiles(changesetsDir)) {
      final sequence = _sequenceNumberOfChangesetFile(entry);
      if (sequence == null || sequence <= cursor) {
        continue;
      }

      final json = jsonDecode(await entry.readAsString()) as Map<String, dynamic>;
      stored.add(
        OcptStoredChangeset(
          sequenceNumber: sequence,
          envelope: OcptChangesetEnvelope.fromJson(json),
        ),
      );
    }

    return ResultWithStatus(status: OcptRemoteStorageStatus.ok, value: stored);
  });

  /// Write the descriptor and the bytes of the snapshot, then point the latest marker at it.
  @override
  Future<StatusWithExtraInfo<OcptRemoteStorageStatus>> uploadSnapshot(
    OcptSnapshotDescriptor descriptor,
    Uint8List bytes,
  ) => _guarded<Object>(() async {
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

    return const ResultWithStatus(status: OcptRemoteStorageStatus.ok);
  });

  /// Read the snapshot the latest marker names, or answer without value when there is none.
  @override
  Future<ResultWithStatus<OcptRemoteStorageStatus, (OcptSnapshotDescriptor, Uint8List)>>
  fetchLatestSnapshot() => _guarded(() async {
    final marker = File(p.join(_snapshotsDir.path, _latestSnapshotMarkerFileName));
    if (!marker.existsSync()) {
      return const ResultWithStatus(status: OcptRemoteStorageStatus.ok);
    }

    final snapshotId = (await marker.readAsString()).trim();
    final descriptorFile = File(
      p.join(_snapshotsDir.path, '$snapshotId$_snapshotDescriptorExtension'),
    );
    final bytesFile = File(p.join(_snapshotsDir.path, '$snapshotId$_snapshotBytesExtension'));
    if (!descriptorFile.existsSync() || !bytesFile.existsSync()) {
      return const ResultWithStatus(status: OcptRemoteStorageStatus.ok);
    }

    final descriptorJson = jsonDecode(await descriptorFile.readAsString()) as Map<String, dynamic>;
    final descriptor = OcptSnapshotDescriptor.fromJson(descriptorJson);
    final bytes = await bytesFile.readAsBytes();

    return ResultWithStatus(status: OcptRemoteStorageStatus.ok, value: (descriptor, bytes));
  });

  // A plain directory has no live peer to reach — sharing it is always through a file-sync client
  // that only converges between launches, never a socket a presence heartbeat could ride. The call
  // is accepted and dropped rather than refused: a caller of the shared `OcptRemoteStorage` seam
  // never has to special-case this transport.
  /// Drop [opaquePayload]: a plain directory has no peer to reach.
  @override
  void sendPresence(String opaquePayload) {}

  /// Run [call], answering [OcptRemoteStorageStatus.unreachable] with the failure it caught when
  /// it throws anything at all: the file system and `dart:convert` are third-party boundaries, and
  /// a directory that cannot be read is the same thing to a caller as a relay that cannot be heard.
  Future<ResultWithStatus<OcptRemoteStorageStatus, T>> _guarded<T>(
    Future<ResultWithStatus<OcptRemoteStorageStatus, T>> Function() call,
  ) async {
    ResultWithStatus<OcptRemoteStorageStatus, T> result;
    try {
      result = await call();
    } catch (error, stackTrace) {
      result = ResultWithStatus(
        status: OcptRemoteStorageStatus.unreachable,
        extraInfo: OcptSyncTransportFailure(error: error, stackTrace: stackTrace),
      );
    }

    return result;
  }

  /// Get the highest sequence number already written under [changesetsDir], or
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

  /// Get every changeset file directly under [changesetsDir], sorted by name — which, given
  /// [_changesetFileName]'s fixed-width zero-padding, is the same order as by sequence number.
  Future<List<File>> _sortedChangesetFiles(Directory changesetsDir) async {
    final entries = await changesetsDir
        .list()
        .where((entry) => entry is File && p.extension(entry.path) == _changesetFileExtension)
        .cast<File>()
        .toList();
    entries.sort((a, b) => a.path.compareTo(b.path));

    return entries;
  }

  /// Get the file name a changeset at [sequence] is written under.
  String _changesetFileName(OcptSequenceNumber sequence) =>
      '${sequence.value.toString().padLeft(_sequenceNumberWidth, '0')}$_changesetFileExtension';

  /// Get the sequence number [file]'s own name encodes, or null when it does not parse as one —
  /// which
  /// a well-formed transport directory never produces, but a hand-edited or foreign one might.
  OcptSequenceNumber? _sequenceNumberOfChangesetFile(File file) {
    final value = int.tryParse(p.basenameWithoutExtension(file.path));

    return value == null ? null : OcptSequenceNumber(value);
  }
}
