// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';

// This file is the harness that will pin each future stable release's upgrade path
// (`docs/adr/0029-schema-versions-frozen-at-stable-releases.md`). The 0.1.0 release froze the
// schema at v1, so `lastStableSchemaVersion == currentSchemaVersion == 1`: that release squashed
// every pre-release migration into a single `onCreate` baseline, so there is still no `onUpgrade`
// step and no frozen-schema DDL fixture to pin yet. The first schema change *after* 0.1.0 will bump
// `currentSchemaVersion` to 2, add the first `onUpgrade` step, and this file will then gain a
// verbatim `CREATE TABLE` DDL fixture for the v1 schema plus a test that migrating that fixture
// onto the current schema lands on exactly what `onCreate` produces — proving
// `onCreate == every stable upgrade path` the way ADR 0029 requires. The tests below only cover
// what always holds regardless.

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
      ]),
    );

    final userVersion = await database.customSelect('PRAGMA user_version').getSingle();
    expect(userVersion.data['user_version'], OcptProjectDatabase.currentSchemaVersion);
  });
}
