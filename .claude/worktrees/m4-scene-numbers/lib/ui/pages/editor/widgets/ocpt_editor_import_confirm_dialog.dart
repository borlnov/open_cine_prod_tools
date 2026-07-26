// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';

/// A dialog confirming that the current screenplay text is about to be replaced by an imported
/// `.fountain` file.
///
/// Use [show] to display it and get back whether the user confirmed the replacement.
class OcptEditorImportConfirmDialog extends StatelessWidget {
  /// Class constructor
  const OcptEditorImportConfirmDialog({super.key});

  /// Shows the dialog and returns true if the user confirmed the replacement, false or null if
  /// they cancelled it.
  static Future<bool?> show(BuildContext context) => showDialog<bool>(
    context: context,
    builder: (context) => const OcptEditorImportConfirmDialog(),
  );

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return AlertDialog(
      title: Text(tr.editorImportConfirmTitle),
      content: Text(tr.editorImportConfirmMessage),
      actions: [
        TextButton(
          onPressed: () => globalGetIt().get<OcptRouterManager>().pop(),
          child: Text(tr.editorImportConfirmCancelAction),
        ),
        FilledButton(
          onPressed: () => globalGetIt().get<OcptRouterManager>().pop<bool>(true),
          child: Text(tr.editorImportConfirmReplaceAction),
        ),
      ],
    );
  }
}
