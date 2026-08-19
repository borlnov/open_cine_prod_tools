// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:io';

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:archive/archive_io.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_manifest.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_report.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_package_status.dart';
import 'package:open_cine_prod_tools/utils/ocpt_erased_person_scrub.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// Reads and writes the **portable project package**: the project database plus every file it
/// references, as one archive somebody can send.
///
/// A `.ocpt` holds no bytes — a headshot, a scouting photo, a filming permit and a signed release
/// are `assets` rows holding an absolute path on the machine that recorded them
/// (`docs/adr/0013-binary-assets-referenced-by-path.md`). Copying that file to a colleague
/// therefore delivers a project whose every reference dangles. A package is what makes the project
/// travel whole.
///
/// **Everything here works from a file path, never from an open database.** That is what lets the
/// same code serve a project open in the workspace and a project card on the home page, and it is
/// why nothing in this file imports drift: a package may be built from a project file at **any**
/// schema version, including one this build would migrate, and opening it through drift would
/// migrate it as a side effect of sending it. The database is read through raw `sqlite3`, and
/// **read-only** — the user's project file is never written by an export, not even to checkpoint
/// its WAL.
///
/// What travels, and what does not:
/// - the database itself, at whatever schema version it is in;
/// - every referenced file that still exists, copied into the archive, its row rewritten to point
///   inside the package (a path travelling verbatim would leak the exporter's home directory
///   layout, and would resolve to nothing anyway);
/// - a referenced file that is **gone** does not travel: it is reported before the write
///   ([scanAssets]) and recorded in the manifest for the import to report again, and its row keeps
///   the path it always had, since a report has to be able to name what is missing;
/// - `project_versions` travels, **scrubbed**: a payload sealed before somebody was erased still
///   holds their full row, so every erased person is taken back out of the copied payloads and
///   `local_erasures` is emptied. Shipping the table instead of applying it would leave the phone
///   number, the address and the allergies of somebody who asked to be removed one `sqlite3` prompt
///   away on the recipient's machine, which is not erasure.
class OcptProjectPackageService {
  /// The `assets` columns this service reads, by the names **SQL** knows them under.
  ///
  /// Watch the two naming worlds this file sits between: drift names a column in `snake_case`
  /// (`is_deleted`, `person_id`), while a version payload — hand-written by
  /// `OcptProjectVersionCodec` rather than generated — keys the very same fields in `camelCase`.
  /// Every statement here is in the first world and every payload key in the second, and mixing
  /// them up fails loudly at the query rather than quietly at the read.
  static const _assetColumns = "id, path, label";

  /// Class constructor
  const OcptProjectPackageService();

  /// Stats every file the project at [projectFilePath] references, without writing anything.
  ///
  /// The question a package export asks before it writes a byte: continuing is the ordinary answer
  /// and skipping is honest, but it is never silent. Returns null when the file cannot be read as a
  /// project at all — there is nothing to ask about then, and [writePackage] reports the same
  /// failure with a status of its own.
  OcptProjectPackagePreflight? scanAssets({required String projectFilePath}) {
    try {
      return _withReadOnlyDatabase(projectFilePath, (database) {
        final rows = _liveAssetRows(database);

        return OcptProjectPackagePreflight(
          referencedAssetCount: rows.length,
          missingAssets: [
            for (final row in rows)
              if (!_referencedFileExists(row.path))
                OcptSkippedAsset(assetId: row.id, label: row.label, originalPath: row.path),
          ],
        );
      });
    } catch (error) {
      appLogger().e("The assets of the project at $projectFilePath can't be scanned: $error");
      return null;
    }
  }

