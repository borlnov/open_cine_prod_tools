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
