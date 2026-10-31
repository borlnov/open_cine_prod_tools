// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// One file that travelled inside the package, and the `assets` row it belongs to.
class OcptPackagedAsset extends Equatable {
  /// The id of the `assets` row this file is referenced by.
  final String assetId;

  /// Where this file sits inside the archive, relative to its root.
  final String entry;

  /// The absolute path this file was referenced by on the machine that exported it.
  ///
  /// Kept for the record alone: the import rewrites the row onto what it just unpacked, and never
  /// tries this path. It is what lets a report say *which* file a row used to name.
  final String originalPath;

  /// Class constructor
  const OcptPackagedAsset({required this.assetId, required this.entry, required this.originalPath});

  /// Parses one packaged asset out of the JSON the manifest stores it as.
  factory OcptPackagedAsset.fromJson(Map<String, dynamic> json) => OcptPackagedAsset(
    assetId: json["assetId"] as String? ?? "",
    entry: json["entry"] as String? ?? "",
    originalPath: json["originalPath"] as String? ?? "",
  );

  /// This asset, as the manifest stores it.
  Map<String, dynamic> toJson() => {
    "assetId": assetId,
    "entry": entry,
    "originalPath": originalPath,
  };

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptPackagedAsset(assetId: $assetId, entry: $entry, originalPath: $originalPath)";

  /// Object properties
  @override
  List<Object?> get props => [assetId, entry, originalPath];
}
