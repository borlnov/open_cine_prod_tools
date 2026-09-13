// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' show sqlite3;

// This file is the harness that pins each stable release's upgrade path
// (`docs/adr/0029-schema-versions-frozen-at-stable-releases.md`). The 0.1.0 release froze the
// schema at v1, and schema version 2 — `OcptSyncRelayCursorsTable` and `OcptSyncPairingsTable`,
// both local, never-synchronised tables the changeset engine and its relay transport add, plus
// `budget_lines.in_kind_resource_id` — was that cycle's own `onUpgrade` step. The 0.2.0 release now
// freezes v2 in turn, which is the moment ADR 0029 ties the verbatim DDL fixture to: [_v1Ddl] below
// is that fixture, a hand-held copy of the real v1 `CREATE TABLE` statements a 0.1.0 file was left
// with, and the test built on it is what proves `onCreate` still reproduces migrating a real v1
// file forward, rather than merely rewriting the same "undo the last upgrade" trick the schema's
// own `onUpgrade` doc comment already describes.

void main() {
  test(
    'currentSchemaVersion is always lastStableSchemaVersion or one above it',
    () {
      final current = OcptProjectDatabase.currentSchemaVersion;
      final lastStable = OcptProjectDatabase.lastStableSchemaVersion;

      expect(
        current == lastStable || current == lastStable + 1,
        isTrue,
        reason:
            'currentSchemaVersion ($current) must equal lastStableSchemaVersion ($lastStable) '
            'when the top migration file is frozen, or lastStableSchemaVersion + 1 when a '
            'development cycle is open: a cycle never bumps the schema version twice.',
      );
    },
  );

  test('a fresh in-memory database opens and holds every table onCreate declares', () async {
    final database = OcptProjectDatabase.memory();
    addTearDown(database.close);

    final tables = await database
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    final tableNames = {for (final row in tables) row.data['name'] as String};

    // A representative sample spanning every area the database holds (see
    // `OcptProjectDatabase`'s own class doc comment): opening succeeds only if `onCreate` ran
    // `m.createAll()` against the full `@DriftDatabase` table list without error.
    expect(
      tableNames,
      containsAll(<String>[
        'project_info',
        'screenplays',
        'scenes',
        'shots',
        'row_field_versions',
        'project_versions',
        'people',
        'roles',
        'locations',
        'elements',
        'breakdown_tags',
        'scene_breakdowns',
        'shooting_days',
        'shooting_slots',
        'budget_postes',
        'budget_entries',
        'budget_resources',
        'budget_revenues',
        'budget_allowances',
        'sync_relay_cursors',
        'sync_pairings',
      ]),
    );

    final userVersion = await database.customSelect('PRAGMA user_version').getSingle();
    expect(userVersion.data['user_version'], OcptProjectDatabase.currentSchemaVersion);
  });

  test(
    'a v1 database migrates to v2, keeping its rows, gaining the two empty local tables and the '
    'budget_lines.in_kind_resource_id column',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('ocpt_migration_v1_to_v2_test_');
      addTearDown(() => tempDir.delete(recursive: true));
      final filePath = p.join(tempDir.path, 'movie.ocpt');

      // The migration from 1 to 2 is additive-only and only ever creates `sync_relay_cursors` and
      // `sync_pairings`, and adds `budget_lines.in_kind_resource_id`
      // (`OcptProjectDatabase.migration`'s own doc comment): a real v1 file is therefore exactly
      // what `onCreate` produces here minus those two tables and that column. Seed a real database
      // at the current schema, then undo those additions by hand — the same trick
      // `home_bloc_test.dart`'s `createProjectAtPreviousFormat` uses — so reopening it exercises the
      // real `onUpgrade` step rather than a fixture standing in for it. [_v1Ddl] below covers the
      // structural side of the same claim, verbatim rather than by undoing the current schema.
      final seeded = OcptProjectDatabase(File(filePath));
      await seeded
          .into(seeded.ocptScreenplaysTable)
          .insert(
            OcptScreenplaysTableCompanion.insert(
              id: 's1',
              title: 'Draft',
              updatedAt: DateTime(2026),
            ),
          );
      await seeded.close();

      final raw = sqlite3.open(filePath);
      raw
        ..execute('DROP TABLE sync_relay_cursors')
        ..execute('DROP TABLE sync_pairings')
        ..execute('ALTER TABLE budget_lines DROP COLUMN in_kind_resource_id')
        ..execute('PRAGMA user_version = 1')
        ..dispose();

      final migrated = OcptProjectDatabase(File(filePath));
      addTearDown(migrated.close);

      final screenplays = await migrated.select(migrated.ocptScreenplaysTable).get();
      expect(screenplays, hasLength(1));
      expect(screenplays.single.id, 's1');
      expect(screenplays.single.title, 'Draft');

      final cursorsBeforeInsert = await migrated.select(migrated.ocptSyncRelayCursorsTable).get();
      expect(cursorsBeforeInsert, isEmpty);
      final pairingsBeforeInsert = await migrated.select(migrated.ocptSyncPairingsTable).get();
      expect(pairingsBeforeInsert, isEmpty);

      await migrated
          .into(migrated.ocptSyncRelayCursorsTable)
          .insert(OcptSyncRelayCursorsTableCompanion.insert(relayId: 'relay-1'));
      final cursorsAfterInsert = await migrated.select(migrated.ocptSyncRelayCursorsTable).get();
      expect(cursorsAfterInsert, hasLength(1));
      expect(cursorsAfterInsert.single.lastAppliedSequence, 0);
      expect(cursorsAfterInsert.single.outboxHighWaterMark, 0);

      await migrated
          .into(migrated.ocptSyncPairingsTable)
          .insert(
            OcptSyncPairingsTableCompanion.insert(
              projectId: 'p1',
              relayBaseUrl: 'https://relay.example.org/',
            ),
          );
      final pairingsAfterInsert = await migrated.select(migrated.ocptSyncPairingsTable).get();
      expect(pairingsAfterInsert, hasLength(1));
      expect(pairingsAfterInsert.single.relayBaseUrl, 'https://relay.example.org/');

      final budgetLinesColumns = await migrated
          .customSelect('PRAGMA table_info(budget_lines)')
          .get();
      expect(
        budgetLinesColumns.map((row) => row.data['name']),
        contains('in_kind_resource_id'),
      );

      final userVersion = await migrated.customSelect('PRAGMA user_version').getSingle();
      expect(userVersion.data['user_version'], OcptProjectDatabase.currentSchemaVersion);
    },
  );

  test(
    'onCreate reproduces exactly what migrating the verbatim v1 fixture forward produces',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('ocpt_migration_v1_fixture_test_');
      addTearDown(() => tempDir.delete(recursive: true));
      final filePath = p.join(tempDir.path, 'movie.ocpt');

      // [_v1Ddl] is created with the raw sqlite3 binding, deliberately never through drift or
      // `OcptProjectDatabase`: that is what makes it a fixture of the frozen v1 shape rather than
      // just another way of asking drift to build the current one.
      final raw = sqlite3.open(filePath);
      for (final statement in _v1Ddl) {
        raw.execute(statement);
      }
      raw
        ..execute('PRAGMA user_version = 1')
        ..dispose();

      final migrated = OcptProjectDatabase(File(filePath));
      addTearDown(migrated.close);
      final migratedShape = _schemaShape(await _tableSqlByName(migrated));

      final fresh = OcptProjectDatabase.memory();
      addTearDown(fresh.close);
      final freshShape = _schemaShape(await _tableSqlByName(fresh));

      // Compared clause by clause, table by table, rather than as whole `CREATE TABLE` strings:
      // `ALTER TABLE ... ADD COLUMN` (`OcptProjectDatabase.migration`'s `m.addColumn` call) always
      // appends the new column at the end of SQLite's own stored schema text, wherever the
      // `OcptBudgetLinesTable` class itself declares it — a real difference in the two engines'
      // output that carries no shape change at all, and a literal string compare of `budget_lines`
      // would wrongly report as one.
      expect(migratedShape, freshShape);

      final userVersion = await migrated.customSelect('PRAGMA user_version').getSingle();
      expect(userVersion.data['user_version'], OcptProjectDatabase.currentSchemaVersion);
    },
  );
}

