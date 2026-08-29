// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';

// This file is the harness that will pin each future stable release's upgrade path: once
// `OcptProjectDatabase.lastStableSchemaVersion` is first raised above 0
// (`docs/adr/0029-schema-versions-frozen-at-stable-releases.md`), an `onUpgrade` step exists for
// the first time, and this file gains a verbatim `CREATE TABLE` DDL fixture for the schema that
// release froze plus a test that migrating that fixture onto the current schema lands on exactly
// what `onCreate` produces — proving `onCreate == every stable upgrade path` the way ADR 0029
// requires. Today `lastStableSchemaVersion == 0`: no stable release has shipped, so there is no
// frozen schema to pin yet, and the tests below only cover what always holds regardless.

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