  /// Writes the project at [projectFilePath] as a package at [packageFilePath], and says what
  /// travelled.
  ///
  /// [projectName] is the project's display name, [appVersion] the version of the app writing this,
  /// both handed in by the caller: this service reads the database for its rows, never for the
  /// facts a manager already holds.
  ///
  /// The archive is streamed to disk entry by entry, never assembled in memory. An existing file at
  /// [packageFilePath] is replaced — the caller got that path from a native save dialog, which has
  /// already asked.
  Future<ResultWithStatus<OcptProjectPackageStatus, OcptProjectPackageExportReport>> writePackage({
    required String projectFilePath,
    required String packageFilePath,
    required String projectName,
    required String appVersion,
    required DateTime exportedAt,
  }) async {
    if (!File(projectFilePath).existsSync()) {
      appLogger().e("The project at $projectFilePath can't be packaged: no such file");
      return const ResultWithStatus(status: OcptProjectPackageStatus.sourceNotFound);
    }

    Directory? workingDirectory;
    try {
      workingDirectory = await Directory.systemTemp.createTemp("ocpt_package_");
      final stagedDatabasePath = p.join(workingDirectory.path, ocptPackageDatabaseEntry);

      // `VACUUM INTO` rather than a file copy: it writes one consistent single file out of a
      // database that another connection may have open, folding in whatever its WAL still holds,
      // and it preserves `PRAGMA user_version`. Copying the bytes under the running app is the bug
      // that only ever appears on somebody else's machine.
      final schemaVersion = _withReadOnlyDatabase(projectFilePath, (database) {
        database.execute("VACUUM INTO ?", [stagedDatabasePath]);
        return _userVersion(database);
      });

      final packaged = <OcptPackagedAsset>[];
      final skipped = <OcptSkippedAsset>[];

      final staged = sqlite3.open(stagedDatabasePath);
      try {
        _scrubErasedPeople(staged);
        _planAndRewriteAssets(staged, packaged: packaged, skipped: skipped);
      } finally {
        staged.dispose();
      }

      final manifest = OcptProjectPackageManifest(
        packageFormat: ocptCurrentPackageFormat,
        appVersion: appVersion,
        schemaVersion: schemaVersion,
        projectName: projectName,
        exportedAt: exportedAt,
        assets: packaged,
        skippedAssets: skipped,
      );

      await _writeArchive(
        packageFilePath: packageFilePath,
        stagedDatabasePath: stagedDatabasePath,
        manifest: manifest,
      );

      return ResultWithStatus(
        status: OcptProjectPackageStatus.ok,
        value: OcptProjectPackageExportReport(
          packagePath: packageFilePath,
          packagedAssetCount: packaged.length,
          skippedAssets: skipped,
        ),
      );
    } catch (error) {
      appLogger().e(
        "The project at $projectFilePath can't be packaged into $packageFilePath: "
        "$error",
      );
      return const ResultWithStatus(status: OcptProjectPackageStatus.ioError);
    } finally {
      await _deleteQuietly(workingDirectory);
    }
  }

  /// Streams [manifest] and the staged database into the zip at [packageFilePath], followed by
  /// every file [OcptProjectPackageManifest.assets] names.
  ///
  /// Each file is added through `ZipFileEncoder.addFile`, which reads it as a stream: the two
  /// hundred scouting photos of an ordinary location scout never sit in memory at once.
  Future<void> _writeArchive({
    required String packageFilePath,
    required String stagedDatabasePath,
    required OcptProjectPackageManifest manifest,
  }) async {
    final encoder = ZipFileEncoder();
    encoder.create(packageFilePath);

    try {
      final manifestBytes = utf8.encode(
        const JsonEncoder.withIndent("  ").convert(manifest.toJson()),
      );
      encoder.addArchiveFile(ArchiveFile.bytes(ocptPackageManifestEntry, manifestBytes));

      await encoder.addFile(File(stagedDatabasePath), ocptPackageDatabaseEntry);

      for (final asset in manifest.assets) {
        await encoder.addFile(File(asset.originalPath), asset.entry);
      }
    } finally {
      await encoder.close();
    }
  }

  /// Takes every erased person back out of the staged copy's version payloads, and empties
  /// `local_erasures`.
  ///
  /// A version payload is never rewritten once captured — that rule is about the **project file**,
  /// and it is not bent here: this runs on a copy that exists only to be packaged, and whose
  /// history is the truth minus what was erased.
  ///
  /// A rewritten row loses its `contentDigest`: the stored digest is the SHA-256 of the payload it
  /// no longer holds, and recomputing one would mean restating the codec's canonicalisation in a
  /// file that deliberately knows nothing about the schema. Null is a value that column already
  /// takes, and it reads as "unknown", which the app treats as *modified* — the fail-safe
  /// direction. Only the rows actually scrubbed are touched, so a project nobody was erased from
  /// travels with its digests intact.
  void _scrubErasedPeople(Database staged) {
    if (!_hasTable(staged, "local_erasures")) {
      return;
    }

    final erasedPersonIds = {
      for (final row in staged.select("SELECT person_id FROM local_erasures"))
        row["person_id"] as String,
    };

    if (erasedPersonIds.isEmpty) {
      return;
    }

    if (_hasTable(staged, "project_versions")) {
      for (final row in staged.select("SELECT id, payload FROM project_versions")) {
        final decoded = jsonDecode(row["payload"] as String);
        if (decoded is! Map<String, dynamic>) {
          continue;
        }

        final scrubbed = ocptScrubErasedPeopleFromPayload(
          payload: decoded,
          erasedPersonIds: erasedPersonIds,
        );
        if (!scrubbed.changed) {
          continue;
        }

        staged.execute(
          "UPDATE project_versions SET payload = ?, content_digest = NULL WHERE id = ?",
          [jsonEncode(scrubbed.payload), row["id"]],
        );
      }
    }

    staged.execute("DELETE FROM local_erasures");
  }

