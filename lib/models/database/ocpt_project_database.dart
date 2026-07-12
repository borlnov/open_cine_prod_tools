// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_project_info_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_scenes_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_screenplay_snapshots_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_screenplays_table.dart';
// These two are only used through the OcptPageFormatConverter/OcptSnapshotReasonConverter type
// converters (declared in the table files above), but the generated ocpt_project_database.g.dart
// part file below references them directly: since a part file shares its main library's imports
// rather than having its own, they must be imported here too for that generated code to resolve.
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';

part 'ocpt_project_database.g.dart';

/// The per-project SQLite database backing a single `.ocpt` project file.
///
/// Every Open Cine Prod Tools project is one such database: it holds the project metadata
/// ([OcptProjectInfoTable]), its screenplay(s) ([OcptScreenplaysTable]), safety copies of their
/// text ([OcptScreenplaySnapshotsTable]) and the reconciled scene index ([OcptScenesTable]).
/// `OcptProjectsManager` owns the single instance open at a time.
@DriftDatabase(
  tables: [OcptProjectInfoTable, OcptScreenplaysTable, OcptScreenplaySnapshotsTable, OcptScenesTable],
)
class OcptProjectDatabase extends _$OcptProjectDatabase {
  /// Opens (creating it if needed) the project database stored at [file].
  OcptProjectDatabase(File file) : super(NativeDatabase(file));

  /// Opens a project database backed by an in-memory SQLite instance, for use in tests only: its
  /// content is lost as soon as the database is closed.
  OcptProjectDatabase.memory() : super(NativeDatabase.memory());

  /// {@macro drift.GeneratedDatabase.schemaVersion}
  @override
  int get schemaVersion => 1;

  /// The database options used by this database.
  ///
  /// `DriftDatabaseOptions.storeDateTimeAsText` is turned on so `dateTime()` columns (e.g.
  /// `screenplay_snapshots.createdAt`) keep full, sub-second precision instead of drift's default
  /// whole-second unix timestamp: several snapshots can otherwise be taken within the same
  /// second (e.g. a burst of saves), which would make them tie when ordered by `createdAt` and
  /// break `OcptScreenplayService`'s "most recent" pruning.
  @override
  DriftDatabaseOptions get options => const DriftDatabaseOptions(storeDateTimeAsText: true);
}
