// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version_summary.dart';

/// One entry of a project's version list, as `OcptProjectVersionsService.listVersions` builds it
/// and the `Versions` dock tab draws it.
///
/// {@macro open_cine_prod_tools.OcptProjectVersionsTable.versusSnapshots}
///
/// This carries **only what a card shows**, never the [OcptProjectVersionRow.payload] it was built
/// from: listing versions must stay a cheap query, and a payload is hundreds of kilobytes. The
/// row's remaining columns — the app version that wrote it, the payload's own format, and the
/// device id of the replica that created it — are recorded for provenance and read by nothing: the
/// app has no accounts, and nothing in this list may name a person or a machine.
class OcptProjectVersion extends Equatable {
  /// The stable, unique id of this version.
  final String id;

  /// The user-facing name of this version.
  final String name;

  /// The user's free-text description of this version; empty when they wrote none.
  final String note;

  /// The date and time at which the user created this version.
  final DateTime createdAt;

  /// The counters shown on this version's card, as they were measured when it was created.
  final OcptProjectVersionSummary summary;

  /// Whether the working copy descends from this version, i.e. whether
  /// `project_info.currentVersionId` points at it.
  ///
  /// This is a read-time property rather than a stored column: the pointer lives in the project
  /// header, and the loading service resolves it once for the whole list.
  final bool isCurrent;

  /// Class constructor
  const OcptProjectVersion({
    required this.id,
    required this.name,
    required this.note,
    required this.createdAt,
    required this.summary,
    required this.isCurrent,
  });

  /// Builds the version described by [row], flagged [isCurrent] by the caller, which is the one
  /// that knows the project header's pointer.
  factory OcptProjectVersion.fromRow({
    required OcptProjectVersionRow row,
    required bool isCurrent,
  }) => OcptProjectVersion(
    id: row.id,
    name: row.name,
    note: row.note,
    createdAt: row.createdAt,
    summary: OcptProjectVersionSummary.parse(row.summaryJson),
    isCurrent: isCurrent,
  );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptProjectVersion(id: $id, name: $name, createdAt: $createdAt, isCurrent: $isCurrent)";

  /// Object properties
  @override
  List<Object?> get props => [id, name, note, createdAt, summary, isCurrent];
}
