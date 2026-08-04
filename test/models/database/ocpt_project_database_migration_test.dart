// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_availability_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/utils/ocpt_weekday_mask.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

// The exact `CREATE TABLE` statements drift generated for schema version 1 (captured from
// `ocpt_project_database.g.dart` before the shot list tables were added), used to build a v1
// fixture from scratch rather than through drift itself. Keeping this verbatim, rather than
// reconstructing it from the current table declarations, is what makes this test prove a real
// upgrade path instead of just a fresh `onCreate`.
const _v1Ddl = '''
CREATE TABLE "project_info" ("id" INTEGER NOT NULL DEFAULT 1, "name" TEXT NOT NULL, "created_at" TEXT NOT NULL, "app_version_at_creation" TEXT NOT NULL, "page_format" TEXT NOT NULL, "settings_json" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "screenplays" ("id" TEXT NOT NULL, "title" TEXT NOT NULL, "fountain_text" TEXT NOT NULL DEFAULT '', "updated_at" TEXT NOT NULL, PRIMARY KEY ("id"));
CREATE TABLE "screenplay_snapshots" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "created_at" TEXT NOT NULL, "reason" TEXT NOT NULL, "fountain_text" TEXT NOT NULL, PRIMARY KEY ("id"));
CREATE TABLE "scenes" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "position" INTEGER NOT NULL, "heading" TEXT NOT NULL, "scene_number" TEXT NULL, "char_start" INTEGER NOT NULL, "char_end" INTEGER NOT NULL, PRIMARY KEY ("id"));
''';

// The same, for schema version 2: the v1 tables plus the three shot list ones, all of them still
// without the sync-ready columns version 3 adds (`is_deleted` everywhere, `sort_key` on the two
// ordered tables) and without `row_field_versions`.
const _v2Ddl = '''
$_v1Ddl
CREATE TABLE "shots" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "scene_id" TEXT NULL REFERENCES scenes (id), "orphaned_heading" TEXT NULL, "position" INTEGER NOT NULL, "shot_size" TEXT NOT NULL DEFAULT '', "framing" TEXT NOT NULL DEFAULT '', "camera_move" TEXT NOT NULL DEFAULT '', "lens" TEXT NOT NULL DEFAULT '', "recording_format" TEXT NOT NULL DEFAULT '', "estimated_duration_ms" INTEGER NULL, "shooting_day" TEXT NULL, "planned_takes" INTEGER NULL, "sound" TEXT NOT NULL DEFAULT '', "status" TEXT NOT NULL DEFAULT 'toShoot', "difficulty_set" INTEGER NOT NULL DEFAULT 1, "difficulty_camera" INTEGER NOT NULL DEFAULT 1, "difficulty_acting" INTEGER NOT NULL DEFAULT 1, "difficulty_sound" INTEGER NOT NULL DEFAULT 1, "notes" TEXT NOT NULL DEFAULT '', "location_notes" TEXT NOT NULL DEFAULT '', "needs_check" INTEGER NOT NULL DEFAULT 0 CHECK ("needs_check" IN (0, 1)), "check_reason" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "shot_characters" ("shot_id" TEXT NOT NULL REFERENCES shots (id), "character_name" TEXT NOT NULL, "position" INTEGER NOT NULL, PRIMARY KEY ("shot_id", "character_name"));
CREATE TABLE "shot_coverages" ("id" TEXT NOT NULL, "shot_id" TEXT NOT NULL REFERENCES shots (id), "scene_id" TEXT NOT NULL REFERENCES scenes (id), "start_offset" INTEGER NOT NULL, "end_offset" INTEGER NOT NULL, "covered_text_digest" TEXT NOT NULL, PRIMARY KEY ("id"));
''';

// The same, for schema version 3: every table carrying its sync-ready columns (`is_deleted`
// everywhere, `sort_key` on the two ordered tables) and the `row_field_versions` sidecar, but the
// `shots` table still without the `abbreviation` column version 4 adds, and no `project_versions`
// table nor the `project_info.current_version_id` column pointing into it, both of which version 5
// adds.
const _v3Ddl = '''
CREATE TABLE "project_info" ("id" INTEGER NOT NULL DEFAULT 1, "name" TEXT NOT NULL, "created_at" TEXT NOT NULL, "app_version_at_creation" TEXT NOT NULL, "page_format" TEXT NOT NULL, "settings_json" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "screenplays" ("id" TEXT NOT NULL, "title" TEXT NOT NULL, "fountain_text" TEXT NOT NULL DEFAULT '', "updated_at" TEXT NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "screenplay_snapshots" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "created_at" TEXT NOT NULL, "reason" TEXT NOT NULL, "fountain_text" TEXT NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "scenes" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "position" INTEGER NOT NULL, "heading" TEXT NOT NULL, "scene_number" TEXT NULL, "char_start" INTEGER NOT NULL, "char_end" INTEGER NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shots" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "scene_id" TEXT NULL REFERENCES scenes (id), "orphaned_heading" TEXT NULL, "position" INTEGER NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "shot_size" TEXT NOT NULL DEFAULT '', "framing" TEXT NOT NULL DEFAULT '', "camera_move" TEXT NOT NULL DEFAULT '', "lens" TEXT NOT NULL DEFAULT '', "recording_format" TEXT NOT NULL DEFAULT '', "estimated_duration_ms" INTEGER NULL, "shooting_day" TEXT NULL, "planned_takes" INTEGER NULL, "sound" TEXT NOT NULL DEFAULT '', "status" TEXT NOT NULL DEFAULT 'toShoot', "difficulty_set" INTEGER NOT NULL DEFAULT 1, "difficulty_camera" INTEGER NOT NULL DEFAULT 1, "difficulty_acting" INTEGER NOT NULL DEFAULT 1, "difficulty_sound" INTEGER NOT NULL DEFAULT 1, "notes" TEXT NOT NULL DEFAULT '', "location_notes" TEXT NOT NULL DEFAULT '', "needs_check" INTEGER NOT NULL DEFAULT 0 CHECK ("needs_check" IN (0, 1)), "check_reason" TEXT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shot_characters" ("shot_id" TEXT NOT NULL REFERENCES shots (id), "character_name" TEXT NOT NULL, "position" INTEGER NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("shot_id", "character_name"));
CREATE TABLE "shot_coverages" ("id" TEXT NOT NULL, "shot_id" TEXT NOT NULL REFERENCES shots (id), "scene_id" TEXT NOT NULL REFERENCES scenes (id), "start_offset" INTEGER NOT NULL, "end_offset" INTEGER NOT NULL, "covered_text_digest" TEXT NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "row_field_versions" ("table_name" TEXT NOT NULL, "row_id" TEXT NOT NULL, "column_name" TEXT NOT NULL, "version" INTEGER NOT NULL, "device_id" TEXT NOT NULL, PRIMARY KEY ("table_name", "row_id", "column_name"));
''';

