// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
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

  /// The open connection to the project's SQLite database.
  final OcptProjectDatabase database;

  /// Class constructor
  const OcptOpenProjectModel({
    required this.path,
    required this.name,
    required this.primaryScreenplayId,
    required this.database,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptOpenProjectModel(path: $path, name: $name)";

  /// Object properties
  ///
  /// [database] deliberately isn't part of the equality: two [OcptOpenProjectModel] describing
  /// the same project file are considered equal regardless of the identity of their database
  /// connection, and only one project is ever open at a time anyway.
  @override
  List<Object?> get props => [path, name, primaryScreenplayId];
}
