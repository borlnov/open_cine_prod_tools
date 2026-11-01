// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_skipped_asset.dart';

/// What an import actually unpacked, and what it landed the user with.
///
/// [skippedAssets] is copied straight from the manifest rather than recomputed: the files it
/// names were never in the archive to begin with, so there is nothing here to check them against
/// — the export already asked whoever sent this package, and the rule of ADR 0021 is that the same
/// list is reported again to whoever receives it, so a colleague who was handed a project with a
/// missing filming permit finds out from their own machine too, not only from the sender's.
class OcptProjectPackageImportReport extends Equatable {
  /// The `.ocpt` this import wrote, ready to be opened through the compatibility gate
  /// (`OcptProjectsManager.probeProjectFile`/`openProject`) — never opened directly here, since a
  /// package may carry a database at a schema version this build would migrate, and stating that
  /// migration is that gate's job, not this import's.
  final String projectFilePath;

  /// The project's display name, as the manifest carried it — not necessarily the name of the
  /// folder it landed in, since [projectFilePath]'s folder is a filesystem-safe rendering of it
  /// (`ocptSafeFileNameOf`) rather than the name itself.
  final String projectName;

  /// How many referenced files were unpacked and had their `assets` row rewritten onto where they
  /// now sit.
  final int importedAssetCount;

  /// Every referenced file the export could not carry, because it was already gone when the
  /// package was written.
  final List<OcptSkippedAsset> skippedAssets;

  /// Class constructor
  const OcptProjectPackageImportReport({
    required this.projectFilePath,
    required this.projectName,
    required this.importedAssetCount,
    required this.skippedAssets,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptProjectPackageImportReport(projectFilePath: $projectFilePath, "
      "projectName: $projectName, importedAssetCount: $importedAssetCount, "
      "skippedAssetCount: ${skippedAssets.length})";

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [projectFilePath, projectName, importedAssetCount, skippedAssets];
}
