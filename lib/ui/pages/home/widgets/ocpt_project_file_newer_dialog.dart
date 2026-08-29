// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_file_compatibility.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_file_verdict.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_confirm_dialog.dart';

/// States that a project file has been refused rather than opened, because nothing this build can
/// do brings it in: it was written by a **newer** build ([OcptProjectFileVerdict.newer]), or it
/// sits at this build's own schema but was last written by a different **development** build
/// ([OcptProjectFileVerdict.foreignDevBuild]).
///
/// A dialog rather than a SnackBar, and one with a single button rather than [OcptConfirmDialog]:
/// there is nothing to confirm here and nothing the user can do about it from this build, so what
/// is owed to them is the facts that let them find the build that *does* open it. A transient
/// message would take those away while they were still reading it.
///
/// One widget answers for both verdicts rather than two, since neither is anything to confirm and
/// both close the same way — [build] only picks which title and message [compatibility]'s verdict
/// calls for.
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

    return AlertDialog(
      title: Text(_title(tr)),
      content: Text(_message(tr)),
      actions: [
        FilledButton(
          onPressed: () => globalGetIt().get<OcptRouterManager>().pop(),
          child: Text(tr.homeProjectFileNewerCloseAction),
        ),
      ],
    );
  }

  /// The title stating which of the two refusals this is.
  String _title(Tr tr) => switch (compatibility.verdict) {
    OcptProjectFileVerdict.foreignDevBuild => tr.homeProjectFileForeignDevBuildTitle,
    OcptProjectFileVerdict.newer ||
    OcptProjectFileVerdict.older ||
    OcptProjectFileVerdict.current ||
    OcptProjectFileVerdict.unreadable => tr.homeProjectFileNewerTitle,
  };

  /// The message naming the facts that let the user find the build that opens the file: for
  /// [OcptProjectFileVerdict.foreignDevBuild], the exact development build that wrote it
  /// ([OcptProjectFileCompatibility.migratedByAppVersion], never null for this verdict — see
  /// `OcptProjectFileCompatibilityService`'s decision function); for
  /// [OcptProjectFileVerdict.newer], both format numbers, and the app version the file was created
  /// with when that is known.
  String _message(Tr tr) {
    if (compatibility.verdict == OcptProjectFileVerdict.foreignDevBuild) {
      return tr.homeProjectFileForeignDevBuildMessage(compatibility.migratedByAppVersion!);
    }

    final appVersionAtCreation = compatibility.appVersionAtCreation;
    // A file from before `project_info` carried a version — or one whose row can't be read — still
    // gets both format numbers; it is only the sentence naming the build that goes.
    return appVersionAtCreation == null
        ? tr.homeProjectFileNewerMessage(
            compatibility.fileSchemaVersion,
            compatibility.appSchemaVersion,
          )
        : tr.homeProjectFileNewerWithAppVersionMessage(
            compatibility.fileSchemaVersion,
            compatibility.appSchemaVersion,
            appVersionAtCreation,
          );
  }
}