/// Every table's own `CREATE TABLE` text, keyed by table name, read off [database]'s
/// `sqlite_master`. SQLite's own automatic indexes (`sqlite_autoindex_...`, one per `PRIMARY KEY`)
/// are excluded: they are not part of the schema anybody wrote, and neither this schema nor its v1
/// fixture declares any explicit index of its own.
Future<Map<String, String>> _tableSqlByName(OcptProjectDatabase database) async {
  final rows = await database
      .customSelect(
        "SELECT name, sql FROM sqlite_master WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%'",
      )
      .get();

  return {for (final row in rows) row.data['name'] as String: row.data['sql'] as String};
}

/// Turns [tableSql] — a table name mapped to its verbatim `CREATE TABLE` text — into a shape that
/// compares two schemas for the same columns and table constraints regardless of the order SQLite
/// happened to list them in, via [_topLevelClauses].
Map<String, Set<String>> _schemaShape(Map<String, String> tableSql) => {
  for (final entry in tableSql.entries) entry.key: _topLevelClauses(entry.value),
};

/// The column and table-constraint definitions inside a `CREATE TABLE "name" (...)` statement, one
/// entry per comma-separated clause at the statement's own top level — a `CHECK (... IN (0, 1))`
/// column's inner comma is never split on, since it sits one parenthesis deeper.
Set<String> _topLevelClauses(String createTableSql) {
  final inner = createTableSql.substring(
    createTableSql.indexOf('(') + 1,
    createTableSql.lastIndexOf(')'),
  );

  final clauses = <String>{};
  var depth = 0;
  var clauseStart = 0;
  for (var i = 0; i < inner.length; i++) {
    switch (inner[i]) {
      case '(':
        depth++;
      case ')':
        depth--;
      case ',' when depth == 0:
        clauses.add(inner.substring(clauseStart, i).trim());
        clauseStart = i + 1;
    }
  }
  clauses.add(inner.substring(clauseStart).trim());

  return clauses;
}

