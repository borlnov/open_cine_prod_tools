// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/utils/ocpt_synchronised_tables.dart';

void main() {
  late OcptProjectDatabase database;

  setUp(() {
    database = OcptProjectDatabase.memory();
  });

  tearDown(() async {
    await database.close();
  });

  /// Every synchronised table `docs/adr/0010-sync-ready-data-model-prerequisites.md` puts an
  /// `isDeleted` column on, minus `scenes` — the whole schema on the day this test was written,
  /// kept as a literal list so this test actually pins the rule's *result* rather than merely
  /// re-running the same column check under test.
  const expectedSynchronisedTableNames = {
    'screenplays',
    'screenplay_snapshots',
    'shots',
    'shot_characters',
    'shot_coverages',
    'people',
    'person_positions',
    'person_skills',
    'person_unavailabilities',
    'roles',
    'role_episodes',
    'locations',
    'location_availabilities',
    'sets',
    'scene_sets',
    'elements',
    'scene_elements',
    'role_elements',
    'role_candidates',
    'assets',
    'breakdown_tags',
    'scene_breakdowns',
    'shooting_days',
    'shooting_slots',
    'shooting_slot_crew',
    'shooting_slot_cast',
    'shooting_day_blocks',
    'shooting_slot_guests',
    'shooting_block_candidates',
    'shooting_day_events',
    'project_dictionary_words',
    'budget_postes',
    'budget_lines',
    'budget_entries',
    'budget_commitments',
    'budget_mileage_rates',
    'budget_resources',
    'budget_revenues',
    'budget_shares',
    'budget_allowances',
  };

  test('equals the whole schema minus scenes and every local table', () {
    final names = ocptSynchronisedTables(database).map((table) => table.actualTableName).toSet();

    expect(names, expectedSynchronisedTableNames);
  });

  test('excludes scenes, which is derived rather than edited directly', () {
    final names = ocptSynchronisedTables(database).map((table) => table.actualTableName).toSet();

    expect(names, isNot(contains('scenes')));
  });

  test('excludes every local, never-synchronised table', () {
    final names = ocptSynchronisedTables(database).map((table) => table.actualTableName).toSet();
    const localTableNames = {
      'project_info',
      'row_field_versions',
      'project_versions',
      'local_erasures',
      'sync_relay_cursors',
    };

    expect(names.intersection(localTableNames), isEmpty);
  });
}