// And for schema version 4: every table of version 3, `shots` gaining the `abbreviation` column at
// the end, where `ALTER TABLE … ADD COLUMN` puts it. This is the shape `v0.1.0-alpha.2` shipped and
// stamped `PRAGMA user_version = 4` into: version 4 belongs to the scenario coverage export's
// abbreviation, and never to the project versions, which land in version 5 whatever the file
// carried before.
const _v4Ddl = '''
CREATE TABLE "project_info" ("id" INTEGER NOT NULL DEFAULT 1, "name" TEXT NOT NULL, "created_at" TEXT NOT NULL, "app_version_at_creation" TEXT NOT NULL, "page_format" TEXT NOT NULL, "settings_json" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "screenplays" ("id" TEXT NOT NULL, "title" TEXT NOT NULL, "fountain_text" TEXT NOT NULL DEFAULT '', "updated_at" TEXT NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "screenplay_snapshots" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "created_at" TEXT NOT NULL, "reason" TEXT NOT NULL, "fountain_text" TEXT NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "scenes" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "position" INTEGER NOT NULL, "heading" TEXT NOT NULL, "scene_number" TEXT NULL, "char_start" INTEGER NOT NULL, "char_end" INTEGER NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shots" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "scene_id" TEXT NULL REFERENCES scenes (id), "orphaned_heading" TEXT NULL, "position" INTEGER NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "shot_size" TEXT NOT NULL DEFAULT '', "framing" TEXT NOT NULL DEFAULT '', "camera_move" TEXT NOT NULL DEFAULT '', "lens" TEXT NOT NULL DEFAULT '', "recording_format" TEXT NOT NULL DEFAULT '', "estimated_duration_ms" INTEGER NULL, "shooting_day" TEXT NULL, "planned_takes" INTEGER NULL, "sound" TEXT NOT NULL DEFAULT '', "status" TEXT NOT NULL DEFAULT 'toShoot', "difficulty_set" INTEGER NOT NULL DEFAULT 1, "difficulty_camera" INTEGER NOT NULL DEFAULT 1, "difficulty_acting" INTEGER NOT NULL DEFAULT 1, "difficulty_sound" INTEGER NOT NULL DEFAULT 1, "notes" TEXT NOT NULL DEFAULT '', "location_notes" TEXT NOT NULL DEFAULT '', "needs_check" INTEGER NOT NULL DEFAULT 0 CHECK ("needs_check" IN (0, 1)), "check_reason" TEXT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "abbreviation" TEXT NOT NULL DEFAULT '', PRIMARY KEY ("id"));
CREATE TABLE "shot_characters" ("shot_id" TEXT NOT NULL REFERENCES shots (id), "character_name" TEXT NOT NULL, "position" INTEGER NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("shot_id", "character_name"));
CREATE TABLE "shot_coverages" ("id" TEXT NOT NULL, "shot_id" TEXT NOT NULL REFERENCES shots (id), "scene_id" TEXT NOT NULL REFERENCES scenes (id), "start_offset" INTEGER NOT NULL, "end_offset" INTEGER NOT NULL, "covered_text_digest" TEXT NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "row_field_versions" ("table_name" TEXT NOT NULL, "row_id" TEXT NOT NULL, "column_name" TEXT NOT NULL, "version" INTEGER NOT NULL, "device_id" TEXT NOT NULL, PRIMARY KEY ("table_name", "row_id", "column_name"));
''';

// And for schema version 5: `project_versions` created with `content_digest` already declared on
// it (the v4/v5 collision described in `docs/adr/0007-schema-migration-policy.md` was folded into
// a single version 5 rather than shipped as two separate steps), plus `project_info` gaining its
// `current_version_id` pointer. This is the shape `onCreate` produced for every schema version 5
// build (captured through a real `OcptProjectDatabase`, not hand-written, for the same reason the
// column order of every fixture above matters), and it still lacks every resources table version 6
// adds.
const _v5Ddl = '''
CREATE TABLE "project_info" ("id" INTEGER NOT NULL DEFAULT 1, "name" TEXT NOT NULL, "created_at" TEXT NOT NULL, "app_version_at_creation" TEXT NOT NULL, "page_format" TEXT NOT NULL, "settings_json" TEXT NULL, "current_version_id" TEXT NULL REFERENCES project_versions (id), PRIMARY KEY ("id"));
CREATE TABLE "project_versions" ("id" TEXT NOT NULL, "name" TEXT NOT NULL, "note" TEXT NOT NULL DEFAULT '', "created_at" TEXT NOT NULL, "app_version" TEXT NOT NULL, "payload_format" INTEGER NOT NULL, "payload" TEXT NOT NULL, "summary_json" TEXT NOT NULL, "created_by_device_id" TEXT NOT NULL, "content_digest" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "row_field_versions" ("table_name" TEXT NOT NULL, "row_id" TEXT NOT NULL, "column_name" TEXT NOT NULL, "version" INTEGER NOT NULL, "device_id" TEXT NOT NULL, PRIMARY KEY ("table_name", "row_id", "column_name"));
CREATE TABLE "scenes" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "position" INTEGER NOT NULL, "heading" TEXT NOT NULL, "scene_number" TEXT NULL, "char_start" INTEGER NOT NULL, "char_end" INTEGER NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "screenplay_snapshots" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "created_at" TEXT NOT NULL, "reason" TEXT NOT NULL, "fountain_text" TEXT NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "screenplays" ("id" TEXT NOT NULL, "title" TEXT NOT NULL, "fountain_text" TEXT NOT NULL DEFAULT '', "updated_at" TEXT NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shot_characters" ("shot_id" TEXT NOT NULL REFERENCES shots (id), "character_name" TEXT NOT NULL, "position" INTEGER NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("shot_id", "character_name"));
CREATE TABLE "shot_coverages" ("id" TEXT NOT NULL, "shot_id" TEXT NOT NULL REFERENCES shots (id), "scene_id" TEXT NOT NULL REFERENCES scenes (id), "start_offset" INTEGER NOT NULL, "end_offset" INTEGER NOT NULL, "covered_text_digest" TEXT NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shots" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "scene_id" TEXT NULL REFERENCES scenes (id), "orphaned_heading" TEXT NULL, "position" INTEGER NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "shot_size" TEXT NOT NULL DEFAULT '', "abbreviation" TEXT NOT NULL DEFAULT '', "framing" TEXT NOT NULL DEFAULT '', "camera_move" TEXT NOT NULL DEFAULT '', "lens" TEXT NOT NULL DEFAULT '', "recording_format" TEXT NOT NULL DEFAULT '', "estimated_duration_ms" INTEGER NULL, "shooting_day" TEXT NULL, "planned_takes" INTEGER NULL, "sound" TEXT NOT NULL DEFAULT '', "status" TEXT NOT NULL DEFAULT 'toShoot', "difficulty_set" INTEGER NOT NULL DEFAULT 1, "difficulty_camera" INTEGER NOT NULL DEFAULT 1, "difficulty_acting" INTEGER NOT NULL DEFAULT 1, "difficulty_sound" INTEGER NOT NULL DEFAULT 1, "notes" TEXT NOT NULL DEFAULT '', "location_notes" TEXT NOT NULL DEFAULT '', "needs_check" INTEGER NOT NULL DEFAULT 0 CHECK ("needs_check" IN (0, 1)), "check_reason" TEXT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
''';

