// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';

/// The outcome of entering the read-only preview of a project version.
///
/// This is used as the [ResultWithStatus] status of `OcptProjectsManager.previewVersion`. Every
/// failure leaves the working copy exactly as it was: a preview that can't be entered is never a
/// half-entered one.
enum OcptProjectPreviewStatus with MixinResultStatus {
  /// The preview is on screen: the current project now reads through the version's own in-memory
  /// database.
  ok(isSuccess: true, canBeRetried: false),

  /// No project is open, so there is nothing to preview a version of.
  noProjectOpen(isSuccess: false, canBeRetried: false),

  /// A mode still holds unsaved changes. Entering a preview swaps the database every edit is
  /// written through, so a pending autosave would land in the previewed version instead of the
  /// working copy: the caller saves first, then retries.
  unsavedChanges(isSuccess: false, canBeRetried: true),

  /// The requested version doesn't exist in this project any more.
  versionNotFound(isSuccess: false, canBeRetried: false),

  /// The version's payload was written by a later build of the app: it is refused rather than
  /// half-read. The user's way out is to update Open Cine Prod Tools.
  unsupportedFutureFormat(isSuccess: false, canBeRetried: false),

  /// The version's payload isn't readable at all: that version is lost, but the project isn't.
  malformedPayload(isSuccess: false, canBeRetried: false),

  /// The version was read but its state couldn't be hydrated into an in-memory database.
  hydrationFailed(isSuccess: false, canBeRetried: true);

  /// {@macro act_dart_result.MixinResultStatus.isSuccess}
  @override
  final bool isSuccess;

  /// {@macro act_dart_result.MixinResultStatus.canBeRetried}
  @override
  final bool canBeRetried;

  /// Class constructor
  const OcptProjectPreviewStatus({required this.isSuccess, required this.canBeRetried});
}
