// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_card_choice_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_manifest.dart';
import 'package:open_cine_prod_tools/types/ocpt_home_import_kind.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_card_choice_dialog.dart';

/// The modal the home header's `Import…` action opens: two cards, `A project` (`.ocptz`) and
/// `A screenplay` (`.fountain`), named side by side where somebody comparing the two gestures can
/// see them together.
///
/// The import flavour of [OcptCardChoiceDialog], exactly as `OcptWorkspaceExportDialog` is its
/// export flavour: it owns the wording of its own two cards and nothing else, in one section with
/// no heading — the dialog's own message already says what the two cards are for.
class OcptHomeImportDialog extends StatelessWidget {
  /// Class constructor
  const OcptHomeImportDialog({super.key});

  /// Shows the dialog and returns the kind of import the user picked, or null if they cancelled it
  /// or picked no card at all.
  static Future<OcptHomeImportKind?> show(BuildContext context) => showDialog<OcptHomeImportKind>(
    context: context,
    builder: (context) => const OcptHomeImportDialog(),
  );

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return OcptCardChoiceDialog<OcptHomeImportKind>(
      title: tr.homeImportDialogTitle,
      message: tr.homeImportDialogMessage,
      sections: [
        OcptCardChoiceSection<OcptHomeImportKind>(
          entries: [
            OcptCardChoiceEntry<OcptHomeImportKind>(
              value: OcptHomeImportKind.project,
              title: tr.homeImportProjectTitle,
              description: tr.homeImportProjectDescription,
              formatLabel: ".$ocptPackageFileExtension",
            ),
            OcptCardChoiceEntry<OcptHomeImportKind>(
              value: OcptHomeImportKind.screenplay,
              title: tr.homeImportScreenplayTitle,
              description: tr.homeImportScreenplayDescription,
              formatLabel: ".fountain",
            ),
          ],
        ),
      ],
    );
  }
}
