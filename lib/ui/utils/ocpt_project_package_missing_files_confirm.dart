// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_manifest.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_report.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_confirm_dialog.dart';
import 'package:path/path.dart' as p;

/// The separator between two missing files in the question's own list.
const _ocptMissingAssetsSeparator = ", ";

/// Asks whether to write the package even though [preflight] found files the project references
/// and that are no longer there, and returns true if the user said to go on.
///
/// Opened by the mode, never by a widget, exactly as every other question this app asks — and
/// worded here rather than in each of the five modes, since what it asks about is the project
/// rather than the mode the user happened to be standing in.
///
/// Not destructive: nothing is lost by exporting, the files are already gone. What the question
/// buys is that a package never travels short in silence — the import states the same list again as
/// the project lands.
Future<bool?> ocptAskAboutMissingPackagedFiles(
  BuildContext context,
  OcptProjectPackagePreflight preflight,
) {
  final tr = Tr.of(context);
  final missingAssets = preflight.missingAssets;

  return OcptConfirmDialog.show(
    context,
    title: tr.projectPackageMissingFilesConfirmTitle,
    message: tr.projectPackageMissingFilesConfirmMessage(
      missingAssets.length,
      missingAssets.map(_ocptMissingAssetLabel).join(_ocptMissingAssetsSeparator),
    ),
    cancelLabel: tr.projectPackageMissingFilesConfirmCancelAction,
    confirmLabel: tr.projectPackageMissingFilesConfirmContinueAction,
    isDestructive: false,
  );
}

/// How [asset] is named in the question: its own label, or the file name its path ends on for a row
/// that never got one.
///
/// A row with no label is an ordinary state — a photo dropped in and never named — and the whole
/// point of listing them is that the user recognises what is missing.
String _ocptMissingAssetLabel(OcptSkippedAsset asset) =>
    asset.label.isNotEmpty ? asset.label : p.basename(asset.originalPath);
