// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_skipped_asset.dart';

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

  /// Get a string representation of the object, useful for debugging and logging.
  @override
  String toString() =>
      "OcptProjectPackageExportReport(packagePath: $packagePath, "
      "packagedAssetCount: $packagedAssetCount, skippedAssetCount: ${skippedAssets.length})";

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [packagePath, packagedAssetCount, skippedAssets];
}
