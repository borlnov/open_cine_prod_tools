// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/models/ocpt_recent_project_model.dart';

/// The project `OcptProjectsManager` currently has open, if any.
///
/// Unlike [OcptRecentProjectModel], which is a plain, JSON-serializable record of a project's
/// last known path/name, this model wraps the live [database] connection of the project that is
/// actually open right now: there is at most one such instance alive at a time.
class OcptOpenProjectModel extends Equatable {
  /// The absolute path to the project file on disk.
  final String path;

  /// The display name of the project, as read from `project_info.name`.
  final String name;

  /// The id of the project's screenplay, the one shown in the editor.
  ///
  /// Every project currently has exactly one screenplay, created alongside the project.
  final String primaryScreenplayId;

  /// The connection every mode reads through, and every user edit is written through.
  ///
  /// This is [fileDatabase] itself outside a preview, and the in-memory database holding
  /// [previewedVersion]'s state while one is on screen. That substitution is the whole of the
  /// preview mechanism: because every read and every user-driven write in the app already goes
  /// through this one slot, no mode has to learn a second data path to display a version.
  final OcptProjectDatabase database;

  /// The connection to the project file itself, never swapped and never closed by a preview.
  ///
  /// Outside a preview this is the very same instance as [database]. It exists as a slot of its
  /// own because the app is about to have a second writer: the collaboration engine applies
  /// incoming changesets to the **project file** on its own schedule, and a changeset arriving
  /// while the user is reading a version has nothing to do with that version — it must land in the
  /// working copy either way. Nothing in the app reads this except `OcptProjectVersionsService`,
  /// which lists, creates and deletes versions against the real file even while a preview is up.
  final OcptProjectDatabase fileDatabase;

  /// The version being previewed read-only, or null when the working copy is on screen.
  final OcptProjectVersion? previewedVersion;

  /// The page setup [previewedVersion]'s payload carried, or null when no version is previewed.
  ///
  /// A preview renders with the layout the version was written against — that is what keeps the
  /// page count shown on its card true — but it **never writes it anywhere**: the page format is
  /// project data and the margins are an app-wide preference, so both are left exactly as they
  /// stand until the user actually restores the version. Carrying the setup here rather than in
  /// the preview database's header is what makes that impossible to get wrong.
  final OcptPageSetup? previewedPageSetup;

  /// Class constructor
  ///
  /// [database] is both slots at once: a freshly opened project has no preview, so what the modes
  /// read and what the project file holds are the same connection.
  const OcptOpenProjectModel({
    required this.path,
    required this.name,
    required this.primaryScreenplayId,
    required OcptProjectDatabase database,
  }) : database = database,
       fileDatabase = database,
       previewedVersion = null,
       previewedPageSetup = null;

  /// Builds the previewing/working-copy variants of an existing model.
  const OcptOpenProjectModel._({
    required this.path,
    required this.name,
    required this.primaryScreenplayId,
    required this.database,
    required this.fileDatabase,
    required this.previewedVersion,
    required this.previewedPageSetup,
  });

  /// Whether what is on screen is a version being previewed, which the user may not edit.
  ///
  /// This is the single source of truth for the read-only state: each mode's bloc gets it from the
  /// project stream it already listens to and gates its own affordances with it, and the mutating
  /// services refuse a write handed the preview database (see
  /// `OcptProjectDatabase.refusesUserWrite`). It is derived from [previewedVersion] rather than
  /// stored beside it so the two can't disagree.
  bool get isReadOnly => previewedVersion != null;

  /// The same open project, seen through [previewDatabase]: the in-memory database [version]'s
  /// payload was hydrated into, laid out with [pageSetup].
  ///
  /// [fileDatabase] is carried over untouched — the project file stays open, and stays writable
  /// for everything that isn't a user edit of what is on screen.
  OcptOpenProjectModel previewing({
    required OcptProjectDatabase previewDatabase,
    required OcptProjectVersion version,
    required OcptPageSetup pageSetup,
  }) => OcptOpenProjectModel._(
    path: path,
    name: name,
    primaryScreenplayId: primaryScreenplayId,
    database: previewDatabase,
    fileDatabase: fileDatabase,
    previewedVersion: version,
    previewedPageSetup: pageSetup,
  );

  /// The same open project, back on its own file: what `OcptProjectsManager.exitPreview` emits
  /// once it has closed the preview database.
  OcptOpenProjectModel get workingCopy => OcptOpenProjectModel._(
    path: path,
    name: name,
    primaryScreenplayId: primaryScreenplayId,
    database: fileDatabase,
    fileDatabase: fileDatabase,
    previewedVersion: null,
    previewedPageSetup: null,
  );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptOpenProjectModel(path: $path, name: $name, previewedVersion: $previewedVersion)";

  /// Object properties
  ///
  /// Neither [database] nor [fileDatabase] is part of the equality: two [OcptOpenProjectModel]
  /// describing the same project file are considered equal regardless of the identity of their
  /// database connections, and only one project is ever open at a time anyway.
  ///
  /// [previewedVersion] on the other hand **must** be, and with it [isReadOnly] and the previewed
  /// version's id: entering or leaving a preview keeps the path, the name and the screenplay id
  /// unchanged, so a model that left it out would compare equal to the one before it and no bloc
  /// would ever rebuild.
  @override
  List<Object?> get props => [path, name, primaryScreenplayId, previewedVersion];
}
