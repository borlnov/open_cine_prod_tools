// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_manifest.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_project_package_missing_files_confirm.dart';

/// States that some of the files an imported package's project references did not travel — they
/// were already missing when the package was written, and the import is only reporting that again.
///
/// A dialog rather than a SnackBar, shown **before** the workspace is pushed — a transient message
/// would be covered by the pushed workspace within the second, and a fact this specific (which
/// files, how many) deserves the same standing `OcptProjectFileNewerDialog` gives a refusal: read
/// at the user's own pace, not glimpsed on the way past. It carries a single button rather than
/// `OcptConfirmDialog`'s two, exactly for `OcptProjectFileNewerDialog`'s own reason — there is
/// nothing to confirm, only something to have read before moving on.
///
/// Nothing at all is shown when a package carried no skipped file: the project opening behind it is
/// the report, and a dialog with nothing to say would only be in the way. Use [show] to display it;
/// it is dismissed through `OcptRouterManager.pop`, never `Navigator`.
class OcptProjectPackageSkippedFilesDialog extends StatelessWidget {
  /// The files the import could not carry, named as [ocptAskAboutMissingPackagedFiles]'s own
  /// question would have named them, had the export not already asked about them once.
  final List<OcptSkippedAsset> skippedAssets;

  /// Class constructor
  const OcptProjectPackageSkippedFilesDialog({super.key, required this.skippedAssets});

  /// Shows the dialog, and completes once the user has dismissed it.
  static Future<void> show(BuildContext context, {required List<OcptSkippedAsset> skippedAssets}) =>
      showDialog<void>(
        context: context,
        builder: (context) => OcptProjectPackageSkippedFilesDialog(skippedAssets: skippedAssets),
      );

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return AlertDialog(
      title: Text(tr.homeImportSkippedFilesTitle),
      content: Text(
        tr.homeImportSkippedFilesMessage(
          skippedAssets.length,
          skippedAssets.map(ocptMissingAssetLabel).join(ocptMissingAssetsSeparator),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => globalGetIt().get<OcptRouterManager>().pop(),
          child: Text(tr.homeImportSkippedFilesCloseAction),
        ),
      ],
    );
  }
}
