// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_file_compatibility_service.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_file_verdict.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

void main() {
  // The service reports what it can't read through appLogger(), which requires a global manager
  // instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  const service = OcptProjectFileCompatibilityService();

  // The schema version the build under test is pretending to write. A literal rather than
  // `OcptProjectDatabase.currentSchemaVersion`: what this service does with a number is the whole
  // of what is being tested, and it must not stop testing it the day that number moves.
  const appSchemaVersion = 19;

  // The version the build under test is pretending to be: a stable release, so most cases don't
  // have to think about the writer identity at all.
  const appVersion = "0.2.0";

  late Directory workspace;

  /// Writes a SQLite file called [name] stating [userVersion], and returns its path.
  ///
  /// Built by hand rather than through drift on purpose: this service is the one thing in the app
  /// that runs *before* drift, against files no build of this app may ever have written.
  String writeDatabase(
    String name, {
    required int userVersion,
    String? appVersionAtCreation,
    String? migratedByAppVersion,
    bool withProjectInfo = true,
    bool withMigratedByColumn = true,
  }) {
    final path = p.join(workspace.path, name);
    final database = sqlite3.open(path);

    if (withProjectInfo) {
      final migratedByColumn = withMigratedByColumn ? ", migrated_by_app_version TEXT" : "";
      database.execute(
        "CREATE TABLE project_info (name TEXT, app_version_at_creation TEXT$migratedByColumn)",
      );
      if (withMigratedByColumn) {
        database.execute(
          "INSERT INTO project_info (name, app_version_at_creation, migrated_by_app_version) "
          "VALUES (?, ?, ?)",
          ["Les Vagues", appVersionAtCreation, migratedByAppVersion],
        );
      } else {
        database.execute(
          "INSERT INTO project_info (name, app_version_at_creation) VALUES (?, ?)",
          ["Les Vagues", appVersionAtCreation],
        );
      }
    } else {
      database.execute("CREATE TABLE notes (line TEXT)");
    }

    // `PRAGMA user_version` takes no parameter, and the value is an int this test states itself.
    database
      ..execute("PRAGMA user_version = $userVersion")
      ..dispose();

    return path;
  }

  setUp(() {
    workspace = Directory.systemTemp.createTempSync("ocpt_compatibility_test_");
  });

  tearDown(() {
    workspace.deleteSync(recursive: true);
  });

  group("probing a file's format", () {
    test("opens a file at this build's own format as it is, unstamped", () {
      final path = writeDatabase(
        "movie.ocpt",
        userVersion: appSchemaVersion,
        appVersionAtCreation: "0.1.0",
      );

      final compatibility = service.probe(
        filePath: path,
        appSchemaVersion: appSchemaVersion,
        appVersion: appVersion,
      );

      expect(compatibility.verdict, OcptProjectFileVerdict.current);
      expect(compatibility.fileSchemaVersion, appSchemaVersion);
      expect(compatibility.appSchemaVersion, appSchemaVersion);
      expect(compatibility.appVersionAtCreation, "0.1.0");
      expect(
        compatibility.migratedByAppVersion,
        isNull,
        reason: "an unstamped file falls back to schema-only, and opens as before",
      );
      expect(compatibility.isRunningBuildPreRelease, isFalse);
      expect(
        compatibility.suggestedBackupPath,
        isNull,
        reason: "nothing is about to change, so there is no copy to promise",
      );
    });

    test("opens a file at this build's own format, written by this exact build", () {
      final path = writeDatabase(
        "movie.ocpt",
        userVersion: appSchemaVersion,
        migratedByAppVersion: appVersion,
      );

      final compatibility = service.probe(
        filePath: path,
        appSchemaVersion: appSchemaVersion,
        appVersion: appVersion,
      );

      expect(compatibility.verdict, OcptProjectFileVerdict.current);
      expect(compatibility.migratedByAppVersion, appVersion);
    });

    test("opens a file at this build's own format when both builds are stable", () {
      final path = writeDatabase(
        "movie.ocpt",
        userVersion: appSchemaVersion,
        migratedByAppVersion: "0.1.0",
      );

      final compatibility = service.probe(
        filePath: path,
        appSchemaVersion: appSchemaVersion,
        appVersion: "0.2.1",
      );

      expect(
        compatibility.verdict,
        OcptProjectFileVerdict.current,
        reason: "a same-schema patch release changed no schema: same number, same frozen shape",
      );
      expect(compatibility.migratedByAppVersion, "0.1.0");
      expect(compatibility.isRunningBuildPreRelease, isFalse);
    });

    test("refuses a file at this build's own format written by a different pre-release build", () {
      final path = writeDatabase(
        "movie.ocpt",
        userVersion: appSchemaVersion,
        migratedByAppVersion: "0.2.0-alpha.1",
      );

      final compatibility = service.probe(
        filePath: path,
        appSchemaVersion: appSchemaVersion,
        appVersion: "0.2.0-alpha.2",
      );

      expect(compatibility.verdict, OcptProjectFileVerdict.foreignDevBuild);
      expect(compatibility.migratedByAppVersion, "0.2.0-alpha.1");
      expect(compatibility.isRunningBuildPreRelease, isTrue);
      expect(
        compatibility.suggestedBackupPath,
        isNull,
        reason: "a refused file is never migrated, so there is nothing to copy",
      );
    });

    test(
      "refuses a file at this build's own format written by a pre-release when this build is "
      "stable",
      () {
        final path = writeDatabase(
          "movie.ocpt",
          userVersion: appSchemaVersion,
          migratedByAppVersion: "0.2.0-alpha.1",
        );

        final compatibility = service.probe(
          filePath: path,
          appSchemaVersion: appSchemaVersion,
          appVersion: appVersion,
        );

        expect(compatibility.verdict, OcptProjectFileVerdict.foreignDevBuild);
        expect(compatibility.migratedByAppVersion, "0.2.0-alpha.1");
        expect(compatibility.isRunningBuildPreRelease, isFalse);
      },
    );

    test("asks for a migration on an older file, and says where the copy goes", () {
      final path = writeDatabase("movie.ocpt", userVersion: 18, appVersionAtCreation: "0.1.0");

      final compatibility = service.probe(
        filePath: path,
        appSchemaVersion: appSchemaVersion,
        appVersion: appVersion,
      );

      expect(compatibility.verdict, OcptProjectFileVerdict.older);
      expect(compatibility.fileSchemaVersion, 18);
      expect(compatibility.suggestedBackupPath, p.join(workspace.path, "movie.backup-v18.ocpt"));
      expect(compatibility.isRunningBuildPreRelease, isFalse);
    });

    test("carries the pre-release flag of a dev build migrating an older file", () {
      final path = writeDatabase("movie.ocpt", userVersion: 18, appVersionAtCreation: "0.1.0");

      final compatibility = service.probe(
        filePath: path,
        appSchemaVersion: appSchemaVersion,
        appVersion: "0.2.0-3-g87a9b8d",
      );

      expect(compatibility.verdict, OcptProjectFileVerdict.older);
      expect(compatibility.isRunningBuildPreRelease, isTrue);
    });

    test("refuses a file from a newer build, and names the build that made it", () {
      final path = writeDatabase("movie.ocpt", userVersion: 42, appVersionAtCreation: "0.9.0");

      final compatibility = service.probe(
        filePath: path,
        appSchemaVersion: appSchemaVersion,
        appVersion: appVersion,
      );

      expect(compatibility.verdict, OcptProjectFileVerdict.newer);
      expect(compatibility.fileSchemaVersion, 42);
      expect(compatibility.appVersionAtCreation, "0.9.0");
      expect(
        compatibility.suggestedBackupPath,
        isNull,
        reason: "a file that is never opened is never copied either",
      );
    });

    test("still reads both formats when there is no project_info to read a version from", () {
      final path = writeDatabase("movie.ocpt", userVersion: 42, withProjectInfo: false);

      final compatibility = service.probe(
        filePath: path,
        appSchemaVersion: appSchemaVersion,
        appVersion: appVersion,
      );

      expect(compatibility.verdict, OcptProjectFileVerdict.newer);
      expect(compatibility.fileSchemaVersion, 42);
      expect(compatibility.appVersionAtCreation, isNull);
      expect(compatibility.migratedByAppVersion, isNull);
    });

    test("still reads both formats when project_info predates the writer identity column", () {
      final path = writeDatabase(
        "movie.ocpt",
        userVersion: appSchemaVersion,
        appVersionAtCreation: "0.1.0",
        withMigratedByColumn: false,
      );

      final compatibility = service.probe(
        filePath: path,
        appSchemaVersion: appSchemaVersion,
        appVersion: appVersion,
      );

      expect(compatibility.verdict, OcptProjectFileVerdict.current);
      expect(compatibility.migratedByAppVersion, isNull);
    });

    test("states nothing about a database carrying no format of its own", () {
      final path = writeDatabase("fresh.ocpt", userVersion: 0);

      final compatibility = service.probe(
        filePath: path,
        appSchemaVersion: appSchemaVersion,
        appVersion: appVersion,
      );

      expect(
        compatibility.verdict,
        OcptProjectFileVerdict.unreadable,
        reason: "a database at version 0 is a fresh or foreign one, never an older project",
      );
      expect(compatibility.fileSchemaVersion, 0);
    });

    test("states nothing about a file that is not a database at all", () {
      final path = p.join(workspace.path, "notes.txt");
      File(path).writeAsStringSync("this is not a database");

      final compatibility = service.probe(
        filePath: path,
        appSchemaVersion: appSchemaVersion,
        appVersion: appVersion,
      );

      expect(compatibility.verdict, OcptProjectFileVerdict.unreadable);
      expect(compatibility.filePath, path);
    });

    test("states nothing about a file that isn't there", () {
      final compatibility = service.probe(
        filePath: p.join(workspace.path, "gone.ocpt"),
        appSchemaVersion: appSchemaVersion,
        appVersion: appVersion,
      );

      expect(compatibility.verdict, OcptProjectFileVerdict.unreadable);
    });
  });

  group("naming the backup", () {
    test("puts it beside the original, keeping the extension the older build knows", () {
      expect(
        service.backupPathFor(
          filePath: p.join(workspace.path, "Les Vagues.ocpt"),
          fileSchemaVersion: 18,
        ),
        p.join(workspace.path, "Les Vagues.backup-v18.ocpt"),
      );
    });

    test("counts up rather than overwriting a backup already there", () {
      final filePath = p.join(workspace.path, "movie.ocpt");
      File(p.join(workspace.path, "movie.backup-v18.ocpt")).writeAsStringSync("first");

      expect(
        service.backupPathFor(filePath: filePath, fileSchemaVersion: 18),
        p.join(workspace.path, "movie.backup-v18-2.ocpt"),
      );

      File(p.join(workspace.path, "movie.backup-v18-2.ocpt")).writeAsStringSync("second");

      expect(
        service.backupPathFor(filePath: filePath, fileSchemaVersion: 18),
        p.join(workspace.path, "movie.backup-v18-3.ocpt"),
      );
    });
  });

  group("writing the backup", () {
    test("keeps a copy still in the old format, and leaves the original untouched", () {
      final path = writeDatabase("movie.ocpt", userVersion: 18, appVersionAtCreation: "0.1.0");
      final backupPath = service.backupPathFor(filePath: path, fileSchemaVersion: 18);
      final originalBytes = File(path).readAsBytesSync();

      expect(service.writeBackup(filePath: path, backupPath: backupPath), isTrue);

      expect(
        File(path).readAsBytesSync(),
        originalBytes,
        reason: "the copy is taken because the original is about to change, and taking it must "
            "not be what changes it",
      );

      final backup = sqlite3.open(backupPath, mode: OpenMode.readOnly);
      addTearDown(backup.dispose);

      expect(backup.select("PRAGMA user_version").first.values.first, 18);
      expect(backup.select("SELECT name FROM project_info").first["name"], "Les Vagues");
    });

    test("reports a copy it couldn't take rather than raising it", () {
      expect(
        service.writeBackup(
          filePath: p.join(workspace.path, "gone.ocpt"),
          backupPath: p.join(workspace.path, "gone.backup-v18.ocpt"),
        ),
        isFalse,
      );
    });
  });
}