// The twelve tables version 6 added on top of [_v5Ddl]: the resources mode as it first shipped,
// with no `location_availabilities` — a location could say when it was free only in the free text
// of its constraints. Captured through a real `OcptProjectDatabase`, like every fixture above.
const _v6ResourcesDdl = '''
CREATE TABLE "people" ("id" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "first_name" TEXT NOT NULL DEFAULT '', "last_name" TEXT NOT NULL DEFAULT '', "email" TEXT NOT NULL DEFAULT '', "phone" TEXT NOT NULL DEFAULT '', "address_line1" TEXT NOT NULL DEFAULT '', "address_line2" TEXT NOT NULL DEFAULT '', "postal_code" TEXT NOT NULL DEFAULT '', "city" TEXT NOT NULL DEFAULT '', "region" TEXT NOT NULL DEFAULT '', "country" TEXT NOT NULL DEFAULT '', "color_index" INTEGER NOT NULL DEFAULT 0, "birth_date" TEXT NULL, "minor_notes" TEXT NOT NULL DEFAULT '', "is_transport_autonomous" INTEGER NULL CHECK ("is_transport_autonomous" IN (0, 1)), "accommodation_notes" TEXT NOT NULL DEFAULT '', "travel_notes" TEXT NOT NULL DEFAULT '', "dietary_notes" TEXT NOT NULL DEFAULT '', "allergies" TEXT NOT NULL DEFAULT '', "measurement_height" TEXT NOT NULL DEFAULT '', "measurement_chest" TEXT NOT NULL DEFAULT '', "measurement_waist" TEXT NOT NULL DEFAULT '', "measurement_hips" TEXT NOT NULL DEFAULT '', "size_top" TEXT NOT NULL DEFAULT '', "size_bottom" TEXT NOT NULL DEFAULT '', "size_shoes" TEXT NOT NULL DEFAULT '', "hmc_notes" TEXT NOT NULL DEFAULT '', "image_rights_status" TEXT NOT NULL DEFAULT 'notApplicable', "image_rights_date" TEXT NULL, "image_rights_asset_id" TEXT NULL REFERENCES assets (id), "photo_asset_id" TEXT NULL REFERENCES assets (id), "notes" TEXT NOT NULL DEFAULT '', PRIMARY KEY ("id"));
CREATE TABLE "person_positions" ("id" TEXT NOT NULL, "person_id" TEXT NOT NULL REFERENCES people (id), "position_id" TEXT NOT NULL DEFAULT '', "custom_label" TEXT NOT NULL DEFAULT '', "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "person_skills" ("id" TEXT NOT NULL, "person_id" TEXT NOT NULL REFERENCES people (id), "label" TEXT NOT NULL DEFAULT '', "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "person_unavailabilities" ("id" TEXT NOT NULL, "person_id" TEXT NOT NULL REFERENCES people (id), "start_date" TEXT NOT NULL, "end_date" TEXT NOT NULL, "slot" TEXT NOT NULL DEFAULT 'fullDay', "start_minute" INTEGER NULL, "end_minute" INTEGER NULL, "reason" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "roles" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "name" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "person_id" TEXT NULL REFERENCES people (id), "kind" TEXT NOT NULL, "is_from_screenplay" INTEGER NOT NULL DEFAULT 0 CHECK ("is_from_screenplay" IN (0, 1)), "orphaned_name" TEXT NULL, "casting_notes" TEXT NOT NULL DEFAULT '', PRIMARY KEY ("id"));
CREATE TABLE "locations" ("id" TEXT NOT NULL, "name" TEXT NOT NULL, "color_index" INTEGER NOT NULL DEFAULT 0, "address_line1" TEXT NOT NULL DEFAULT '', "address_line2" TEXT NOT NULL DEFAULT '', "postal_code" TEXT NOT NULL DEFAULT '', "city" TEXT NOT NULL DEFAULT '', "region" TEXT NOT NULL DEFAULT '', "country" TEXT NOT NULL DEFAULT '', "latitude" REAL NULL, "longitude" REAL NULL, "contact_person_id" TEXT NULL, "contact_notes" TEXT NOT NULL DEFAULT '', "permit_status" TEXT NOT NULL DEFAULT 'toRequest', "permit_label" TEXT NOT NULL DEFAULT '', "permit_date" TEXT NULL, "permit_asset_id" TEXT NULL, "parking_notes" TEXT NOT NULL DEFAULT '', "power_notes" TEXT NOT NULL DEFAULT '', "facilities_notes" TEXT NOT NULL DEFAULT '', "constraints_notes" TEXT NOT NULL DEFAULT '', "notes" TEXT NOT NULL DEFAULT '', "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "sets" ("id" TEXT NOT NULL, "location_id" TEXT NOT NULL REFERENCES locations (id), "code" TEXT NOT NULL DEFAULT '', "name" TEXT NOT NULL, "notes" TEXT NOT NULL DEFAULT '', "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "scene_sets" ("id" TEXT NOT NULL, "scene_id" TEXT NOT NULL REFERENCES scenes (id), "set_id" TEXT NOT NULL REFERENCES sets (id), "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "elements" ("id" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "category" TEXT NOT NULL, "sub_category" TEXT NOT NULL DEFAULT '', "name" TEXT NOT NULL, "code" TEXT NOT NULL DEFAULT '', "quantity" TEXT NOT NULL DEFAULT '', "source_kind" TEXT NOT NULL, "owner_person_id" TEXT NULL, "owner_notes" TEXT NOT NULL DEFAULT '', "brought_by_person_id" TEXT NULL, "storage_notes" TEXT NOT NULL DEFAULT '', "is_secured" INTEGER NOT NULL DEFAULT 0 CHECK ("is_secured" IN (0, 1)), "is_ready_for_shoot" INTEGER NOT NULL DEFAULT 0 CHECK ("is_ready_for_shoot" IN (0, 1)), "is_returned" INTEGER NOT NULL DEFAULT 0 CHECK ("is_returned" IN (0, 1)), "cost" INTEGER NULL, "purpose_notes" TEXT NOT NULL DEFAULT '', "notes" TEXT NOT NULL DEFAULT '', "photo_asset_id" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "scene_elements" ("id" TEXT NOT NULL, "scene_id" TEXT NOT NULL REFERENCES scenes (id), "element_id" TEXT NOT NULL REFERENCES elements (id), "quantity" TEXT NOT NULL DEFAULT '', "notes" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "assets" ("id" TEXT NOT NULL, "kind" TEXT NOT NULL, "path" TEXT NOT NULL, "label" TEXT NOT NULL DEFAULT '', "added_at" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "person_id" TEXT NULL, "location_id" TEXT NULL REFERENCES locations (id), "element_id" TEXT NULL REFERENCES elements (id), PRIMARY KEY ("id"));
CREATE TABLE "local_erasures" ("person_id" TEXT NOT NULL REFERENCES people (id), "erased_at" TEXT NOT NULL, PRIMARY KEY ("person_id"));
''';

