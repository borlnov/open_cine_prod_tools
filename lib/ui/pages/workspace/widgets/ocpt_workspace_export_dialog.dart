// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_card_choice_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_manifest.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_export_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_export_pick.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_card_choice_dialog.dart';

/// The panel every production mode's toolbar `Export` button opens: the documents the active mode
/// knows how to print, generic over that mode's own export enum [T], and under them the project
/// itself.
///
/// The export flavour of [OcptCardChoiceDialog], which owns the grid, the greying and the popping;
/// what this adds is the wording of the panel's own standing card.
///
/// **The project package card is this dialog's, not the modes'.** It sits in every mode's panel,
/// below the documents behind a divider and its own heading, because it is not a document: nobody
/// reads it, it is the project. Five modes each declaring it in their own export enum would let its
/// wording, its position and its availability drift apart mode by mode, the same reasoning that
/// makes the end of the toolbar the shell's own chrome. Which is why the pick is
/// [OcptWorkspaceExportPick] rather than a bare `T`: the panel can hand back something no mode's
/// enum has a value for.
///
/// Under a version preview that card is drawn **unavailable with a reason** rather than withheld,
/// which is this panel's standing exception to the app's "withhold, don't disable" rule and is
/// arbitrated as such: what it would export is the working copy on disk, which is not what the user
/// is looking at, while every other export under a preview writes what *is* on screen. Leaving it
/// clickable would make it the odd one out in the one way that matters, and hiding it would make
/// the panel lie about what the app knows how to produce. The reason on the greyed card says all of
/// it. [isPreviewingVersion] is what the mode tells this dialog for that, and nothing else.
///
/// [title] and [message] are plain strings handed in by the caller, the wording of both being
/// per-mode.
class OcptWorkspaceExportDialog<T> extends StatelessWidget {
  /// The dialog's title.
  final String title;

  /// The sentence under the title saying what this panel is.
  final String message;

  /// The documents the active mode offers, one card each, in the given order.
  final List<OcptWorkspaceExportEntry<T>> entries;

  /// Whether a version is currently being previewed, which is what greys the project package card.
  final bool isPreviewingVersion;

  /// Class constructor
  const OcptWorkspaceExportDialog({
    required this.title,
    required this.message,
    required this.entries,
    required this.isPreviewingVersion,
    super.key,
  });

  /// Shows the dialog and returns what the user picked — one of [entries]' own values, or the
  /// project package — or null if they cancelled it or picked no card at all.
  static Future<OcptWorkspaceExportPick<T>?> show<T>(
    BuildContext context, {
    required String title,
    required String message,
    required List<OcptWorkspaceExportEntry<T>> entries,
    required bool isPreviewingVersion,
  }) => showDialog<OcptWorkspaceExportPick<T>>(
    context: context,
    builder: (context) => OcptWorkspaceExportDialog<T>(
      title: title,
      message: message,
      entries: entries,
      isPreviewingVersion: isPreviewingVersion,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return OcptCardChoiceDialog<OcptWorkspaceExportPick<T>>(
      title: title,
      message: message,
      sections: [
        OcptCardChoiceSection<OcptWorkspaceExportPick<T>>(
          entries: [
            for (final entry in entries)
              OcptCardChoiceEntry<OcptWorkspaceExportPick<T>>(
                value: OcptWorkspaceExportDocumentPick<T>(entry.value),
                title: entry.title,
                description: entry.description,
                formatLabel: entry.formatLabel,
                unavailableReason: entry.unavailableReason,
              ),
          ],
        ),
        OcptCardChoiceSection<OcptWorkspaceExportPick<T>>(
          heading: tr.workspaceExportProjectSectionHeading,
          entries: [
            OcptCardChoiceEntry<OcptWorkspaceExportPick<T>>(
              value: OcptWorkspaceExportProjectPackagePick<T>(),
              title: tr.workspaceExportProjectPackageTitle,
              description: tr.workspaceExportProjectPackageDescription,
              formatLabel: ".$ocptPackageFileExtension",
              unavailableReason: isPreviewingVersion
                  ? tr.workspaceExportProjectPackagePreviewReason
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}
