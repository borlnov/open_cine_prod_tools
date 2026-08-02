// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_version_notice_kind.dart';

/// The localized, user-facing message reporting [kind], shown as a SnackBar over whichever
/// production mode the `Versions` dock tab was used from.
///
/// Shared by every mode rather than mapped again in each page, for the same reason the panel
/// itself is shared: the outcome describes the project, not the mode that happened to ask.
String ocptProjectVersionNoticeMessage(BuildContext context, OcptProjectVersionNoticeKind kind) {
  final tr = Tr.of(context);

  return switch (kind) {
    OcptProjectVersionNoticeKind.creationFailed => tr.projectVersionCreationError,
    OcptProjectVersionNoticeKind.deletionFailed => tr.projectVersionDeletionError,
    OcptProjectVersionNoticeKind.previewBlockedByUnsavedChanges =>
      tr.projectVersionPreviewUnsavedChangesError,
    OcptProjectVersionNoticeKind.previewUnsupportedFormat =>
      tr.projectVersionPreviewUnsupportedFormatError,
    OcptProjectVersionNoticeKind.previewFailed => tr.projectVersionPreviewError,
    OcptProjectVersionNoticeKind.restoreFailed => tr.projectVersionRestoreError,
    OcptProjectVersionNoticeKind.restoreUnsupportedFormat =>
      tr.projectVersionRestoreUnsupportedFormatError,
  };
}
