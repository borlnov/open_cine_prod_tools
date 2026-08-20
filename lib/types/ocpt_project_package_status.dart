// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';

/// The outcome of writing or reading a portable project package.
///
/// A package is the whole project as one file somebody can send: the `.ocpt` plus every file it
/// references. See `OcptProjectPackageService` for what travels in one and what deliberately does
/// not. Cancelling a dialog is not one of these: the caller picks the paths and simply never asks
/// for the operation.
enum OcptProjectPackageStatus with MixinResultStatus {
  /// The package was written, or read back, in full.
  ok(isSuccess: true, canBeRetried: false),

  /// The project file the export was pointed at is not there, or holds no project at all.
  sourceNotFound(isSuccess: false, canBeRetried: false),

  /// The archive could not be read as a package: it is not a zip, or it holds no manifest.
  unreadableArchive(isSuccess: false, canBeRetried: false),

  /// The package states a `packageFormat` this build does not know how to read.
  ///
  /// The refusal a newer package gets, on the model of `OcptProjectVersionCodec`'s own contract: an
  /// older format is upgraded on read, a newer one is refused rather than half-read.
  unsupportedPackageFormat(isSuccess: false, canBeRetried: false),

  /// The folder the import would create is already there.
  ///
  /// Refused rather than merged or overwritten: what sits in it is somebody's project, and an
  /// import that wrote over it would be the one destructive act in this whole feature. Retryable
  /// because picking another parent folder is all it takes.
  destinationExists(isSuccess: false, canBeRetried: true),

  /// Reading or writing failed for a reason the app can only report (a full disk, a permission).
  ioError(isSuccess: false, canBeRetried: true);

  /// {@macro act_dart_result.MixinResultStatus.isSuccess}
  @override
  final bool isSuccess;

  /// {@macro act_dart_result.MixinResultStatus.canBeRetried}
  @override
  final bool canBeRetried;

  /// Class constructor
  const OcptProjectPackageStatus({required this.isSuccess, required this.canBeRetried});
}
