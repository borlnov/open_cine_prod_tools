// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_file_compatibility.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_confirm_dialog.dart';

/// States that a project file was written by a **newer** build of the app, and so has not been
/// opened.
///
/// A dialog rather than a SnackBar, and one with a single button rather than [OcptConfirmDialog]:
/// there is nothing to confirm here and nothing the user can do about it from this build, so what
/// is owed to them is the three facts that let them find the build that *does* open it — the format
/// their file is in, the format this app reads, and the version it was created with. A transient
/// message would take all three away while they were still reading it.
///
/// The file itself is untouched: not opened, not migrated, and not added to the recent projects
/// list. Use [show] to display it; it is dismissed through `OcptRouterManager.pop`, never
/// `Navigator`.
class OcptProjectFileNewerDialog extends StatelessWidget {
  /// What the probe found about the file, which is every word of what this dialog states.
  final OcptProjectFileCompatibility compatibility;

  /// Class constructor
  const OcptProjectFileNewerDialog({super.key, required this.compatibility});

  /// Shows the dialog, and completes once the user has dismissed it.
  static Future<void> show(
    BuildContext context, {
    required OcptProjectFileCompatibility compatibility,
  }) => showDialog<void>(
    context: context,
    builder: (context) => OcptProjectFileNewerDialog(compatibility: compatibility),
  );

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final appVersionAtCreation = compatibility.appVersionAtCreation;

    return AlertDialog(
      title: Text(tr.homeProjectFileNewerTitle),
      content: Text(
        // A file from before `project_info` carried a version — or one whose row can't be read —
        // still gets both format numbers; it is only the sentence naming the build that goes.
        appVersionAtCreation == null
            ? tr.homeProjectFileNewerMessage(
                compatibility.fileSchemaVersion,
                compatibility.appSchemaVersion,
              )
            : tr.homeProjectFileNewerWithAppVersionMessage(
                compatibility.fileSchemaVersion,
                compatibility.appSchemaVersion,
                appVersionAtCreation,
              ),
      ),
      actions: [
        FilledButton(
          onPressed: () => globalGetIt().get<OcptRouterManager>().pop(),
          child: Text(tr.homeProjectFileNewerCloseAction),
        ),
      ],
    );
  }
}