// The one table version 7 added on top of [_v5Ddl]/[_v6ResourcesDdl]: `location_availabilities`,
// the dated windows during which a location may be shot in. Captured through a real
// `OcptProjectDatabase`, like every fixture above. `project_info` here still lacks
// `currency_code`, which version 8 adds.
const _v7LocationAvailabilitiesDdl = '''
CREATE TABLE "location_availabilities" ("id" TEXT NOT NULL, "location_id" TEXT NOT NULL REFERENCES locations (id), "start_date" TEXT NOT NULL, "end_date" TEXT NOT NULL, "weekdays" INTEGER NOT NULL DEFAULT 127, "slot" TEXT NOT NULL DEFAULT 'fullDay', "start_minute" INTEGER NULL, "end_minute" INTEGER NULL, "kind" TEXT NOT NULL DEFAULT 'available', "note" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
''';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ocpt_project_database_migration_test_');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  final createdAt = DateTime.utc(2026, 1, 15, 9, 30);
  final updatedAt = DateTime.utc(2026, 1, 16, 18, 45, 30);
  final snapshotCreatedAt = DateTime.utc(2026, 1, 16, 18, 44);

  /// Writes the rows every version of the schema already had — the project header, one screenplay,
  /// one snapshot and one scene — into the legacy database [db] built from [_v1Ddl], [_v2Ddl] or
  /// [_v3Ddl].
  void seedCommonRows(sqlite3.Database db) {
    db.execute(
      "INSERT INTO project_info (id, name, created_at, app_version_at_creation, page_format) "
      "VALUES (1, 'My Movie', '${createdAt.toIso8601String()}', '0.1.0', 'a4');",
    );
    db.execute(
      "INSERT INTO screenplays (id, title, fountain_text, updated_at) "
      "VALUES ('s1', 'Draft', 'INT. HOUSE - DAY\n\nCLARA enters.', "
      "'${updatedAt.toIso8601String()}');",
    );
    db.execute(
      "INSERT INTO screenplay_snapshots (id, screenplay_id, created_at, reason, fountain_text) "
      "VALUES ('snap1', 's1', '${snapshotCreatedAt.toIso8601String()}', 'manual', "
      "'INT. HOUSE - DAY');",
    );
    db.execute(
      "INSERT INTO scenes (id, screenplay_id, position, heading, scene_number, char_start, "
      "char_end) VALUES ('scene1', 's1', 0, 'INT. HOUSE - DAY', NULL, 0, 18);",
    );
  }

  /// Asserts that the rows [seedCommonRows] wrote all came through [database] unchanged.
  Future<void> expectCommonRowsSurvived(OcptProjectDatabase database) async {
    final projectInfo = await database.select(database.ocptProjectInfoTable).getSingle();
    expect(projectInfo.name, "My Movie");
    expect(projectInfo.appVersionAtCreation, "0.1.0");
    expect(projectInfo.pageFormat, OcptPageFormat.a4);
    expect(projectInfo.createdAt, createdAt);

    final screenplay = await database.select(database.ocptScreenplaysTable).getSingle();
    expect(screenplay.id, "s1");
    expect(screenplay.title, "Draft");
    expect(screenplay.fountainText, "INT. HOUSE - DAY\n\nCLARA enters.");
    expect(screenplay.updatedAt, updatedAt);
    expect(screenplay.isDeleted, isFalse);

    final snapshot = await database.select(database.ocptScreenplaySnapshotsTable).getSingle();
    expect(snapshot.id, "snap1");
    expect(snapshot.screenplayId, "s1");
    expect(snapshot.reason, OcptSnapshotReason.manual);
    expect(snapshot.fountainText, "INT. HOUSE - DAY");
    expect(snapshot.createdAt, snapshotCreatedAt);
    expect(snapshot.isDeleted, isFalse);

    final scene = await (database.select(
      database.ocptScenesTable,
    )..where((table) => table.id.equals("scene1"))).getSingle();
    expect(scene.id, "scene1");
    expect(scene.heading, "INT. HOUSE - DAY");
    expect(scene.sceneNumber, isNull);
    expect(scene.charStart, 0);
    expect(scene.charEnd, 18);
    expect(scene.isDeleted, isFalse);
  }

  /// Asserts that the version 5 shape is in place and usable in [database]: the `project_versions`
  /// table accepts a row, `project_info.current_version_id` — added by the same step — accepts a
  /// pointer to it, and the version's `content_digest` defaults to null for a freshly inserted row
  /// that didn't set it.
  Future<void> expectProjectVersionsAreUsable(OcptProjectDatabase database) async {
    await database
        .into(database.ocptProjectVersionsTable)
        .insert(
          OcptProjectVersionsTableCompanion.insert(
            id: "version1",
            name: "v1 — First read",
            createdAt: DateTime.utc(2026, 2, 1, 10),
            appVersion: "0.1.0",
            payloadFormat: 1,
            payload: '{"payloadFormat":1}',
            summaryJson: '{"pageCount":41}',
            createdByDeviceId: "device-1",
          ),
        );

    await database
        .update(database.ocptProjectInfoTable)
        .write(const OcptProjectInfoTableCompanion(currentVersionId: Value("version1")));

    final version = await database.select(database.ocptProjectVersionsTable).getSingle();
    expect(version.name, "v1 — First read");
    expect(version.note, "");
    expect(version.contentDigest, isNull);

    final projectInfo = await database.select(database.ocptProjectInfoTable).getSingle();
    expect(projectInfo.currentVersionId, "version1");
  }

  /// The `user_version` pragma [database]'s file now carries.
  Future<Object?> readSchemaVersion(OcptProjectDatabase database) async {
    final row = await database.customSelect('PRAGMA user_version').getSingle();
    return row.data['user_version'];
  }

  /// The shape of every table [database] holds: the table name mapped to its columns, each read
  /// from `PRAGMA table_info` as its name, declared type, nullability, default and primary key
  /// rank.
  ///
  /// A table's columns are gathered into a set rather than a list because the two ways a table can
  /// reach the current version disagree on their *order* and on nothing else: `createTable` writes
  /// them in the order the Dart declaration lists them, while `ALTER TABLE … ADD COLUMN` can only
  /// append. Which columns exist, and what each of them is, is what an upgraded file and a fresh
  /// one have to agree on for the rest of the app to treat them alike.
  Future<Map<String, Set<String>>> readSchemaShape(OcptProjectDatabase database) async {
    final tables = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' "
          "ORDER BY name",
        )
        .get();

    final shape = <String, Set<String>>{};
    for (final table in tables) {
      final tableName = table.read<String>('name');
      final columns = await database.customSelect('PRAGMA table_info("$tableName")').get();
      shape[tableName] = {
        for (final column in columns)
          "${column.read<String>('name')} ${column.read<String>('type')} "
          "notNull=${column.read<int>('notnull')} "
          "default=${column.data['dflt_value']} pk=${column.read<int>('pk')}",
      };
    }

    return shape;
  }

  test('a database created from scratch has the shape every upgrade path lands on', () async {
    // The reference: a file drift creates itself, through `onCreate` alone, never having been
    // anything but version 7.
    final freshDatabase = OcptProjectDatabase(File(p.join(tempDir.path, 'fresh.ocpt')));
    final freshShape = await readSchemaShape(freshDatabase);
    expect(await readSchemaVersion(freshDatabase), 8);
    await freshDatabase.close();

    // Naming the tables rather than counting them: two empty shapes would compare equal below and
    // prove nothing at all, and this is also where a table added later without a migration step
    // shows up.
    expect(freshShape.keys, {
      'project_info',
      'project_versions',
      'row_field_versions',
      'scenes',
      'screenplay_snapshots',
      'screenplays',
      'shot_characters',
      'shot_coverages',
      'shots',
      'people',
      'person_positions',
      'person_skills',
      'person_unavailabilities',
      'roles',
      'locations',
      'location_availabilities',
      'sets',
      'scene_sets',
      'elements',
      'scene_elements',
      'assets',
      'local_erasures',
    });

    // And every file an earlier version could have left behind, brought up by `onUpgrade`: each
    // must land on that same shape, whichever generation of columns it already carried.
    for (final (fileName, ddl, userVersion) in [
      ('upgraded_from_v1.ocpt', _v1Ddl, 1),
      ('upgraded_from_v2.ocpt', _v2Ddl, 2),
      ('upgraded_from_v3.ocpt', _v3Ddl, 3),
      ('upgraded_from_v4.ocpt', _v4Ddl, 4),
      ('upgraded_from_v5.ocpt', _v5Ddl, 5),
      ('upgraded_from_v6.ocpt', '$_v5Ddl$_v6ResourcesDdl', 6),
      (
        'upgraded_from_v7.ocpt',
        '$_v5Ddl$_v6ResourcesDdl$_v7LocationAvailabilitiesDdl',
        7,
      ),
    ]) {
      final filePath = p.join(tempDir.path, fileName);

      final legacyDb = sqlite3.sqlite3.open(filePath);
      legacyDb.execute(ddl);
      legacyDb.execute('PRAGMA user_version = $userVersion;');
      seedCommonRows(legacyDb);
      legacyDb.dispose();

      final database = OcptProjectDatabase(File(filePath));
      expect(
        await readSchemaShape(database),
        freshShape,
        reason: "a file coming from version $userVersion must end up on the very shape `onCreate` "
            "writes",
      );
      expect(await readSchemaVersion(database), 8);

      await database.close();
    }
  });

  test('a v1 database migrates to the current schema, preserving every existing row', () async {
    final filePath = p.join(tempDir.path, 'legacy_v1.ocpt');

    // Build the v1 fixture directly with the `sqlite3` package: no drift involved yet, so this
    // is genuinely an "old file on disk" rather than something drift's own `onCreate` produced.
    final legacyDb = sqlite3.sqlite3.open(filePath);
    legacyDb.execute(_v1Ddl);
    legacyDb.execute('PRAGMA user_version = 1;');
    seedCommonRows(legacyDb);
    legacyDb.dispose();

    // Open the same file through the current OcptProjectDatabase: this is the migration, replayed
    // through both of its steps in order.
    final database = OcptProjectDatabase(File(filePath));

    // (a) every original row survived, unchanged.
    await expectCommonRowsSurvived(database);

    // (b) the shot list tables exist and accept a row, referencing the rows the file already held:
    // the migration has to leave the old and the new sides joinable. They were created from the
    // current declarations, so they carry the version 3 columns straight away.
    await database
        .into(database.ocptShotsTable)
        .insert(
          OcptShotsTableCompanion.insert(
            id: "shot1",
            screenplayId: "s1",
            sceneId: const Value("scene1"),
            position: 0,
            sortKey: const Value("V"),
          ),
        );
    await database
        .into(database.ocptShotCharactersTable)
        .insert(
          OcptShotCharactersTableCompanion.insert(
            shotId: "shot1",
            characterName: "CLARA",
            position: 0,
            sortKey: const Value("V"),
          ),
        );
    await database
        .into(database.ocptShotCoveragesTable)
        .insert(
          OcptShotCoveragesTableCompanion.insert(
            id: "cov1",
            shotId: "shot1",
            sceneId: "scene1",
            startOffset: 0,
            endOffset: 12,
            coveredTextDigest: "digest",
          ),
        );

    final shot = await database.select(database.ocptShotsTable).getSingle();
    expect(shot.id, "shot1");
    expect(shot.isDeleted, isFalse);
    expect(shot.abbreviation, "");
    final shotCharacter = await database.select(database.ocptShotCharactersTable).getSingle();
    expect(shotCharacter.characterName, "CLARA");
    final coverage = await database.select(database.ocptShotCoveragesTable).getSingle();
    expect(coverage.sceneId, "scene1");

    // (c) the version 3 sidecar table exists too.
    await database
        .into(database.ocptRowFieldVersionsTable)
        .insert(
          OcptRowFieldVersionsTableCompanion.insert(
            targetTableName: "shots",
            rowId: "shot1",
            columnName: "framing",
            version: 1,
            deviceId: "device-1",
          ),
        );
    expect(await database.select(database.ocptRowFieldVersionsTable).getSingle(), isNotNull);

    // (d) so do the version 5 project versions, pointed at by the project header.
    await expectProjectVersionsAreUsable(database);

    // (e) the schema version stored in the file is now 5.
    expect(await readSchemaVersion(database), 8);

    await database.close();
  });

  test('a v2 database migrates to the current schema, backfilling a sortKey per group', () async {
    final filePath = p.join(tempDir.path, 'legacy_v2.ocpt');

    final legacyDb = sqlite3.sqlite3.open(filePath);
    legacyDb.execute(_v2Ddl);
    legacyDb.execute('PRAGMA user_version = 2;');
    seedCommonRows(legacyDb);
    legacyDb.execute(
      "INSERT INTO scenes (id, screenplay_id, position, heading, scene_number, char_start, "
      "char_end) VALUES ('scene2', 's1', 1, 'EXT. STREET - NIGHT', NULL, 18, 40);",
    );

    // Three shots in the first scene, one in the second, one already orphaned: three independent
    // groups, each numbered from 0 by the version the file comes from.
    for (final (id, sceneId, position) in const [
      ('shot-a', "'scene1'", 0),
      ('shot-b', "'scene1'", 1),
      ('shot-c', "'scene1'", 2),
      ('shot-d', "'scene2'", 0),
      ('shot-orphan', 'NULL', 0),
    ]) {
      legacyDb.execute(
        "INSERT INTO shots (id, screenplay_id, scene_id, position, framing) "
        "VALUES ('$id', 's1', $sceneId, $position, 'framing of $id');",
      );
    }

    for (final (name, position) in const [('CLARA', 0), ('MARC', 1), ('THÉO', 2)]) {
      legacyDb.execute(
        "INSERT INTO shot_characters (shot_id, character_name, position) "
        "VALUES ('shot-a', '$name', $position);",
      );
    }

    legacyDb.execute(
      "INSERT INTO shot_coverages (id, shot_id, scene_id, start_offset, end_offset, "
      "covered_text_digest) VALUES ('cov1', 'shot-a', 'scene1', 0, 12, 'digest');",
    );
    legacyDb.dispose();

    final database = OcptProjectDatabase(File(filePath));

    // (a) every original row survived, unchanged, and is live rather than tombstoned.
    await expectCommonRowsSurvived(database);

    final shots =
        await (database.select(database.ocptShotsTable)
              ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
            .get();
    expect(shots, hasLength(5));
    expect(shots.every((row) => !row.isDeleted), isTrue);
    for (final row in shots) {
      expect(row.framing, "framing of ${row.id}");
      expect(row.abbreviation, "");
    }

    final coverage = await database.select(database.ocptShotCoveragesTable).getSingle();
    expect(coverage.shotId, "shot-a");
    expect(coverage.isDeleted, isFalse);

    // (b) every group got its own strictly ascending run of keys, in the order `position` held.
    final sortKeyById = {for (final row in shots) row.id: row.sortKey};
    expect(sortKeyById.values.every((key) => key.isNotEmpty), isTrue);
    expect(
      sortKeyById['shot-a']!.compareTo(sortKeyById['shot-b']!),
      lessThan(0),
    );
    expect(
      sortKeyById['shot-b']!.compareTo(sortKeyById['shot-c']!),
      lessThan(0),
    );

    // (c) reading each group back by sortKey yields the order the file had under `position`.
    Future<List<String>> shotIdsOfScene(String? sceneId) async {
      final rows =
          await (database.select(database.ocptShotsTable)
                ..where(
                  (table) => sceneId == null
                      ? table.sceneId.isNull()
                      : table.sceneId.equals(sceneId),
                )
                ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
              .get();
      return [for (final row in rows) row.id];
    }

    expect(await shotIdsOfScene('scene1'), ['shot-a', 'shot-b', 'shot-c']);
    expect(await shotIdsOfScene('scene2'), ['shot-d']);
    expect(await shotIdsOfScene(null), ['shot-orphan']);

    // (d) a shot's characters are a group of their own, backfilled the same way.
    final characters =
        await (database.select(database.ocptShotCharactersTable)
              ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
            .get();
    expect([for (final row in characters) row.characterName], ['CLARA', 'MARC', 'THÉO']);
    expect(characters.every((row) => row.sortKey.isNotEmpty && !row.isDeleted), isTrue);

    // (e) the sidecar table was created, the project versions are usable, and the file now says
    // version 5.
    await database
        .into(database.ocptRowFieldVersionsTable)
        .insert(
          OcptRowFieldVersionsTableCompanion.insert(
            targetTableName: "shots",
            rowId: "shot-a",
            columnName: "framing",
            version: 1,
            deviceId: "device-1",
          ),
        );
    expect(await database.select(database.ocptRowFieldVersionsTable).getSingle(), isNotNull);
    await expectProjectVersionsAreUsable(database);
    expect(await readSchemaVersion(database), 8);

    await database.close();
  });

  test('a v3 database migrates on, gaining an abbreviation and the project versions', () async {
    final filePath = p.join(tempDir.path, 'legacy_v3.ocpt');

    final legacyDb = sqlite3.sqlite3.open(filePath);
    legacyDb.execute(_v3Ddl);
    legacyDb.execute('PRAGMA user_version = 3;');
    seedCommonRows(legacyDb);
    legacyDb.execute(
      "INSERT INTO shots (id, screenplay_id, scene_id, position, sort_key, shot_size, framing, "
      "is_deleted) VALUES ('shot-a', 's1', 'scene1', 0, 'V', 'Gros plan', 'framing of shot-a', 0);",
    );
    legacyDb.execute(
      "INSERT INTO row_field_versions (table_name, row_id, column_name, version, device_id) "
      "VALUES ('shots', 'shot-a', 'framing', 7, 'device-0');",
    );
    legacyDb.dispose();

    final database = OcptProjectDatabase(File(filePath));

    // (a) every row the file already held survived, the shot and the version 3 ones included:
    // these steps only add columns and a table, and touch nothing else.
    await expectCommonRowsSurvived(database);

    final shot = await database.select(database.ocptShotsTable).getSingle();
    expect(shot.id, "shot-a");
    expect(shot.shotSize, "Gros plan");
    expect(shot.framing, "framing of shot-a");
    expect(shot.sortKey, "V");
    expect(shot.isDeleted, isFalse);

    final stamp = await database.select(database.ocptRowFieldVersionsTable).getSingle();
    expect(stamp.rowId, "shot-a");
    expect(stamp.version, 7);

    // (b) the version 4 column is there, holding its default rather than being deduced
    // retroactively: an abbreviation is only ever written when a shot size is committed from the
    // inspector.
    expect(shot.abbreviation, "");

    await database
        .update(database.ocptShotsTable)
        .write(const OcptShotsTableCompanion(abbreviation: Value("GP")));
    expect((await database.select(database.ocptShotsTable).getSingle()).abbreviation, "GP");

    // (c) the project header kept its own values, and its new pointer starts empty: a project that
    // predates this version has never had a version of its own.
    final projectInfoBefore = await database.select(database.ocptProjectInfoTable).getSingle();
    expect(projectInfoBefore.currentVersionId, isNull);

    // (d) the version 5 shape is in place and usable, and the file now says version 5.
    await expectProjectVersionsAreUsable(database);
    expect(await readSchemaVersion(database), 8);

    await database.close();
  });

  test('a v4 database written by the alpha still opens, gaining the project versions', () async {
    final filePath = p.join(tempDir.path, 'legacy_v4.ocpt');

    // The file `v0.1.0-alpha.2` leaves behind: the abbreviation column is what its version 4 means,
    // and it has never heard of the project versions. Opening it must run the version 5 step alone,
    // creating `project_versions` rather than altering a table that isn't there.
    final legacyDb = sqlite3.sqlite3.open(filePath);
    legacyDb.execute(_v4Ddl);
    legacyDb.execute('PRAGMA user_version = 4;');
    seedCommonRows(legacyDb);
    legacyDb.execute(
      "INSERT INTO shots (id, screenplay_id, scene_id, position, sort_key, shot_size, "
      "abbreviation) VALUES ('shot-a', 's1', 'scene1', 0, 'V', 'Plan moyen', 'PM');",
    );
    legacyDb.dispose();

    final database = OcptProjectDatabase(File(filePath));

    // (a) every row the file already held survived, its abbreviation included: the version 4 step
    // is skipped, so nothing tries to add a column the file already carries.
    await expectCommonRowsSurvived(database);

    final shot = await database.select(database.ocptShotsTable).getSingle();
    expect(shot.id, "shot-a");
    expect(shot.shotSize, "Plan moyen");
    expect(shot.abbreviation, "PM");

    // (b) the version 5 shape is in place and usable, and the file now says version 5.
    await expectProjectVersionsAreUsable(database);
    expect(await readSchemaVersion(database), 8);

    await database.close();
  });

  test('a v5 database migrates on, gaining the resources tables', () async {
    final filePath = p.join(tempDir.path, 'legacy_v5.ocpt');

    // The shape PR #44 shipped: `project_versions` (with `content_digest` already on it) and
    // `project_info.current_version_id`, but none of the resources mode's twelve tables.
    final legacyDb = sqlite3.sqlite3.open(filePath);
    legacyDb.execute(_v5Ddl);
    legacyDb.execute('PRAGMA user_version = 5;');
    seedCommonRows(legacyDb);
    legacyDb.execute(
      "INSERT INTO project_versions (id, name, note, created_at, app_version, payload_format, "
      "payload, summary_json, created_by_device_id, content_digest) VALUES ('version1', "
      "'v1 — First read', '', '${DateTime.utc(2026, 2, 1, 10).toIso8601String()}', '0.1.0', 1, "
      "'{\"payloadFormat\":1}', '{\"pageCount\":41}', 'device-1', 'digest1');",
    );
    legacyDb.execute(
      "UPDATE project_info SET current_version_id = 'version1' WHERE id = 1;",
    );
    legacyDb.dispose();

    final database = OcptProjectDatabase(File(filePath));

    // (a) every row the file already held survived untouched: this step only creates tables, it
    // touches nothing that exists.
    await expectCommonRowsSurvived(database);

    final version = await database.select(database.ocptProjectVersionsTable).getSingle();
    expect(version.id, "version1");
    expect(version.contentDigest, "digest1");

    final projectInfo = await database.select(database.ocptProjectInfoTable).getSingle();
    expect(projectInfo.currentVersionId, "version1");

    // (b) the twelve resources tables exist and are usable, referencing each other and the rows
    // the file already held.
    await database
        .into(database.ocptPeopleTable)
        .insert(
          OcptPeopleTableCompanion.insert(
            id: "person1",
            firstName: const Value("Clara"),
            lastName: const Value("Dupont"),
          ),
        );

    await database
        .into(database.ocptRolesTable)
        .insert(
          OcptRolesTableCompanion.insert(
            id: "role1",
            screenplayId: "s1",
            name: "CLARA",
            kind: OcptRoleKind.speaking,
            personId: const Value("person1"),
          ),
        );

    await database
        .into(database.ocptLocationsTable)
        .insert(
          OcptLocationsTableCompanion.insert(
            id: "location1",
            name: "La maison des Pains",
            contactPersonId: const Value("person1"),
          ),
        );

    await database
        .into(database.ocptSetsTable)
        .insert(
          OcptSetsTableCompanion.insert(id: "set1", locationId: "location1", name: "Cuisine"),
        );

    await database
        .into(database.ocptElementsTable)
        .insert(
          OcptElementsTableCompanion.insert(
            id: "element1",
            category: OcptElementCategory.prop,
            name: "Valise",
            sourceKind: OcptElementSourceKind.owned,
            ownerPersonId: const Value("person1"),
          ),
        );

    await database
        .into(database.ocptAssetsTable)
        .insert(
          OcptAssetsTableCompanion.insert(
            id: "asset1",
            kind: OcptAssetKind.personPhoto,
            path: "/tmp/clara.jpg",
            addedAt: DateTime.utc(2026, 2, 2),
            personId: const Value("person1"),
          ),
        );

    await database
        .into(database.ocptLocalErasuresTable)
        .insert(
          OcptLocalErasuresTableCompanion.insert(
            personId: "person1",
            erasedAt: DateTime.utc(2026, 2, 3),
          ),
        );

    final person = await database.select(database.ocptPeopleTable).getSingle();
    expect(person.id, "person1");
    expect(person.firstName, "Clara");
    expect(person.imageRightsStatus, OcptImageRightsStatus.notApplicable);

    final role = await database.select(database.ocptRolesTable).getSingle();
    expect(role.personId, "person1");
    expect(role.kind, OcptRoleKind.speaking);

    final location = await database.select(database.ocptLocationsTable).getSingle();
    expect(location.contactPersonId, "person1");
    expect(location.permitStatus, OcptPermitStatus.toRequest);

    final setRow = await database.select(database.ocptSetsTable).getSingle();
    expect(setRow.locationId, "location1");

    final element = await database.select(database.ocptElementsTable).getSingle();
    expect(element.ownerPersonId, "person1");
    expect(element.category, OcptElementCategory.prop);

    final asset = await database.select(database.ocptAssetsTable).getSingle();
    expect(asset.personId, "person1");
    expect(asset.kind, OcptAssetKind.personPhoto);

    final erasure = await database.select(database.ocptLocalErasuresTable).getSingle();
    expect(erasure.personId, "person1");

    // (c) `local_erasures` is the one table of this schema whose rows may be deleted for real.
    await (database.delete(
      database.ocptLocalErasuresTable,
    )..where((table) => table.personId.equals("person1"))).go();
    expect(await database.select(database.ocptLocalErasuresTable).get(), isEmpty);

    // (d) the file now says version 8.
    expect(await readSchemaVersion(database), 8);

    await database.close();
  });

  test('a v6 database migrates on, gaining the location availabilities', () async {
    final filePath = p.join(tempDir.path, 'legacy_v6.ocpt');

    // The shape the resources mode first shipped in: every resources table, and no
    // `location_availabilities` — a location could only say when it was free in free text.
    final legacyDb = sqlite3.sqlite3.open(filePath);
    legacyDb.execute(_v5Ddl);
    legacyDb.execute(_v6ResourcesDdl);
    legacyDb.execute('PRAGMA user_version = 6;');
    seedCommonRows(legacyDb);
    legacyDb.execute(
      "INSERT INTO locations (id, name, constraints_notes, sort_key) VALUES ('location1', "
      "'La maison des Pains', 'Free on Mondays', 'V');",
    );
    legacyDb.dispose();

    final database = OcptProjectDatabase(File(filePath));

    // (a) every row the file already held survived untouched: this step only creates one table.
    await expectCommonRowsSurvived(database);

    final location = await database.select(database.ocptLocationsTable).getSingle();
    expect(location.constraintsNotes, "Free on Mondays");

    // (b) the new table exists, is usable, and carries the defaults a fresh row relies on.
    await database
        .into(database.ocptLocationAvailabilitiesTable)
        .insert(
          OcptLocationAvailabilitiesTableCompanion.insert(
            id: "availability1",
            locationId: "location1",
            startDate: DateTime.utc(2026, 3, 2),
            endDate: DateTime.utc(2026, 3, 20),
          ),
        );

    final availability = await database
        .select(database.ocptLocationAvailabilitiesTable)
        .getSingle();
    expect(availability.locationId, "location1");
    expect(availability.weekdays, ocptEveryWeekdayMask);
    expect(availability.slot, OcptDayPartSlot.fullDay);
    expect(availability.kind, OcptLocationAvailabilityKind.available);
    expect(availability.isDeleted, isFalse);

    // (c) the file now says version 8.
    expect(await readSchemaVersion(database), 8);

    await database.close();
  });

  test('a v7 database migrates on, gaining the currency', () async {
    final filePath = p.join(tempDir.path, 'legacy_v7.ocpt');

    // The shape version 7 left behind: `location_availabilities` exists, but `project_info` has
    // no `currency_code` yet.
    final legacyDb = sqlite3.sqlite3.open(filePath);
    legacyDb.execute(_v5Ddl);
    legacyDb.execute(_v6ResourcesDdl);
    legacyDb.execute(_v7LocationAvailabilitiesDdl);
    legacyDb.execute('PRAGMA user_version = 7;');
    seedCommonRows(legacyDb);
    legacyDb.dispose();

    final database = OcptProjectDatabase(File(filePath));

    // (a) every row the file already held survived untouched: this step only adds one column.
    await expectCommonRowsSurvived(database);

    // (b) the new column exists and defaults an already-existing project to EUR, exactly as a
    // freshly created one does when the device locale can't suggest anything better.
    final projectInfo = await database.select(database.ocptProjectInfoTable).getSingle();
    expect(projectInfo.currencyCode, "EUR");

    await database
        .update(database.ocptProjectInfoTable)
        .write(const OcptProjectInfoTableCompanion(currencyCode: Value("USD")));
    expect((await database.select(database.ocptProjectInfoTable).getSingle()).currencyCode, "USD");

    // (c) the file now says version 8.
    expect(await readSchemaVersion(database), 8);

    await database.close();
  });
}
