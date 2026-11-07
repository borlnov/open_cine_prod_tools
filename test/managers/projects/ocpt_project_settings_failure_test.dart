// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:drift/drift.dart' show HasResultSet, ResultSetImplementation, SimpleSelectStatement;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/logging/ocpt_logs_helper_builder.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_project_settings_ops.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_preview_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_language.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../../ocpt_result_expectations.dart';

/// A read of one setting of the open project, with the value the fixture holds for it.
typedef _Read = ({Future<OcptDatabaseResult<Object>> Function(OcptProjectsManager) call});

/// A write of one setting of the open project.
typedef _Write = ({Future<OcptDatabaseOutcome> Function(OcptProjectsManager) call});

/// A project database whose reads break an assertion, as a mistake of the programmer does.
class _AssertingDatabase extends OcptProjectDatabase {
  /// Class constructor
  _AssertingDatabase() : super.memory();

  /// Break an assertion as a read built wrongly does.
  @override
  SimpleSelectStatement<T, R> select<T extends HasResultSet, R>(
    ResultSetImplementation<T, R> table, {
    bool distinct = false,
  }) => throw AssertionError("built wrongly");
}

/// What the settings of the open project answer when the project file fails them, or when the
/// read-only preview refuses a write: a failure status with the type of what failed and nothing
/// written, then the same call going through once the refusal is lifted.
void main() {
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager manager;
  late Directory tempDir;

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_project_settings_failure_");
    manager = OcptProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: () => "en",
    );
    await manager.initLifeCycle();
    await manager.createProject(name: "My Movie", filePath: p.join(tempDir.path, "movie.ocpt"));
  });

  tearDown(() async {
    await manager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Run [statement] on the open project's database.
  Future<void> run(String statement) => manager.currentProject!.database.customStatement(statement);

  /// Read the whole `project_info` row of the open project, through [database].
  Future<OcptProjectInfoRow> infoOf(OcptProjectDatabase database) =>
      database.select(database.ocptProjectInfoTable).getSingle();

  final reads = <String, _Read>{
    "loadCurrentProjectPageFormat": (call: (m) => m.loadCurrentProjectPageFormat()),
    "loadCurrentProjectCurrencyCode": (call: (m) => m.loadCurrentProjectCurrencyCode()),
    "loadCurrentProjectMinimumRestMinutes": (call: (m) => m.loadCurrentProjectMinimumRestMinutes()),
    "loadCurrentProjectScreenplayLanguage": (call: (m) => m.loadCurrentProjectScreenplayLanguage()),
    "loadCurrentProjectDefaultVatRateBasisPoints": (
      call: (m) => m.loadCurrentProjectDefaultVatRateBasisPoints(),
    ),
    "loadCurrentProjectMealPriceCents": (call: (m) => m.loadCurrentProjectMealPriceCents()),
    "loadCurrentProjectSnackPriceCents": (call: (m) => m.loadCurrentProjectSnackPriceCents()),
  };

  final writes = <String, _Write>{
    "saveCurrentProjectPageFormat": (
      call: (m) => m.saveCurrentProjectPageFormat(OcptPageFormat.a4),
    ),
    "saveCurrentProjectCurrencyCode": (call: (m) => m.saveCurrentProjectCurrencyCode("GBP")),
    "saveCurrentProjectMinimumRestMinutes": (
      call: (m) => m.saveCurrentProjectMinimumRestMinutes(660),
    ),
    "saveCurrentProjectScreenplayLanguage": (
      call: (m) => m.saveCurrentProjectScreenplayLanguage(OcptScreenplayLanguage.fr),
    ),
    "saveCurrentProjectDefaultVatRateBasisPoints": (
      call: (m) => m.saveCurrentProjectDefaultVatRateBasisPoints(2000),
    ),
    "saveCurrentProjectMealPriceCents": (call: (m) => m.saveCurrentProjectMealPriceCents(1200)),
    "saveCurrentProjectSnackPriceCents": (call: (m) => m.saveCurrentProjectSnackPriceCents(400)),
  };

  group("with a project file that fails the call", () {
    for (final entry in reads.entries) {
      test("${entry.key} answers a database error when the table cannot be read", () async {
        await run("ALTER TABLE project_info RENAME TO project_info_gone");

        final result = await entry.value.call(manager);

        expect(result.status, OcptDatabaseStatus.databaseError);
        expect(result.extraInfo, isA<Type>());
        expect(result.value, isNull);
      });
    }

    for (final entry in writes.entries) {
      test("${entry.key} answers a database error and writes nothing, then goes through", () async {
        final database = manager.currentProject!.database;
        final before = await infoOf(database);
        await run(
          "CREATE TRIGGER refuse_update BEFORE UPDATE ON project_info "
          "BEGIN SELECT RAISE(ABORT, 'refused'); END",
        );

        final refused = await entry.value.call(manager);

        expect(refused.status, OcptDatabaseStatus.databaseError);
        expect(refused.extraInfo, isA<Type>());
        expect(await infoOf(database), before);

        await run("DROP TRIGGER refuse_update");
        await entry.value.call(manager).okOrFail;

        expect(await infoOf(database), isNot(before));
      });

      test("${entry.key} answers a database error when the table is gone", () async {
        await run("ALTER TABLE project_info RENAME TO project_info_gone");

        final result = await entry.value.call(manager);

        expect(result.status, OcptDatabaseStatus.databaseError);
      });
    }

    test("a write refused by one trigger leaves the other settings as they were", () async {
      final database = manager.currentProject!.database;
      await manager.saveCurrentProjectCurrencyCode("USD").okOrFail;
      final before = await infoOf(database);
      await run(
        "CREATE TRIGGER refuse_update BEFORE UPDATE ON project_info "
        "WHEN NEW.page_format IS NOT OLD.page_format "
        "BEGIN SELECT RAISE(ABORT, 'refused'); END",
      );

      final refused = await manager.saveCurrentProjectPageFormat(OcptPageFormat.a4);
      final allowed = await manager.saveCurrentProjectCurrencyCode("EUR");

      expect(refused.status, OcptDatabaseStatus.databaseError);
      expect(allowed.status, OcptDatabaseStatus.ok);
      expect((await infoOf(database)).pageFormat, before.pageFormat);
      expect((await infoOf(database)).currencyCode, "EUR");
    });
  });

  group("with no project open", () {
    setUp(() async {
      await manager.closeCurrentProject().okOrFail;
    });

    for (final entry in reads.entries) {
      test("${entry.key} answers ok with no value", () async {
        final result = await entry.value.call(manager);

        expect(result.status, OcptDatabaseStatus.ok);
        expect(result.value, isNull);
      });
    }

    for (final entry in writes.entries) {
      test("${entry.key} answers ok", () async {
        await entry.value.call(manager).okOrFail;
      });
    }
  });

  group("under a read-only preview", () {
    late OcptProjectDatabase fileDatabase;
    late OcptProjectInfoRow fileBefore;
    late OcptProjectInfoRow previewBefore;

    setUp(() async {
      final version = await manager.createProjectVersion(name: "v1", note: "").valueOrFail;
      expect((await manager.previewVersion(version.id)).status, OcptProjectPreviewStatus.ok);
      final project = manager.currentProject!;
      fileDatabase = project.fileDatabase;
      fileBefore = await infoOf(fileDatabase);
      previewBefore = await infoOf(project.database);
    });

    for (final entry in writes.entries) {
      test("${entry.key} answers ok and writes nothing, in the preview or the file", () async {
        await entry.value.call(manager).okOrFail;

        expect(await infoOf(manager.currentProject!.database), previewBefore);
        expect(await infoOf(fileDatabase), fileBefore);
      });
    }

    for (final entry in reads.entries) {
      test("${entry.key} still reads the preview", () async {
        final result = await entry.value.call(manager);

        expect(result.status, OcptDatabaseStatus.ok);
      });
    }
  });

  test("a mistake of the programmer goes through instead of becoming a status", () async {
    final database = _AssertingDatabase();
    addTearDown(database.close);
    final project = OcptOpenProjectModel(
      path: p.join(tempDir.path, "other.ocpt"),
      name: "Other",
      primaryScreenplayId: "screenplay",
      database: database,
    );

    await expectLater(
      OcptProjectSettingsOps.loadCurrentProjectPageFormat(
        project: project,
        logger: buildOcptLogsHelper("test"),
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}
