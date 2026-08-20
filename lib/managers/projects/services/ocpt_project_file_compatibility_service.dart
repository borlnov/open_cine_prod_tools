// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_file_compatibility.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_file_verdict.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// Reads what format a project file is in **before anything opens it**, and keeps the copy a
/// migration is answered with.
///
/// Opening a `.ocpt` written by another build is not a neutral act. A file from an *older* build is
/// migrated in place by drift's `onUpgrade`, which is right but irreversible, and until now
/// happened silently with nothing kept. A file from a *newer* build is worse: drift calls
/// `onUpgrade(m, from, to)` with `from > to`, every `if (from < N)` guard declines to run, and
/// `PRAGMA user_version` is then stamped back down to the running build's number — the file still
/// holds the newer build's tables while claiming to be old, and the next upgrade runs its steps a
/// second time over them.
///
/// So this service looks first, through raw `sqlite3` opened **read-only**: no drift, so no
/// migration and no `user_version` write can happen as a side effect of looking. It knows nothing
/// of Flutter and holds no state — it takes a path and answers about it, which is what lets it be
/// tested against files a test builds by hand.
class OcptProjectFileCompatibilityService {
  /// The name a backup takes, before the counter that may follow it: the project's own file name,
  /// the format it is in, and the extension it always had.
  ///
  /// The extension is kept on purpose. A backup is a file the *older* build can still open, which
  /// is the entire reason for taking it, and a `.ocpt.bak` it would refuse to list would be a copy
  /// nobody can use.
  static const _backupInfix = "backup-v";

  /// Class constructor
  const OcptProjectFileCompatibilityService();

  /// Reads the format of the project file at [filePath] without opening it as a project, and says
  /// what that means for a build writing [appSchemaVersion].
  ///
  /// Never throws: a file that cannot be read at all comes back as
  /// [OcptProjectFileVerdict.unreadable], which is not a refusal — it is this gate saying it has
  /// nothing to state, leaving the open to report whatever it finds, exactly as it did before this
  /// existed.
  OcptProjectFileCompatibility probe({required String filePath, required int appSchemaVersion}) {
    try {
      final database = sqlite3.open(filePath, mode: OpenMode.readOnly);
      try {
        final fileSchemaVersion = _userVersion(database);

        // A database states 0 until something writes a version into it: a file freshly created, or
        // one that belongs to another application entirely. Neither is an older project — reading
        // it as one would offer to migrate a file that has nothing to migrate.
        if (fileSchemaVersion <= 0) {
          return OcptProjectFileCompatibility(
            filePath: filePath,
            fileSchemaVersion: 0,
            appSchemaVersion: appSchemaVersion,
            verdict: OcptProjectFileVerdict.unreadable,
          );
        }

        final verdict = switch (fileSchemaVersion) {
          _ when fileSchemaVersion > appSchemaVersion => OcptProjectFileVerdict.newer,
          _ when fileSchemaVersion < appSchemaVersion => OcptProjectFileVerdict.older,
          _ => OcptProjectFileVerdict.current,
        };

        return OcptProjectFileCompatibility(
          filePath: filePath,
          fileSchemaVersion: fileSchemaVersion,
          appSchemaVersion: appSchemaVersion,
          appVersionAtCreation: _appVersionAtCreation(database),
          suggestedBackupPath: verdict == OcptProjectFileVerdict.older
              ? backupPathFor(filePath: filePath, fileSchemaVersion: fileSchemaVersion)
              : null,
          verdict: verdict,
        );
      } finally {
        database.dispose();
      }
    } catch (error) {
      appLogger().w("The format of the project file at $filePath can't be read: $error");
      return OcptProjectFileCompatibility(
        filePath: filePath,
        fileSchemaVersion: 0,
        appSchemaVersion: appSchemaVersion,
        verdict: OcptProjectFileVerdict.unreadable,
      );
    }
  }

  /// Where the copy of the project file at [filePath], still in format [fileSchemaVersion], is to
  /// be kept: beside the original, named after it, and free.
  ///
  /// A counter is appended rather than an existing backup overwritten — a project migrated twice
  /// (restored from an old drive, opened again) would otherwise lose the very copy the first
  /// migration promised to keep.
  ///
  /// Public because [probe] is what fills [OcptProjectFileCompatibility.suggestedBackupPath] with
  /// it, and a test asserting on the promise the dialog makes has to be able to state it too.
  String backupPathFor({required String filePath, required int fileSchemaVersion}) {
    final directory = p.dirname(filePath);
    final stem = p.basenameWithoutExtension(filePath);
    final extension = p.extension(filePath);

    var candidate = p.join(directory, "$stem.$_backupInfix$fileSchemaVersion$extension");
    var counter = 2;
    while (File(candidate).existsSync()) {
      candidate = p.join(directory, "$stem.$_backupInfix$fileSchemaVersion-$counter$extension");
      counter++;
    }

    return candidate;
  }

  /// Writes the copy of the project file at [filePath] to [backupPath], and says whether it is
  /// there.
  ///
  /// `VACUUM INTO` rather than a file copy, for the reason `OcptProjectPackageService` gives: it
  /// writes one consistent single file out of a database another connection may hold open, folds in
  /// whatever the write-ahead log still carries, and preserves `PRAGMA user_version` — which is
  /// what makes the copy a file the older build still opens. The source is opened **read-only**:
  /// the backup is taken precisely because the original is about to be changed, and taking it must
  /// not be what changes it.
  bool writeBackup({required String filePath, required String backupPath}) {
    try {
      Directory(p.dirname(backupPath)).createSync(recursive: true);

      final database = sqlite3.open(filePath, mode: OpenMode.readOnly);
      try {
        database.execute("VACUUM INTO ?", [backupPath]);
      } finally {
        database.dispose();
      }

      return true;
    } catch (error) {
      appLogger().e(
        "The project file at $filePath can't be copied to $backupPath before being "
        "migrated: $error",
      );
      return false;
    }
  }

  /// The app version stamped into [database]'s `project_info` when the project was created, or
  /// null when there is no such row to read.
  ///
  /// The table is asked for rather than assumed: this runs against a file at *any* format,
  /// including one from before that column existed and one that is not a project at all.
  String? _appVersionAtCreation(Database database) {
    final hasProjectInfo = database.select(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'project_info'",
    ).isNotEmpty;
    if (!hasProjectInfo) {
      return null;
    }

    final rows = database.select("SELECT app_version_at_creation FROM project_info LIMIT 1");
    if (rows.isEmpty) {
      return null;
    }

    return rows.first["app_version_at_creation"] as String?;
  }

  /// The `PRAGMA user_version` of [database]: the schema version the file states about itself.
  int _userVersion(Database database) =>
      database.select("PRAGMA user_version").first.values.first! as int;
}