/// The verbatim schema version 1 `CREATE TABLE` statements — the shape the 0.1.0 release froze,
/// captured from a fresh [OcptProjectDatabase.memory]'s own `sqlite_master` (schema version 2's
/// `onCreate` output) with the two tables `onUpgrade` creates from 1 to 2 (`sync_relay_cursors`,
/// `sync_pairings`) removed, and `budget_lines`'s own `in_kind_resource_id` column — the one
/// `onUpgrade` adds — stripped back out; per `OcptProjectDatabase.migration`'s own doc comment,
/// those are the only differences between the two versions. No stable `.ocpt` file has ever carried
/// a different shape than this: schema version 1 carries no earlier migration history of its own
/// (`docs/adr/0029-schema-versions-frozen-at-stable-releases.md`), so this is also, verbatim, the
/// very first schema a real project file was ever written in.
const _v1Ddl = <String>[
  'CREATE TABLE "assets" ("id" TEXT NOT NULL, "kind" TEXT NOT NULL, "path" TEXT NOT NULL, "label" TEXT NOT NULL DEFAULT \'\', "added_at" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "person_id" TEXT NULL, "location_id" TEXT NULL REFERENCES locations (id), "element_id" TEXT NULL REFERENCES elements (id), "budget_entry_id" TEXT NULL REFERENCES budget_entries (id), "valid_from" TEXT NULL, "valid_until" TEXT NULL, PRIMARY KEY ("id"))',
  'CREATE TABLE "breakdown_tags" ("id" TEXT NOT NULL, "scene_id" TEXT NOT NULL REFERENCES scenes (id), "target_kind" TEXT NOT NULL, "element_id" TEXT NULL REFERENCES elements (id), "role_id" TEXT NULL REFERENCES roles (id), "set_id" TEXT NULL REFERENCES sets (id), "start_offset" INTEGER NOT NULL, "end_offset" INTEGER NOT NULL, "tagged_text" TEXT NOT NULL, "needs_check" INTEGER NOT NULL DEFAULT 0 CHECK ("needs_check" IN (0, 1)), "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "budget_allowances" ("id" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "person_id" TEXT NULL REFERENCES people (id), "kind" TEXT NOT NULL DEFAULT \'travel\', "label" TEXT NOT NULL DEFAULT \'\', "date" TEXT NULL, "end_date" TEXT NULL, "quantity_milli" INTEGER NOT NULL DEFAULT 0, "unit_amount_milli_cents" INTEGER NOT NULL DEFAULT 0, "notes" TEXT NOT NULL DEFAULT \'\', PRIMARY KEY ("id"))',
  'CREATE TABLE "budget_commitments" ("id" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "due_date" TEXT NULL, "label" TEXT NOT NULL, "poste_id" TEXT NOT NULL REFERENCES budget_postes (id), "amount_cents" INTEGER NOT NULL DEFAULT 0, "is_tax_inclusive" INTEGER NOT NULL DEFAULT 1 CHECK ("is_tax_inclusive" IN (0, 1)), "vat_rate_basis_points" INTEGER NULL, "status" TEXT NOT NULL DEFAULT \'quoteAccepted\', "line_id" TEXT NULL REFERENCES budget_lines (id), PRIMARY KEY ("id"))',
  'CREATE TABLE "budget_entries" ("id" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "date" TEXT NOT NULL, "label" TEXT NOT NULL, "poste_id" TEXT NULL REFERENCES budget_postes (id), "debit_cents" INTEGER NOT NULL DEFAULT 0, "credit_cents" INTEGER NOT NULL DEFAULT 0, "is_tax_inclusive" INTEGER NOT NULL DEFAULT 1 CHECK ("is_tax_inclusive" IN (0, 1)), "vat_rate_basis_points" INTEGER NULL, "voucher_number" TEXT NOT NULL DEFAULT \'\', "resource_id" TEXT NULL REFERENCES budget_resources (id), "revenue_id" TEXT NULL REFERENCES budget_revenues (id), "share_id" TEXT NULL REFERENCES budget_shares (id), "commitment_id" TEXT NULL REFERENCES budget_commitments (id), "person_id" TEXT NULL, PRIMARY KEY ("id"))',
  'CREATE TABLE "budget_lines" ("id" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "poste_id" TEXT NOT NULL REFERENCES budget_postes (id), "label" TEXT NOT NULL, "quantity_milli" INTEGER NOT NULL DEFAULT 1000, "unit" TEXT NOT NULL DEFAULT \'\', "unit_amount_cents" INTEGER NOT NULL DEFAULT 0, "is_tax_inclusive" INTEGER NOT NULL DEFAULT 1 CHECK ("is_tax_inclusive" IN (0, 1)), "vat_rate_basis_points" INTEGER NULL, "element_id" TEXT NULL REFERENCES elements (id), "provision_key" TEXT NULL, "provision_digest" TEXT NULL, "notes" TEXT NOT NULL DEFAULT \'\', PRIMARY KEY ("id"))',
  'CREATE TABLE "budget_mileage_rates" ("id" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "label" TEXT NOT NULL, "rate_per_km_milli_cents" INTEGER NOT NULL DEFAULT 0, PRIMARY KEY ("id"))',
  'CREATE TABLE "budget_postes" ("id" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "code" TEXT NOT NULL DEFAULT \'\', "label" TEXT NOT NULL, "simple_label" TEXT NULL, "estimate_to_complete_cents" INTEGER NULL, PRIMARY KEY ("id"))',
  'CREATE TABLE "budget_resources" ("id" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "group_kind" TEXT NOT NULL DEFAULT \'subsidy\', "person_id" TEXT NULL, "label" TEXT NOT NULL, "amount_cents" INTEGER NOT NULL DEFAULT 0, "status" TEXT NOT NULL DEFAULT \'pending\', "is_reimbursable" INTEGER NOT NULL DEFAULT 0 CHECK ("is_reimbursable" IN (0, 1)), "notes" TEXT NOT NULL DEFAULT \'\', PRIMARY KEY ("id"))',
  'CREATE TABLE "budget_revenues" ("id" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "date" TEXT NOT NULL, "label" TEXT NOT NULL, "amount_cents" INTEGER NOT NULL DEFAULT 0, "status" TEXT NOT NULL DEFAULT \'expected\', "notes" TEXT NOT NULL DEFAULT \'\', PRIMARY KEY ("id"))',
  'CREATE TABLE "budget_shares" ("id" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "person_id" TEXT NULL, "label" TEXT NOT NULL, "share_permille" INTEGER NOT NULL DEFAULT 0, "reinvest_permille" INTEGER NOT NULL DEFAULT 0, "notes" TEXT NOT NULL DEFAULT \'\', PRIMARY KEY ("id"))',
  'CREATE TABLE "elements" ("id" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "category" TEXT NOT NULL, "sub_category" TEXT NOT NULL DEFAULT \'\', "name" TEXT NOT NULL, "code" TEXT NOT NULL DEFAULT \'\', "quantity" TEXT NOT NULL DEFAULT \'\', "source_kind" TEXT NOT NULL, "owner_person_id" TEXT NULL, "owner_notes" TEXT NOT NULL DEFAULT \'\', "brought_by_person_id" TEXT NULL, "storage_notes" TEXT NOT NULL DEFAULT \'\', "status" TEXT NOT NULL DEFAULT \'toFind\', "is_secured" INTEGER NOT NULL DEFAULT 0 CHECK ("is_secured" IN (0, 1)), "is_ready_for_shoot" INTEGER NOT NULL DEFAULT 0 CHECK ("is_ready_for_shoot" IN (0, 1)), "is_returned" INTEGER NOT NULL DEFAULT 0 CHECK ("is_returned" IN (0, 1)), "cost" INTEGER NULL, "purpose_notes" TEXT NOT NULL DEFAULT \'\', "notes" TEXT NOT NULL DEFAULT \'\', "photo_asset_id" TEXT NULL, PRIMARY KEY ("id"))',
  'CREATE TABLE "local_erasures" ("person_id" TEXT NOT NULL REFERENCES people (id), "erased_at" TEXT NOT NULL, PRIMARY KEY ("person_id"))',
  'CREATE TABLE "location_availabilities" ("id" TEXT NOT NULL, "location_id" TEXT NOT NULL REFERENCES locations (id), "start_date" TEXT NOT NULL, "end_date" TEXT NOT NULL, "weekdays" INTEGER NOT NULL DEFAULT 127, "slot" TEXT NOT NULL DEFAULT \'fullDay\', "start_minute" INTEGER NULL, "end_minute" INTEGER NULL, "kind" TEXT NOT NULL DEFAULT \'available\', "note" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "locations" ("id" TEXT NOT NULL, "name" TEXT NOT NULL, "color_index" INTEGER NOT NULL DEFAULT 0, "address_line1" TEXT NOT NULL DEFAULT \'\', "address_line2" TEXT NOT NULL DEFAULT \'\', "postal_code" TEXT NOT NULL DEFAULT \'\', "city" TEXT NOT NULL DEFAULT \'\', "region" TEXT NOT NULL DEFAULT \'\', "country" TEXT NOT NULL DEFAULT \'\', "latitude" REAL NULL, "longitude" REAL NULL, "contact_person_id" TEXT NULL, "contact_notes" TEXT NOT NULL DEFAULT \'\', "permit_status" TEXT NOT NULL DEFAULT \'toRequest\', "permit_label" TEXT NOT NULL DEFAULT \'\', "permit_date" TEXT NULL, "permit_asset_id" TEXT NULL, "parking_notes" TEXT NOT NULL DEFAULT \'\', "power_notes" TEXT NOT NULL DEFAULT \'\', "facilities_notes" TEXT NOT NULL DEFAULT \'\', "constraints_notes" TEXT NOT NULL DEFAULT \'\', "notes" TEXT NOT NULL DEFAULT \'\', "sort_key" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "people" ("id" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "first_name" TEXT NOT NULL DEFAULT \'\', "last_name" TEXT NOT NULL DEFAULT \'\', "email" TEXT NOT NULL DEFAULT \'\', "phone" TEXT NOT NULL DEFAULT \'\', "address_line1" TEXT NOT NULL DEFAULT \'\', "address_line2" TEXT NOT NULL DEFAULT \'\', "postal_code" TEXT NOT NULL DEFAULT \'\', "city" TEXT NOT NULL DEFAULT \'\', "region" TEXT NOT NULL DEFAULT \'\', "country" TEXT NOT NULL DEFAULT \'\', "color_index" INTEGER NOT NULL DEFAULT 0, "birth_date" TEXT NULL, "minor_notes" TEXT NOT NULL DEFAULT \'\', "max_daily_presence_minutes" INTEGER NULL, "is_transport_autonomous" INTEGER NULL CHECK ("is_transport_autonomous" IN (0, 1)), "accommodation_notes" TEXT NOT NULL DEFAULT \'\', "travel_notes" TEXT NOT NULL DEFAULT \'\', "dietary_notes" TEXT NOT NULL DEFAULT \'\', "allergies" TEXT NOT NULL DEFAULT \'\', "measurement_height" TEXT NOT NULL DEFAULT \'\', "measurement_chest" TEXT NOT NULL DEFAULT \'\', "measurement_waist" TEXT NOT NULL DEFAULT \'\', "measurement_hips" TEXT NOT NULL DEFAULT \'\', "size_top" TEXT NOT NULL DEFAULT \'\', "size_bottom" TEXT NOT NULL DEFAULT \'\', "size_shoes" TEXT NOT NULL DEFAULT \'\', "hmc_notes" TEXT NOT NULL DEFAULT \'\', "image_rights_status" TEXT NOT NULL DEFAULT \'notApplicable\', "image_rights_date" TEXT NULL, "image_rights_asset_id" TEXT NULL REFERENCES assets (id), "photo_asset_id" TEXT NULL REFERENCES assets (id), "notes" TEXT NOT NULL DEFAULT \'\', "commute_km_milli" INTEGER NULL, "mileage_rate_id" TEXT NULL REFERENCES budget_mileage_rates (id), PRIMARY KEY ("id"))',
  'CREATE TABLE "person_positions" ("id" TEXT NOT NULL, "person_id" TEXT NOT NULL REFERENCES people (id), "position_id" TEXT NOT NULL DEFAULT \'\', "custom_label" TEXT NOT NULL DEFAULT \'\', "sort_key" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "person_skills" ("id" TEXT NOT NULL, "person_id" TEXT NOT NULL REFERENCES people (id), "label" TEXT NOT NULL DEFAULT \'\', "sort_key" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "person_unavailabilities" ("id" TEXT NOT NULL, "person_id" TEXT NOT NULL REFERENCES people (id), "start_date" TEXT NOT NULL, "end_date" TEXT NOT NULL, "slot" TEXT NOT NULL DEFAULT \'fullDay\', "start_minute" INTEGER NULL, "end_minute" INTEGER NULL, "reason" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "project_dictionary_words" ("id" TEXT NOT NULL, "word" TEXT NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "project_info" ("id" INTEGER NOT NULL DEFAULT 1, "name" TEXT NOT NULL, "created_at" TEXT NOT NULL, "app_version_at_creation" TEXT NOT NULL, "migrated_by_app_version" TEXT NULL, "page_format" TEXT NOT NULL, "currency_code" TEXT NOT NULL DEFAULT \'EUR\', "settings_json" TEXT NULL, "minimum_rest_minutes" INTEGER NULL, "screenplay_language" TEXT NULL, "default_vat_rate_basis_points" INTEGER NULL, "meal_price_cents" INTEGER NULL, "snack_price_cents" INTEGER NULL, "is_budget_simplified" INTEGER NULL CHECK ("is_budget_simplified" IN (0, 1)), "current_version_id" TEXT NULL REFERENCES project_versions (id), PRIMARY KEY ("id"))',
  'CREATE TABLE "project_versions" ("id" TEXT NOT NULL, "name" TEXT NOT NULL, "note" TEXT NOT NULL DEFAULT \'\', "created_at" TEXT NOT NULL, "app_version" TEXT NOT NULL, "payload_format" INTEGER NOT NULL, "payload" TEXT NOT NULL, "summary_json" TEXT NOT NULL, "created_by_device_id" TEXT NOT NULL, "content_digest" TEXT NULL, PRIMARY KEY ("id"))',
  'CREATE TABLE "role_candidates" ("id" TEXT NOT NULL, "role_id" TEXT NOT NULL REFERENCES roles (id), "person_id" TEXT NOT NULL REFERENCES people (id), "status" TEXT NOT NULL DEFAULT \'seen\', "auditioned_on" TEXT NULL, "notes" TEXT NOT NULL DEFAULT \'\', "sort_key" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "role_elements" ("id" TEXT NOT NULL, "role_id" TEXT NOT NULL REFERENCES roles (id), "element_id" TEXT NOT NULL REFERENCES elements (id), "notes" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "role_episodes" ("id" TEXT NOT NULL, "role_id" TEXT NOT NULL REFERENCES roles (id), "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "roles" ("id" TEXT NOT NULL, "name" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "person_id" TEXT NULL REFERENCES people (id), "kind" TEXT NOT NULL, "is_from_screenplay" INTEGER NOT NULL DEFAULT 0 CHECK ("is_from_screenplay" IN (0, 1)), "orphaned_name" TEXT NULL, "casting_notes" TEXT NOT NULL DEFAULT \'\', PRIMARY KEY ("id"))',
  'CREATE TABLE "row_field_versions" ("table_name" TEXT NOT NULL, "row_id" TEXT NOT NULL, "column_name" TEXT NOT NULL, "version" INTEGER NOT NULL, "device_id" TEXT NOT NULL, PRIMARY KEY ("table_name", "row_id", "column_name"))',
  'CREATE TABLE "scene_breakdowns" ("id" TEXT NOT NULL, "scene_id" TEXT NOT NULL REFERENCES scenes (id), "status" TEXT NOT NULL DEFAULT \'toDo\', "notes" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "scene_elements" ("id" TEXT NOT NULL, "scene_id" TEXT NOT NULL REFERENCES scenes (id), "element_id" TEXT NOT NULL REFERENCES elements (id), "quantity" TEXT NOT NULL DEFAULT \'\', "notes" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "scene_sets" ("id" TEXT NOT NULL, "scene_id" TEXT NOT NULL REFERENCES scenes (id), "set_id" TEXT NOT NULL REFERENCES sets (id), "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "scenes" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "position" INTEGER NOT NULL, "heading" TEXT NOT NULL, "scene_number" TEXT NULL, "char_start" INTEGER NOT NULL, "char_end" INTEGER NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "screenplay_snapshots" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "created_at" TEXT NOT NULL, "reason" TEXT NOT NULL, "fountain_text" TEXT NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "screenplays" ("id" TEXT NOT NULL, "title" TEXT NOT NULL, "fountain_text" TEXT NOT NULL DEFAULT \'\', "updated_at" TEXT NOT NULL, "number" INTEGER NOT NULL DEFAULT 1, "sort_key" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "sets" ("id" TEXT NOT NULL, "location_id" TEXT NOT NULL REFERENCES locations (id), "code" TEXT NOT NULL DEFAULT \'\', "name" TEXT NOT NULL, "notes" TEXT NOT NULL DEFAULT \'\', "sort_key" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "shooting_block_candidates" ("id" TEXT NOT NULL, "block_id" TEXT NOT NULL REFERENCES shooting_day_blocks (id), "role_candidate_id" TEXT NOT NULL REFERENCES role_candidates (id), "sort_key" TEXT NOT NULL DEFAULT \'\', "notes" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "shooting_day_blocks" ("id" TEXT NOT NULL, "shooting_day_id" TEXT NOT NULL REFERENCES shooting_days (id), "sort_key" TEXT NOT NULL DEFAULT \'\', "slot_id" TEXT NOT NULL REFERENCES shooting_slots (id), "kind" TEXT NOT NULL DEFAULT \'shot\', "shot_id" TEXT NULL REFERENCES shots (id), "scene_id" TEXT NULL REFERENCES scenes (id), "label" TEXT NOT NULL DEFAULT \'\', "duration_minutes" INTEGER NULL, "anchor_minute" INTEGER NULL, "notes" TEXT NOT NULL DEFAULT \'\', "crew_note" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "shooting_day_events" ("id" TEXT NOT NULL, "shooting_day_id" TEXT NOT NULL REFERENCES shooting_days (id), "minute" INTEGER NOT NULL, "label" TEXT NOT NULL DEFAULT \'\', "notes" TEXT NOT NULL DEFAULT \'\', "sort_key" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "shooting_days" ("id" TEXT NOT NULL, "date" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT \'\', "status" TEXT NOT NULL DEFAULT \'planned\', "crew_note" TEXT NOT NULL DEFAULT \'\', "weather_note" TEXT NOT NULL DEFAULT \'\', "notes" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "shooting_slot_cast" ("id" TEXT NOT NULL, "slot_id" TEXT NOT NULL REFERENCES shooting_slots (id), "role_id" TEXT NOT NULL REFERENCES roles (id), "sort_key" TEXT NOT NULL DEFAULT \'\', "notes" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "shooting_slot_crew" ("id" TEXT NOT NULL, "slot_id" TEXT NOT NULL REFERENCES shooting_slots (id), "sort_key" TEXT NOT NULL DEFAULT \'\', "person_id" TEXT NOT NULL REFERENCES people (id), "position_id" TEXT NOT NULL DEFAULT \'\', "custom_label" TEXT NOT NULL DEFAULT \'\', "notes" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "shooting_slot_guests" ("id" TEXT NOT NULL, "slot_id" TEXT NOT NULL REFERENCES shooting_slots (id), "person_id" TEXT NULL REFERENCES people (id), "free_name" TEXT NOT NULL DEFAULT \'\', "reason" TEXT NOT NULL DEFAULT \'\', "notes" TEXT NOT NULL DEFAULT \'\', "sort_key" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "shooting_slots" ("id" TEXT NOT NULL, "shooting_day_id" TEXT NOT NULL REFERENCES shooting_days (id), "sort_key" TEXT NOT NULL DEFAULT \'\', "label" TEXT NOT NULL DEFAULT \'\', "location_id" TEXT NULL REFERENCES locations (id), "set_id" TEXT NULL REFERENCES sets (id), "anchor_edge" TEXT NOT NULL DEFAULT \'start\', "anchor_minute" INTEGER NULL, "anchor_slot_id" TEXT NULL REFERENCES shooting_slots (id), "notes" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "shot_characters" ("shot_id" TEXT NOT NULL REFERENCES shots (id), "character_name" TEXT NOT NULL, "position" INTEGER NOT NULL, "sort_key" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("shot_id", "character_name"))',
  'CREATE TABLE "shot_coverages" ("id" TEXT NOT NULL, "shot_id" TEXT NOT NULL REFERENCES shots (id), "scene_id" TEXT NOT NULL REFERENCES scenes (id), "start_offset" INTEGER NOT NULL, "end_offset" INTEGER NOT NULL, "covered_text_digest" TEXT NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "shots" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "scene_id" TEXT NULL REFERENCES scenes (id), "orphaned_heading" TEXT NULL, "position" INTEGER NOT NULL, "sort_key" TEXT NOT NULL DEFAULT \'\', "shot_size" TEXT NOT NULL DEFAULT \'\', "abbreviation" TEXT NOT NULL DEFAULT \'\', "framing" TEXT NOT NULL DEFAULT \'\', "camera_move" TEXT NOT NULL DEFAULT \'\', "lens" TEXT NOT NULL DEFAULT \'\', "recording_format" TEXT NOT NULL DEFAULT \'\', "estimated_duration_ms" INTEGER NULL, "shooting_day" TEXT NULL, "planned_takes" INTEGER NULL, "sound" TEXT NOT NULL DEFAULT \'\', "status" TEXT NOT NULL DEFAULT \'toShoot\', "difficulty_set" INTEGER NOT NULL DEFAULT 1, "difficulty_camera" INTEGER NOT NULL DEFAULT 1, "difficulty_acting" INTEGER NOT NULL DEFAULT 1, "difficulty_sound" INTEGER NOT NULL DEFAULT 1, "notes" TEXT NOT NULL DEFAULT \'\', "location_notes" TEXT NOT NULL DEFAULT \'\', "needs_check" INTEGER NOT NULL DEFAULT 0 CHECK ("needs_check" IN (0, 1)), "check_reason" TEXT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
];
