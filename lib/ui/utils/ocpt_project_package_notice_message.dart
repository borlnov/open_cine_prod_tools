// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_notice.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_package_notice_kind.dart';

/// The localized, user-facing message reporting [notice], shown as a SnackBar over whichever
/// production mode the `Export` panel was opened from.
///
/// Shared by every mode rather than mapped again in each page, for the same reason the standing
/// card is the panel's own: the outcome describes the project, not the mode that happened to ask.
///
/// A package that travelled short says so in the very sentence that says it was written — one
/// SnackBar, not two, and never a success that quietly drops what the user was warned about.
String ocptProjectPackageNoticeMessage(BuildContext context, OcptProjectPackageNotice notice) {
  final tr = Tr.of(context);

  return switch (notice.kind) {
    OcptProjectPackageNoticeKind.exportSucceeded => notice.skippedAssetCount > 0
        ? tr.projectPackageExportSuccessWithSkippedMessage(
            notice.path ?? "",
            notice.skippedAssetCount,
          )
        : tr.projectPackageExportSuccessMessage(notice.path ?? ""),
    OcptProjectPackageNoticeKind.exportFailed => tr.projectPackageExportError,
    OcptProjectPackageNoticeKind.exportShared => tr.projectPackageExportShared,
  };
}
