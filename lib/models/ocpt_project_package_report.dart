// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_skipped_asset.dart';

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

  /// Whether every referenced file is where it should be, and so nothing has to be asked.
  bool get isComplete => missingAssets.isEmpty;

  /// Class constructor
  const OcptProjectPackagePreflight({
    required this.referencedAssetCount,
    required this.missingAssets,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptProjectPackagePreflight(referencedAssetCount: $referencedAssetCount, "
      "missingAssetCount: ${missingAssets.length})";

  /// Object properties
  @override
  List<Object?> get props => [referencedAssetCount, missingAssets];
}
