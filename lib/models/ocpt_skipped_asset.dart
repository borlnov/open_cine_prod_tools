// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// One file the export could **not** carry, because it was no longer where its `assets` row said.
///
/// A dangling reference is a normal state (`docs/adr/0013-binary-assets-referenced-by-path.md`),
/// so it never blocks an export — but it is stated twice: to whoever exports, before a single byte
/// is written, and to whoever imports, as the project lands. An export that silently shipped fewer
/// files than the project references would be a lie both ends could act on.
class OcptSkippedAsset extends Equatable {
  /// The id of the `assets` row whose file was missing.
  final String assetId;

  /// The row's own label, which is how the user knows *what* is missing.
  final String label;

  /// The absolute path the row names, and where nothing was found.
  final String originalPath;

  /// Class constructor
  const OcptSkippedAsset({required this.assetId, required this.label, required this.originalPath});

  /// Parses one skipped asset out of the JSON the manifest stores it as.
  factory OcptSkippedAsset.fromJson(Map<String, dynamic> json) => OcptSkippedAsset(
    assetId: json["assetId"] as String? ?? "",
    label: json["label"] as String? ?? "",
    originalPath: json["originalPath"] as String? ?? "",
  );

  /// This asset, as the manifest stores it.
  Map<String, dynamic> toJson() => {
    "assetId": assetId,
    "label": label,
    "originalPath": originalPath,
  };

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptSkippedAsset(assetId: $assetId, label: $label, originalPath: $originalPath)";

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [assetId, label, originalPath];
}
