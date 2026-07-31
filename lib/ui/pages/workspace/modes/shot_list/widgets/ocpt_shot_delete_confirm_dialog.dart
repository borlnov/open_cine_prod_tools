// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';

/// A dialog confirming that a shot is about to be permanently deleted.
///
/// Use [show] to display it and get back whether the user confirmed the deletion. Modelled on
/// `OcptEditorImportConfirmDialog`: dismissed through `OcptRouterManager.pop`, never `Navigator`.
class OcptShotDeleteConfirmDialog extends StatelessWidget {
  /// The `OcptShot.code` of the shot about to be deleted, shown in the confirmation message.
  final String shotCode;

  /// Class constructor
  const OcptShotDeleteConfirmDialog({super.key, required this.shotCode});

  /// Shows the dialog and returns true if the user confirmed the deletion, false or null if they
  /// cancelled it.
  static Future<bool?> show(BuildContext context, {required String shotCode}) => showDialog<bool>(
    context: context,
    builder: (context) => OcptShotDeleteConfirmDialog(shotCode: shotCode),
  );

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return AlertDialog(
      title: Text(tr.shotListDeleteConfirmTitle),
      content: Text(tr.shotListDeleteConfirmMessage(shotCode)),
      actions: [
        TextButton(
          onPressed: () => globalGetIt().get<OcptRouterManager>().pop(),
          child: Text(tr.shotListDeleteConfirmCancelAction),
        ),
        FilledButton(
          onPressed: () => globalGetIt().get<OcptRouterManager>().pop<bool>(true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          child: Text(tr.shotListDeleteConfirmDeleteAction),
        ),
      ],
    );
  }
}
