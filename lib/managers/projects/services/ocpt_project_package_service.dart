// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:io';

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:archive/archive_io.dart';
import 'package:open_cine_prod_tools/constants/ocpt_project_file.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_manifest.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_report.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_package_status.dart';
import 'package:open_cine_prod_tools/utils/ocpt_erased_person_scrub.dart';
import 'package:open_cine_prod_tools/utils/ocpt_safe_file_name.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// Thrown from inside [OcptProjectPackageService.readPackage]'s unpacking loop the moment an entry
/// would land outside the destination folder, and caught by the very method that throws it.
///
/// A dedicated type rather than reusing a generic exception: the outer `catch` needs to tell this
/// apart from an ordinary I/O failure so it can report
/// [OcptProjectPackageStatus.unreadableArchive] (the archive itself is the problem) rather than
/// [OcptProjectPackageStatus.ioError] (reading or writing failed for a reason outside the app).
class _OcptZipSlipException implements Exception {
  /// Class constructor
  const _OcptZipSlipException(this.entryName);

  /// The archive entry whose path resolved outside the destination folder.
  final String entryName;

  @override
  String toString() => "the entry '$entryName' resolves outside the destination folder";
}

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

  /// The folder name a package unpacks into when [OcptProjectPackageManifest.projectName] leaves
  /// [ocptSafeFileNameOf] nothing usable — every character was one Windows forbids, or the name was
  /// only dots and whitespace. Rare (the export reads the very same `project_info.name` the create
  /// dialog already required to be non-empty), but a colleague sending a package built by a much
  /// older version, or one hand-edited before being sent, is not something this side controls.
  static const _fallbackImportedProjectFolderName = "Imported project";

  /// The upgrade steps [_upgradedManifest] replays, keyed by the format each one upgrades **from**
  /// — the entry at `n` turns a format-`n` manifest JSON object into a format-`n + 1` one.
  ///
  /// Empty today, because [ocptCurrentPackageFormat] is `1`, the only format this service has ever
  /// written: there is nothing older to upgrade from yet. The seam exists so that the day a
  /// `packageFormat` `2` ships, its upgrade step has exactly one place to be added — this map is
  /// not here because it does anything now, but so nothing has to be restructured when it does.
  static const _packageManifestUpgrades =
      <int, Map<String, dynamic> Function(Map<String, dynamic> json)>{};

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

  /// Unpacks the package at [packageFilePath] into a new folder inside [parentDirectoryPath], and
  /// says what landed.
  ///
  /// This never opens the unpacked `.ocpt` through drift — see this class's own doc comment for
  /// why — so it never migrates the file it just wrote either. The caller opens it afterwards
  /// through `OcptProjectsManager.probeProjectFile`/`openProject`, which is what states a migration
  /// for a package built by an older build; this method's whole job stops at "a project file now
  /// exists on disk, at whatever schema it travelled in, every reference inside it pointing at a
  /// real file beside it".
  ///
  /// The destination folder is created only once every check that can fail *before* touching disk
  /// has passed (the archive reads, the manifest parses, the format is one this build knows, the
  /// folder isn't already there) — and if anything goes wrong once it exists, that folder is
  /// deleted before this returns [OcptProjectPackageStatus.ioError]: a half-unpacked folder looks
  /// like a project and is not one, and leaving it behind would be a worse failure than the one
  /// that caused it.
  Future<ResultWithStatus<OcptProjectPackageStatus, OcptProjectPackageImportReport>> readPackage({
    required String packageFilePath,
    required String parentDirectoryPath,
  }) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeStream(InputFileStream(packageFilePath));
    } catch (error) {
      appLogger().e("The package at $packageFilePath can't be read as a zip archive: $error");
      return const ResultWithStatus(status: OcptProjectPackageStatus.unreadableArchive);
    }

    try {
      return await _unpackDecodedPackage(
        archive: archive,
        packageFilePath: packageFilePath,
        parentDirectoryPath: parentDirectoryPath,
      );
    } finally {
      // Decoding a zip does not read it: every entry keeps the `.ocptz` open so its bytes can be
      // streamed out later, and nothing closes those handles on its own. Left open, the package the
      // user just imported stays held by the app — which on Windows means a file they cannot move,
      // rename or delete until they quit it.
      await archive.clear();
    }
  }

  /// Unpacks [archive], already decoded out of the package at [packageFilePath], into a new folder
  /// inside [parentDirectoryPath].
  ///
  /// Split out of [readPackage] so that every way out of the unpacking — the four refusals, the
  /// failures and the success alike — passes through the one place that closes the archive again.
  Future<ResultWithStatus<OcptProjectPackageStatus, OcptProjectPackageImportReport>>
  _unpackDecodedPackage({
    required Archive archive,
    required String packageFilePath,
    required String parentDirectoryPath,
  }) async {
    final entriesByName = {
      for (final entry in archive.files)
        if (entry.isFile) entry.name: entry,
    };

    final manifest = _readManifest(entriesByName[ocptPackageManifestEntry]);
    if (manifest == null) {
      appLogger().e("The package at $packageFilePath carries no readable manifest");
      return const ResultWithStatus(status: OcptProjectPackageStatus.unreadableArchive);
    }

    // An archive without the project database is not a package, whatever else it holds — the
    // manifest alone describes one without being one.
    if (!entriesByName.containsKey(ocptPackageDatabaseEntry)) {
      appLogger().e("The package at $packageFilePath carries no $ocptPackageDatabaseEntry");
      return const ResultWithStatus(status: OcptProjectPackageStatus.unreadableArchive);
    }

    if (manifest.packageFormat <= 0) {
      appLogger().e(
        "The package at $packageFilePath states no readable packageFormat: refused rather than "
        "guessed",
      );
      return const ResultWithStatus(status: OcptProjectPackageStatus.unreadableArchive);
    }

    if (manifest.packageFormat > ocptCurrentPackageFormat) {
      appLogger().w(
        "The package at $packageFilePath is in format ${manifest.packageFormat}, which this "
        "build (format $ocptCurrentPackageFormat) doesn't know how to read: refused, nothing "
        "written",
      );
      return const ResultWithStatus(status: OcptProjectPackageStatus.unsupportedPackageFormat);
    }

    final folderName = ocptSafeFileNameOf(
      manifest.projectName,
      fallback: _fallbackImportedProjectFolderName,
    );
    final destinationDirectory = Directory(p.join(parentDirectoryPath, folderName));
    if (destinationDirectory.existsSync()) {
      appLogger().w(
        "The import of $packageFilePath is refused: ${destinationDirectory.path} already exists",
      );
      return const ResultWithStatus(status: OcptProjectPackageStatus.destinationExists);
    }

    try {
      destinationDirectory.createSync(recursive: true);

      final projectFilePath = p.join(
        destinationDirectory.path,
        "$folderName.$ocptProjectFileExtension",
      );
      await _unpackEntries(
        archive: archive,
        destinationDirectory: destinationDirectory,
        projectFilePath: projectFilePath,
      );
      _rewireUnpackedAssetPaths(
        projectFilePath: projectFilePath,
        destinationDirectory: destinationDirectory,
        assets: manifest.assets,
      );

      return ResultWithStatus(
        status: OcptProjectPackageStatus.ok,
        value: OcptProjectPackageImportReport(
          projectFilePath: projectFilePath,
          projectName: manifest.projectName,
          importedAssetCount: manifest.assets.length,
          skippedAssets: manifest.skippedAssets,
        ),
      );
    } on _OcptZipSlipException catch (error) {
      appLogger().e("The package at $packageFilePath can't be trusted: $error");
      await _deleteQuietly(destinationDirectory);
      return const ResultWithStatus(status: OcptProjectPackageStatus.unreadableArchive);
    } catch (error) {
      appLogger().e("The package at $packageFilePath can't be unpacked: $error");
      await _deleteQuietly(destinationDirectory);
      return const ResultWithStatus(status: OcptProjectPackageStatus.ioError);
    }
  }

  /// Reads and parses [entry] as [OcptProjectPackageManifest], or null when it is missing or is not
  /// the JSON object the manifest is always written as.
  ///
  /// [OcptProjectPackageManifest.fromJson] is tolerant of a missing field (it may be reading an
  /// older format), which is exactly why the shape is checked here first: a manifest that isn't
  /// even a JSON object is not an older format of anything, it is not a manifest.
  OcptProjectPackageManifest? _readManifest(ArchiveFile? entry) {
    if (entry == null) {
      return null;
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(entry.readBytes() ?? const []));
    } catch (_) {
      return null;
    }

    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final packageFormat = decoded["packageFormat"];
    final upgraded = packageFormat is int
        ? _upgradedManifest(decoded, packageFormat: packageFormat)
        : decoded;

    return OcptProjectPackageManifest.fromJson(upgraded);
  }

  /// [json], a manifest read at [packageFormat], upgraded step by step up to
  /// [ocptCurrentPackageFormat] through [_packageManifestUpgrades] — a no-op today, since that map
  /// is still empty (see its own doc comment).
  ///
  /// Mirrors `OcptProjectVersionCodec.decode`'s own loop: a format this build has no documented
  /// step for stops the loop rather than guessing at one, and whatever [OcptProjectPackageManifest.
  /// fromJson] then makes of the result is the same tolerant reading it already gives a field an
  /// older format never wrote.
  Map<String, dynamic> _upgradedManifest(Map<String, dynamic> json, {required int packageFormat}) {
    var upgraded = json;
    for (var format = packageFormat; format < ocptCurrentPackageFormat; format++) {
      final step = _packageManifestUpgrades[format];
      if (step == null) {
        break;
      }
      upgraded = step(upgraded);
    }
    return upgraded;
  }

  /// Streams every file [archive] holds — except its manifest — onto disk under
  /// [destinationDirectory], `project.ocpt` landing at [projectFilePath] and every other entry at
  /// its own relative path underneath.
  ///
  /// Each entry's path is checked against [destinationDirectory] **before** anything is written for
  /// it: the archive may come from anywhere, and an entry engineered as `../../../etc/something`
  /// must never be allowed to resolve outside the folder the user picked. `project.ocpt` itself
  /// never goes through that check against its own name — it always lands at [projectFilePath],
  /// which this method computes, never at whatever [ocptPackageDatabaseEntry] states.
  Future<void> _unpackEntries({
    required Archive archive,
    required Directory destinationDirectory,
    required String projectFilePath,
  }) async {
    for (final entry in archive.files) {
      if (!entry.isFile || entry.name == ocptPackageManifestEntry) {
        continue;
      }

      final targetPath = entry.name == ocptPackageDatabaseEntry
          ? projectFilePath
          : _nativePathForEntry(destinationDirectory.path, entry.name);

      if (!_isWithinDestination(destinationDirectory.path, targetPath)) {
        throw _OcptZipSlipException(entry.name);
      }

      Directory(p.dirname(targetPath)).createSync(recursive: true);
      final output = OutputFileStream(targetPath);
      try {
        entry.writeContent(output);
      } finally {
        await output.close();
      }
    }
  }

  /// Rewrites the unpacked `.ocpt` at [projectFilePath] so every `assets` row [assets] names points
  /// at the absolute path the file now sits at under [destinationDirectory], keyed off `assetId` —
  /// never off a drift schema, exactly as [_planAndRewriteAssets] rewrites the staged copy on the
  /// way out.
  ///
  /// Opened through raw `sqlite3`, read-write this time: the file may be at any schema version,
  /// including one this build would migrate, and opening it through drift here would migrate it as
  /// a side effect of importing it — the compatibility gate the caller runs afterwards is what
  /// states that instead. [_hasTable] is reused for the same reason it exists on the write side: a
  /// package built before the `assets` table existed has nothing to rewrite, and a manifest entry
  /// naming a row this database doesn't hold is not a failure — the `UPDATE` simply matches nothing.
  void _rewireUnpackedAssetPaths({
    required String projectFilePath,
    required Directory destinationDirectory,
    required List<OcptPackagedAsset> assets,
  }) {
    if (assets.isEmpty) {
      return;
    }

    final database = sqlite3.open(projectFilePath);
    try {
      if (!_hasTable(database, "assets")) {
        return;
      }

      for (final asset in assets) {
        final absolutePath = p.absolute(
          _nativePathForEntry(destinationDirectory.path, asset.entry),
        );
        database.execute("UPDATE assets SET path = ? WHERE id = ?", [absolutePath, asset.assetId]);
      }
    } finally {
      database.dispose();
    }
  }

  /// [entryName] — a `/`-separated path as a zip entry always names one — turned into a path built
  /// with the platform's own separator, under [destinationDirectoryPath].
  ///
  /// A zip entry is `/`-separated on every platform that wrote it, Windows included; joining it
  /// onto a native path as a single segment would leave the two mixed on Windows, which is why
  /// this splits on the archive's own separator and rejoins with [p.joinAll] instead of a plain
  /// [p.join].
  String _nativePathForEntry(String destinationDirectoryPath, String entryName) =>
      p.joinAll([destinationDirectoryPath, ...p.posix.split(entryName)]);

  /// Whether [candidatePath] resolves to somewhere inside [destinationPath] once both are
  /// canonicalised — the zip-slip guard [_unpackEntries] checks before writing a single byte of
  /// any entry.
  ///
  /// [p.canonicalize] only normalises `..`/`.` segments and makes the path absolute; it never
  /// touches the filesystem, so this is safe to call before [candidatePath] exists.
  bool _isWithinDestination(String destinationPath, String candidatePath) =>
      p.isWithin(p.canonicalize(destinationPath), p.canonicalize(candidatePath));

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
