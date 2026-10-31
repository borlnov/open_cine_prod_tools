// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_packaged_asset.dart';
import 'package:open_cine_prod_tools/models/ocpt_skipped_asset.dart';

/// The `packageFormat` this build writes, and the highest one it knows how to read.
///
/// Versioned **independently of the database schema**, exactly as `OcptProjectVersionCodec`'s
/// `payloadFormat` is: what changes here is the shape of the archive around the project, not the
/// shape of the project. An older format is upgraded on read, a newer one is refused
/// (`OcptProjectPackageStatus.unsupportedPackageFormat`) rather than half-read.
const ocptCurrentPackageFormat = 1;

/// The name the project database always takes inside a package.
///
/// Fixed rather than named after the project, so a package renamed on its way through an email
/// still reads: the display name travels in [OcptProjectPackageManifest.projectName].
const ocptPackageDatabaseEntry = "project.ocpt";

/// The folder every packaged file sits under, inside the archive.
const ocptPackageAssetsDirectory = "assets";

/// The name of the manifest entry inside a package.
const ocptPackageManifestEntry = "manifest.json";

/// The extension a package file carries, and the one the save dialog restricts itself to.
///
/// The project file's own extension plus a `z`: what it holds is a project, zipped with everything
/// that project points at.
const ocptPackageFileExtension = "ocptz";

/// What a package says about itself: its own format, what wrote it, and what it carries.
///
/// It is the first thing an import reads and the only thing it may trust before opening anything:
/// the `.ocpt` beside it is a foreign file until the compatibility gate has looked at it.
class OcptProjectPackageManifest extends Equatable {
  /// The format this package is written in — see [ocptCurrentPackageFormat].
  final int packageFormat;

  /// The version of the app that wrote this package.
  final String appVersion;

  /// The `PRAGMA user_version` of the packaged `.ocpt`.
  ///
  /// Recorded for what it says rather than for what it does: the package carries the database at
  /// whatever schema it was in, and it is the **importing** build's own gate that states a
  /// migration. An export never migrates the project it copies.
  final int schemaVersion;

  /// The project's display name, as `project_info.name` held it.
  final String projectName;

  /// When this package was written.
  final DateTime exportedAt;

  /// Every file that travelled, in the order the export walked the `assets` table.
  final List<OcptPackagedAsset> assets;

  /// Every referenced file that was already gone when the package was written.
  final List<OcptSkippedAsset> skippedAssets;

  /// Class constructor
  const OcptProjectPackageManifest({
    required this.packageFormat,
    required this.appVersion,
    required this.schemaVersion,
    required this.projectName,
    required this.exportedAt,
    required this.assets,
    required this.skippedAssets,
  });

  /// Parses a manifest out of the JSON a package stores it as.
  ///
  /// Tolerant on every field but [packageFormat]: a manifest whose format this build knows is one
  /// it wrote the shape of, and a field missing from it is likelier to be an older format than a
  /// corruption — the caller checks the format first and stops there when it is too new.
  factory OcptProjectPackageManifest.fromJson(Map<String, dynamic> json) =>
      OcptProjectPackageManifest(
        packageFormat: json["packageFormat"] as int? ?? 0,
        appVersion: json["appVersion"] as String? ?? "",
        schemaVersion: json["schemaVersion"] as int? ?? 0,
        projectName: json["projectName"] as String? ?? "",
        exportedAt:
            DateTime.tryParse(json["exportedAt"] as String? ?? "") ??
            DateTime.fromMillisecondsSinceEpoch(0),
        assets: [
          for (final asset in json["assets"] as List<dynamic>? ?? const [])
            if (asset is Map<String, dynamic>) OcptPackagedAsset.fromJson(asset),
        ],
        skippedAssets: [
          for (final asset in json["skippedAssets"] as List<dynamic>? ?? const [])
            if (asset is Map<String, dynamic>) OcptSkippedAsset.fromJson(asset),
        ],
      );

  /// This manifest, as the package stores it.
  Map<String, dynamic> toJson() => {
    "packageFormat": packageFormat,
    "appVersion": appVersion,
    "schemaVersion": schemaVersion,
    "projectName": projectName,
    "exportedAt": exportedAt.toIso8601String(),
    "assets": [for (final asset in assets) asset.toJson()],
    "skippedAssets": [for (final asset in skippedAssets) asset.toJson()],
  };

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptProjectPackageManifest(packageFormat: $packageFormat, appVersion: $appVersion, "
      "schemaVersion: $schemaVersion, projectName: $projectName, exportedAt: $exportedAt, "
      "assetCount: ${assets.length}, skippedAssetCount: ${skippedAssets.length})";

  /// Object properties
  @override
  List<Object?> get props => [
    packageFormat,
    appVersion,
    schemaVersion,
    projectName,
    exportedAt,
    assets,
    skippedAssets,
  ];
}
