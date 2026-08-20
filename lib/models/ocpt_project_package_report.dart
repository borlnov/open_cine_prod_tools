// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_manifest.dart';

/// What an export found before writing anything: how many files the project references, and which
/// of them are no longer there.
///
/// This is what the question asked before a package is written is built from — the page or the mode
/// opens `OcptConfirmDialog` with it when [missingAssets] is not empty, and writes straight away
/// when it is. Scanning is cheap (it stats one file per `assets` row) and reads nothing else.
class OcptProjectPackagePreflight extends Equatable {
  /// How many live `assets` rows the project holds, missing files included.
  final int referencedAssetCount;

  /// Every referenced file that is not where its row says it is.
  final List<OcptSkippedAsset> missingAssets;

  /// Class constructor
  const OcptProjectPackagePreflight({
    required this.referencedAssetCount,
    required this.missingAssets,
  });

  /// Whether every referenced file is where it should be, and so nothing has to be asked.
  bool get isComplete => missingAssets.isEmpty;

  /// Object properties
  @override
  List<Object?> get props => [referencedAssetCount, missingAssets];
}

/// What an export actually wrote.
///
/// [skippedAssets] repeats what the preflight already said rather than deriving from it: the file
/// that vanished between the question and the write belongs in the report too, and the report is
/// what the manifest carries to the other machine.
class OcptProjectPackageExportReport extends Equatable {
  /// Where the package was written.
  final String packagePath;

  /// How many referenced files travelled inside it.
  final int packagedAssetCount;

  /// Every referenced file that did not, because it was already gone.
  final List<OcptSkippedAsset> skippedAssets;

  /// Class constructor
  const OcptProjectPackageExportReport({
    required this.packagePath,
    required this.packagedAssetCount,
    required this.skippedAssets,
  });

  /// Object properties
  @override
  List<Object?> get props => [packagePath, packagedAssetCount, skippedAssets];
}

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

  /// Object properties
  @override
  List<Object?> get props => [projectFilePath, projectName, importedAssetCount, skippedAssets];
}