  /// Decides what travels, and rewrites the staged copy's `assets` rows onto their entry inside the
  /// package.
  ///
  /// A row whose file is gone is left exactly as it was: the import has to be able to report *which
  /// file* is missing, and the row is drawn as a dangling reference on either machine anyway.
  void _planAndRewriteAssets(
    Database staged, {
    required List<OcptPackagedAsset> packaged,
    required List<OcptSkippedAsset> skipped,
  }) {
    for (final row in _liveAssetRows(staged)) {
      if (!_referencedFileExists(row.path)) {
        skipped.add(OcptSkippedAsset(assetId: row.id, label: row.label, originalPath: row.path));
        continue;
      }

      // The asset's own id names its folder, so two files called `photo.jpg` referenced by two
      // different rows cannot collide, and the name the user knows the file by is kept.
      final entry = p.url.join(ocptPackageAssetsDirectory, row.id, p.basename(row.path));
      packaged.add(OcptPackagedAsset(assetId: row.id, entry: entry, originalPath: row.path));
      staged.execute("UPDATE assets SET path = ? WHERE id = ?", [entry, row.id]);
    }
  }

  /// Every live `assets` row of [database], or none at all when the table is not part of that
  /// file's schema yet.
  List<({String id, String path, String label})> _liveAssetRows(Database database) {
    if (!_hasTable(database, "assets")) {
      return const [];
    }

    return [
      for (final row in database.select(
        "SELECT $_assetColumns FROM assets WHERE is_deleted = 0 ORDER BY id",
      ))
        (
          id: row["id"] as String,
          path: (row["path"] as String?) ?? "",
          label: (row["label"] as String?) ?? "",
        ),
    ];
  }

  /// Whether the file an `assets` row references is still where the row says.
  ///
  /// An empty path is not a file that moved: it is a row an erasure blanked, and there is nothing
  /// there to look for or to report.
  bool _referencedFileExists(String path) => path.isNotEmpty && File(path).existsSync();

  /// Whether [database] holds a table called [name].
  ///
  /// A package can be built from a project file at any schema version, so every table this service
  /// touches beyond `assets` is asked for rather than assumed.
  bool _hasTable(Database database, String name) => database.select(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
    [name],
  ).isNotEmpty;

  /// The `PRAGMA user_version` of [database]: the schema version the file states about itself.
  int _userVersion(Database database) =>
      database.select("PRAGMA user_version").first.values.first! as int;

  /// Runs [action] against [path] opened **read-only**, and closes it whatever happens.
  ///
  /// Read-only is a promise rather than a precaution: an export must never write to the project it
  /// is copying — not a page, not a WAL checkpoint, not a `user_version`. SQLite reads through
  /// another connection's uncommitted-to-disk WAL from here all the same, which is what makes
  /// exporting an open project safe.
  T _withReadOnlyDatabase<T>(String path, T Function(Database database) action) {
    final database = sqlite3.open(path, mode: OpenMode.readOnly);
    try {
      return action(database);
    } finally {
      database.dispose();
    }
  }

  /// Deletes [directory] and everything under it, reporting a failure without raising it.
  ///
  /// This runs in a `finally`, where throwing would replace whatever actually went wrong with a
  /// complaint about a temporary folder.
  Future<void> _deleteQuietly(Directory? directory) async {
    if (directory == null || !directory.existsSync()) {
      return;
    }

    try {
      await directory.delete(recursive: true);
    } catch (error) {
      appLogger().w("The temporary packaging folder ${directory.path} can't be deleted: $error");
    }
  }
}
