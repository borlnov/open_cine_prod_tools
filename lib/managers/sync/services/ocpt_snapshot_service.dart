// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';
import 'dart:typed_data';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:crypto/crypto.dart';
import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_package_service.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_package_status.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Turns an open project into snapshot bytes and back, the one piece
/// `docs/plans/relay.md` (Phase C, commit 1) needed of `OcptRemoteStorage.uploadSnapshot`/
/// `fetchLatestSnapshot` before either could actually be called: the join flow, the first append
/// to an empty relay (`docs/plans/collaboration-and-sync.md` §5.3) and a restore's publish (§3.4)
/// all need a project turned into bytes and back.
///
/// **The snapshot payload is the portable project package, unchanged.** [OcptProjectPackageService]
/// already zips a project's `.ocpt` and every file it references into one archive somebody can
/// send — that archive *is* the opaque snapshot `OcptRemoteStorage` carries, so this service is
/// nothing but byte↔file plumbing around it over a scratch temporary directory: [buildSnapshot]
/// writes a package and reads it back as bytes, [applySnapshot] writes bytes to a package file and
/// unpacks it. Neither ever holds the project open through drift — [OcptProjectPackageService]
/// itself never does, for the reasons its own doc comment gives, and a snapshot is exactly as free
/// to be built from, or applied onto, a project at any schema version this build would otherwise
/// migrate.
class OcptSnapshotService {
  /// Creates a service using [packageService] to read and write the portable package a snapshot's
  /// bytes actually are.
  ///
  /// [temporaryDirectory] is injectable so a test can point the scratch files this service writes
  /// at a directory of its own choosing rather than the system's; it defaults to
  /// [Directory.systemTemp], which is what every caller outside a test wants.
  const OcptSnapshotService({
    this.packageService = const OcptProjectPackageService(),
    Directory Function()? temporaryDirectory,
  }) : _temporaryDirectory = temporaryDirectory ?? _systemTempDirectory;

  static Directory _systemTempDirectory() => Directory.systemTemp;

  /// The service reading and writing the portable package a snapshot's bytes actually are.
  final OcptProjectPackageService packageService;

  final Directory Function() _temporaryDirectory;

  /// Packages the project at [projectFilePath] and returns it as snapshot bytes, paired with the
  /// descriptor an `OcptRemoteStorage.uploadSnapshot` call carries alongside them.
  ///
  /// [projectName] and [appVersion] are handed in by the caller, exactly as
  /// [OcptProjectPackageService.writePackage] itself requires — this service reads the project
  /// file for its rows, never for facts a manager already holds. [sequenceUpTo] is the caller's own
  /// concern too: the relay-assigned position this snapshot already reflects, normally the pushing
  /// replica's own delivery cursor at the moment it decides to publish.
  ///
  /// The descriptor's [OcptSnapshotDescriptor.snapshotId] is a fresh UUID (this is a new, distinct
  /// snapshot even when its content happens to match a previous one byte for byte), its
  /// [OcptSnapshotDescriptor.byteLength] is the returned bytes' own length, and its
  /// [OcptSnapshotDescriptor.contentDigest] is their SHA-256 hex digest — the same digest
  /// [applySnapshot] verifies a downloaded snapshot against when handed a descriptor to check.
  ///
  /// Throws [StateError] when the underlying package write fails (see
  /// [OcptProjectPackageService.writePackage]'s own possible statuses) — there is no partial
  /// snapshot to hand back in that case, only a reason it could not be built. Every scratch file
  /// this writes along the way is deleted before returning, success or failure alike.
  Future<(OcptSnapshotDescriptor, Uint8List)> buildSnapshot({
    required String projectFilePath,
    required String projectName,
    required String appVersion,
    required OcptSequenceNumber sequenceUpTo,
    DateTime? exportedAt,
  }) async {
    final workingDirectory = await _temporaryDirectory().createTemp('ocpt_snapshot_build_');
    try {
      final packageFilePath = p.join(workingDirectory.path, 'snapshot.ocptz');

      final written = await packageService.writePackage(
        projectFilePath: projectFilePath,
        packageFilePath: packageFilePath,
        projectName: projectName,
        appVersion: appVersion,
        exportedAt: exportedAt ?? DateTime.now(),
      );
      if (written.status != OcptProjectPackageStatus.ok) {
        throw StateError(
          'The project at $projectFilePath could not be packaged into a snapshot: '
          '${written.status}',
        );
      }

      final bytes = await File(packageFilePath).readAsBytes();
      final descriptor = OcptSnapshotDescriptor(
        snapshotId: const Uuid().v4(),
        sequenceUpTo: sequenceUpTo,
        byteLength: bytes.length,
        contentDigest: sha256.convert(bytes).toString(),
      );

      return (descriptor, bytes);
    } finally {
      await _deleteQuietly(workingDirectory);
    }
  }

  /// Materialises [bytes] as a new project under [parentDirectoryPath], and returns the `.ocpt`
  /// path it landed at.
  ///
  /// [bytes] is written to a scratch package file and unpacked exactly as a colleague's `.ocptz`
  /// import would be ([OcptProjectPackageService.readPackage]), which is what states the new
  /// project's own folder name from the package's own manifest and refuses to overwrite an
  /// existing one.
  ///
  /// When [descriptor] is given, [bytes] is verified against its [OcptSnapshotDescriptor.
  /// contentDigest] before anything is unpacked — a mismatch throws [StateError] rather than
  /// materialising a project nobody can trust was actually what the relay described. Passing no
  /// descriptor skips that check, for a caller that never had one to compare against.
  ///
  /// Throws [StateError] when the underlying package read fails (see
  /// [OcptProjectPackageService.readPackage]'s own possible statuses). Every scratch file this
  /// writes along the way is deleted before returning, success or failure alike.
  Future<String> applySnapshot({
    required Uint8List bytes,
    required String parentDirectoryPath,
    OcptSnapshotDescriptor? descriptor,
  }) async {
    if (descriptor != null) {
      final actualDigest = sha256.convert(bytes).toString();
      if (actualDigest != descriptor.contentDigest) {
        throw StateError(
          'The snapshot ${descriptor.snapshotId} does not match its own content digest: '
          'expected ${descriptor.contentDigest}, got $actualDigest',
        );
      }
    }

    final workingDirectory = await _temporaryDirectory().createTemp('ocpt_snapshot_apply_');
    try {
      final packageFilePath = p.join(workingDirectory.path, 'snapshot.ocptz');
      await File(packageFilePath).writeAsBytes(bytes);

      final read = await packageService.readPackage(
        packageFilePath: packageFilePath,
        parentDirectoryPath: parentDirectoryPath,
      );
      if (read.status != OcptProjectPackageStatus.ok) {
        throw StateError(
          'The snapshot could not be materialised into $parentDirectoryPath: ${read.status}',
        );
      }

      return read.value!.projectFilePath;
    } finally {
      await _deleteQuietly(workingDirectory);
    }
  }

  /// Deletes [directory] and everything under it, reporting a failure without raising it.
  ///
  /// This runs in a `finally`, where throwing would replace whatever actually went wrong with a
  /// complaint about a temporary folder — [OcptProjectPackageService]'s own equivalent does the
  /// same, for the same reason.
  Future<void> _deleteQuietly(Directory directory) async {
    if (!directory.existsSync()) {
      return;
    }

    try {
      await directory.delete(recursive: true);
    } catch (error) {
      appLogger().w("The temporary snapshot folder ${directory.path} can't be deleted: $error");
    }
  }
}
