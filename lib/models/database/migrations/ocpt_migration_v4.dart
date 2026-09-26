// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';

/// Schema version 4's own `onUpgrade` step, called from [OcptProjectDatabase.migration] for a file
/// opened below it: creates the five tables the storyboard and floor plans mode is built on
/// (`docs/plans/storyboard.md`, §2, §3) — `storyboard_panels`, `storyboard_annotations`,
/// `floor_plan_sets`, `floor_plan_symbols` and `floor_plan_arrows`.
///
/// **Additive only** (`docs/adr/0007-schema-migration-policy.md`): five `createTable` calls, nothing
/// else — no reshape, no backfill, no existing table touched. A v3 file opened by this build gains
/// five empty tables and keeps every row it already held.
///
/// Because schema version 4 is still an open development cycle (`OcptProjectDatabase
/// .currentSchemaVersion`'s own doc comment), every reshape landed since — `floor_plan_symbols
/// .setElementShape`/`.fovReachM`/`.sceneId`/`.overridesSymbolId`, `floor_plan_arrows.ctrlXM`/
/// `.ctrlYM`, and `floor_plan_sets` losing `sceneId`/`name`/`sortKey` in favour of its own id being
/// the Resources set's (`docs/plans/storyboard.md`, §10) — was made straight on the table classes
/// rather than through a v5 migration: this step's `createTable` calls already produce the current
/// shape, with no `addColumn`/reshape step of its own needed.
Future<void> ocptMigrateToSchemaV4({
  required Migrator migrator,
  required OcptProjectDatabase database,
}) async {
  await migrator.createTable(database.ocptStoryboardPanelsTable);
  await migrator.createTable(database.ocptStoryboardAnnotationsTable);
  await migrator.createTable(database.ocptFloorPlanSetsTable);
  await migrator.createTable(database.ocptFloorPlanSymbolsTable);
  await migrator.createTable(database.ocptFloorPlanArrowsTable);
}
